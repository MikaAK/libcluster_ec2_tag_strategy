defmodule Cluster.Strategy.EC2Tag.BlacklistTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias Cluster.Strategy.EC2Tag.Blacklist

  @node_a :"app_a@host-1"
  @node_b :"app_b@host-2"
  @opts [threshold: 3, retry_interval: 1_000]

  describe "record/5 & partition/3" do
    test "nodes below the failure threshold stay allowed" do
      tracker =
        Blacklist.new()
        |> Blacklist.record([@node_a], [@node_a], 0, @opts)
        |> Blacklist.record([@node_a], [@node_a], 5, @opts)

      assert {[@node_a], []} = Blacklist.partition(tracker, [@node_a], 10)
    end

    test "a node reaching the threshold is blocked until retry_interval passes" do
      tracker = fail_times(Blacklist.new(), @node_a, 3)

      assert {[], [@node_a]} = Blacklist.partition(tracker, [@node_a], 500)
      assert {[@node_a], []} = Blacklist.partition(tracker, [@node_a], 1_500)
    end

    test "a successful connect clears failures and blacklist" do
      tracker =
        Blacklist.new()
        |> fail_times(@node_a, 3)
        |> Blacklist.record([@node_a], [], 1_500, @opts)

      assert {[@node_a], []} = Blacklist.partition(tracker, [@node_a], 1_600)
      assert tracker.failures === %{}
      assert tracker.blacklist === %{}
    end

    test "a failed probe re-blacklists immediately" do
      tracker =
        Blacklist.new()
        |> fail_times(@node_a, 3)
        |> Blacklist.record([@node_a], [@node_a], 2_000, @opts)

      assert {[], [@node_a]} = Blacklist.partition(tracker, [@node_a], 2_500)
      assert {[@node_a], []} = Blacklist.partition(tracker, [@node_a], 3_100)
    end

    test "only failing nodes are tracked, healthy nodes are untouched" do
      tracker = Blacklist.record(Blacklist.new(), [@node_a, @node_b], [@node_a], 0, @opts)

      assert tracker.failures === %{@node_a => 1}
      assert {[@node_a, @node_b], []} = Blacklist.partition(tracker, [@node_a, @node_b], 1)
    end

    test "threshold :infinity disables blacklisting" do
      opts = [threshold: :infinity, retry_interval: 1_000]

      tracker =
        Enum.reduce(1..50, Blacklist.new(), fn attempt, acc ->
          Blacklist.record(acc, [@node_a], [@node_a], attempt, opts)
        end)

      assert {[@node_a], []} = Blacklist.partition(tracker, [@node_a], 100)
      assert tracker.blacklist === %{}
    end
  end

  describe "prune/2" do
    test "drops state for nodes no longer discovered" do
      tracker =
        Blacklist.new()
        |> fail_times(@node_a, 3)
        |> Blacklist.record([@node_b], [@node_b], 0, @opts)
        |> Blacklist.prune([@node_b])

      assert tracker.failures === %{@node_b => 1}
      assert tracker.blacklist === %{}
    end
  end

  defp fail_times(tracker, node, count) do
    Enum.reduce(1..count, tracker, fn attempt, acc ->
      Blacklist.record(acc, [node], [node], attempt, @opts)
    end)
  end
end
