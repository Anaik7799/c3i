defmodule Indrajaal.Substrate.L5.LegacyPreserver do
  @moduledoc """
  ## Design Intent
  L5 substrate legacy preserver — pure functional module that maintains
  historical continuity by tracking version lineage and detecting breaks
  in the evolutionary chain.

  Biological metaphor: epigenetic memory — certain traits are preserved
  across generations regardless of current selection pressure. The preserver
  ensures no evolutionary transition erases foundational capabilities.

  Algorithm:
    - Maintains an ordered list of version records (newest first).
    - Each version record: `{id, capabilities, timestamp, parent_id}`.
    - `record_version/2` appends a new version linked to its parent.
    - `continuity_check/2` verifies that required capabilities are preserved
      across the transition from parent to child.
    - Lineage depth = number of versions in the chain.
    - Gaps are detected when a version's `parent_id` does not match any
      recorded version's `id`.

  ## STAMP Constraints
  - SC-S5-001: Cybernetic VSM S5 policy — ENFORCED
  - SC-SMRITI-141: Lineage chain unbroken — ENFORCED
  - SC-SMRITI-142: Evolution history append-only — REFERENCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type version_record :: %{
          id: String.t(),
          capabilities: MapSet.t(),
          timestamp: integer(),
          parent_id: String.t() | nil
        }

  @type continuity_result :: %{
          continuous: boolean(),
          dropped_capabilities: [atom()],
          added_capabilities: [atom()]
        }

  @type t :: %__MODULE__{
          versions: [version_record()],
          protected_capabilities: MapSet.t(),
          gap_count: non_neg_integer()
        }

  defstruct versions: [],
            protected_capabilities: MapSet.new(),
            gap_count: 0

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new LegacyPreserver.

  Options:
    - `:protected_capabilities` — list of capability atoms that MUST be
      preserved across all version transitions (default `[]`).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    protected = Keyword.get(opts, :protected_capabilities, [])

    cond do
      not is_list(protected) ->
        {:error, "protected_capabilities must be a list of atoms"}

      not Enum.all?(protected, &is_atom/1) ->
        {:error, "all protected_capabilities must be atoms"}

      true ->
        {:ok, %__MODULE__{protected_capabilities: MapSet.new(protected)}}
    end
  end

  @doc """
  Record a new version in the lineage.

  `capabilities` is a list of atoms representing what the version provides.
  `parent_id` links to the previous version (`nil` for root).
  """
  @spec record_version(t(), String.t(), [atom()], String.t() | nil) ::
          {:ok, t()} | {:error, String.t()}
  def record_version(%__MODULE__{} = state, id, capabilities, parent_id)
      when is_binary(id) and is_list(capabilities) do
    cond do
      Enum.any?(state.versions, fn v -> v.id == id end) ->
        {:error, "version id #{id} already exists"}

      not Enum.all?(capabilities, &is_atom/1) ->
        {:error, "capabilities must be a list of atoms"}

      true ->
        record = %{
          id: id,
          capabilities: MapSet.new(capabilities),
          timestamp: System.monotonic_time(:millisecond),
          parent_id: parent_id
        }

        # Check for gap: parent_id given but not found in versions
        gap =
          if parent_id != nil and
               not Enum.any?(state.versions, fn v -> v.id == parent_id end) do
            1
          else
            0
          end

        new_state = %{
          state
          | versions: [record | state.versions],
            gap_count: state.gap_count + gap
        }

        {:ok, new_state}
    end
  end

  def record_version(%__MODULE__{}, _id, _caps, _parent),
    do: {:error, "id must be a string"}

  @doc """
  Check continuity between a parent version and a child version.

  Returns whether all `protected_capabilities` from the parent are present
  in the child, plus lists of dropped and added capabilities.
  """
  @spec continuity_check(t(), String.t(), String.t()) ::
          {:ok, continuity_result()} | {:error, String.t()}
  def continuity_check(%__MODULE__{} = state, parent_id, child_id) do
    with {:ok, parent} <- find_version(state, parent_id),
         {:ok, child} <- find_version(state, child_id) do
      dropped =
        state.protected_capabilities
        |> Enum.filter(fn cap ->
          MapSet.member?(parent.capabilities, cap) and
            not MapSet.member?(child.capabilities, cap)
        end)

      added =
        child.capabilities
        |> Enum.filter(fn cap -> not MapSet.member?(parent.capabilities, cap) end)
        |> Enum.to_list()

      {:ok,
       %{
         continuous: Enum.empty?(dropped),
         dropped_capabilities: dropped,
         added_capabilities: added
       }}
    end
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      version_count: length(state.versions),
      protected_capability_count: MapSet.size(state.protected_capabilities),
      gap_count: state.gap_count,
      latest_version: state.versions |> List.first() |> then(&if(&1, do: &1.id, else: nil))
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec find_version(t(), String.t()) :: {:ok, version_record()} | {:error, String.t()}
  defp find_version(%__MODULE__{versions: versions}, id) do
    case Enum.find(versions, fn v -> v.id == id end) do
      nil -> {:error, "version #{id} not found"}
      v -> {:ok, v}
    end
  end
end
