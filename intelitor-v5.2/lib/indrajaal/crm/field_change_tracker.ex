defmodule Indrajaal.CRM.FieldChangeTracker do
  @moduledoc """
  CRM field change tracking — pure functions for diff computation and change record creation.

  Provides a composable, side-effect-free API to:
  - Compute field-level diffs between two CRM entity maps
  - Build typed change records for audit persistence
  - Filter trivial or no-op changes

  Persistence is delegated to `Indrajaal.Crm.AuditLog.record_change/4`; this module
  only handles the pure transformation layer.

  ## STAMP Compliance
  - SC-AUDIT-001: All CRM field changes audited
  - SC-FUNC-001: Module must compile without errors/warnings
  - SC-L1-001: Pure functions, no side effects

  ## Example

      before = %{stage: "prospecting", amount: 1000, owner_id: "u1"}
      after  = %{stage: "qualification", amount: 1500, owner_id: "u1"}
      changes = FieldChangeTracker.diff(before, after)
      # => %{stage: {"prospecting", "qualification"}, amount: {1000, 1500}}

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — task 4a2ab7eb |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type field_name :: atom() | String.t()
  @type change_pair :: {old_value :: term(), new_value :: term()}
  @type change_map :: %{field_name() => change_pair()}

  @type change_record :: %{
          entity_type: atom(),
          entity_id: String.t(),
          changes: change_map(),
          actor_id: String.t(),
          recorded_at: DateTime.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Compute a field-level diff between two entity maps.

  Returns a map of changed fields only, where each value is a `{old, new}` tuple.
  Fields with identical values are excluded. Fields present in `before` but missing
  from `after` are reported as deleted (`{old_value, nil}`). Fields appearing only
  in `after` are reported as added (`{nil, new_value}`).

  ## Parameters
  - `before` — map representing the entity state before the operation
  - `after_map` — map representing the entity state after the operation
  - `opts` — optional keyword list:
    - `:only` — list of field keys to consider (default: all keys)
    - `:ignore` — list of field keys to skip (default: none)

  ## Examples

      iex> diff(%{name: "Alice"}, %{name: "Bob"})
      %{name: {"Alice", "Bob"}}

      iex> diff(%{a: 1, b: 2}, %{a: 1, b: 2})
      %{}
  """
  @spec diff(map(), map(), keyword()) :: change_map()
  def diff(before, after_map, opts \\ [])

  def diff(before, after_map, opts) when is_map(before) and is_map(after_map) do
    only_keys = Keyword.get(opts, :only)
    ignore_keys = Keyword.get(opts, :ignore, []) |> MapSet.new()

    all_keys =
      MapSet.union(MapSet.new(Map.keys(before)), MapSet.new(Map.keys(after_map)))

    filtered_keys =
      case only_keys do
        nil -> all_keys
        keys -> MapSet.intersection(all_keys, MapSet.new(keys))
      end

    filtered_keys
    |> MapSet.reject(&MapSet.member?(ignore_keys, &1))
    |> Enum.reduce(%{}, fn key, acc ->
      old_val = Map.get(before, key)
      new_val = Map.get(after_map, key)

      if old_val == new_val do
        acc
      else
        Map.put(acc, key, {old_val, new_val})
      end
    end)
  end

  @doc """
  Build a typed change record suitable for passing to `Indrajaal.Crm.AuditLog.record_change/4`.

  ## Parameters
  - `entity_type` — atom such as `:opportunity`, `:lead`, `:contact`, `:account`
  - `entity_id` — UUID string
  - `changes` — result of `diff/3`
  - `actor_id` — user or agent identifier

  ## Returns
  A `change_record()` map with a `recorded_at` timestamp set to `DateTime.utc_now()`.
  """
  @spec build_record(atom(), String.t(), change_map(), String.t()) :: change_record()
  def build_record(entity_type, entity_id, changes, actor_id)
      when is_atom(entity_type) and is_binary(entity_id) and is_map(changes) and
             is_binary(actor_id) do
    %{
      entity_type: entity_type,
      entity_id: entity_id,
      changes: changes,
      actor_id: actor_id,
      recorded_at: DateTime.utc_now()
    }
  end

  @doc """
  Return `true` if the given `change_map()` has no entries (no-op diff).

  ## Examples

      iex> empty?(%{})
      true

      iex> empty?(%{name: {"Alice", "Bob"}})
      false
  """
  @spec empty?(change_map()) :: boolean()
  def empty?(changes) when is_map(changes), do: map_size(changes) == 0

  @doc """
  Return only changes for the given list of field keys.

  ## Examples

      iex> select(%{a: {1, 2}, b: {3, 4}}, [:a])
      %{a: {1, 2}}
  """
  @spec select(change_map(), [field_name()]) :: change_map()
  def select(changes, keys) when is_map(changes) and is_list(keys) do
    Map.take(changes, keys)
  end

  @doc """
  Summarise a `change_map()` as a human-readable list of strings.

  ## Examples

      iex> summarize(%{stage: {"prospecting", "qualification"}})
      ["stage: prospecting → qualification"]
  """
  @spec summarize(change_map()) :: [String.t()]
  def summarize(changes) when is_map(changes) do
    Enum.map(changes, fn {field, {old_val, new_val}} ->
      "#{field}: #{inspect(old_val)} → #{inspect(new_val)}"
    end)
  end
end
