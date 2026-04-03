defmodule Indrajaal.Mesh.HolonPhenotype do
  @moduledoc """
  HolonPhenotype - Runtime state (mutable).
  Represents the current "expression" of the holon.
  Mirrors F# Cepaf.Mesh.HolonPhenotype.

  ## STAMP Compliance
  - SC-SIL4-012: 5 Startup Phases
  - SC-SIL4-013: 6 Shutdown Phases
  """

  @enforce_keys [:genotype_id]
  defstruct [
    :genotype_id,
    :container_id,
    :pid,
    health: :unknown,
    startup_phase: :not_started,
    shutdown_phase: :running,
    diagnostic_coverage: 0.0,
    proof_token: "UNVERIFIED",
    started_at: nil,
    last_health_check: nil,
    last_heartbeat: nil,
    active_connections: 0,
    errors: [],
    metrics: %{}
  ]

  @type health ::
          :unknown
          | :starting
          | :healthy
          | :unhealthy
          | :lameduck
          | :stopping
          | :stopped
          | {:failed, String.t()}

  @type startup_phase ::
          :not_started
          | :preflight
          | :port_scour
          | :dependency_check
          | :booting
          | :health_check
          | :ready
          | {:failed_startup, String.t()}

  @type shutdown_phase ::
          :running
          | {:pre_shutdown, DateTime.t()}
          | {:draining, integer(), DateTime.t()}
          | {:stopping, DateTime.t()}
          | :killing
          | {:terminated, integer()}

  @type t :: %__MODULE__{
          genotype_id: String.t(),
          container_id: String.t() | nil,
          pid: integer() | nil,
          health: health(),
          startup_phase: startup_phase(),
          shutdown_phase: shutdown_phase(),
          diagnostic_coverage: float(),
          proof_token: String.t(),
          started_at: DateTime.t() | nil,
          last_health_check: DateTime.t() | nil,
          last_heartbeat: DateTime.t() | nil,
          active_connections: non_neg_integer(),
          errors: [String.t()],
          metrics: %{String.t() => float()}
        }
end
