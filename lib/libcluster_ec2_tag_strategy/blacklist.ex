defmodule Cluster.Strategy.EC2Tag.Blacklist do
  @moduledoc """
  Tracks repeated connect failures per node and temporarily removes failing
  nodes from the dial list.

  A node that fails `:connect_failure_threshold` consecutive connect attempts
  is blacklisted for `:blacklist_retry_interval` milliseconds. Once the
  interval expires the node is allowed through again on the next cycle as a
  probe: a successful connect clears all state for the node, another failure
  re-blacklists it immediately (the failure count is retained while
  blacklisted).

  This keeps a foreign or misconfigured node (wrong Erlang cookie, blocked
  distribution port) from being hammered every poll cycle forever, which both
  floods logs with handshake rejections and can feed `:global`'s
  overlapping-partition prevention with permanently half-connected views.
  """

  require Logger

  defstruct failures: %{}, blacklist: %{}

  @type t :: %__MODULE__{
    failures: %{node() => pos_integer()},
    blacklist: %{node() => integer()}
  }

  def new, do: %__MODULE__{}

  @doc """
  Drops tracking state for nodes that are no longer discovered, so the maps
  cannot grow unbounded as instances come and go.
  """
  def prune(%__MODULE__{failures: failures, blacklist: blacklist}, discovered_nodes) do
    %__MODULE__{
      failures: Map.take(failures, discovered_nodes),
      blacklist: Map.take(blacklist, discovered_nodes)
    }
  end

  @doc """
  Splits candidate nodes into `{allowed, blocked}`. Blacklisted nodes whose
  retry time has passed are allowed through as probes.
  """
  def partition(%__MODULE__{blacklist: blacklist}, nodes, now) do
    Enum.split_with(nodes, fn node ->
      case Map.get(blacklist, node) do
        nil -> true
        retry_at -> now >= retry_at
      end
    end)
  end

  @doc """
  Records the outcome of a connect cycle. `attempted` is every node that was
  dialed this cycle, `failed_nodes` the subset that failed to connect.

  Options:

    * `:threshold` - consecutive failures before a node is blacklisted.
      Pass `:infinity` to disable blacklisting.
    * `:retry_interval` - milliseconds a blacklisted node is skipped before
      the next probe.
  """
  def record(%__MODULE__{} = tracker, attempted, failed_nodes, now, opts) do
    failed = MapSet.new(failed_nodes)

    Enum.reduce(attempted, tracker, fn node, acc ->
      if MapSet.member?(failed, node) do
        record_failure(acc, node, now, opts[:threshold], opts[:retry_interval])
      else
        clear(acc, node)
      end
    end)
  end

  defp record_failure(tracker, node, now, threshold, retry_interval) do
    count = Map.get(tracker.failures, node, 0) + 1
    tracker = %{tracker | failures: Map.put(tracker.failures, node, count)}

    if is_integer(threshold) and count >= threshold do
      Logger.warning(
        "[Cluster.Strategy.EC2Tag] Blacklisting #{node} after #{count} failed connect attempts, retrying in #{retry_interval}ms"
      )

      %{tracker | blacklist: Map.put(tracker.blacklist, node, now + retry_interval)}
    else
      tracker
    end
  end

  defp clear(tracker, node) do
    %__MODULE__{
      failures: Map.delete(tracker.failures, node),
      blacklist: Map.delete(tracker.blacklist, node)
    }
  end
end
