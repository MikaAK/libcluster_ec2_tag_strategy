defmodule Cluster.Strategy.EC2Tag.Utils do
  require Logger

  @moduledoc false

  def current_hostname do
    # Not sure why but this doesn't have an error case
    {:ok, hostname} = :inet.gethostname()

    to_string(hostname)
  end

  def fetch_instances_from_hosts(hostnames) do
    res = hostnames
      |> Enum.map(&fetch_instances_from_host/1)
      |> reduce_status_tuples

    case res do
      {:ok, hosts} -> {:ok, List.flatten(hosts)}
      {:error, e} ->
        {:error, ErrorMessage.failed_dependency(
          "failed to get instances from hosts",
          %{details: e}
        )}
    end
  end

  def fetch_instances_from_host(hostname) when is_binary(hostname) do
    fetch_instances_from_host(String.to_charlist(hostname))
  end

  def fetch_instances_from_host(hostname) do
    case :net_adm.names(hostname) do
      {:ok, nodes} ->
        {:ok, Enum.map(nodes, fn {name, _port} ->
          :"#{name}@#{hostname}"
        end)}

      {:error, :address} ->
        Logger.debug("[Cluster.Strategy.EC2Tag] EPMD Not online yet for #{hostname}")

        {:ok, []}
    end
  end

  def reduce_status_tuples(status_tuples) do
    {status, res} =
      Enum.reduce(status_tuples, {:ok, []}, fn
        {:ok, _}, {:error, _} = e -> e
        {:ok, record}, {:ok, acc} -> {:ok, [record | acc]}
        {:error, error}, {:ok, _} -> {:error, [error]}
        {:error, e}, {:error, error_acc} -> {:error, [e | error_acc]}
        {:exit, error}, {:ok, _} -> {:error, [error]}
        {:exit, error}, {:error, error_acc} -> {:error, [error | error_acc]}
      end)

    {status, Enum.reverse(res)}
  end
end
