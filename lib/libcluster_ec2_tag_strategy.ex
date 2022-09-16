defmodule Cluster.Strategy.EC2Tag do
  @moduledoc "#{File.read!(\"./README.md\")}"

  require Logger

  use Cluster.Strategy

  alias Cluster.Strategy.State

  alias Cluster.Strategy.EC2Tag.{Utils, AwsInstanceFetcher}

  @default_interval :timer.seconds(5)

  def start_link([]) do
    Logger.warn("No topologies setup for LibCluster EC2Tag strategy")

    :ignore
  end

  def start_link(topologies) do
    Enum.each(topologies, fn %State{config: config} ->
      validate_config!(config)
    end)

    case Enum.find(topologies, &current_node_in_tag?/1) do
      nil ->
        Logger.warn("Current node doesn't have any tag name/value pairs that match one of the topologies")

        :ignore

      topology -> Task.start_link(fn -> run_loop(topology) end)
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
    case AwsInstanceFetcher.find_hosts_by_tag(
      config[:region],
      config[:tag_name],
      config[:tag_value],
      config[:host_name_fn]
    ) do
      {:ok, []} -> false
      {:ok, hosts} -> Utils.current_hostname() in hosts

      {:error, e} ->
        Logger.error("Error fetching hosts by tag from amazon\n#{inspect e, pretty: true}")

        false
    end
  end

  defp run_loop(%State{config: config} = state) do
    attempt_to_connect_to_hosts_by_tag(
      state,
      config[:region],
      config[:tag_name],
      config[:tag_value]
    )

    Process.sleep(config[:check_interval] || @default_interval)
    run_loop(state)
  end

  defp attempt_to_connect_to_hosts_by_tag(state, region, tag_name, tag_value) do
    with {:ok, hosts} when hosts !== [] <- AwsInstanceFetcher.find_hosts_by_tag(region, tag_name, tag_value),
         {:ok, nodes} <- Utils.fetch_instances_from_host(hostname) do
      Cluster.Strategy.connect_nodes(state.topology, state.connect_nodes, state.list_nodes, nodes)
    else
      {:ok, []} ->
        Logger.error("Cannot find hosts to connect to with the tag name of #{tag_name} and the value of #{tag_value}")

      {:error, e} ->
        Logger.error("Cannot find hosts to connect to with the tag name of #{tag_name} and the value of #{tag_value}\n#{inspect e, pretty: true}")
    end
  end
end
