defmodule Indrajaal.Core.Holon.State do
  @moduledoc """
  Holon State Management - Immutable State for v20.0.0

  Manages the internal state of a holon including:
  1. VSM system states (S1-S5)
  2. Structural relationships (parent, children)
  3. Health metrics
  4. Operational metadata

  ## State Invariants
  - State MUST be immutable (all updates return new state)
  - VSM states MUST be independently updatable
  - Health MUST be derivable from VSM states
  - Parent/child relationships MUST be consistent

  ## STAMP Constraints
  - SC-STATE-001: State updates MUST be atomic
  - SC-STATE-002: State MUST include constitution hash
  - SC-STATE-003: State transitions MUST be logged
  """

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Constitution.Hash

  @type t :: %__MODULE__{
          id: Holon.holon_id(),
          layer: Holon.layer(),
          parent: Holon.holon_id() | nil,
          children: [Holon.holon_id()],
          health: Holon.health(),
          vsm: Holon.vsm_state(),
          constitution_hash: binary(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          metadata: map()
        }

  defstruct [
    :id,
    :layer,
    :parent,
    children: [],
    health: :healthy,
    vsm: %{s1: %{}, s2: %{}, s3: %{}, s4: %{}, s5: %{}},
    constitution_hash: <<>>,
    created_at: nil,
    updated_at: nil,
    metadata: %{}
  ]

  @doc """
  Creates a new holon state.
  """
  @spec new(module(), Holon.layer(), Keyword.t()) :: t()
  def new(module, layer, opts \\ []) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: to_string(module),
      layer: layer,
      parent: Keyword.get(opts, :parent),
      children: Keyword.get(opts, :children, []),
      health: :healthy,
      vsm: initial_vsm_state(),
      constitution_hash: Hash.compute(),
      created_at: now,
      updated_at: now,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Updates the S1 (Operations) state.
  """
  @spec update_s1(t(), map()) :: t()
  def update_s1(%__MODULE__{vsm: vsm} = state, s1_update) do
    new_vsm = %{vsm | s1: Map.merge(vsm.s1, s1_update)}
    %{state | vsm: new_vsm, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the S2 (Coordination) state.
  """
  @spec update_s2(t(), map()) :: t()
  def update_s2(%__MODULE__{vsm: vsm} = state, s2_update) do
    new_vsm = %{vsm | s2: Map.merge(vsm.s2, s2_update)}
    %{state | vsm: new_vsm, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the S3 (Control) state.
  """
  @spec update_s3(t(), map()) :: t()
  def update_s3(%__MODULE__{vsm: vsm} = state, s3_update) do
    new_vsm = %{vsm | s3: Map.merge(vsm.s3, s3_update)}
    %{state | vsm: new_vsm, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the S4 (Intelligence) state.
  """
  @spec update_s4(t(), map()) :: t()
  def update_s4(%__MODULE__{vsm: vsm} = state, s4_update) do
    new_vsm = %{vsm | s4: Map.merge(vsm.s4, s4_update)}
    %{state | vsm: new_vsm, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the S5 (Policy) state.
  """
  @spec update_s5(t(), map()) :: t()
  def update_s5(%__MODULE__{vsm: vsm} = state, s5_update) do
    new_vsm = %{vsm | s5: Map.merge(vsm.s5, s5_update)}
    %{state | vsm: new_vsm, updated_at: DateTime.utc_now()}
  end

  @doc """
  Updates the health status.
  """
  @spec update_health(t(), Holon.health()) :: t()
  def update_health(%__MODULE__{} = state, health) do
    %{state | health: health, updated_at: DateTime.utc_now()}
  end

  @doc """
  Adds a child holon.
  """
  @spec add_child(t(), Holon.holon_id()) :: t()
  def add_child(%__MODULE__{children: children} = state, child_id) do
    if child_id in children do
      state
    else
      %{state | children: [child_id | children], updated_at: DateTime.utc_now()}
    end
  end

  @doc """
  Removes a child holon.
  """
  @spec remove_child(t(), Holon.holon_id()) :: t()
  def remove_child(%__MODULE__{children: children} = state, child_id) do
    %{state | children: List.delete(children, child_id), updated_at: DateTime.utc_now()}
  end

  @doc """
  Derives health from VSM states.

  Health is determined by:
  - S5 violations → :failed
  - S3 over budget → :critical
  - S2 oscillation → :degraded
  - Otherwise → :healthy
  """
  @spec derive_health(t()) :: Holon.health()
  def derive_health(%__MODULE__{vsm: vsm}) do
    cond do
      Map.get(vsm.s5, :violated, false) -> :failed
      Map.get(vsm.s3, :over_budget, false) -> :critical
      Map.get(vsm.s2, :oscillating, false) -> :degraded
      true -> :healthy
    end
  end

  @doc """
  Updates health based on current VSM state.
  """
  @spec refresh_health(t()) :: t()
  def refresh_health(%__MODULE__{} = state) do
    update_health(state, derive_health(state))
  end

  @doc """
  Returns a summary of the state for logging/debugging.
  """
  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = state) do
    %{
      id: state.id,
      layer: state.layer,
      health: state.health,
      children_count: length(state.children),
      has_parent: not is_nil(state.parent),
      age_seconds: DateTime.diff(DateTime.utc_now(), state.created_at)
    }
  end

  # Private

  defp initial_vsm_state do
    %{
      s1: %{operations_count: 0, last_operation: nil},
      s2: %{peers: [], oscillating: false},
      s3: %{budget: %{}, usage: %{}, over_budget: false},
      s4: %{observations: [], plans: [], confidence: 0.0},
      s5: %{verified: true, violated: false, last_check: nil}
    }
  end
end
