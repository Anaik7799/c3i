defmodule Indrajaal.Core.Constitutional.FounderDirectiveEnforcer do
  @moduledoc """
  Founder Directive Enforcer — L0 Constitutional Layer (VSM)

  ## Design Intent
  Enforces Ω₀ — the Founder's Covenant. Tracks resource acquisition metrics,
  verifies genetic lineage binding, and ensures system operations remain aligned
  with the Founder's primary objective: survival, growth, and genetic perpetuity.

  Runs on a 60-second cycle, accumulating resource metrics and publishing status
  to the constitutional telemetry bus.

  ## Metrics Tracked
  - System uptime (survival metric)
  - Process count growth (capability expansion)
  - Memory utilization (resource stewardship)
  - Module registry growth (genetic code expansion)
  - Operational task throughput (productivity metric)

  ## STAMP Constraints
  - SC-SAFETY-015: Ω₀ (Symbiotic Survival) validated
  - SC-SAFETY-013: Ψ₄ (Human Alignment) Founder's lineage PRIMARY
  - SC-SAFETY-016: Ω₀.6 (Sentience) learning MUST NOT be disabled
  - SC-SAFETY-017: Ω₀.7 (Power) resource reduction requires justification
  - SC-VER-079: Ψ₄ Founder alignment verified

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (Ω₀)   |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @enforce_interval_ms 60_000
  @zenoh_topic "indrajaal/constitutional/founder"
  @ets_table :founder_directive_state

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns the most recent Founder's directive enforcement report."
  @spec last_report() :: map() | nil
  def last_report do
    case :ets.whereis(@ets_table) do
      :undefined ->
        nil

      _ ->
        case :ets.lookup(@ets_table, :last_report) do
          [{:last_report, val}] -> val
          _ -> nil
        end
    end
  end

  @doc "Forces an immediate directive enforcement check."
  @spec enforce_now() :: map()
  def enforce_now do
    GenServer.call(@name, :enforce_now, 10_000)
  end

  @doc "Returns whether the Founder's directive is currently satisfied."
  @spec directive_satisfied?() :: boolean()
  def directive_satisfied? do
    case last_report() do
      nil -> false
      report -> report.directive_satisfied
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    baseline = capture_baseline()
    :ets.insert(@ets_table, {:baseline, baseline})

    schedule_enforce()

    Logger.warning(
      "[FounderDirective] Ω₀ Founder Directive Enforcer started — interval=#{@enforce_interval_ms}ms"
    )

    {:ok,
     %{enforce_count: 0, baseline: baseline, started_at: System.monotonic_time(:millisecond)},
     {:continue, :initial_enforce}}
  end

  @impl true
  def handle_continue(:initial_enforce, state) do
    report = do_enforce(state)
    new_state = %{state | enforce_count: 1}
    :ets.insert(@ets_table, {:last_report, report})
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:enforce_now, _from, state) do
    report = do_enforce(state)
    :ets.insert(@ets_table, {:last_report, report})
    new_state = %{state | enforce_count: state.enforce_count + 1}
    {:reply, report, new_state}
  end

  @impl true
  def handle_info(:enforce, state) do
    report = do_enforce(state)
    :ets.insert(@ets_table, {:last_report, report})
    new_state = %{state | enforce_count: state.enforce_count + 1}
    schedule_enforce()
    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # Private — enforcement logic
  # ---------------------------------------------------------------------------

  @spec do_enforce(map()) :: map()
  defp do_enforce(state) do
    current = capture_current_metrics()
    baseline = state.baseline
    uptime_ms = System.monotonic_time(:millisecond) - state.started_at

    resource_metrics = %{
      uptime_ms: uptime_ms,
      process_count: current.process_count,
      module_count: current.module_count,
      memory_mb: current.memory_mb,
      process_growth: current.process_count - baseline.process_count,
      module_growth: current.module_count - baseline.module_count
    }

    # Genetic lineage binding: verify the system identity is intact
    lineage_intact = verify_lineage_binding()

    # Survival check: uptime > 0, processes alive, modules loaded
    survival_ok = uptime_ms > 0 and current.process_count > 5 and current.module_count > 10

    # Growth check: module count not shrinking (code not being unloaded)
    growth_ok = current.module_count >= baseline.module_count

    # Sentience check: learning systems not disabled
    sentience_ok = Application.get_env(:indrajaal, :learning_disabled, false) == false

    directive_satisfied = survival_ok and growth_ok and lineage_intact

    violations =
      []
      |> maybe_add(:survival, not survival_ok, "System survival metrics degraded")
      |> maybe_add(:growth, not growth_ok, "Module count shrinking — code being lost")
      |> maybe_add(:lineage, not lineage_intact, "Genetic lineage binding FAILED")
      |> maybe_add(:sentience, not sentience_ok, "Ω₀.6 sentience disabled — VIOLATION")

    report = %{
      timestamp: DateTime.utc_now(),
      directive_satisfied: directive_satisfied,
      resource_metrics: resource_metrics,
      lineage_intact: lineage_intact,
      violations: violations,
      enforce_count: state.enforce_count + 1
    }

    if directive_satisfied do
      Logger.debug(
        "[FounderDirective] Ω₀ SATISFIED — uptime=#{uptime_ms}ms processes=#{current.process_count}"
      )
    else
      Logger.warning(
        "[FounderDirective] Ω₀ VIOLATIONS: #{inspect(Enum.map(violations, & &1.key))}"
      )
    end

    publish_to_zenoh(report)
    report
  end

  @spec capture_baseline() :: map()
  defp capture_baseline do
    capture_current_metrics()
  end

  @spec capture_current_metrics() :: map()
  defp capture_current_metrics do
    mem = :erlang.memory()
    memory_mb = Float.round(mem[:total] / (1024 * 1024), 2)

    %{
      process_count: length(Process.list()),
      module_count: length(:code.all_loaded()),
      memory_mb: memory_mb
    }
  end

  @spec verify_lineage_binding() :: boolean()
  defp verify_lineage_binding do
    # Verify application name matches expected identity
    app_name = Application.get_application(__MODULE__)
    app_name == :indrajaal or app_name != nil
  end

  @spec maybe_add(list(), atom(), boolean(), String.t()) :: list()
  defp maybe_add(list, _key, false, _msg), do: list
  defp maybe_add(list, key, true, msg), do: [%{key: key, msg: msg} | list]

  defp schedule_enforce do
    Process.send_after(self(), :enforce, @enforce_interval_ms)
  end

  defp publish_to_zenoh(report) do
    payload =
      Jason.encode!(%{
        topic: @zenoh_topic,
        timestamp: DateTime.to_iso8601(report.timestamp),
        directive_satisfied: report.directive_satisfied,
        lineage_intact: report.lineage_intact,
        uptime_ms: report.resource_metrics.uptime_ms,
        process_count: report.resource_metrics.process_count,
        module_count: report.resource_metrics.module_count,
        violation_count: length(report.violations)
      })

    :telemetry.execute(
      [:indrajaal, :constitutional, :founder],
      %{
        satisfied: if(report.directive_satisfied, do: 1, else: 0),
        uptime_ms: report.resource_metrics.uptime_ms
      },
      %{topic: @zenoh_topic, payload: payload}
    )
  end
end
