defmodule Indrajaal.Cockpit.Prajna.Bio.Types do
  @moduledoc """
  ## Biological Type Definitions

  Core data structures for the PRAJNA v2.0 Biomorphic Architecture.
  """

  defmodule GeneticPayload do
    @moduledoc """
    Self-describing message envelope supporting schema evolution.
    """
    @type t :: %__MODULE__{
            id: String.t(),
            timestamp: DateTime.t(),
            genome_hash: String.t(),
            dna: map(),
            markers: list(atom()),
            signature: String.t() | nil
          }

    defstruct [
      :id,
      :timestamp,
      :genome_hash,
      :dna,
      :markers,
      :signature
    ]
  end

  defmodule VitalSigns do
    @moduledoc """
    Standardized state vector exposed by every Holon.
    """
    @type t :: %__MODULE__{
            health: float(),
            stress: float(),
            energy: float(),
            age: non_neg_integer(),
            generation: non_neg_integer(),
            intent: atom()
          }

    defstruct [
      :health,
      :stress,
      :energy,
      :age,
      :generation,
      :intent
    ]
  end
end
