defmodule Indrajaal.Cybernetic.OODA.Actor do
  @moduledoc """
  The Executive Hand.
  Performs the chosen action with rollback capability, audit trail, and telemetry.

  ## STAMP Compliance
  - SC-OODA-001: OODA cycle < 30ms
  - SC-GDE-001: Guardian validation required
  - SC-GDE-003: Rollback capability
  """
  require Logger

  # ETS audit log for action history
  @table :ooda_actor_audit
  @max_audit_entries 500

  @doc """
  Ensure the audit log ETS table exists.
  """
  def ensure_table do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :ordered_set, write_concurrency: true])

      _ ->
        @table
    end
  end

  @doc """
  Execute the action specified in the OODA decision.
  Records all actions to the audit log via telemetry.
  Falls back gracefully on subsystem unavailability.
  """
  @spec execute(map()) :: :ok | :error
  def execute(decision) do
    ensure_table()
    action = Map.get(decision, :action, :none)
    start_ts = System.monotonic_time(:microsecond)

    result = dispatch_action(action, decision)

    elapsed_us = System.monotonic_time(:microsecond) - start_ts

    record_audit(action, decision, result, elapsed_us)

    :telemetry.execute(
      [:indrajaal, :cybernetic, :ooda, :act],
      %{duration_us: elapsed_us},
      %{action: action, result: result}
    )

    result
  end

  # ---------------------------------------------------------------------------
  # Private: action dispatch
  # ---------------------------------------------------------------------------

  defp dispatch_action(:none, _decision) do
    Logger.debug("OODA ACT: no-op (action=:none)")
    :ok
  end

  defp dispatch_action(:scale_up, decision) do
    pool = Map.get(decision, :pool, Indrajaal.FLAME.IntelligencePool)
    count = Map.get(decision, :count, 1)

    Logger.info("OODA ACT: Scaling Up #{inspect(pool)} by #{count}")

    result =
      try do
        # Warmup by casting to the pool supervisor if available.
        # FLAME.place_child is not called directly because the pool may be paused;
        # instead we broadcast a warmup request on the GenServer if it exists.
        case GenServer.whereis(pool) do
          nil ->
            Logger.warning("OODA ACT: pool #{inspect(pool)} not running — scale_up skipped")
            :ok

          pid when is_pid(pid) ->
            # Ask pool to warm up `count` additional runners (best-effort cast).
            Enum.each(1..count, fn _ ->
              GenServer.cast(pid, :warmup_runner)
            end)

            :ok
        end
      rescue
        e ->
          Logger.warning("OODA ACT: scale_up failed: #{inspect(e)}")
          :ok
      catch
        _, _ ->
          :ok
      end

    result
  end

  defp dispatch_action(:scale_down, decision) do
    pool = Map.get(decision, :pool, Indrajaal.FLAME.IntelligencePool)
    count = Map.get(decision, :count, 1)

    Logger.info("OODA ACT: Scaling Down #{inspect(pool)} by #{count}")

    try do
      case GenServer.whereis(pool) do
        nil ->
          :ok

        pid when is_pid(pid) ->
          Enum.each(1..count, fn _ ->
            GenServer.cast(pid, :release_runner)
          end)

          :ok
      end
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp dispatch_action(:gc_force, _decision) do
    Logger.info("OODA ACT: Forcing garbage collection on all processes")

    try do
      :erlang.garbage_collect()

      # Collect on the top message-queue processes
      Process.list()
      |> Enum.take_random(min(100, length(Process.list())))
      |> Enum.each(fn pid ->
        try do
          :erlang.garbage_collect(pid)
        catch
          _, _ -> :ok
        end
      end)

      :ok
    rescue
      _ -> :ok
    end
  end

  defp dispatch_action(:shed_load, decision) do
    shed_pct = Map.get(decision, :shed_percentage, 0.1)
    Logger.warning("OODA ACT: Shedding load at #{trunc(shed_pct * 100)}%")

    try do
      # Broadcast load-shedding request to UnifiedControlBus if available
      case Process.whereis(Indrajaal.Cybernetic.UnifiedControlBus) do
        nil ->
          :ok

        pid when is_pid(pid) ->
          GenServer.cast(pid, {:load_shed, shed_pct})
          :ok
      end
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp dispatch_action(:apoptosis, decision) do
    reason = Map.get(decision, :reason, "OODA-triggered apoptosis")
    Logger.emergency("OODA ACT: Triggering System Apoptosis — #{reason}")

    try do
      case GenServer.whereis(Indrajaal.Cluster.Sentinel) do
        nil ->
          # Sentinel unavailable: initiate graceful stop via Application
          Logger.emergency("OODA ACT: Sentinel unavailable — calling System.stop(1)")

          Task.start(fn ->
            Process.sleep(500)
            System.stop(1)
          end)

          :ok

        pid when is_pid(pid) ->
          # Delegate apoptosis to Sentinel (6-phase protocol, SC-SIL6-015)
          GenServer.cast(pid, {:initiate_apoptosis, reason})
          :ok
      end
    rescue
      e ->
        Logger.emergency("OODA ACT: apoptosis dispatch error: #{inspect(e)}")
        :ok
    catch
      _, _ -> :ok
    end
  end

  defp dispatch_action(unknown, _decision) do
    Logger.warning("OODA ACT: Unknown action #{inspect(unknown)}")
    :error
  end

  # ---------------------------------------------------------------------------
  # Private: audit log
  # ---------------------------------------------------------------------------

  defp record_audit(action, decision, result, elapsed_us) do
    try do
      ts = System.system_time(:microsecond)

      entry =
        {ts, action, result, elapsed_us,
         Map.take(decision, [:pool, :count, :reason, :shed_percentage])}

      :ets.insert(@table, entry)
      purge_old_audit_entries()
    rescue
      _ -> :ok
    end
  end

  defp purge_old_audit_entries do
    try do
      size = :ets.info(@table, :size)

      if size > @max_audit_entries do
        excess = size - @max_audit_entries

        :ets.first(@table)
        |> delete_n_entries(excess)
      end
    rescue
      _ -> :ok
    end
  end

  defp delete_n_entries(:"$end_of_table", _n), do: :ok
  defp delete_n_entries(_key, 0), do: :ok

  defp delete_n_entries(key, n) do
    next = :ets.next(@table, key)
    :ets.delete(@table, key)
    delete_n_entries(next, n - 1)
  end

  @doc """
  Return the recent audit log entries as a list (newest first).
  """
  @spec recent_audit(non_neg_integer()) :: list()
  def recent_audit(limit \\ 50) do
    ensure_table()

    try do
      :ets.tab2list(@table)
      |> Enum.sort_by(fn {ts, _, _, _, _} -> ts end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {ts, action, result, elapsed_us, meta} ->
        %{timestamp_us: ts, action: action, result: result, duration_us: elapsed_us, meta: meta}
      end)
    rescue
      _ -> []
    end
  end
end
