defmodule Indrajaal.Mesh.StateCheckpoint do
  @moduledoc """
  StateCheckpoint - Snapshot of mesh state for recovery.
  Mirrors F# Cepaf.Mesh.StateCheckpoint.

  ## STAMP Compliance
  - SC-SIL4-004: Checkpoint on shutdown
  - SC-SIL4-007: Dying gasp mandatory
  """

  alias Indrajaal.Mesh.HolonPhenotype

  @enforce_keys [:id, :timestamp, :state_hash, :holons]
  defstruct [
    :id,
    :timestamp,
    :state_hash,
    :holons,
    active_operations: [],
    pending_writes: [],
    reason: "unknown"
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          timestamp: DateTime.t(),
          state_hash: String.t(),
          holons: %{String.t() => HolonPhenotype.t()},
          active_operations: [String.t()],
          pending_writes: [{String.t(), binary()}],
          reason: String.t()
        }
end
