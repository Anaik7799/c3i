defmodule Indrajaal.Evolution.SystemEvolution do
  @moduledoc """
  ## SYSTEM EVOLUTION AGENT (L5-MIND)
  Autonomously reads the Sovereign Blueprint (KMS) to determine
  the next evolutionary step.

  **Mechanism**:
  1. Queries `Indrajaal.KMS.Todo`.
  2. Filters for `pending` status.
  3. Sorts by Priority (P0 > P1).
  4. Broadcasts the task via Zenoh/Telemetry.

  **Safety**: Read-only. Does not modify the plan directly.
  """
  use GenServer
  require Logger
  require Ash.Query

  alias Indrajaal.KMS.Todo

  # 60s cycle
  @check_interval 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def propose_mutation(mutation) do
    Logger.info("🧬 [EVOLUTION] Analyzing Mutation Proposal: #{mutation}")
    # In a full implementation, this would create a 'proposed' Todo in KMS
    :ok
  end

  @impl true
  def init(_opts) do
    Logger.info("🧠 [EVOLUTION] System Evolution Agent Active.")
    schedule_check()
    {:ok, %{current_focus: nil}}
  end

  @impl true
  def handle_info(:evolve, state) do
    next_step = fetch_next_step()

    if next_step do
      broadcast_next_step(next_step)
      {:noreply, %{state | current_focus: next_step.name}}
    else
      {:noreply, state}
    end

    schedule_check()
  end

  defp fetch_next_step do
    # Strategic Parser: Prioritize P0 > P1 > P2
    Todo
    |> Ash.Query.filter(status: :pending)
    # p0 < p1
    |> Ash.Query.sort(priority: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read!()
    |> List.first()
  rescue
    e ->
      Logger.error("🧠 [EVOLUTION] Failed to query KMS: #{inspect(e)}")
      nil
  end

  defp broadcast_next_step(task) do
    Logger.info("🧠 [EVOLUTION] Next Evolutionary Step: #{task.name} (#{task.priority})")

    # Metacognition: Why did we choose this?
    reasoning =
      case task.priority do
        :p0 -> "Critical Survival Imperative"
        :p1 -> "Strategic Advantage"
        _ -> "Routine Maintenance"
      end

    :telemetry.execute(
      [:indrajaal, :evolution, :next_step],
      %{timestamp: System.system_time(:millisecond)},
      %{
        task: task.name,
        priority: task.priority,
        hlc: Indrajaal.Time.HLC.new(),
        reasoning: reasoning,
        trace_context: Indrajaal.Observability.TraceContext.inject(),
        session_id: "global_evolution_session"
      }
    )
  end

  defp schedule_check do
    Process.send_after(self(), :evolve, @check_interval)
  end
end
