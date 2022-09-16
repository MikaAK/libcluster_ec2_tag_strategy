defmodule Cluster.Strategy.EC2Tag.Utils do
  @moduledoc false

  def current_hostname do
    String.trim_trailing(to_string(:net_adm.localhost()), ".lan")
  end

  def fetch_instances_from_hosts(hostnames) do
    res = hostnames
      |> Enum.map(&fetch_instances_from_host/1)
      |> reduce_status_tuples

    with {:ok, hosts} <- res do
      {:ok, List.flatten(hosts)}
    end
  end

  def fetch_instances_from_host(hostname) when is_binary(hostname) do
    fetch_instances_from_host(String.to_charlist(hostname))
  end

  def fetch_instances_from_host(hostname) do
    with {:ok, nodes} <- :net_adm.names(hostname) do
      {:ok, Enum.map(nodes, fn {name, _port} ->
        :"#{name}@#{hostname}"
      end)}
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
