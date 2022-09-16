defmodule Cluster.Strategy.EC2Tag.AwsInstanceFetcher do
  def find_hosts_by_tag(region, tag_name, tag_value, node_name_fn \\ &(&1["instanceId"])) do
    with {:ok, instances} <- fetch_aws_instances(region) do
      instances
        |> Enum.filter(fn %{"tagSet" => %{"item" => tags}} ->
           Enum.any?(tags, fn
            %{"key" => ^tag_name, "value" => ^tag_value} -> true
            %{"key" => ^tag_name, "value" => value} when is_list(tag_value) -> value in tag_value
            %{"key" => ^tag_name, "value" => value} when is_struct(tag_value, Regex) -> Regex.match?(tag_value, value)
            _ -> false
          end)
        end)
        |> Enum.map(node_name_fn)
        |> then(&{:ok, &1})
    end
  end

  defp fetch_aws_instances(region) do
    ExAws.EC2.describe_instances()
      |> ex_aws_request(region)
      |> handle_describe_response
  end

  defp ex_aws_request(request_struct, nil) do
    ExAws.request(request_struct)
  end

  defp ex_aws_request(request_struct, region) do
    ExAws.request(request_struct, region: region)
  end

  defp handle_describe_response({:error, {:http_error, status_code, %{body: body}}}) do
    {:error, apply(ErrorMessage, ErrorMessage.http_code_reason_atom(status_code), [
      "error with fetching from aws",
      %{error_body: body}
    ])}
  end

  defp handle_describe_response({:ok, %{body: body}}) do
    case XmlToMap.naive_map(body) do
      %{"DescribeInstancesResponse" => %{"reservationSet" => %{"item" => items}}} ->
        {:ok, Enum.map(items, fn %{"instancesSet" => %{"item" => item}} -> item end)}

      structure ->
        {:error, ErrorMessage.bad_request(
          "couldn't parse the structure from aws correctly",
          %{structure: structure}
        )}
    end
  end
end
