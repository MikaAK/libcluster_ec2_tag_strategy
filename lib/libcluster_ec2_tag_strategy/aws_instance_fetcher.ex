defmodule Cluster.Strategy.EC2Tag.AwsInstanceFetcher do
  @moduledoc false

  def find_hosts_by_tag(region, tag_name, tag_value, host_name_fn, filter_fn) do
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
        |> maybe_filter_by_option(filter_fn)
        |> Enum.map(host_name_fn || &(&1["instanceId"]))
        |> then(&{:ok, &1})
    end
  end

  defp fetch_aws_instances(region) do
    ExAws.EC2.describe_instances()
      |> ex_aws_request(region)
      |> handle_describe_response
  end

  defp maybe_filter_by_option(instances, nil) do
    instances
  end

  defp maybe_filter_by_option(instances, filter_fn) when is_function(filter_fn, 1) do
    Enum.filter(instances, filter_fn)
  end

  defp maybe_filter_by_option(_instances, _) do
    raise "For some reason, :filter_fn being passed to Cluster.Strategy.EC2Tag is not a single arity function"
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
