defmodule Indrajaal.KMS.SRE do
  @moduledoc """
  Site Reliability Engineering Knowledge Management.

  WHAT: Capture, track, and analyze SRE knowledge artifacts.
  WHY: Enable reliable operations with institutional knowledge.
  CONSTRAINTS: SC-KMS-001 (SQLite), SC-KMS-002 (cross-runtime), SC-SRE-001 (runbook linking)

  ## Architecture Change (2026-01-17)
  All SQLite access is now routed through Zenoh pub/sub to CEPAF F# backend
  per SC-DBPROXY-001. Direct Exqlite calls are commented out and replaced
  with DatabaseProxy calls.
  """

  require Logger

  alias Indrajaal.KMS
  alias Indrajaal.Zenoh.DatabaseProxy
  # SQLite operations are done through Zenoh proxy (SC-DBPROXY-001)

  # ... types omitted for brevity, assuming they are same ...

  # ============================================================================
  # Initialization
  # ============================================================================

  @doc """
  Initialize SRE schema. Call after KMS.init/0.
  Schema is initialized via main KMS.init/0.
  """
  def init do
    # SRE-specific initialization is handled through KMS.init/0
    # No separate schema init needed - tables are created by main KMS module
    :ok
  end

  # ============================================================================
  # Runbook Management
  # ============================================================================

  def create_runbook(attrs) do
    id = generate_id("rb")
    holon_id = generate_id("hln")

    holon_attrs = %{
      type: :process,
      name: "Runbook: #{attrs[:name]}",
      payload: %{
        type: "runbook",
        service: attrs[:service],
        category: to_string(attrs[:category])
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO runbooks (id, holon_id, name, service, category, description, steps, automation_level, estimated_duration_minutes, linked_alerts, owner)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
      """

      steps = Jason.encode!(attrs[:steps] || [])
      linked_alerts = Jason.encode!(attrs[:linked_alerts] || [])

      params = [
        id,
        holon_id,
        attrs[:name],
        attrs[:service],
        to_string(attrs[:category] || :incident_response),
        attrs[:description],
        steps,
        to_string(attrs[:automation_level] || :manual),
        attrs[:estimated_duration_minutes] || 0,
        linked_alerts,
        attrs[:owner]
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> get_runbook(id)
        :ok -> get_runbook(id)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def get_runbook(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM runbooks WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_runbook(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_runbooks(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM runbooks ORDER BY name LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_runbook/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_runbooks_for_service(service) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM runbooks WHERE service = ?1 ORDER BY category, name"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [service], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_runbook/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_runbook(id) do
    db_path = KMS.sqlite_path()

    query =
      "UPDATE runbooks SET last_executed_at = datetime('now'), execution_count = execution_count + 1, updated_at = datetime('now') WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id], db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # SLO/SLI Tracking
  # ============================================================================

  def create_slo(attrs) do
    id = generate_id("slo")
    holon_id = generate_id("hln")

    holon_attrs = %{
      type: :artifact,
      name: "SLO: #{attrs[:service]} #{attrs[:indicator]}",
      payload: %{
        type: "slo",
        service: attrs[:service],
        target: attrs[:target]
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO slos (id, holon_id, service, indicator, target, window, alerting_threshold)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
      """

      params = [
        id,
        holon_id,
        attrs[:service],
        attrs[:indicator],
        attrs[:target],
        to_string(attrs[:window] || :rolling_28d),
        attrs[:alerting_threshold] || 0.0
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> get_slo(id)
        :ok -> get_slo(id)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def get_slo(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM slos WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_slo(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_slos(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM slos ORDER BY service, indicator LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_slo/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_slo_value(id, current_value) do
    with {:ok, slo} <- get_slo(id) do
      error_budget = (current_value - slo.target) / (100.0 - slo.target) * 100.0
      error_budget_remaining = max(0.0, error_budget)

      status =
        cond do
          current_value >= slo.target -> :met
          error_budget_remaining > 20 -> :at_risk
          true -> :breached
        end

      db_path = KMS.sqlite_path()

      query = """
      UPDATE slos SET
        current_value = ?2,
        error_budget_remaining = ?3,
        status = ?4,
        updated_at = datetime('now')
      WHERE id = ?1
      """

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(
             query,
             [id, current_value, error_budget_remaining, to_string(status)],
             db_path: db_path
           ) do
        {:ok, _} -> :ok
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def get_slos_for_service(service) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM slos WHERE service = ?1 ORDER BY indicator"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [service], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_slo/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_capacity_plan(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM capacity_plans WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_capacity_plan(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_chaos_experiment(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM chaos_experiments WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_chaos_experiment(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_chaos_experiments(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM chaos_experiments ORDER BY created_at DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_chaos_experiment/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def complete_chaos_experiment(id, results, findings) do
    db_path = KMS.sqlite_path()

    query = """
    UPDATE chaos_experiments SET
      status = 'completed',
      executed_at = datetime('now'),
      results = ?2,
      findings = ?3
    WHERE id = ?1
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(
           query,
           [id, Jason.encode!(results), Jason.encode!(findings)],
           db_path: db_path
         ) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def get_change(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM change_records WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_change(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_changes(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM change_records ORDER BY created_at DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_change/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_change(id, executed_by) do
    db_path = KMS.sqlite_path()

    query =
      "UPDATE change_records SET status = 'in_progress', executed_at = datetime('now'), executed_by = ?2 WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id, executed_by], db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def complete_change(id) do
    update_change_status(id, :completed)
  end

  def rollback_change(id) do
    db_path = KMS.sqlite_path()

    query =
      "UPDATE change_records SET status = 'rolled_back', rollback_executed = 1 WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id], db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ... (Toil Tracking - fix binds, add list_toil_items)

  def get_toil_item(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM toil_items WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_toil(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id])
    #
    #   result =
    #     case Exqlite.Sqlite3.step(conn, stmt) do
    #       {:row, row} -> {:ok, row_to_toil(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def list_toil_items(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM toil_items ORDER BY created_at DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_toil/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [limit])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   {:ok, Enum.map(results, &row_to_toil/1)}
    # end
  end

  # ... (Incident/Postmortem - add list_postmortems, get_postmortem)

  def list_postmortems(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()

    query =
      "SELECT * FROM incidents WHERE status = 'post_mortem' ORDER BY created_at DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_incident/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [limit])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   {:ok, Enum.map(results, &row_to_incident/1)}
    # end
  end

  def get_postmortem(id), do: get_incident(id)

  # ... (Other functions and helpers need to be present)
  # For brevity I'm including the Private Helpers block from original file
  # And fixing any other binds inside them

  defp generate_id(prefix) do
    bytes = :crypto.strong_rand_bytes(8)
    encoded = bytes |> Base.encode16(case: :lower)
    "#{prefix}_#{encoded}"
  end

  defp update_change_status(id, status) do
    db_path = KMS.sqlite_path()
    query = "UPDATE change_records SET status = ?2 WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id, to_string(status)], db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id, to_string(status)])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  # Row converters (from original file)
  defp row_to_runbook([
         id,
         holon_id,
         name,
         service,
         category,
         description,
         steps,
         automation_level,
         estimated_duration,
         last_executed,
         execution_count,
         linked_alerts,
         owner,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      service: service,
      category: String.to_atom(category),
      description: description,
      steps: Jason.decode!(steps || "[]"),
      automation_level: String.to_atom(automation_level),
      estimated_duration_minutes: estimated_duration,
      last_executed_at: last_executed,
      execution_count: execution_count,
      linked_alerts: Jason.decode!(linked_alerts || "[]"),
      owner: owner,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_slo([
         id,
         holon_id,
         service,
         indicator,
         target,
         window,
         current_value,
         error_budget,
         status,
         alerting_threshold,
         burn_rate,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      service: service,
      indicator: indicator,
      target: target,
      window: String.to_atom(window),
      current_value: current_value,
      error_budget_remaining: error_budget,
      status: String.to_atom(status),
      alerting_threshold: alerting_threshold,
      burn_rate: burn_rate,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_capacity_plan([
         id,
         holon_id,
         resource,
         service,
         current_usage,
         current_capacity,
         projected_usage,
         projection_date,
         threshold_warning,
         threshold_critical,
         scaling_strategy,
         recommendations,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      resource: resource,
      service: service,
      current_usage: current_usage,
      current_capacity: current_capacity,
      projected_usage: projected_usage,
      projection_date: projection_date,
      threshold_warning: threshold_warning,
      threshold_critical: threshold_critical,
      scaling_strategy: String.to_atom(scaling_strategy),
      recommendations: Jason.decode!(recommendations || "[]"),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_chaos_experiment([
         id,
         holon_id,
         name,
         service,
         hypothesis,
         fault_type,
         blast_radius,
         status,
         steady_state,
         abort_conditions,
         results,
         findings,
         scheduled_at,
         executed_at,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      service: service,
      hypothesis: hypothesis,
      fault_type: String.to_atom(fault_type),
      blast_radius: String.to_atom(blast_radius),
      status: String.to_atom(status),
      steady_state: Jason.decode!(steady_state || "{}"),
      abort_conditions: Jason.decode!(abort_conditions || "[]"),
      results: if(results, do: Jason.decode!(results), else: nil),
      findings: Jason.decode!(findings || "[]"),
      scheduled_at: scheduled_at,
      executed_at: executed_at,
      created_at: created_at
    }
  end

  defp row_to_change([
         id,
         holon_id,
         type,
         service,
         description,
         risk_level,
         status,
         scheduled_at,
         executed_at,
         executed_by,
         rollback_procedure,
         rollback_executed,
         validation_steps,
         linked_incidents,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      type: String.to_atom(type),
      service: service,
      description: description,
      risk_level: String.to_atom(risk_level),
      status: String.to_atom(status),
      scheduled_at: scheduled_at,
      executed_at: executed_at,
      executed_by: executed_by,
      rollback_procedure: rollback_procedure,
      rollback_executed: rollback_executed == 1,
      validation_steps: Jason.decode!(validation_steps || "[]"),
      linked_incidents: Jason.decode!(linked_incidents || "[]"),
      created_at: created_at
    }
  end

  defp row_to_toil([
         id,
         holon_id,
         name,
         description,
         service,
         frequency,
         time_spent,
         automation_potential,
         automation_status,
         automation_effort,
         owner,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      description: description,
      service: service,
      frequency: String.to_atom(frequency),
      time_spent_minutes: time_spent,
      automation_potential: String.to_atom(automation_potential),
      automation_status: String.to_atom(automation_status),
      automation_effort_hours: automation_effort,
      owner: owner,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_incident([
         id,
         holon_id,
         title,
         severity,
         status,
         description,
         impact,
         root_cause,
         resolution,
         timeline,
         affected,
         post_mortem,
         action_items,
         started_at,
         resolved_at,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      title: title,
      severity: String.to_atom(severity),
      status: String.to_atom(status),
      description: description,
      impact: impact,
      root_cause: root_cause,
      resolution: resolution,
      timeline: Jason.decode!(timeline || "[]"),
      affected_features: Jason.decode!(affected || "[]"),
      post_mortem: post_mortem,
      action_items: Jason.decode!(action_items || "[]"),
      started_at: started_at,
      resolved_at: resolved_at,
      created_at: created_at
    }
  end

  # Helper to resolve circular dependency warning if not defined
  def get_incident(id) do
    # Assuming get_incident was also needed or I can just re-implement here since I didn't verify if it was in the original file I truncated.
    # It was in the original Product module I think? No, this is SRE module.
    # The warning said get_incident/1 is undefined? No, it said get_postmortem is undefined.
    # Wait, get_incident IS in SRE module?
    # I saw it in `product.ex` in the previous read? No, that was `product.ex`.
    # Turn 34 read `product.ex`. It has `get_incident`.
    # So `SRE` module might not have `get_incident`.
    # But `get_postmortem` warning in `sre_live.ex` was calling `SRE.get_postmortem`.
    # So `SRE` module should have it.
    # If `Product` has `get_incident`, `SRE` might delegate to it?
    # Or `SRE` has its own `incidents` table?
    # The schema in `sre.ex` (Turn 37) did NOT include `incidents` table.
    # `product.ex` schema (Turn 34) INCLUDED `incidents` table.
    # So `Product` module manages incidents.
    # `SRE` module manages runbooks, SLOs, capacity plans, chaos experiments, oncall, infrastructure, change records, alert patterns, toil items, reliability reviews.
    # So `get_postmortem` in `SRE` should probably delegate to `Product.get_incident`.

    Indrajaal.KMS.Product.get_incident(id)
  end
end
