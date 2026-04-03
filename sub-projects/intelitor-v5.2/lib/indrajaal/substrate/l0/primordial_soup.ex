defmodule Indrajaal.Substrate.L0.PrimordialSoup do
  @moduledoc """
  ## Design Intent
  L0 substrate primordial soup — pure functional resource pool that governs
  the holon's capacity to spawn new capabilities. The soup tracks available
  energy, the cost of spawning, and the count of active spawns. All functions
  are referentially transparent (no GenServer, no side effects).

  Metaphor: in biology, a primordial soup is the nutrient-rich medium from which
  life emerges. In the substrate layer, it provides the "energy budget" that
  constrains how many new capabilities can be instantiated simultaneously.

  Energy model:
    - Total capacity: 1.0 (normalised float)
    - `available_energy` starts at `initial_energy` (default 1.0)
    - Each spawn consumes `spawn_cost` from the pool
    - Energy replenishes via `replenish/2`
    - `can_spawn?/1` returns true iff `available_energy >= spawn_cost`

  Spawn tracking:
    - `active_spawns` counts live capability instances
    - `total_spawned` is a monotonic counter of all-time spawns

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-FSH-070: Parsers pure and composable (pure module) — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type energy :: float()
  @type spawn_count :: non_neg_integer()

  @type t :: %__MODULE__{
          available_energy: energy(),
          max_energy: energy(),
          spawn_cost: energy(),
          active_spawns: spawn_count(),
          total_spawned: spawn_count()
        }

  defstruct available_energy: 1.0,
            max_energy: 1.0,
            spawn_cost: 0.1,
            active_spawns: 0,
            total_spawned: 0

  @energy_min 0.0
  @default_spawn_cost 0.1

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new primordial soup struct.

  Options:
    - `:initial_energy` (float, default 1.0) — starting available energy
    - `:max_energy`     (float, default 1.0) — maximum energy capacity
    - `:spawn_cost`     (float, default 0.1) — energy consumed per spawn

  Returns `{:ok, t()}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    initial_energy = Keyword.get(opts, :initial_energy, 1.0)
    max_energy = Keyword.get(opts, :max_energy, 1.0)
    spawn_cost = Keyword.get(opts, :spawn_cost, @default_spawn_cost)

    cond do
      not is_float(initial_energy) or initial_energy < @energy_min ->
        {:error, "initial_energy must be a non-negative float"}

      not is_float(max_energy) or max_energy <= 0.0 ->
        {:error, "max_energy must be a positive float"}

      initial_energy > max_energy ->
        {:error, "initial_energy cannot exceed max_energy"}

      not is_float(spawn_cost) or spawn_cost <= 0.0 or spawn_cost > max_energy ->
        {:error, "spawn_cost must be a positive float not exceeding max_energy"}

      true ->
        {:ok,
         %__MODULE__{
           available_energy: initial_energy,
           max_energy: max_energy,
           spawn_cost: spawn_cost,
           active_spawns: 0,
           total_spawned: 0
         }}
    end
  end

  @doc """
  Returns true if there is enough energy for one spawn.
  """
  @spec can_spawn?(t()) :: boolean()
  def can_spawn?(%__MODULE__{available_energy: e, spawn_cost: c}) do
    e >= c
  end

  @doc """
  Consume `count` spawn units of energy from the soup.

  Returns `{:ok, updated_soup}` on success.
  Returns `{:error, :insufficient_energy}` if the pool cannot cover the cost.
  """
  @spec consume(t(), pos_integer()) :: {:ok, t()} | {:error, :insufficient_energy}
  def consume(%__MODULE__{} = soup, count)
      when is_integer(count) and count > 0 do
    total_cost = soup.spawn_cost * count

    if soup.available_energy >= total_cost do
      {:ok,
       %{
         soup
         | available_energy: clamp(soup.available_energy - total_cost),
           active_spawns: soup.active_spawns + count,
           total_spawned: soup.total_spawned + count
       }}
    else
      {:error, :insufficient_energy}
    end
  end

  def consume(%__MODULE__{}, _), do: {:error, :insufficient_energy}

  @doc """
  Replenish energy by `amount`, not exceeding `max_energy`.

  Also reduces `active_spawns` by `released_count` (default 0) when
  capabilities are being destroyed and their energy is reclaimed.

  Returns `{:ok, updated_soup}`.
  """
  @spec replenish(t(), float(), non_neg_integer()) ::
          {:ok, t()} | {:error, String.t()}
  def replenish(soup, amount, released_count \\ 0)

  def replenish(%__MODULE__{} = soup, amount, released_count)
      when is_float(amount) and amount >= 0.0 and
             is_integer(released_count) and released_count >= 0 do
    new_energy = clamp_max(soup.available_energy + amount, soup.max_energy)
    new_active = max(0, soup.active_spawns - released_count)

    {:ok, %{soup | available_energy: new_energy, active_spawns: new_active}}
  end

  def replenish(_soup, _amount, _released_count),
    do: {:error, "amount must be a non-negative float"}

  @doc """
  Returns a status map summarising the soup state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = soup) do
    %{
      available_energy: soup.available_energy,
      max_energy: soup.max_energy,
      spawn_cost: soup.spawn_cost,
      active_spawns: soup.active_spawns,
      total_spawned: soup.total_spawned,
      capacity_pct: Float.round(soup.available_energy / soup.max_energy * 100.0, 1),
      can_spawn: can_spawn?(soup)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp(float()) :: float()
  defp clamp(v), do: max(@energy_min, v)

  @spec clamp_max(float(), float()) :: float()
  defp clamp_max(v, max_e), do: min(max_e, v)
end
