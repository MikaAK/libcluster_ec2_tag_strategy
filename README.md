# LibCluster Cluster.Strategy.EC2Tag
This clustering strategy relies on Amazon EC2 Tags as well as EPMD to find hosts, and then uses
the `:net_adm` module to connect to nodes on those hosts

***Note: This module requires [ExAws](https://github.com/ex-aws/ex_aws) to be configured***

## Installation

[Available in Hex](https://hex.pm/docs/libcluster_ec2_taag_strategy), the package can be installed
by adding `libcluster_ec2_tag_strategy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_ec2_tag_strategy, "~> 0.1.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/libcluster_ec2_tag_strategy>.


## Usage
You can have LibCluster automatically connect to nodes that match tags and setup multiple
topologies:

```elixir
config :libcluster, :topologies, [
  frontend_nodes: [
    strategy: Cluster.Strategy.EC2Tag,
    config: [
      tag_name: "Backend Group",
      tag_value: ~r/(user|account) Frontend/i,
      filter_fn: {MyHelper, :filter_instances}
    ]
  ],

  data_nodes: [
    strategy: Cluster.Strategy.EC2Tag,
    config: [
      tag_name: "Backend Group",
      tag_value: "Data Nodes",
      region: "us-east-2",
      filter_node_names: {MyHelper, :filter_node_names}
    ]
  ],

  some_other_nodes: [
    strategy: Cluster.Strategy.EC2Tag,
    config: [
      tag_name: "Backend Group",
      tag_value: "Extra Nodes",
      region: "us-east-2",
      host_name_fn: {MyHelper, :host_name}
    ]
  ]
]
```

```elixir
defmodule MyHelper do
  def filter_instances(%{"tagSet" => %{"item" => tags}}) do
    case Enum.find(tags, &(&1["name"] === "Name")) do
      nil -> false
      %{"value" => value} -> value === "Learn Elixir Lander"
    end
  end

  def filter_node_names(node) do
    node =~ "my_node@host-00.&"
  end

  # This comes from ExAws.EC2 describe_instances
  # By default we use the `instanceId`
  def host_name(ec2_instance) do
    ec2_instance["privateDns"]
  end
end
```
