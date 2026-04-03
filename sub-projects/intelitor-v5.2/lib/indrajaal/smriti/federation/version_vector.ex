defmodule Indrajaal.Smriti.Federation.VersionVector do
  @moduledoc """
  Version vectors for causal ordering in distributed SMRITI.

  Implements conflict-free replication per SC-SMRITI-062.
  Each holon mutation increments the local node's counter.
  """

  @type t :: %{String.t() => non_neg_integer()}

  @spec new(String.t()) :: t()
  def new(node_id) do
    %{node_id => 0}
  end

  @spec increment(t(), String.t()) :: t()
  def increment(vv, node_id) do
    Map.update(vv, node_id, 1, &(&1 + 1))
  end

  @spec merge(t(), t()) :: t()
  def merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  @spec descends?(t(), t()) :: boolean()
  def descends?(vv1, vv2) do
    # vv1 descends from vv2 if all counters in vv2 are <= vv1
    Enum.all?(vv2, fn {node, count} ->
      Map.get(vv1, node, 0) >= count
    end)
  end

  @spec concurrent?(t(), t()) :: boolean()
  def concurrent?(vv1, vv2) do
    not descends?(vv1, vv2) and not descends?(vv2, vv1)
  end

  @spec to_string(t()) :: String.t()
  def to_string(vv) do
    vv
    |> Enum.map(fn {node, count} -> "#{String.slice(node, 0, 8)}:#{count}" end)
    |> Enum.join(",")
  end
end
