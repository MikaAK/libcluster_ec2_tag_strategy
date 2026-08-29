defmodule Cluster.Strategy.EC2Tag do
  @moduledoc "#{File.read!("./README.md")}"

  require Logger

  use Cluster.Strategy

  alias Cluster.Strategy.State

  alias Cluster.Strategy.EC2Tag.{Utils, AwsInstanceFetcher, Blacklist}

  @default_interval :timer.seconds(5)
  @default_connect_failure_threshold 5
  @default_blacklist_retry_interval :timer.minutes(1)

  def start_link([]) do
    Logger.warning("No topologies setup for LibCluster EC2Tag strategy")

    :ignore
  end

  def start_link(topologies) do
    Enum.each(topologies, fn %State{config: config} ->
      validate_config!(config)
    end)

    case Enum.find(topologies, &current_node_in_tag?/1) do
      nil ->
        Logger.warning("[Cluster.Strategy.EC2Tag] Current node doesn't have any tag name/value pairs that match one of the topologies")

        :ignore

      topology -> Task.start_link(fn -> run_loop(topology, Blacklist.new()) end)
    end
  end

  defp validate_config!(config) do
    if is_nil(config[:tag_name]) do
      raise "Must set :tag_name in topology config for Cluster.Strategy.EC2Tag"
    end

    if is_nil(config[:tag_value]) do
      raise "Must set :tag_value in topology config for Cluster.Strategy.EC2Tag"
    end
  end

  defp current_node_in_tag?(%State{config: config}) do
    case find_hosts_by_tag_for_config(config) do
      {:ok, []} -> false

      {:ok, hosts} ->
        # Utils.current_hostname/1 might return hostname with format like this:
        # ip-10-0-1-1
        # But hosts' format could be ip-10-0-1-1.ap-southeast-2.compute.internal
        # So needs to check if the hosts contains any hostname that starts
        # with ip-10-0-1-1
        hostname = Utils.current_hostname()
        Enum.any?(hosts, &String.starts_with?(&1, hostname))

      {:error, e} ->
        Logger.error("[Cluster.Strategy.EC2Tag] Error fetching hosts by tag from amazon\n#{inspect e, pretty: true}")

        false
    end
  end

  defp run_loop(%State{config: config} = state, blacklist) do
    blacklist = attempt_to_connect_to_hosts_by_tag(state, blacklist)

    Process.sleep(config[:check_interval] || @default_interval)
    run_loop(state, blacklist)
  end

  defp attempt_to_connect_to_hosts_by_tag(%State{
    config: config,
    topology: topology,
    connect: connect,
    list_nodes: list_nodes
  }, blacklist) do
    with {:ok, hosts} <- find_hosts_by_tag_for_config(config),
         {:ok, nodes} <- Utils.fetch_instances_from_hosts(hosts) do
      nodes = maybe_filter_node_names(nodes, config[:filter_node_name])
      now = System.monotonic_time(:millisecond)
      blacklist = Blacklist.drop_undiscovered_nodes(blacklist, nodes)
      {allowed, blocked} = Blacklist.split_into_allowed_and_blocked(blacklist, nodes, now)

      if not Enum.empty?(blocked) do
        Logger.debug("[Cluster.Strategy.EC2Tag] Skipping blacklisted nodes: #{inspect(blocked)}")
      end

      failed_nodes =
        case Cluster.Strategy.connect_nodes(topology, connect, list_nodes, allowed) do
          :ok -> []
          {:error, bad_nodes} -> Enum.map(bad_nodes, fn {node, _reason} -> node end)
        end

      Blacklist.record_connect_results(blacklist, allowed, failed_nodes, now,
        threshold: config[:connect_failure_threshold] || @default_connect_failure_threshold,
        retry_interval: config[:blacklist_retry_interval] || @default_blacklist_retry_interval
      )
    else
      {:ok, []} ->
        Logger.error("[Cluster.Strategy.EC2Tag] Cannot find hosts to connect to with the tag name of #{config[:tag_name]} and the value of #{config[:tag_value]}")

        blacklist

      {:error, e} ->
        Logger.error("[Cluster.Strategy.EC2Tag] Error finding hosts for #{config[:tag_name]} with value of #{config[:tag_value]}\n#{inspect e, pretty: true}")

        blacklist
    end
  end

  defp maybe_filter_node_names(nodes, nil) do
    nodes
  end

  defp maybe_filter_node_names(nodes, {module, function_name}) do
    apply(module, function_name, [nodes])
  end

  defp find_hosts_by_tag_for_config(config) do
    AwsInstanceFetcher.find_hosts_by_tag(
      config[:region],
      config[:tag_name],
      config[:tag_value],
      config[:host_name_fn],
      config[:filter_fn]
    )
  end
end
