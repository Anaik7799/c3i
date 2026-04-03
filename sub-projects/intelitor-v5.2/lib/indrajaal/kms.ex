defmodule Indrajaal.KMS do
  @moduledoc """
  Public Interface for the Knowledge Management System (KMS).

  This module acts as the public facade for the KMS system, delegating
  calls to the underlying service and storage engines.

  ## Purpose
  Unified access point for:
  - Holon CRUD operations (SQLite)
  - Analytics & Reports (DuckDB)
  - Vector Search (SQLite-VSS)
  - Web Knowledge (Search/Extraction)

  ## Compliance
  - SC-KMS-001: SQLite + DuckDB backend
  - SC-KMS-002: Cross-runtime access
  """

  alias Indrajaal.KMS.Service

  # Configuration & Paths
  defdelegate init(), to: Service
  defdelegate data_dir(), to: Service
  defdelegate sqlite_path(), to: Service
  defdelegate duckdb_path(), to: Service
  defdelegate stamp_constraints(), to: Service

  # Holon CRUD
  defdelegate get_holon(id), to: Service
  defdelegate get_holon_by_fqun(fqun), to: Service
  defdelegate list_holons(opts \\ []), to: Service
  defdelegate create_holon(attrs), to: Service
  defdelegate update_holon(id, attrs), to: Service
  defdelegate delete_holon(id), to: Service

  # Graph & Relationships
  defdelegate create_edge(source, target, relation, opts \\ []), to: Service
  defdelegate create_edge(edge_map), to: Service
  defdelegate get_edges(id), to: Service
  defdelegate list_edges(opts \\ []), to: Service
  defdelegate get_children(id), to: Service
  defdelegate get_descendants(id), to: Service

  # Search & Vectors
  defdelegate search(query, opts \\ []), to: Service
  defdelegate store_embedding(id, embedding, opts \\ []), to: Service
  defdelegate get_embedding(id, opts \\ []), to: Service
  defdelegate similarity_search(embedding, opts \\ []), to: Service

  # AI & Web Knowledge
  defdelegate ask_oracle(query, opts \\ []), to: Service
  defdelegate ask_oracle_augmented(query, opts \\ []), to: Service
  defdelegate web_search(query, opts \\ []), to: Service
  defdelegate fetch_url(url, opts \\ []), to: Service
  defdelegate web_cache_stats(), to: Service

  # Analytics & Reporting
  defdelegate health_report(), to: Service
  defdelegate event_stats(opts \\ []), to: Service
  defdelegate entropy_report(threshold \\ 0.5), to: Service
  defdelegate archive_events(days \\ 90), to: Service
  defdelegate log_event(id, type, payload \\ %{}), to: Service

  # Swarm Operations
  defdelegate extract_swarm_cell(id, path), to: Service
  defdelegate merge_swarm_cell(path), to: Service
end
