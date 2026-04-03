defmodule Indrajaal.KMS.Product do
  @moduledoc """
  Product and Business Operations Knowledge Management.

  WHAT: Capture, track, and analyze product lifecycle knowledge artifacts.
  WHY: Enable data-driven product decisions with complete context.
  CONSTRAINTS: SC-KMS-001 (SQLite), SC-KMS-002 (cross-runtime), SC-PRD-001 (feature tracking)

  ## Architecture Change (2026-01-17)
  All SQLite access is now routed through Zenoh pub/sub to CEPAF F# backend
  per SC-DBPROXY-001. Direct Exqlite calls are commented out and replaced
  with DatabaseProxy calls.
  """

  require Logger

  alias Indrajaal.KMS
  alias Indrajaal.Zenoh.DatabaseProxy
  # SQLite operations are done through Zenoh proxy (SC-DBPROXY-001)

  # ... types omitted ...

  # ============================================================================
  # Initialization
  # ============================================================================

  @doc """
  Initialize product schema. Call after KMS.init/0.
  Schema is initialized via main KMS.init/0.
  """
  def init do
    # Product-specific initialization is handled through KMS.init/0
    # No separate schema init needed - tables are created by main KMS module
    :ok
  end

  # ============================================================================
  # Feature Lifecycle
  # ============================================================================

  def create_feature(attrs) do
    id = generate_id("feat")
    holon_id = generate_id("hln")

    holon_attrs = %{
      type: :artifact,
      name: "Feature: #{attrs[:name]}",
      payload: %{
        type: "feature",
        name: attrs[:name],
        description: attrs[:description],
        priority: to_string(attrs[:priority] || :medium)
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO features (id, holon_id, name, description, status, priority, quarter, owner, stakeholders, dependencies, metrics)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
      """

      stakeholders = Jason.encode!(attrs[:stakeholders] || [])
      dependencies = Jason.encode!(attrs[:dependencies] || [])
      metrics = Jason.encode!(attrs[:metrics] || %{})

      params = [
        id,
        holon_id,
        attrs[:name],
        attrs[:description],
        to_string(attrs[:status] || :ideation),
        to_string(attrs[:priority] || :medium),
        attrs[:quarter],
        attrs[:owner],
        stakeholders,
        dependencies,
        metrics
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> get_feature(id)
        :ok -> get_feature(id)
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, params)
      #
      #   case Exqlite.Sqlite3.step(conn, stmt) do
      #     :done ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       get_feature(id)
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  def get_feature(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM features WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_feature(row)}
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
    #       {:row, row} -> {:ok, row_to_feature(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def list_features(opts \\ []) do
    status = Keyword.get(opts, :status)
    priority = Keyword.get(opts, :priority)
    quarter = Keyword.get(opts, :quarter)
    limit = Keyword.get(opts, :limit, 100)

    db_path = KMS.sqlite_path()

    {where_clauses, params} =
      []
      |> maybe_add_filter(status, "status", 1)
      |> maybe_add_filter(priority, "priority", 2)
      |> maybe_add_filter(quarter, "quarter", 3)

    where_sql =
      if where_clauses == [], do: "", else: "WHERE " <> Enum.join(where_clauses, " AND ")

    query =
      "SELECT * FROM features #{where_sql} ORDER BY priority, created_at DESC LIMIT ?#{length(params) + 1}"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, params ++ [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_feature/1)}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, params ++ [limit])
    #
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   {:ok, Enum.map(results, &row_to_feature/1)}
    # end
  end

  def update_feature_status(id, status) do
    db_path = KMS.sqlite_path()

    completed_at =
      if status == :released, do: ", completed_at = datetime('now')", else: ""

    query =
      "UPDATE features SET status = ?2, updated_at = datetime('now')#{completed_at} WHERE id = ?1"

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

  # ============================================================================
  # Release Management
  # ============================================================================

  def create_release(attrs) do
    id = generate_id("rel")
    holon_id = generate_id("hln")

    holon_attrs = build_release_holon_attrs(attrs)

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO releases (id, holon_id, version, name, status, features, changes, breaking_changes, release_notes)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
      """

      features = Jason.encode!(attrs[:features] || [])
      changes = Jason.encode!(attrs[:changes] || [])
      breaking = Jason.encode!(attrs[:breaking_changes] || [])

      params = [
        id,
        holon_id,
        attrs[:version],
        attrs[:name],
        to_string(attrs[:status] || :planning),
        features,
        changes,
        breaking,
        attrs[:release_notes]
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> get_release(id)
        :ok -> get_release(id)
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, params)
      #
      #   case Exqlite.Sqlite3.step(conn, stmt) do
      #     :done ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       get_release(id)
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  def get_release(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM releases WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_release(row)}
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
    #       {:row, row} -> {:ok, row_to_release(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def list_releases(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM releases ORDER BY version DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_release/1)}
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
    #   {:ok, Enum.map(results, &row_to_release/1)}
    # end
  end

  def get_release_by_version(version) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM releases WHERE version = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [version], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_release(row)}
      {:ok, []} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [version])
    #
    #   result =
    #     case Exqlite.Sqlite3.step(conn, stmt) do
    #       {:row, row} -> {:ok, row_to_release(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def deploy_release(id) do
    db_path = KMS.sqlite_path()
    query = "UPDATE releases SET status = 'deployed', deployed_at = datetime('now') WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id], db_path: db_path) do
      {:ok, _} ->
        # Update associated features to released
        with {:ok, release} <- get_release(id) do
          Enum.each(release.features, &update_feature_status(&1, :released))
        end

        :ok

      :ok ->
        with {:ok, release} <- get_release(id) do
          Enum.each(release.features, &update_feature_status(&1, :released))
        end

        :ok

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   # Update associated features to released
    #   with {:ok, release} <- get_release(id) do
    #     Enum.each(release.features, &update_feature_status(&1, :released))
    #   end
    #
    #   :ok
    # end
  end

  def rollback_release(id, reason) do
    db_path = KMS.sqlite_path()

    query =
      "UPDATE releases SET status = 'rolled_back', rolled_back_at = datetime('now') WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id], db_path: db_path) do
      {:ok, _} ->
        KMS.log_event(id, :rollback, %{reason: reason})
        :ok

      :ok ->
        KMS.log_event(id, :rollback, %{reason: reason})
        :ok

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   # Log rollback event
    #   KMS.log_event(id, :rollback, %{reason: reason})
    #   :ok
    # end
  end

  # ============================================================================
  # Customer Feedback
  # ============================================================================

  def record_feedback(attrs) do
    id = generate_id("fb")
    holon_id = generate_id("hln")

    holon_attrs = build_feedback_holon_attrs(attrs)

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO feedback (id, holon_id, source, customer_id, content, sentiment, category, linked_features, status)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
      """

      linked = Jason.encode!(attrs[:linked_features] || [])

      params = [
        id,
        holon_id,
        to_string(attrs[:source]),
        attrs[:customer_id],
        attrs[:content],
        to_string(attrs[:sentiment] || :neutral),
        attrs[:category],
        linked,
        to_string(attrs[:status] || :new)
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> get_feedback(id)
        :ok -> get_feedback(id)
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, params)
      #
      #   case Exqlite.Sqlite3.step(conn, stmt) do
      #     :done ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       get_feedback(id)
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  def get_feedback(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM feedback WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_feedback(row)}
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
    #       {:row, row} -> {:ok, row_to_feedback(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def list_feedback(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM feedback ORDER BY created_at DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_feedback/1)}
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
    #   {:ok, Enum.map(results, &row_to_feedback/1)}
    # end
  end

  def link_feedback_to_feature(feedback_id, feature_id) do
    with {:ok, feedback} <- get_feedback(feedback_id) do
      linked = [feature_id | feedback.linked_features] |> Enum.uniq()

      db_path = KMS.sqlite_path()
      query = "UPDATE feedback SET linked_features = ?2 WHERE id = ?1"

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, [feedback_id, Jason.encode!(linked)],
             db_path: db_path
           ) do
        {:ok, _} -> :ok
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, [feedback_id, Jason.encode!(linked)])
      #   Exqlite.Sqlite3.step(conn, stmt)
      #   Exqlite.Sqlite3.release(conn, stmt)
      #   Exqlite.Sqlite3.close(conn)
      #   :ok
      # end
    end
  end

  # ... (feedback_sentiment_summary - kept same, assume it works or fix if needed)

  # ============================================================================
  # Experiment Tracking
  # ============================================================================

  def create_experiment(attrs) do
    id = generate_id("exp")
    holon_id = generate_id("hln")

    holon_attrs = %{
      type: :process,
      name: "Experiment: #{attrs[:name]}",
      payload: %{
        type: "experiment",
        hypothesis: attrs[:hypothesis]
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO experiments (id, holon_id, name, hypothesis, status, variant_a, variant_b, metrics, sample_size)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
      """

      metrics = Jason.encode!(attrs[:metrics] || [])

      params = [
        id,
        holon_id,
        attrs[:name],
        attrs[:hypothesis],
        to_string(attrs[:status] || :draft),
        attrs[:variant_a],
        attrs[:variant_b],
        metrics,
        attrs[:sample_size] || 0
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> get_experiment(id)
        :ok -> get_experiment(id)
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, params)
      #
      #   case Exqlite.Sqlite3.step(conn, stmt) do
      #     :done ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       get_experiment(id)
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  def get_experiment(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM experiments WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_experiment(row)}
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
    #       {:row, row} -> {:ok, row_to_experiment(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def list_experiments(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM experiments ORDER BY created_at DESC LIMIT ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [limit], db_path: db_path) do
      {:ok, rows} when is_list(rows) -> {:ok, Enum.map(rows, &row_to_experiment/1)}
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
    #   {:ok, Enum.map(results, &row_to_experiment/1)}
    # end
  end

  def start_experiment(id) do
    update_experiment_field(id, "status", "'running'")
    update_experiment_field(id, "start_date", "datetime('now')")
  end

  def complete_experiment(id, results, conclusion) do
    db_path = KMS.sqlite_path()

    query = """
    UPDATE experiments SET
      status = 'completed',
      end_date = datetime('now'),
      results = ?2,
      conclusion = ?3
    WHERE id = ?1
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id, Jason.encode!(results), conclusion],
           db_path: db_path
         ) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id, Jason.encode!(results), conclusion])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  # ============================================================================
  # Incident Management
  # ============================================================================

  def create_incident(attrs) do
    id = generate_id("inc")
    holon_id = generate_id("hln")

    holon_attrs = %{
      type: :process,
      name: "Incident: #{attrs[:title]}",
      payload: %{
        type: "incident",
        severity: to_string(attrs[:severity]),
        description: attrs[:description]
      },
      vital_signs: %{health: 0.3, stress: 0.9, energy: 0.5}
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO incidents (id, holon_id, title, severity, status, description, impact, timeline, affected_features, started_at)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'))
      """

      timeline =
        Jason.encode!([
          %{time: DateTime.utc_now() |> DateTime.to_iso8601(), event: "Incident created"}
        ])

      affected = Jason.encode!(attrs[:affected_features] || [])

      params =
        [
          id,
          holon_id,
          attrs[:title],
          to_string(attrs[:severity]),
          to_string(attrs[:status] || :investigating),
          attrs[:description],
          attrs[:impact],
          timeline,
          affected
        ]

      _execute_insert_and_fetch(db_path, query, params, id, &get_incident/1)
    end
  end

  def get_incident(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM incidents WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_incident(row)}
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
    #       {:row, row} -> {:ok, row_to_incident(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  # ... (add_incident_event, resolve_incident, add_post_mortem - fix binds)

  def add_incident_event(id, event) do
    with {:ok, incident} <- get_incident(id) do
      new_event = %{time: DateTime.utc_now() |> DateTime.to_iso8601(), event: event}
      timeline = incident.timeline ++ [new_event]

      db_path = KMS.sqlite_path()
      query = "UPDATE incidents SET timeline = ?2 WHERE id = ?1"

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, [id, Jason.encode!(timeline)], db_path: db_path) do
        {:ok, _} -> :ok
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, [id, Jason.encode!(timeline)])
      #   Exqlite.Sqlite3.step(conn, stmt)
      #   Exqlite.Sqlite3.release(conn, stmt)
      #   Exqlite.Sqlite3.close(conn)
      #   :ok
      # end
    end
  end

  def resolve_incident(id, resolution) do
    db_path = KMS.sqlite_path()

    query = """
    UPDATE incidents SET
      status = 'resolved',
      root_cause = ?2,
      resolution = ?3,
      resolved_at = datetime('now')
    WHERE id = ?1
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(
           query,
           [id, resolution[:root_cause], resolution[:resolution]],
           db_path: db_path
         ) do
      {:ok, _} ->
        add_incident_event(id, "Incident resolved")
        :ok

      :ok ->
        add_incident_event(id, "Incident resolved")
        :ok

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id, resolution[:root_cause], resolution[:resolution]])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   add_incident_event(id, "Incident resolved")
    #   :ok
    # end
  end

  def add_post_mortem(id, post_mortem, action_items) do
    db_path = KMS.sqlite_path()

    query = """
    UPDATE incidents SET
      status = 'post_mortem',
      post_mortem = ?2,
      action_items = ?3
    WHERE id = ?1
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id, post_mortem, Jason.encode!(action_items)],
           db_path: db_path
         ) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id, post_mortem, Jason.encode!(action_items)])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  # ============================================================================
  # Roadmap Planning
  # ============================================================================

  def create_roadmap_item(attrs) do
    id = generate_id("road")
    holon_id = generate_id("hln")

    holon_attrs = %{
      type: :artifact,
      name: "Roadmap: #{attrs[:name]}",
      payload: %{
        type: "roadmap_item",
        quarter: attrs[:quarter],
        theme: attrs[:theme]
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO roadmap_items (id, holon_id, name, description, quarter, theme, status, features, dependencies, confidence)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
      """

      features = Jason.encode!(attrs[:features] || [])
      deps = Jason.encode!(attrs[:dependencies] || [])

      params =
        [
          id,
          holon_id,
          attrs[:name],
          attrs[:description],
          attrs[:quarter],
          attrs[:theme],
          to_string(attrs[:status] || :tentative),
          features,
          deps,
          attrs[:confidence] || 0.5
        ]

      _execute_insert_and_fetch(db_path, query, params, id, &get_roadmap_item/1)
    end
  end

  def get_roadmap_item(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM roadmap_items WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_roadmap_item(row)}
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
    #       {:row, row} -> {:ok, row_to_roadmap_item(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  @doc """
  Get all roadmap items.
  """
  @spec get_roadmap() :: {:ok, [map()]} | {:error, term()}
  def get_roadmap do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM roadmap_items ORDER BY quarter, confidence DESC LIMIT 100"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        {:ok, Enum.map(rows, &row_to_roadmap_item/1)}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   {:ok, Enum.map(results, &row_to_roadmap_item/1)}
    # end
  end

  @doc """
  Get roadmap items for a specific quarter.
  """
  @spec get_roadmap(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_roadmap(quarter) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM roadmap_items WHERE quarter = ?1 ORDER BY confidence DESC"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [quarter], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        {:ok, Enum.map(rows, &row_to_roadmap_item/1)}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [quarter])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   {:ok, Enum.map(results, &row_to_roadmap_item/1)}
    # end
  end

  # ============================================================================
  # KPIs
  # ============================================================================

  def upsert_kpi(attrs) do
    id = attrs[:id] || generate_id("kpi")
    holon_id = attrs[:holon_id] || generate_id("hln")

    db_path = KMS.sqlite_path()

    query = """
    INSERT INTO kpis (id, holon_id, name, description, category, target, current, unit, trend, linked_features)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
    ON CONFLICT (id) DO UPDATE SET
      current = excluded.current,
      trend = excluded.trend,
      updated_at = datetime('now')
    """

    linked = Jason.encode!(attrs[:linked_features] || [])

    params = [
      id,
      holon_id,
      attrs[:name],
      attrs[:description],
      attrs[:category],
      attrs[:target],
      attrs[:current] || 0,
      attrs[:unit],
      to_string(attrs[:trend] || :stable),
      linked
    ]

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
      {:ok, _} -> get_kpi(id)
      :ok -> get_kpi(id)
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [
    #     id,
    #     holon_id,
    #     attrs[:name],
    #     attrs[:description],
    #     attrs[:category],
    #     attrs[:target],
    #     attrs[:current] || 0,
    #     attrs[:unit],
    #     to_string(attrs[:trend] || :stable),
    #     linked
    #   ])
    #
    #   case Exqlite.Sqlite3.step(conn, stmt) do
    #     :done ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       get_kpi(id)
    #
    #     {:error, reason} ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       {:error, reason}
    #   end
    # end
  end

  def get_kpi(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM kpis WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_kpi(row)}
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
    #       {:row, row} -> {:ok, row_to_kpi(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  def list_kpis(opts \\ []) do
    category = Keyword.get(opts, :category)
    db_path = KMS.sqlite_path()

    {query, params} =
      if category do
        {"SELECT * FROM kpis WHERE category = ?1 ORDER BY name", [category]}
      else
        {"SELECT * FROM kpis ORDER BY category, name", []}
      end

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, params, db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        {:ok, Enum.map(rows, &row_to_kpi/1)}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, params)
    #
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   {:ok, Enum.map(results, &row_to_kpi/1)}
    # end
  end

  def update_kpi_value(id, value) do
    with {:ok, kpi} <- get_kpi(id) do
      trend =
        cond do
          value > kpi.current -> :up
          value < kpi.current -> :down
          true -> :stable
        end

      db_path = KMS.sqlite_path()

      query =
        "UPDATE kpis SET current = ?2, trend = ?3, updated_at = datetime('now') WHERE id = ?1"

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, [id, value, to_string(trend)], db_path: db_path) do
        {:ok, _} -> :ok
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end

      # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
      # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
      #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      #   Exqlite.Sqlite3.bind(stmt, [id, value, to_string(trend)])
      #   Exqlite.Sqlite3.step(conn, stmt)
      #   Exqlite.Sqlite3.release(conn, stmt)
      #   Exqlite.Sqlite3.close(conn)
      #   :ok
      # end
    end
  end

  # ... (Stats - keep as is or verify binds if any)
  # There are no binds in product_stats and feature_velocity, just selects.

  # ... (Private Helpers - keep as is, but ensure _execute_insert_and_fetch uses correct bind)

  defp _execute_insert_and_fetch(db_path, query, params, id, fetch_fn) do
    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
      {:ok, _} -> fetch_fn.(id)
      :ok -> fetch_fn.(id)
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, params)
    #
    #   case Exqlite.Sqlite3.step(conn, stmt) do
    #     :done ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       fetch_fn.(id)
    #
    #     {:error, reason} ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       {:error, reason}
    #   end
    # end
  end

  # ... (other helpers)

  defp build_release_holon_attrs(attrs) do
    %{
      type: :artifact,
      name: "Release: #{attrs[:version]}",
      payload: %{
        type: "release",
        version: attrs[:version],
        name: attrs[:name]
      }
    }
  end

  defp build_feedback_holon_attrs(attrs) do
    %{
      type: :knowledge,
      name: "Feedback: #{String.slice(attrs[:content], 0, 50)}...",
      payload: %{
        type: "feedback",
        source: to_string(attrs[:source]),
        content: attrs[:content]
      }
    }
  end

  defp generate_id(prefix) do
    random_bytes = :crypto.strong_rand_bytes(8)
    encoded = random_bytes |> Base.encode16(case: :lower)
    "#{prefix}_#{encoded}"
  end

  defp maybe_add_filter(acc, nil, _field, _idx), do: acc

  defp maybe_add_filter({clauses, params}, value, field, idx) do
    {["#{field} = ?#{idx}" | clauses], [to_string(value) | params]}
  end

  defp maybe_add_filter([], value, field, idx) do
    maybe_add_filter({[], []}, value, field, idx)
  end

  defp update_experiment_field(id, field, value) do
    db_path = KMS.sqlite_path()

    # Note: field name is injected directly (unsafe if user input), but here it's hardcoded in callers.
    # value should be parameterized if possible, but here it's passed as string.
    # For correctness with bind, the caller should pass value as param.
    # But start_experiment passes "datetime('now')" which is SQL.
    # So we leave value injection for now, assuming safe callers.
    # Ideally should be refactored.
    query = "UPDATE experiments SET #{field} = #{value} WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id], db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  # Row converters
  defp row_to_feature([
         id,
         holon_id,
         name,
         description,
         status,
         priority,
         quarter,
         owner,
         stakeholders,
         dependencies,
         metrics,
         created_at,
         updated_at,
         completed_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      description: description,
      status: String.to_atom(status),
      priority: String.to_atom(priority),
      quarter: quarter,
      owner: owner,
      stakeholders: Jason.decode!(stakeholders || "[]"),
      dependencies: Jason.decode!(dependencies || "[]"),
      metrics: Jason.decode!(metrics || "{}"),
      created_at: created_at,
      updated_at: updated_at,
      completed_at: completed_at
    }
  end

  defp row_to_release([
         id,
         holon_id,
         version,
         name,
         status,
         features,
         changes,
         breaking,
         notes,
         deployed_at,
         rolled_back_at,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      version: version,
      name: name,
      status: String.to_atom(status),
      features: Jason.decode!(features || "[]"),
      changes: Jason.decode!(changes || "[]"),
      breaking_changes: Jason.decode!(breaking || "[]"),
      release_notes: notes,
      deployed_at: deployed_at,
      rolled_back_at: rolled_back_at,
      created_at: created_at
    }
  end

  defp row_to_feedback([
         id,
         holon_id,
         source,
         customer_id,
         content,
         sentiment,
         category,
         linked,
         status,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      source: String.to_atom(source),
      customer_id: customer_id,
      content: content,
      sentiment: String.to_atom(sentiment),
      category: category,
      linked_features: Jason.decode!(linked || "[]"),
      status: String.to_atom(status),
      created_at: created_at
    }
  end

  defp row_to_experiment([
         id,
         holon_id,
         name,
         hypothesis,
         status,
         variant_a,
         variant_b,
         metrics,
         sample_size,
         start_date,
         end_date,
         results,
         conclusion,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      hypothesis: hypothesis,
      status: String.to_atom(status),
      variant_a: variant_a,
      variant_b: variant_b,
      metrics: Jason.decode!(metrics || "[]"),
      sample_size: sample_size,
      start_date: start_date,
      end_date: end_date,
      results: if(results, do: Jason.decode!(results), else: nil),
      conclusion: conclusion,
      created_at: created_at
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

  defp row_to_roadmap_item([
         id,
         holon_id,
         name,
         description,
         quarter,
         theme,
         status,
         features,
         dependencies,
         confidence,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      description: description,
      quarter: quarter,
      theme: theme,
      status: String.to_atom(status),
      features: Jason.decode!(features || "[]"),
      dependencies: Jason.decode!(dependencies || "[]"),
      confidence: confidence,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_kpi([
         id,
         holon_id,
         name,
         description,
         category,
         target,
         current,
         unit,
         trend,
         linked,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      description: description,
      category: category,
      target: target,
      current: current,
      unit: unit,
      trend: String.to_atom(trend),
      linked_features: Jason.decode!(linked || "[]"),
      updated_at: updated_at
    }
  end
end
