defmodule Indrajaal.KMS.Developer do
  @moduledoc """
  Developer Knowledge Management for KMS.

  WHAT: Capture, link, and retrieve developer-focused knowledge artifacts.
  WHY: Enable knowledge-driven development with contextual insights.
  CONSTRAINTS: SC-KMS-001 (SQLite), SC-KMS-002 (cross-runtime), SC-DEV-001 (code linking)

  ## Use Cases

  1. **Developer Knowledge Capture** - Capture insights during coding
  2. **Code-Knowledge Linking** - Link holons to code locations
  3. **Decision Documentation** - Record architectural decisions (ADRs)
  4. **Pattern Library** - Store and retrieve reusable patterns
  5. **Debug Session Capture** - Document debugging sessions
  6. **Review Integration** - Capture code review knowledge
  7. **Onboarding Acceleration** - Contextual help for new developers

  ## Usage

      # Link knowledge to code
      :ok = Developer.link_to_code(holon_id, "lib/auth/oauth.ex", 42, 58)

      # Record a decision
      {:ok, decision} = Developer.record_decision(%{
        title: "Use JWT for API auth",
        context: "Need stateless authentication",
        decision: "Implement JWT with refresh tokens",
        consequences: "Must handle token revocation"
      })

      # Store a pattern
      {:ok, pattern} = Developer.store_pattern(%{
        name: "GenServer with Circuit Breaker",
        category: :resilience,
        template: "..."
      })
  """

  require Logger

  alias Indrajaal.KMS
  alias Indrajaal.Zenoh.DatabaseProxy
  # SQLite operations are done through Zenoh proxy (SC-DBPROXY-001)

  # ============================================================================
  # Types
  # ============================================================================

  @type code_link :: %{
          id: String.t(),
          holon_id: String.t(),
          file_path: String.t(),
          start_line: non_neg_integer(),
          end_line: non_neg_integer() | nil,
          link_type: link_type(),
          context: String.t() | nil,
          git_commit: String.t() | nil,
          created_at: String.t(),
          updated_at: String.t()
        }

  @type link_type :: :explains | :implements | :documents | :references | :tests | :reviews

  @type decision :: %{
          id: String.t(),
          holon_id: String.t(),
          title: String.t(),
          status: decision_status(),
          context: String.t(),
          decision: String.t(),
          consequences: String.t() | nil,
          alternatives: [String.t()],
          stakeholders: [String.t()],
          related_decisions: [String.t()],
          supersedes: String.t() | nil,
          created_at: String.t(),
          updated_at: String.t()
        }

  @type decision_status :: :proposed | :accepted | :deprecated | :superseded

  @type pattern :: %{
          id: String.t(),
          holon_id: String.t(),
          name: String.t(),
          category: pattern_category(),
          problem: String.t(),
          solution: String.t(),
          template: String.t(),
          examples: [String.t()],
          tags: [String.t()],
          usage_count: non_neg_integer(),
          created_at: String.t(),
          updated_at: String.t()
        }

  @type pattern_category ::
          :structural
          | :behavioral
          | :creational
          | :resilience
          | :security
          | :performance
          | :testing

  @type debug_session :: %{
          id: String.t(),
          holon_id: String.t(),
          title: String.t(),
          symptom: String.t(),
          root_cause: String.t() | nil,
          investigation_steps: [String.t()],
          solution: String.t() | nil,
          prevention: String.t() | nil,
          time_spent_minutes: non_neg_integer(),
          files_involved: [String.t()],
          created_at: String.t(),
          resolved_at: String.t() | nil
        }

  @type review_note :: %{
          id: String.t(),
          holon_id: String.t(),
          pr_url: String.t() | nil,
          file_path: String.t(),
          line_number: non_neg_integer() | nil,
          note_type: review_note_type(),
          content: String.t(),
          author: String.t(),
          resolved: boolean(),
          created_at: String.t()
        }

  @type review_note_type :: :suggestion | :question | :issue | :praise | :learning

  # ============================================================================
  # Schema Extension
  # ============================================================================

  @developer_schema """
  -- Code-Knowledge Links
  CREATE TABLE IF NOT EXISTS code_links (
    id TEXT PRIMARY KEY,
    holon_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    start_line INTEGER NOT NULL,
    end_line INTEGER,
    link_type TEXT NOT NULL CHECK(link_type IN ('explains','implements','documents','references','tests','reviews')),
    context TEXT,
    git_commit TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_code_links_holon ON code_links(holon_id);
  CREATE INDEX IF NOT EXISTS idx_code_links_file ON code_links(file_path);
  CREATE INDEX IF NOT EXISTS idx_code_links_type ON code_links(link_type);

  -- Architectural Decisions (ADRs)
  CREATE TABLE IF NOT EXISTS decisions (
    id TEXT PRIMARY KEY,
    holon_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'proposed' CHECK(status IN ('proposed','accepted','deprecated','superseded')),
    context TEXT NOT NULL,
    decision TEXT NOT NULL,
    consequences TEXT,
    alternatives TEXT DEFAULT '[]',
    stakeholders TEXT DEFAULT '[]',
    related_decisions TEXT DEFAULT '[]',
    supersedes TEXT REFERENCES decisions(id),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_decisions_holon ON decisions(holon_id);
  CREATE INDEX IF NOT EXISTS idx_decisions_status ON decisions(status);

  -- Pattern Library
  CREATE TABLE IF NOT EXISTS patterns (
    id TEXT PRIMARY KEY,
    holon_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK(category IN ('structural','behavioral','creational','resilience','security','performance','testing')),
    problem TEXT NOT NULL,
    solution TEXT NOT NULL,
    template TEXT NOT NULL,
    examples TEXT DEFAULT '[]',
    tags TEXT DEFAULT '[]',
    usage_count INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_patterns_holon ON patterns(holon_id);
  CREATE INDEX IF NOT EXISTS idx_patterns_category ON patterns(category);
  CREATE INDEX IF NOT EXISTS idx_patterns_name ON patterns(name);

  -- Debug Sessions
  CREATE TABLE IF NOT EXISTS debug_sessions (
    id TEXT PRIMARY KEY,
    holon_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    symptom TEXT NOT NULL,
    root_cause TEXT,
    investigation_steps TEXT DEFAULT '[]',
    solution TEXT,
    prevention TEXT,
    time_spent_minutes INTEGER DEFAULT 0,
    files_involved TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now')),
    resolved_at TEXT
  );

  CREATE INDEX IF NOT EXISTS idx_debug_sessions_holon ON debug_sessions(holon_id);

  -- Review Notes
  CREATE TABLE IF NOT EXISTS review_notes (
    id TEXT PRIMARY KEY,
    holon_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    pr_url TEXT,
    file_path TEXT NOT NULL,
    line_number INTEGER,
    note_type TEXT NOT NULL CHECK(note_type IN ('suggestion','question','issue','praise','learning')),
    content TEXT NOT NULL,
    author TEXT NOT NULL,
    resolved INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_review_notes_holon ON review_notes(holon_id);
  CREATE INDEX IF NOT EXISTS idx_review_notes_file ON review_notes(file_path);
  CREATE INDEX IF NOT EXISTS idx_review_notes_type ON review_notes(note_type);

  -- Developer FTS extension
  CREATE VIRTUAL TABLE IF NOT EXISTS developer_fts USING fts5(
    id, type, title, content,
    tokenize='porter'
  );
  """

  # ============================================================================
  # Initialization
  # ============================================================================

  @doc """
  Initialize developer schema. Call after KMS.init/0.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    db_path = KMS.sqlite_path()

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    # Execute schema creation statements via proxy
    @developer_schema
    |> String.split(";")
    |> Enum.each(fn stmt ->
      stmt = String.trim(stmt)
      if stmt != "", do: DatabaseProxy.sqlite_execute(stmt, [], db_path: db_path)
    end)

    Logger.info("[KMS.Developer] Developer schema initialized via Zenoh proxy")
    :ok

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path) do
    #   @developer_schema
    #   |> String.split(";")
    #   |> Enum.each(fn stmt ->
    #     stmt = String.trim(stmt)
    #     if stmt != "", do: Exqlite.Sqlite3.execute(conn, stmt)
    #   end)
    #
    #   Exqlite.Sqlite3.close(conn)
    #   Logger.info("[KMS.Developer] Developer schema initialized")
    #   :ok
    # end
  end

  # ============================================================================
  # Code-Knowledge Linking
  # ============================================================================

  @doc """
  Link a holon to a code location.

  ## Examples

      :ok = Developer.link_to_code("hln_abc", "lib/auth/oauth.ex", 42, 58,
        type: :implements,
        context: "OAuth2 flow implementation"
      )
  """
  @spec link_to_code(
          String.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer() | nil,
          keyword()
        ) ::
          :ok | {:error, term()}
  def link_to_code(holon_id, file_path, start_line, end_line \\ nil, opts \\ []) do
    type_value = Keyword.get(opts, :type, :references)
    link_type = type_value |> to_string()
    context = Keyword.get(opts, :context)
    git_commit = Keyword.get(opts, :git_commit) || get_current_git_commit()

    id = generate_id("lnk")
    db_path = KMS.sqlite_path()

    query = """
    INSERT INTO code_links (id, holon_id, file_path, start_line, end_line, link_type, context, git_commit)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
    ON CONFLICT (id) DO UPDATE SET
      file_path = excluded.file_path,
      start_line = excluded.start_line,
      end_line = excluded.end_line,
      context = excluded.context,
      git_commit = excluded.git_commit,
      updated_at = datetime('now')
    """

    params = [id, holon_id, file_path, start_line, end_line, link_type, context, git_commit]

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [
    #     id,
    #     holon_id,
    #     file_path,
    #     start_line,
    #     end_line,
    #     link_type,
    #     context,
    #     git_commit
    #   ])
    #
    #   case Exqlite.Sqlite3.step(conn, stmt) do
    #     :done ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       :ok
    #
    #     {:error, reason} ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       {:error, reason}
    #   end
    # end
  end

  @doc """
  Get all code links for a file.
  """
  @spec get_links_for_file(String.t()) :: {:ok, [code_link()]} | {:error, term()}
  def get_links_for_file(file_path) do
    db_path = KMS.sqlite_path()

    query = """
    SELECT cl.*, h.name as holon_name, h.type as holon_type
    FROM code_links cl
    JOIN holons h ON cl.holon_id = h.id
    WHERE cl.file_path = ?1
    ORDER BY cl.start_line
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [file_path], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        links = Enum.map(rows, &row_to_code_link/1)
        {:ok, links}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [file_path])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   links = Enum.map(results, &row_to_code_link/1)
    #   {:ok, links}
    # end
  end

  @doc """
  Get knowledge for a specific line in a file.
  """
  @spec get_knowledge_at_line(String.t(), non_neg_integer()) :: {:ok, [map()]} | {:error, term()}
  def get_knowledge_at_line(file_path, line_number) do
    db_path = KMS.sqlite_path()

    query = """
    SELECT h.*, cl.link_type, cl.context as link_context
    FROM code_links cl
    JOIN holons h ON cl.holon_id = h.id
    WHERE cl.file_path = ?1
      AND cl.start_line <= ?2
      AND (cl.end_line IS NULL OR cl.end_line >= ?2)
    ORDER BY cl.start_line DESC
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [file_path, line_number, line_number],
           db_path: db_path
         ) do
      {:ok, rows} when is_list(rows) -> {:ok, rows}
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [file_path, line_number, line_number])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   {:ok, results}
    # end
  end

  # ============================================================================
  # Decision Documentation (ADRs)
  # ============================================================================

  @doc """
  Record an architectural decision.

  ## Examples

      {:ok, decision} = Developer.record_decision(%{
        title: "Use JWT for API authentication",
        context: "Need stateless authentication for microservices",
        decision: "Implement JWT with short-lived access tokens and refresh tokens",
        consequences: "Must implement token revocation, adds complexity",
        alternatives: ["Session-based auth", "OAuth2 only"],
        stakeholders: ["backend-team", "security-team"]
      })
  """
  @spec record_decision(map()) :: {:ok, decision()} | {:error, term()}
  def record_decision(attrs) do
    id = generate_id("adr")
    holon_id = generate_id("hln")

    # Create backing holon
    holon_attrs = %{
      type: :artifact,
      name: "ADR: #{attrs[:title]}",
      payload: %{
        type: "decision",
        title: attrs[:title],
        context: attrs[:context],
        decision: attrs[:decision]
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO decisions (id, holon_id, title, status, context, decision, consequences, alternatives, stakeholders, related_decisions, supersedes)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
      """

      status = to_string(attrs[:status] || :proposed)
      alternatives = Jason.encode!(attrs[:alternatives] || [])
      stakeholders = Jason.encode!(attrs[:stakeholders] || [])
      related = Jason.encode!(attrs[:related_decisions] || [])

      params = [
        id,
        holon_id,
        attrs[:title],
        status,
        attrs[:context],
        attrs[:decision],
        attrs[:consequences],
        alternatives,
        stakeholders,
        related,
        attrs[:supersedes]
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> {:ok, get_decision!(id)}
        :ok -> {:ok, get_decision!(id)}
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
      #       {:ok, get_decision!(id)}
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  @doc """
  Get a decision by ID.
  """
  @spec get_decision(String.t()) :: {:ok, decision()} | {:error, :not_found}
  def get_decision(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM decisions WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_decision(row)}
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
    #       {:row, row} -> {:ok, row_to_decision(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  @doc """
  List patterns stored in KMS.
  """
  @spec list_patterns() :: {:ok, [map()]} | {:error, term()}
  def list_patterns do
    # Patterns are stored as holons with type :pattern
    KMS.list_holons(type: :pattern)
  end

  @doc """
  List debug sessions stored in KMS.
  """
  @spec list_debug_sessions() :: {:ok, [map()]} | {:error, term()}
  def list_debug_sessions do
    # Debug sessions are stored as holons with type :debug_session
    KMS.list_holons(type: :debug_session)
  end

  @doc """
  List code links (holon-to-code mappings).
  """
  @spec list_code_links() :: {:ok, [map()]} | {:error, term()}
  def list_code_links do
    # Code links are stored as edges with type :code_link
    KMS.list_edges(type: :code_link)
  end

  @doc """
  List decisions with optional filtering.
  """
  @spec list_decisions(keyword()) :: {:ok, [decision()]} | {:error, term()}
  def list_decisions(opts \\ []) do
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 100)

    db_path = KMS.sqlite_path()

    {query, params} =
      if status do
        {"SELECT * FROM decisions WHERE status = ?1 ORDER BY created_at DESC LIMIT ?2",
         [to_string(status), limit]}
      else
        {"SELECT * FROM decisions ORDER BY created_at DESC LIMIT ?1", [limit]}
      end

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, params, db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        decisions = Enum.map(rows, &row_to_decision/1)
        {:ok, decisions}

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
    #   decisions = Enum.map(results, &row_to_decision/1)
    #   {:ok, decisions}
    # end
  end

  @doc """
  Accept a decision (change status to accepted).
  """
  @spec accept_decision(String.t()) :: :ok | {:error, term()}
  def accept_decision(id) do
    update_decision_status(id, :accepted)
  end

  @doc """
  Deprecate a decision.
  """
  @spec deprecate_decision(String.t(), String.t() | nil) :: :ok | {:error, term()}
  def deprecate_decision(id, superseded_by \\ nil) do
    db_path = KMS.sqlite_path()

    query =
      if superseded_by do
        "UPDATE decisions SET status = 'superseded', supersedes = ?2, updated_at = datetime('now') WHERE id = ?1"
      else
        "UPDATE decisions SET status = 'deprecated', updated_at = datetime('now') WHERE id = ?1"
      end

    params = if superseded_by, do: [id, superseded_by], else: [id]

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   if superseded_by do
    #     Exqlite.Sqlite3.bind(stmt, [id, superseded_by])
    #   else
    #     Exqlite.Sqlite3.bind(stmt, [id])
    #   end
    #
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  # ============================================================================
  # Pattern Library
  # ============================================================================

  @doc """
  Store a reusable pattern.

  ## Examples

      {:ok, pattern} = Developer.store_pattern(%{
        name: "GenServer with Circuit Breaker",
        category: :resilience,
        problem: "Prevent cascading failures in distributed systems",
        solution: "Wrap GenServer calls with circuit breaker logic",
        template: "defmodule MyService do\n  use GenServer\n  # ... circuit breaker implementation\nend",
        tags: ["genserver", "fault-tolerance", "resilience"]
      })
  """
  @spec store_pattern(map()) :: {:ok, pattern()} | {:error, term()}
  def store_pattern(attrs) do
    id = generate_id("pat")
    holon_id = generate_id("hln")

    holon_attrs = build_pattern_holon_attrs(attrs)

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO patterns (id, holon_id, name, category, problem, solution, template, examples, tags)
      VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
      """

      category = to_string(attrs[:category])
      examples = Jason.encode!(attrs[:examples] || [])
      tags = Jason.encode!(attrs[:tags] || [])

      params = [
        id,
        holon_id,
        attrs[:name],
        category,
        attrs[:problem],
        attrs[:solution],
        attrs[:template],
        examples,
        tags
      ]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> {:ok, get_pattern!(id)}
        :ok -> {:ok, get_pattern!(id)}
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
      #       {:ok, get_pattern!(id)}
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  defp build_pattern_holon_attrs(attrs) do
    %{
      type: :artifact,
      name: "Pattern: #{attrs[:name]}",
      payload: %{
        type: "pattern",
        name: attrs[:name],
        category: to_string(attrs[:category]),
        template: attrs[:template]
      }
    }
  end

  @doc """
  Get a pattern by ID.
  """
  @spec get_pattern(String.t()) :: {:ok, pattern()} | {:error, :not_found}
  def get_pattern(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM patterns WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_pattern(row)}
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
    #       {:row, row} -> {:ok, row_to_pattern(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  @doc """
  Search patterns by category or tags.
  """
  @spec search_patterns(keyword()) :: {:ok, [pattern()]} | {:error, term()}
  def search_patterns(opts \\ []) do
    category = Keyword.get(opts, :category)
    tag = Keyword.get(opts, :tag)
    query_text = Keyword.get(opts, :query)
    limit = Keyword.get(opts, :limit, 50)

    db_path = KMS.sqlite_path()

    {query, params} =
      cond do
        category ->
          {"SELECT * FROM patterns WHERE category = ?1 ORDER BY usage_count DESC LIMIT ?2",
           [to_string(category), limit]}

        tag ->
          {"SELECT * FROM patterns WHERE tags LIKE ?1 ORDER BY usage_count DESC LIMIT ?2",
           ["%\"#{tag}\"%", limit]}

        query_text ->
          {"SELECT * FROM patterns WHERE name LIKE ?1 OR problem LIKE ?1 OR solution LIKE ?1 ORDER BY usage_count DESC LIMIT ?2",
           ["%#{query_text}%", limit]}

        true ->
          {"SELECT * FROM patterns ORDER BY usage_count DESC LIMIT ?1", [limit]}
      end

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, params, db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        patterns = Enum.map(rows, &row_to_pattern/1)
        {:ok, patterns}

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
    #   patterns = Enum.map(results, &row_to_pattern/1)
    #   {:ok, patterns}
    # end
  end

  @doc """
  Increment pattern usage count.
  """
  @spec use_pattern(String.t()) :: :ok | {:error, term()}
  def use_pattern(id) do
    db_path = KMS.sqlite_path()

    query =
      "UPDATE patterns SET usage_count = usage_count + 1, updated_at = datetime('now') WHERE id = ?1"

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

  # ============================================================================
  # Debug Session Capture
  # ============================================================================

  @doc """
  Start a debug session.

  ## Examples

      {:ok, session} = Developer.start_debug_session(%{
        title: "Memory leak in WebSocket handler",
        symptom: "Memory usage grows unbounded over time"
      })
  """
  @spec start_debug_session(map()) :: {:ok, debug_session()} | {:error, term()}
  def start_debug_session(attrs) do
    id = generate_id("dbg")
    holon_id = generate_id("hln")

    # Create backing holon for significant debug sessions
    holon_attrs = %{
      type: :process,
      name: "Debug: #{attrs[:title]}",
      payload: %{
        type: "debug_session",
        symptom: attrs[:symptom]
      }
    }

    with {:ok, _holon} <- KMS.create_holon(holon_attrs) do
      db_path = KMS.sqlite_path()

      query = """
      INSERT INTO debug_sessions (id, holon_id, title, symptom, investigation_steps, files_involved)
      VALUES (?1, ?2, ?3, ?4, '[]', '[]')
      """

      params = [id, holon_id, attrs[:title], attrs[:symptom]]

      # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
      case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
        {:ok, _} -> {:ok, get_debug_session!(id)}
        :ok -> {:ok, get_debug_session!(id)}
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
      #       {:ok, get_debug_session!(id)}
      #
      #     {:error, reason} ->
      #       Exqlite.Sqlite3.release(conn, stmt)
      #       Exqlite.Sqlite3.close(conn)
      #       {:error, reason}
      #   end
      # end
    end
  end

  @doc """
  Add an investigation step to a debug session.
  """
  @spec add_investigation_step(String.t(), String.t()) :: :ok | {:error, term()}
  def add_investigation_step(session_id, step) do
    with {:ok, session} <- get_debug_session(session_id) do
      steps = session.investigation_steps ++ [step]
      update_debug_session_field(session_id, :investigation_steps, Jason.encode!(steps))
    end
  end

  @doc """
  Resolve a debug session with root cause and solution.
  """
  @spec resolve_debug_session(String.t(), map()) :: :ok | {:error, term()}
  def resolve_debug_session(session_id, resolution) do
    db_path = KMS.sqlite_path()

    query = """
    UPDATE debug_sessions SET
      root_cause = ?2,
      solution = ?3,
      prevention = ?4,
      time_spent_minutes = ?5,
      resolved_at = datetime('now')
    WHERE id = ?1
    """

    params = [
      session_id,
      resolution[:root_cause],
      resolution[:solution],
      resolution[:prevention],
      resolution[:time_spent_minutes] || 0
    ]

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, params)
    #
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  @doc """
  Get a debug session by ID.
  """
  @spec get_debug_session(String.t()) :: {:ok, debug_session()} | {:error, :not_found}
  def get_debug_session(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM debug_sessions WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> {:ok, row_to_debug_session(row)}
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
    #       {:row, row} -> {:ok, row_to_debug_session(row)}
    #       :done -> {:error, :not_found}
    #     end
    #
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   result
    # end
  end

  @doc """
  Search debug sessions by symptom or root cause.
  """
  @spec search_debug_sessions(String.t()) :: {:ok, [debug_session()]} | {:error, term()}
  def search_debug_sessions(query_text) do
    db_path = KMS.sqlite_path()

    query = """
    SELECT * FROM debug_sessions
    WHERE symptom LIKE ?1 OR root_cause LIKE ?1 OR solution LIKE ?1
    ORDER BY created_at DESC
    LIMIT 50
    """

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, ["%#{query_text}%"], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        sessions = Enum.map(rows, &row_to_debug_session/1)
        {:ok, sessions}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, ["%#{query_text}%"])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   sessions = Enum.map(results, &row_to_debug_session/1)
    #   {:ok, sessions}
    # end
  end

  # ============================================================================
  # Review Integration
  # ============================================================================

  @doc """
  Add a review note.
  """
  @spec add_review_note(map()) :: {:ok, review_note()} | {:error, term()}
  def add_review_note(attrs) do
    id = generate_id("rev")
    holon_id = generate_id("hln")

    # Create backing holon for significant learnings
    if attrs[:note_type] in [:learning, :issue] do
      holon_attrs = %{
        type: :knowledge,
        name: "Review: #{String.slice(attrs[:content], 0, 50)}...",
        payload: %{
          type: "review_note",
          file: attrs[:file_path],
          content: attrs[:content]
        }
      }

      KMS.create_holon(holon_attrs)
    end

    db_path = KMS.sqlite_path()

    query = """
    INSERT INTO review_notes (id, holon_id, pr_url, file_path, line_number, note_type, content, author)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
    """

    params = [
      id,
      holon_id,
      attrs[:pr_url],
      attrs[:file_path],
      attrs[:line_number],
      to_string(attrs[:note_type]),
      attrs[:content],
      attrs[:author]
    ]

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, params, db_path: db_path) do
      {:ok, _} -> {:ok, get_review_note!(id)}
      :ok -> {:ok, get_review_note!(id)}
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
    #       {:ok, get_review_note!(id)}
    #
    #     {:error, reason} ->
    #       Exqlite.Sqlite3.release(conn, stmt)
    #       Exqlite.Sqlite3.close(conn)
    #       {:error, reason}
    #   end
    # end
  end

  @doc """
  Get review notes for a file.
  """
  @spec get_review_notes_for_file(String.t()) :: {:ok, [review_note()]} | {:error, term()}
  def get_review_notes_for_file(file_path) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM review_notes WHERE file_path = ?1 ORDER BY line_number, created_at"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [file_path], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        notes = Enum.map(rows, &row_to_review_note/1)
        {:ok, notes}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [file_path])
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   notes = Enum.map(results, &row_to_review_note/1)
    #   {:ok, notes}
    # end
  end

  # ============================================================================
  # Onboarding / Contextual Help
  # ============================================================================

  @doc """
  Get contextual knowledge for a file (combines all knowledge types).
  """
  @spec get_file_context(String.t()) :: {:ok, map()} | {:error, term()}
  def get_file_context(file_path) do
    with {:ok, code_links} <- get_links_for_file(file_path),
         {:ok, review_notes} <- get_review_notes_for_file(file_path) do
      # Get related decisions
      holon_ids = Enum.map(code_links, & &1.holon_id)

      {:ok, decisions} =
        if Enum.empty?(holon_ids) do
          {:ok, []}
        else
          list_decisions_for_holons(holon_ids)
        end

      {:ok,
       %{
         file_path: file_path,
         knowledge_links: code_links,
         review_notes: review_notes,
         related_decisions: decisions,
         knowledge_density: length(code_links) + length(review_notes)
       }}
    end
  end

  @doc """
  Get developer statistics.
  """
  @spec developer_stats() :: {:ok, map()} | {:error, term()}
  def developer_stats do
    db_path = KMS.sqlite_path()

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    stats = %{
      code_links: count_table(db_path, "code_links"),
      decisions: count_table(db_path, "decisions"),
      patterns: count_table(db_path, "patterns"),
      debug_sessions: count_table(db_path, "debug_sessions"),
      review_notes: count_table(db_path, "review_notes"),
      decisions_by_status: count_by_field(db_path, "decisions", "status"),
      patterns_by_category: count_by_field(db_path, "patterns", "category")
    }

    {:ok, stats}

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path) do
    #   stats = %{
    #     code_links: count_table(conn, "code_links"),
    #     decisions: count_table(conn, "decisions"),
    #     patterns: count_table(conn, "patterns"),
    #     debug_sessions: count_table(conn, "debug_sessions"),
    #     review_notes: count_table(conn, "review_notes"),
    #     decisions_by_status: count_by_field(conn, "decisions", "status"),
    #     patterns_by_category: count_by_field(conn, "patterns", "category")
    #   }
    #
    #   Exqlite.Sqlite3.close(conn)
    #   {:ok, stats}
    # end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp generate_id(prefix) do
    random_bytes = :crypto.strong_rand_bytes(8)
    encoded = random_bytes |> Base.encode16(case: :lower)
    "#{prefix}_#{encoded}"
  end

  defp get_current_git_commit do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {commit, 0} -> String.trim(commit)
      _ -> nil
    end
  end

  defp update_decision_status(id, status) do
    db_path = KMS.sqlite_path()
    query = "UPDATE decisions SET status = ?2, updated_at = datetime('now') WHERE id = ?1"

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

  defp update_debug_session_field(id, field, value) do
    db_path = KMS.sqlite_path()
    query = "UPDATE debug_sessions SET #{field} = ?2 WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_execute(query, [id, value], db_path: db_path) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id, value])
    #   Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   :ok
    # end
  end

  defp list_decisions_for_holons(holon_ids) do
    db_path = KMS.sqlite_path()
    placeholders = Enum.map_join(1..length(holon_ids), ",", &"?#{&1}")
    query = "SELECT * FROM decisions WHERE holon_id IN (#{placeholders})"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, holon_ids, db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        {:ok, Enum.map(rows, &row_to_decision/1)}

      {:error, reason} ->
        {:error, reason}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, holon_ids)
    #
    #   results = fetch_all_rows(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #
    #   {:ok, Enum.map(results, &row_to_decision/1)}
    # end
  end

  defp count_table(db_path, table) do
    query = "SELECT COUNT(*) FROM #{table}"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [], db_path: db_path) do
      {:ok, [[count]]} -> count
      {:ok, _} -> 0
      {:error, _} -> 0
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, "SELECT COUNT(*) FROM #{table}")
    #
    # count =
    #   case Exqlite.Sqlite3.step(conn, stmt) do
    #     {:row, [n]} -> n
    #     _ -> 0
    #   end
    #
    # Exqlite.Sqlite3.release(conn, stmt)
    # count
  end

  defp count_by_field(db_path, table, field) do
    query = "SELECT #{field}, COUNT(*) FROM #{table} GROUP BY #{field}"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [], db_path: db_path) do
      {:ok, rows} when is_list(rows) ->
        Map.new(rows, fn [k, v] -> {k, v} end)

      {:error, _} ->
        %{}
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # {:ok, stmt} =
    #   Exqlite.Sqlite3.prepare(conn, "SELECT #{field}, COUNT(*) FROM #{table} GROUP BY #{field}")
    #
    # results = fetch_all_rows(conn, stmt)
    # Exqlite.Sqlite3.release(conn, stmt)
    # Map.new(results, fn [k, v] -> {k, v} end)
  end

  defp get_decision!(id) do
    {:ok, decision} = get_decision(id)
    decision
  end

  defp get_pattern!(id) do
    {:ok, pattern} = get_pattern(id)
    pattern
  end

  defp get_debug_session!(id) do
    {:ok, session} = get_debug_session(id)
    session
  end

  defp get_review_note!(id) do
    db_path = KMS.sqlite_path()
    query = "SELECT * FROM review_notes WHERE id = ?1"

    # SC-DBPROXY-001: Use Zenoh proxy for SQLite access
    case DatabaseProxy.sqlite_query(query, [id], db_path: db_path) do
      {:ok, [row]} -> row_to_review_note(row)
      {:ok, []} -> raise "Review note not found: #{id}"
      {:error, reason} -> raise "Failed to get review note: #{inspect(reason)}"
    end

    # LEGACY: Direct Exqlite access (SC-DBPROXY-001: commented out)
    # with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
    #      {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
    #   Exqlite.Sqlite3.bind(stmt, [id])
    #   {:row, row} = Exqlite.Sqlite3.step(conn, stmt)
    #   Exqlite.Sqlite3.release(conn, stmt)
    #   Exqlite.Sqlite3.close(conn)
    #   row_to_review_note(row)
    # end
  end

  # Row converters
  defp row_to_code_link([
         id,
         holon_id,
         file_path,
         start_line,
         end_line,
         link_type,
         context,
         git_commit,
         created_at,
         updated_at | _
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      file_path: file_path,
      start_line: start_line,
      end_line: end_line,
      link_type: String.to_atom(link_type),
      context: context,
      git_commit: git_commit,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_decision([
         id,
         holon_id,
         title,
         status,
         context,
         decision,
         consequences,
         alternatives,
         stakeholders,
         related,
         supersedes,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      title: title,
      status: String.to_atom(status),
      context: context,
      decision: decision,
      consequences: consequences,
      alternatives: Jason.decode!(alternatives || "[]"),
      stakeholders: Jason.decode!(stakeholders || "[]"),
      related_decisions: Jason.decode!(related || "[]"),
      supersedes: supersedes,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_pattern([
         id,
         holon_id,
         name,
         category,
         problem,
         solution,
         template,
         examples,
         tags,
         usage_count,
         created_at,
         updated_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      name: name,
      category: String.to_atom(category),
      problem: problem,
      solution: solution,
      template: template,
      examples: Jason.decode!(examples || "[]"),
      tags: Jason.decode!(tags || "[]"),
      usage_count: usage_count,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  defp row_to_debug_session([
         id,
         holon_id,
         title,
         symptom,
         root_cause,
         steps,
         solution,
         prevention,
         time_spent,
         files,
         created_at,
         resolved_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      title: title,
      symptom: symptom,
      root_cause: root_cause,
      investigation_steps: Jason.decode!(steps || "[]"),
      solution: solution,
      prevention: prevention,
      time_spent_minutes: time_spent,
      files_involved: Jason.decode!(files || "[]"),
      created_at: created_at,
      resolved_at: resolved_at
    }
  end

  defp row_to_review_note([
         id,
         holon_id,
         pr_url,
         file_path,
         line_number,
         note_type,
         content,
         author,
         resolved,
         created_at
       ]) do
    %{
      id: id,
      holon_id: holon_id,
      pr_url: pr_url,
      file_path: file_path,
      line_number: line_number,
      note_type: String.to_atom(note_type),
      content: content,
      author: author,
      resolved: resolved == 1,
      created_at: created_at
    }
  end
end
