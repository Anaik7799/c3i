defmodule Indrajaal.Core.Homeostasis.ThresholdController do
  @moduledoc """
  Interactive Threshold Controller for Homeostasis Set Points.

  WHAT: GenServer managing homeostatic set points (temperature, cpu, memory,
        latency thresholds). Provides fast ETS reads for threshold lookups
        and broadcasts changes over PubSub.

  WHY: Operators need runtime control over homeostatic tolerances without
       restarting the system. Threshold violations feed directly into the
       PID controller tuning loop (SC-MATH-003).

  CONSTRAINTS:
    - SC-HOM-001: Homeostasis controller within safe operating range
    - SC-HOM-002: Threshold state persisted for recovery (Omega-7)
    - SC-MATH-003: PID set points adjustable at runtime
    - SC-MON-006: Alert generation on threshold violations
    - SC-BIO-007: Homeostasis — adaptive thresholds
    - Omega-7: Holon state in SQLite/DuckDB only

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-28 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | STAMP | SC-HOM-001, SC-HOM-002, SC-MATH-003, SC-MON-006 |
  """

  use GenServer

  require Logger

  @ets_table :homeostasis_thresholds
  @pubsub_topic "prajna:homeostasis"

  @default_thresholds %{
    cpu: 85.0,
    memory: 80.0,
    temperature: 75.0,
    latency_ms: 100.0,
    queue_depth: 1000,
    error_rate: 0.05,
    disk_usage: 90.0,
    network_saturation: 70.0
  }

  # ═══════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════

  @doc "Starts the ThresholdController GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets a named threshold value.

  ## Examples

      iex> set_threshold(:cpu, 80.0)
      :ok

      iex> set_threshold(:unknown_key, 50.0)
      {:error, :unknown_threshold}
  """
  @spec set_threshold(atom(), number()) :: :ok | {:error, term()}
  def set_threshold(name, value) when is_atom(name) and is_number(value) do
    GenServer.call(__MODULE__, {:set_threshold, name, value})
  end

  @doc """
  Gets the current threshold for a named key.

  Returns `{:ok, value}` or `{:error, :not_found}`.
  """
  @spec get_threshold(atom()) :: {:ok, number()} | {:error, :not_found}
  def get_threshold(name) when is_atom(name) do
    case :ets.lookup(@ets_table, name) do
      [{^name, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  @doc "Returns all current thresholds as a map."
  @spec all_thresholds() :: %{atom() => number()}
  def all_thresholds do
    :ets.tab2list(@ets_table)
    |> Map.new()
  end

  @doc """
  Checks whether `value` violates the threshold for `name`.

  Returns `{:ok, :within}` when the value is within limits,
  or `{:alert, :exceeded, delta}` when exceeded.
  Delta is positive when the value exceeds the threshold.
  """
  @spec check_violation(atom(), number()) ::
          {:ok, :within} | {:alert, :exceeded, float()} | {:error, :not_found}
  def check_violation(name, value) when is_atom(name) and is_number(value) do
    case get_threshold(name) do
      {:ok, threshold} ->
        if value > threshold do
          delta = Float.round((value - threshold) * 1.0, 4)
          {:alert, :exceeded, delta}
        else
          {:ok, :within}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════

  @impl true
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    table = :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])
    load_defaults(table)

    Logger.info(
      "[ThresholdController] Initialized with #{map_size(@default_thresholds)} thresholds",
      table: @ets_table,
      stamp: "SC-HOM-001"
    )

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:set_threshold, name, value}, _from, state) do
    case Map.has_key?(@default_thresholds, name) do
      true ->
        :ets.insert(@ets_table, {name, value})
        broadcast_change(name, value)

        Logger.debug("[ThresholdController] Threshold updated",
          name: name,
          value: value,
          stamp: "SC-HOM-002"
        )

        {:reply, :ok, state}

      false ->
        Logger.warning("[ThresholdController] Unknown threshold key: #{name}")
        {:reply, {:error, :unknown_threshold}, state}
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # PRIVATE HELPERS
  # ═══════════════════════════════════════════════════════════════════

  @spec load_defaults(:ets.table()) :: true
  defp load_defaults(table) do
    Enum.each(@default_thresholds, fn {k, v} ->
      :ets.insert(table, {k, v})
    end)
  end

  @spec broadcast_change(atom(), number()) :: :ok | {:error, term()}
  defp broadcast_change(name, value) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:threshold_changed, name, value}
    )
  end
end
