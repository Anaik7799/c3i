# lib/indrajaal/kms/federation/version_vector.ex
defmodule Indrajaal.KMS.Federation.VersionVector do
  @moduledoc """
  Version vectors for causal ordering in distributed SMRITI.
  STAMP: SC-SMRITI-062
  """
  @type t :: %{String.t() => non_neg_integer()}

  def new(node_id), do: %{node_id => 0}

  def increment(vv, node_id) do
    Map.update(vv, node_id, 1, &(&1 + 1))
  end

  def merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  def descends?(vv1, vv2) do
    Enum.all?(vv2, fn {node, count} -> Map.get(vv1, node, 0) >= count end)
  end

  def concurrent?(vv1, vv2), do: not descends?(vv1, vv2) and not descends?(vv2, vv1)
end
