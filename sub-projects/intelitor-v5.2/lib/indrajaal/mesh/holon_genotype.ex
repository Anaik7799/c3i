defmodule Indrajaal.Mesh.HolonGenotype do
  @moduledoc """
  HolonGenotype - Static configuration (immutable).
  Represents the "DNA" of a container in the mesh.
  Mirrors F# Cepaf.Mesh.HolonGenotype.

  ## STAMP Compliance
  - SC-SIL4-001: Static configuration must be immutable
  - SC-CLU-002: Fractal-cluster topology definition
  """

  @derive Jason.Encoder
  @enforce_keys [:id, :name, :role, :image]
  defstruct [
    :id,
    :name,
    :role,
    :image,
    ports: [],
    environment: %{},
    after: [],
    requires: [],
    wants: [],
    health_check: nil,
    health_interval_ms: 5000,
    memory_mb: 512,
    cpu_limit: 1.0,
    network: "indrajaal-net",
    ip_address: nil,
    start_delay_ms: 0,
    max_jitter_ms: 0
  ]

  @type role :: :primary | :seed | :satellite | :controller | :worker

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          role: role(),
          image: String.t(),
          ports: [{pos_integer(), pos_integer()}],
          environment: %{String.t() => String.t()},
          after: [String.t()],
          requires: [String.t()],
          wants: [String.t()],
          health_check: String.t() | nil,
          health_interval_ms: non_neg_integer(),
          memory_mb: pos_integer(),
          cpu_limit: float(),
          network: String.t(),
          ip_address: String.t() | nil,
          start_delay_ms: non_neg_integer(),
          max_jitter_ms: non_neg_integer()
        }
end
