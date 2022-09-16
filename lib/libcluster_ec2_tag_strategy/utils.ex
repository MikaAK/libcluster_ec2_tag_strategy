defmodule Cluster.Strategy.EC2Tag.Utils do
  defp current_hostname do
    String.trim_trailing(to_string(:net_adm.localhost()), ".lan")
  end

  defp fetch_instances_from_host(hostname) when is_binary(hostname) do
    fetch_instances_from_host(String.to_charlist(hostname))
  end

  defp fetch_instances_from_host(hostname) do
    with {:ok, nodes} <- :net_adm.names(charlist) do
      {:ok, Enum.map(nodes, fn {name, _port} ->
        :"#{name}@#{hostname}"
      end)}
    end
  end
end
