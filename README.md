# LibCluster Cluster.Strategy.EC2Tag
This clustering strategy relies on Amazon EC2 Tags as well as EPMD to find hosts, and then uses
the `:net_adm` module to connect to nodes on those hosts.

It also supports setting multiple toplogies, and will choose which one to use based off the current
host_name and tags found. For example if your current node has the tags that match one topology, they
will be considered to be part of that topology and attempt to connect into that mesh

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

## Connect-failure blacklist

Nodes that repeatedly fail to connect (wrong Erlang cookie, blocked
distribution port, foreign cluster sharing the same EC2 tag) are temporarily
blacklisted instead of being re-dialed every poll cycle. This prevents log
floods from rejected handshakes and keeps `:global`'s overlapping-partition
prevention from churning on permanently half-connected nodes.

After `:connect_failure_threshold` consecutive failures (default `5`) a node
is skipped for `:blacklist_retry_interval` ms (default one minute), then
probed again — one failed probe re-blacklists it, a successful connect clears
it. Blacklisting only gates outbound dial attempts; established connections
are never touched.

```elixir
config :libcluster, :topologies,
  my_nodes: [
    strategy: Cluster.Strategy.EC2Tag,
    config: [
      tag_name: "Group",
      tag_value: "My Backend",

      # optional — defaults shown
      connect_failure_threshold: 5,          # :infinity disables blacklisting
      blacklist_retry_interval: :timer.minutes(1)
    ]
  ]
```
