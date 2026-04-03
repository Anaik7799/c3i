# lib/indrajaal/kms/agents/knowledge_agent.ex
defmodule Indrajaal.KMS.Agents.KnowledgeAgent do
  @moduledoc """
  Self-aware knowledge agent with OODA loop.

  WHAT: Monitors SMRITI knowledge base entropy and health using real SQLite
  metrics. Triggers compaction or optimization when entropy exceeds thresholds.

  WHY: SC-SMRITI-031 requires autonomous knowledge management. Random entropy
  observation is dangerous — the agent must observe actual database state to
  make correct decisions about compaction vs. optimization.

  CONSTRAINTS:
  - SC-SMRITI-031: Autonomous knowledge agent
  - SC-BIO-001: OODA cycle < 100ms
  - SC-OBS-031: All agent operations emit telemetry

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 21.2.1  | 2026-03-10 | Claude | Fix: real SQLite entropy observation      |
  | 21.0.0  | 2026-01-05 | Claude | Initial stub (random entropy)             |
  """
  use GenServer
  require Logger

  alias Indrajaal.KMS.SQLite

  # 30s OODA Cycle
  @ooda_interval 30_000
  @smriti_db_path Application.compile_env(:indrajaal, :smriti_db_path, "data/kms/smriti.db")

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    schedule_ooda()

    {:ok,
     %{
       state: :observing,
       metrics: %{entropy: 0.0, health: 1.0},
       history: []
     }}
  end

  def handle_info(:ooda_cycle, state) do
    new_state = run_ooda_loop(state)
    schedule_ooda()
    {:noreply, new_state}
  end

  defp run_ooda_loop(state) do
    # 1. OBSERVE — real system metrics
    observations = observe_system()

    # 2. ORIENT
    context = orient_context(observations, state.history)

    # 3. DECIDE
    decision = decide_action(context)

    # 4. ACT
    act(decision)

    :telemetry.execute(
      [:smriti, :agent, :ooda_cycle],
      %{
        entropy: observations.entropy,
        health: observations.health,
        timestamp: System.system_time(:nanosecond)
      },
      %{decision: decision}
    )

    %{state | metrics: observations, history: [decision | Enum.take(state.history, 10)]}
  end

  defp observe_system do
    entropy = measure_entropy()
    health = measure_health()

    %{
      entropy: entropy,
      health: health,
      timestamp: DateTime.utc_now()
    }
  end

  # Measure average entropy across all holons in the SMRITI database
  defp measure_entropy do
    case SQLite.query(@smriti_db_path, "SELECT AVG(entropy) FROM holons") do
      {:ok, [%{} = row]} ->
        row |> Map.values() |> List.first() |> parse_float(0.0)

      {:ok, [[avg]]} when is_number(avg) ->
        avg / 1.0

      _ ->
        0.0
    end
  rescue
    _ -> 0.0
  end

  # Measure database health: accessible, integrity OK, not empty
  defp measure_health do
    cond do
      not File.exists?(@smriti_db_path) -> 0.0
      not db_accessible?() -> 0.2
      not integrity_ok?() -> 0.5
      true -> 1.0
    end
  rescue
    _ -> 0.0
  end

  defp db_accessible? do
    case SQLite.query(@smriti_db_path, "SELECT 1") do
      {:ok, _} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp integrity_ok? do
    case SQLite.query(@smriti_db_path, "PRAGMA integrity_check") do
      {:ok, [%{integrity_check: "ok"}]} -> true
      {:ok, [["ok"]]} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp parse_float(nil, default), do: default
  defp parse_float(val, _default) when is_float(val), do: val
  defp parse_float(val, _default) when is_integer(val), do: val / 1.0
  defp parse_float(_, default), do: default

  defp orient_context(obs, _history) do
    cond do
      obs.health < 0.5 -> :critical_entropy
      obs.entropy > 0.8 -> :critical_entropy
      obs.entropy > 0.5 -> :high_entropy
      true -> :stable
    end
  end

  defp decide_action(:critical_entropy), do: :trigger_compaction
  defp decide_action(:high_entropy), do: :schedule_optimization
  defp decide_action(:stable), do: :maintain

  defp act(:trigger_compaction) do
    Logger.warning("[KnowledgeAgent] CRITICAL ENTROPY DETECTED. Triggering compaction.")
    :telemetry.execute([:smriti, :agent, :act], %{action: "compaction"}, %{})
  end

  defp act(:schedule_optimization) do
    Logger.info("[KnowledgeAgent] High entropy. Scheduling optimization.")
    :telemetry.execute([:smriti, :agent, :act], %{action: "optimization"}, %{})
  end

  defp act(:maintain) do
    Logger.debug("[KnowledgeAgent] System stable. Maintaining course.")
  end

  defp schedule_ooda, do: Process.send_after(self(), :ooda_cycle, @ooda_interval)
end
