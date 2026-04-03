defmodule Indrajaal.Mesh.TopologyCache do
  @moduledoc """
  TopologyCache - Validated startup order cache.
  Mirrors F# Cepaf.Mesh.TopologyCache.

  ## STAMP Compliance
  - SC-SIL4-005: DAG validated on boot
  - AOR-SIL4-001: Deterministic boot sequence
  """

  alias Indrajaal.Deployment.StartupWave

  @enforce_keys [:version, :config_hash, :start_order, :shutdown_order, :created_at]
  defstruct [
    :version,
    :config_hash,
    :start_order,
    :shutdown_order,
    :created_at,
    :validated_at,
    is_valid: false
  ]

  @type t :: %__MODULE__{
          version: String.t(),
          config_hash: String.t(),
          start_order: [StartupWave.t()],
          shutdown_order: [StartupWave.t()],
          created_at: DateTime.t(),
          validated_at: DateTime.t() | nil,
          is_valid: boolean()
        }
end
