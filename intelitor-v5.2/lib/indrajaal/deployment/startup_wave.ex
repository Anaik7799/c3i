defmodule Indrajaal.Deployment.StartupWave do
  @moduledoc """
  Represents a single wave of containers to start in parallel.
  Containers in the same wave have no dependencies on each other.
  """
  @enforce_keys [:order, :containers]
  defstruct [:order, :containers, :timeout_ms, :jitter_enabled]

  @type t :: %__MODULE__{
          order: pos_integer(),
          containers: [String.t()],
          timeout_ms: non_neg_integer(),
          jitter_enabled: boolean()
        }
end
