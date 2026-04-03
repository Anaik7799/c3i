defmodule Indrajaal.Smriti.Federation.ReplicationEngine do
  @moduledoc """
  Core engine for reconciling state between nodes using Version Vectors.
  Replaces basic conflict detection with full CRDT-style resolution.
  """
  alias Indrajaal.Smriti.Federation.VersionVector

  @doc """
  Calculates the delta between local and remote version vectors.
  Returns map of node IDs that need updating.
  """
  def calculate_delta(local_vv, remote_vv) do
    Enum.reduce(remote_vv, %{}, fn {node, ver}, acc ->
      local_ver = Map.get(local_vv, node, 0)

      if ver > local_ver do
        Map.put(acc, node, ver)
      else
        acc
      end
    end)
  end

  @doc """
  Resolves state between two version vectors.
  Returns:
  - {:synced, vv} if identical
  - {:update_required, delta} if remote > local
  - {:up_to_date, local} if local > remote
  - {:conflict, {local, remote}} if concurrent
  """
  def resolve_state(local_vv, remote_vv) do
    cond do
      local_vv == remote_vv ->
        {:synced, local_vv}

      VersionVector.descends?(remote_vv, local_vv) ->
        {:update_required, calculate_delta(local_vv, remote_vv)}

      VersionVector.descends?(local_vv, remote_vv) ->
        {:up_to_date, local_vv}

      true ->
        {:conflict, {local_vv, remote_vv}}
    end
  end
end
