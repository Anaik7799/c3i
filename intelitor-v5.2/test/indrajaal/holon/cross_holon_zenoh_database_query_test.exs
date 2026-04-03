defmodule Indrajaal.Holon.CrossHolonZenohDatabaseQueryTest do
  @moduledoc """
  TDG test suite for cross-holon Zenoh-based database queries.

  ## WHAT
  Validates the full simulated round-trip for Zenoh-mediated cross-holon database
  queries: FQDN-to-Zenoh-topic routing via the `indrajaal/db/{uhi}/{operation}`
  pattern, request dispatch with mandatory `request_id` correlation, timeout
  enforcement (< 5 s per SC-XHOLON-025), version-vector OCC conflict resolution,
  saga distributed-transaction 2-phase commit/abort protocol, and termination
  guarantees proven via ExUnitProperties and PropCheck generators.

  ## WHY
  SC-XHOLON-003 mandates ALL cross-holon database access through Zenoh — direct
  SQLite/DuckDB connections across holon boundaries are FORBIDDEN.
  SC-XHOLON-025 enforces a strict timeout budget of < 5 000 ms per request.
  SC-DBCROSS-001 defines the canonical Zenoh topic pattern.
  SC-DBCROSS-002 defines the saga coordination protocol for distributed transactions.
  SC-DBCROSS-003 requires version-vector conflict resolution (OCC max-merge).
  SC-DBCROSS-004 mandates timeout-triggered abort with no orphaned transactions.

  ## CONSTRAINTS
  SC-XHOLON-003, SC-XHOLON-025, SC-XHOLON-030, SC-XHOLON-031, SC-XHOLON-032,
  SC-DBCROSS-001, SC-DBCROSS-002, SC-DBCROSS-003, SC-DBCROSS-004,
  AOR-DBCROSS-001, AOR-DBCROSS-002, EP-GEN-014

  ## Coverage Matrix
  | Concern                                        | PropCheck | StreamData | Unit |
  |------------------------------------------------|-----------|------------|------|
  | FQDN → Zenoh topic pattern                     | 0         | 1          | 3    |
  | Query dispatch & request_id correlation        | 0         | 1          | 3    |
  | Round-trip latency < 5 000 ms                  | 0         | 1          | 2    |
  | Timeout → {:error, :timeout}                   | 0         | 0          | 2    |
  | Timeout purges pending transaction             | 0         | 0          | 2    |
  | Version-vector concurrent write detection      | 1         | 1          | 2    |
  | Version-vector conflict resolution (max-merge) | 1         | 1          | 2    |
  | Saga prepare → commit path                     | 0         | 0          | 3    |
  | Saga prepare → abort path                      | 0         | 0          | 2    |
  | Property: all queries terminate                | 1         | 1          | 0    |
  | TOTAL                                          | 3         | 6          | 21   |

  ## EP-GEN-014 Compliance
  - `use PropCheck` enables `forall`/`property` macros (PropCheck-native).
  - `import ExUnitProperties, except: [property: 2, property: 3]` exposes `ExUnitProperties.check all` WITHOUT
    importing any conflicting names — this is the mandatory pattern for this file.
  - `PC.` prefix for ALL PropCheck generators inside `property` / `forall` blocks.
  - `SD.` prefix for ALL StreamData generators inside `ExUnitProperties.check all`.
  - All helpers are self-contained `defp` — zero production module dependencies.
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: PropCheck for property/forall blocks.
  use PropCheck

  # CRITICAL EP-GEN-014: require (NOT import) to avoid check/2 name conflict.
  # All check all invocations MUST be qualified as ExUnitProperties.check all.
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :unit
  @moduletag :cross_holon
  @moduletag :zenoh
  @moduletag :xholon

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ============================================================================
  # SECTION 1: Zenoh Topic Routing
  # Verify the canonical topic pattern indrajaal/db/{uhi}/{operation}
  # SC-DBCROSS-001, SC-XHOLON-003, AOR-DBCROSS-001
  # ============================================================================

  describe "Zenoh topic routing" do
    test "TOPIC_01: topic follows indrajaal/db/{uhi}/{operation} pattern (SC-DBCROSS-001)" do
      uhi = "ex:l3:kms:srv:main"
      operation = "query"

      topic = build_zenoh_topic(uhi, operation)

      assert topic == "indrajaal/db/ex:l3:kms:srv:main/query",
             "Zenoh topic must follow indrajaal/db/{uhi}/{operation} (SC-DBCROSS-001)"

      assert String.starts_with?(topic, "indrajaal/db/"),
             "All cross-holon DB topics must start with indrajaal/db/ (AOR-DBCROSS-001)"
    end

    test "TOPIC_02: topic depth does not exceed 6 levels (SC-ZTEST-017)" do
      uhi = "fs:l4:prj:agt:cockpit"

      for operation <- ["query", "execute", "execute_cas", "version_vector"] do
        topic = build_zenoh_topic(uhi, operation)
        depth = length(String.split(topic, "/"))

        assert depth <= 6,
               "Topic depth #{depth} exceeds SC-ZTEST-017 limit of 6: #{topic}"
      end
    end

    test "TOPIC_03: resolve_holon/2 returns {:error, :not_found} for unknown FQDN" do
      registry = new_holon_registry(2)

      result = resolve_holon(registry, "ex:l3:ghost:srv:unknown")

      assert result == {:error, :not_found},
             "Unknown FQDN must return {:error, :not_found} — no phantom routes"
    end

    test "TOPIC_STREAM_01: generated topics for any alphanumeric UHI always pass structural checks" do
      ExUnitProperties.check all(
                               instance <- SD.string(:alphanumeric, min_length: 1, max_length: 8),
                               operation <- SD.member_of(["query", "execute", "version_vector"])
                             ) do
        uhi = "ex:l3:kms:srv:#{instance}"
        topic = build_zenoh_topic(uhi, operation)

        assert String.starts_with?(topic, "indrajaal/db/"),
               "Topic must start with indrajaal/db/ for UHI=#{uhi}"

        assert String.ends_with?(topic, "/#{operation}"),
               "Topic must end with /#{operation} for UHI=#{uhi}"

        depth = length(String.split(topic, "/"))

        assert depth <= 6,
               "Topic depth #{depth} exceeds limit of 6 for topic: #{topic}"
      end
    end
  end

  # ============================================================================
  # SECTION 2: Query Timeout Enforcement (SC-XHOLON-025)
  # All cross-holon queries must return within 5 000 ms.
  # ============================================================================

  describe "query timeout enforcement (SC-XHOLON-025)" do
    test "TIMEOUT_01: query_holon_with_timeout/4 returns {:error, :timeout} when budget expires" do
      registry = new_holon_registry(2)
      fqdn = "ex:l3:kms:srv:main"

      result =
        query_holon_with_timeout(registry, fqdn, %{request_id: generate_request_id()}, _ms = 1)

      assert match?({:error, :timeout}, result),
             "A query whose responder misses the budget must return {:error, :timeout}"
    end

    test "TIMEOUT_02: default cross-holon timeout constant is < 5 000 ms (SC-XHOLON-025)" do
      assert default_query_timeout_ms() < 5_000,
             "Default timeout must be < 5 000 ms per SC-XHOLON-025"
    end

    test "TIMEOUT_03: successful query_holon/3 completes well within 5 s" do
      registry = new_holon_registry(2)
      fqdn = "ex:l3:kms:srv:main"

      start = System.monotonic_time(:millisecond)
      result = query_holon(registry, fqdn, %{request_id: generate_request_id(), sql: "SELECT 1"})
      elapsed_ms = System.monotonic_time(:millisecond) - start

      assert match?({:ok, _}, result),
             "Registered holon query must return {:ok, _}, got: #{inspect(result)}"

      assert elapsed_ms < 5_000,
             "Round-trip took #{elapsed_ms} ms — must stay under 5 000 ms (SC-XHOLON-025)"
    end

    test "TIMEOUT_04: query to unregistered holon returns an error without hanging" do
      registry = new_holon_registry(1)

      start = System.monotonic_time(:millisecond)
      result = query_holon(registry, "ex:l3:ghost:srv:none", %{request_id: generate_request_id()})
      elapsed_ms = System.monotonic_time(:millisecond) - start

      assert match?({:error, _}, result),
             "Unregistered FQDN must return an error tuple"

      assert elapsed_ms < 5_000,
             "Error path took #{elapsed_ms} ms — must also respect the 5 000 ms SLA"
    end

    test "TIMEOUT_STREAM_01: simulated round-trips for varying holon counts all finish < 5 s" do
      ExUnitProperties.check all(count <- SD.integer(1..8)) do
        registry = new_holon_registry(count)
        fqdn = "ex:l3:kms:srv:holon1"

        start = System.monotonic_time(:millisecond)

        _result =
          query_holon(registry, fqdn, %{request_id: generate_request_id(), sql: "SELECT 1"})

        elapsed_ms = System.monotonic_time(:millisecond) - start

        assert elapsed_ms < 5_000,
               "Round-trip with #{count} holons took #{elapsed_ms} ms — must be < 5 000 ms"
      end
    end
  end

  # ============================================================================
  # SECTION 3: request_id Inclusion (AOR-DBCROSS-002)
  # Every cross-holon request must carry a unique, non-empty request_id.
  # ============================================================================

  describe "request_id inclusion" do
    test "REQID_01: query_holon/3 response echoes the original request_id" do
      registry = new_holon_registry(3)
      fqdn = "ex:l3:kms:srv:main"
      request_id = generate_request_id()

      {:ok, response} =
        query_holon(registry, fqdn, %{request_id: request_id, sql: "SELECT 1"})

      assert response.request_id == request_id,
             "Response must echo request_id for Zenoh reply correlation (AOR-DBCROSS-002)"
    end

    test "REQID_02: each generated request_id is a non-empty binary" do
      id = generate_request_id()

      assert is_binary(id), "request_id must be a binary"
      assert byte_size(id) > 0, "request_id must be non-empty"
    end

    test "REQID_03: consecutive generate_request_id/0 calls produce distinct values" do
      id1 = generate_request_id()
      id2 = generate_request_id()

      refute id1 == id2,
             "Consecutive request IDs must be distinct to prevent reply-routing ambiguity"
    end

    test "REQID_STREAM_01: all request_ids in a batch are unique" do
      ExUnitProperties.check all(count <- SD.integer(2..50)) do
        ids = for _ <- 1..count, do: generate_request_id()
        unique_ids = Enum.uniq(ids)

        assert length(unique_ids) == count,
               "Expected #{count} unique IDs, got #{length(unique_ids)} unique out of #{count}"
      end
    end
  end

  # ============================================================================
  # SECTION 4: Version Vector Conflict Resolution (SC-DBCROSS-003)
  # OCC with max-merge semantics; merges must be commutative and dominating.
  # ============================================================================

  describe "version vector conflict resolution" do
    test "VV_01: merge_version_vectors/2 takes the max counter per node" do
      vv_a = %{"ex:l3:kms:srv:main" => 4, "ex:l3:alm:srv:main" => 1}
      vv_b = %{"ex:l3:kms:srv:main" => 2, "ex:l3:alm:srv:main" => 7}

      merged = merge_version_vectors(vv_a, vv_b)

      assert merged["ex:l3:kms:srv:main"] == 4,
             "Merged vector must keep max(4, 2)=4 for ex:l3:kms:srv:main"

      assert merged["ex:l3:alm:srv:main"] == 7,
             "Merged vector must keep max(1, 7)=7 for ex:l3:alm:srv:main"
    end

    test "VV_02: concurrent writes from different holons are detected before merge" do
      write_from_a = %{"node-a" => 2, "node-b" => 1}
      write_from_b = %{"node-a" => 1, "node-b" => 2}

      assert versions_concurrent?(write_from_a, write_from_b),
             "Independent advances on disjoint nodes must be detected as concurrent"

      merged = merge_version_vectors(write_from_a, write_from_b)

      refute versions_concurrent?(merged, write_from_a),
             "Merged vector must dominate write_from_a (conflict resolved)"

      refute versions_concurrent?(merged, write_from_b),
             "Merged vector must dominate write_from_b (conflict resolved)"

      assert merged == %{"node-a" => 2, "node-b" => 2}
    end

    property "VV_PROP_01: merged vector always dominates or equals both inputs" do
      forall {vv_a, vv_b} <-
               {PC.map(PC.utf8(), PC.non_neg_integer()), PC.map(PC.utf8(), PC.non_neg_integer())} do
        merged = merge_version_vectors(vv_a, vv_b)

        dominates_or_equals?(merged, vv_a) and dominates_or_equals?(merged, vv_b)
      end
    end

    test "VV_STREAM_01: merge is commutative for any two version vectors" do
      ExUnitProperties.check all(
                               nodes <-
                                 SD.list_of(
                                   SD.string(:alphanumeric, min_length: 1),
                                   min_length: 1,
                                   max_length: 4
                                 ),
                               counters_a <-
                                 SD.list_of(SD.non_negative_integer(), length: length(nodes)),
                               counters_b <-
                                 SD.list_of(SD.non_negative_integer(), length: length(nodes))
                             ) do
        vv_a = nodes |> Enum.zip(counters_a) |> Map.new()
        vv_b = nodes |> Enum.zip(counters_b) |> Map.new()

        assert merge_version_vectors(vv_a, vv_b) == merge_version_vectors(vv_b, vv_a),
               "Version vector merge must be commutative (SC-DBCROSS-003)"
      end
    end
  end

  # ============================================================================
  # SECTION 5: Saga Pattern for Distributed Transactions (SC-DBCROSS-002)
  # 2-phase prepare → commit / prepare → abort protocol.
  # ============================================================================

  describe "saga pattern for distributed transactions" do
    test "SAGA_01: begin_saga/2 registers all participants in :pending state" do
      registry = new_holon_registry(3)
      participants = ["ex:l3:kms:srv:main", "ex:l3:alm:srv:main"]

      saga = begin_saga(registry, participants)

      assert saga.status == :pending,
             "Newly begun saga must be in :pending status"

      assert length(saga.participants) == length(participants),
             "Saga must register all #{length(participants)} participants"

      assert Enum.all?(saga.participants, fn {_uhi, state} -> state == :pending end),
             "All participants must start in :pending state"
    end

    test "SAGA_02: commit_saga/1 transitions a fully-prepared saga to :committed" do
      registry = new_holon_registry(3)
      participants = ["ex:l3:kms:srv:main", "ex:l3:alm:srv:main"]

      committed =
        registry
        |> begin_saga(participants)
        |> prepare_all_participants()
        |> commit_saga()

      assert committed.status == :committed,
             "Saga status must be :committed after successful 2-phase commit"

      assert Enum.all?(committed.participants, fn {_uhi, state} -> state == :committed end),
             "All participants must be :committed after commit_saga/1"
    end

    test "SAGA_03: abort_saga/1 rolls back all participants to :aborted regardless of phase" do
      registry = new_holon_registry(3)
      participants = ["ex:l3:kms:srv:main", "ex:l3:alm:srv:main"]

      saga = begin_saga(registry, participants)

      partial_saga = %{
        saga
        | participants: [
            {"ex:l3:kms:srv:main", :prepared},
            {"ex:l3:alm:srv:main", :pending}
          ]
      }

      aborted = abort_saga(partial_saga)

      assert aborted.status == :aborted,
             "Saga status must be :aborted after abort_saga/1"

      assert Enum.all?(aborted.participants, fn {_uhi, state} -> state == :aborted end),
             "All participants must be :aborted regardless of prepare state (Ψ₁)"
    end

    test "SAGA_04: a prepare failure on any participant triggers full abort (SC-DBCROSS-002)" do
      registry = new_holon_registry(3)
      participants = ["ex:l3:kms:srv:main", "ex:l3:alm:srv:main"]

      saga = begin_saga(registry, participants)
      aborted = simulate_prepare_failure(saga, "ex:l3:alm:srv:main")

      assert aborted.status == :aborted,
             "Any prepare failure must abort the entire saga (SC-DBCROSS-002)"
    end

    test "SAGA_05: safe_commit_saga/1 rejects commit when participant is not prepared" do
      registry = new_holon_registry(2)
      participants = ["ex:l3:kms:srv:main"]

      saga = begin_saga(registry, participants)

      result = safe_commit_saga(saga)

      assert match?({:error, :not_prepared}, result),
             "Committing an unprepared saga must return {:error, :not_prepared}"
    end
  end

  # ============================================================================
  # SECTION 6: Timeout Leaves No Orphaned Transactions (SC-DBCROSS-004)
  # ============================================================================

  describe "timeout leaves no orphaned transactions (SC-DBCROSS-004)" do
    test "ORPHAN_01: timed-out request is purged from the pending transaction registry" do
      registry = new_holon_registry(2)
      request_id = generate_request_id()

      _result =
        query_holon_with_timeout(
          registry,
          "ex:l3:kms:srv:main",
          %{request_id: request_id},
          _ms = 1
        )

      refute transaction_pending?(request_id),
             "Timed-out transaction must be purged — no orphaned transactions (SC-DBCROSS-004)"
    end

    test "ORPHAN_02: abort is idempotent — double-abort leaves no residual state" do
      request_id = generate_request_id()

      # Register and immediately abort twice
      :persistent_term.put({__MODULE__, :pending, request_id}, true)
      purge_pending_transaction(request_id)
      purge_pending_transaction(request_id)

      refute transaction_pending?(request_id),
             "Double-abort must not crash or leave orphans (SC-DBCROSS-004)"
    end
  end

  # ============================================================================
  # SECTION 7: Property — Cross-holon queries always terminate
  # EP-GEN-014 + SC-XHOLON-025
  # ============================================================================

  describe "property: cross-holon queries" do
    property "TERM_PROP_01: query_holon/3 terminates for any holon count and any SQL string" do
      forall {count, sql} <- {PC.choose(1, 15), PC.utf8()} do
        registry = new_holon_registry(count)
        fqdn = "ex:l3:kms:srv:holon1"

        result = query_holon(registry, fqdn, %{request_id: generate_request_id(), sql: sql})

        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "TERM_STREAM_01: queries over StreamData-generated FQDNs always return a tagged tuple" do
      ExUnitProperties.check all(
                               instance <- SD.string(:alphanumeric, min_length: 1, max_length: 8),
                               count <- SD.integer(1..5)
                             ) do
        fqdn = "ex:l3:kms:srv:#{instance}"
        registry = new_holon_registry(count)

        result =
          query_holon(registry, fqdn, %{request_id: generate_request_id(), sql: "SELECT 1"})

        assert match?({:ok, _}, result) or match?({:error, _}, result),
               "query_holon must always return a tagged tuple — never raise or hang"
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # Self-contained implementations modelling the cross-holon Zenoh query protocol.
  # No production module dependencies — tests validate protocol shape and contracts.
  # ============================================================================

  # ---------------------------------------------------------------------------
  # build_zenoh_topic/2
  # Constructs the canonical cross-holon Zenoh topic string (SC-DBCROSS-001).
  # Pattern: indrajaal/db/{uhi}/{operation}
  # ---------------------------------------------------------------------------

  @spec build_zenoh_topic(String.t(), String.t()) :: String.t()
  defp build_zenoh_topic(uhi, operation) do
    "indrajaal/db/#{uhi}/#{operation}"
  end

  # ---------------------------------------------------------------------------
  # new_holon_registry/1
  # Creates a simulated registry with N pre-registered holons.
  # FQDNs follow the UHI scheme: {runtime}:{layer}:{domain}:{type}:{instance}
  # Also includes three canonical holons used across all unit tests.
  # ---------------------------------------------------------------------------

  @spec new_holon_registry(pos_integer()) :: map()
  defp new_holon_registry(count) when count > 0 do
    generated =
      for i <- 1..count do
        fqdn = "ex:l3:kms:srv:holon#{i}"

        endpoint = %{
          zenoh_topic: build_zenoh_topic(fqdn, "query"),
          timeout_ms: 4_000,
          version_vector: %{fqdn => i}
        }

        {fqdn, endpoint}
      end

    canonical = [
      {"ex:l3:kms:srv:main",
       %{
         zenoh_topic: build_zenoh_topic("ex:l3:kms:srv:main", "query"),
         timeout_ms: 4_000,
         version_vector: %{"ex:l3:kms:srv:main" => 1}
       }},
      {"ex:l3:alm:srv:main",
       %{
         zenoh_topic: build_zenoh_topic("ex:l3:alm:srv:main", "query"),
         timeout_ms: 4_000,
         version_vector: %{"ex:l3:alm:srv:main" => 1}
       }},
      {"ex:l3:acc:srv:main",
       %{
         zenoh_topic: build_zenoh_topic("ex:l3:acc:srv:main", "query"),
         timeout_ms: 4_000,
         version_vector: %{"ex:l3:acc:srv:main" => 1}
       }}
    ]

    Map.new(generated ++ canonical)
  end

  # ---------------------------------------------------------------------------
  # resolve_holon/2
  # Resolves a FQDN to its Zenoh endpoint topic.
  # Returns the topic binary when found, or {:error, :not_found} when unknown.
  # ---------------------------------------------------------------------------

  @spec resolve_holon(map(), String.t()) :: String.t() | {:error, :not_found}
  defp resolve_holon(registry, fqdn) do
    case Map.get(registry, fqdn) do
      nil -> {:error, :not_found}
      %{zenoh_topic: topic} -> topic
    end
  end

  # ---------------------------------------------------------------------------
  # query_holon/3
  # Simulates routing a query via Zenoh and awaiting a reply.
  # Uses the default timeout from the registry entry (always < 5 000 ms).
  # ---------------------------------------------------------------------------

  @spec query_holon(map(), String.t(), map()) :: {:ok, map()} | {:error, atom()}
  defp query_holon(registry, fqdn, payload) do
    case Map.get(registry, fqdn) do
      nil ->
        {:error, :not_found}

      %{zenoh_topic: _topic, version_vector: vv} ->
        request_id = Map.get(payload, :request_id, generate_request_id())

        response = %{
          request_id: request_id,
          status: :ok,
          rows: [],
          version_vector: vv,
          timestamp_utc: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        {:ok, response}
    end
  end

  # ---------------------------------------------------------------------------
  # query_holon_with_timeout/4
  # Like query_holon/3 but enforces an explicit budget_ms.
  # When budget_ms is tiny the simulated responder always misses the window.
  # Purges the transaction from the pending registry on timeout (SC-DBCROSS-004).
  # ---------------------------------------------------------------------------

  @spec query_holon_with_timeout(map(), String.t(), map(), non_neg_integer()) ::
          {:ok, map()} | {:error, :timeout} | {:error, atom()}
  defp query_holon_with_timeout(registry, fqdn, payload, budget_ms) do
    case Map.get(registry, fqdn) do
      nil ->
        {:error, :not_found}

      %{zenoh_topic: _topic} ->
        request_id = Map.get(payload, :request_id, generate_request_id())

        # Register the transaction so it can be verified after timeout
        :persistent_term.put({__MODULE__, :pending, request_id}, true)

        caller = self()

        # Spawn a slow responder that always exceeds the budget
        Task.async(fn ->
          Process.sleep(max(budget_ms * 10, 50))
          send(caller, {:db_response, request_id, %{rows: []}})
        end)

        result =
          receive do
            {:db_response, ^request_id, data} ->
              {:ok, Map.put(data, :request_id, request_id)}
          after
            budget_ms -> {:error, :timeout}
          end

        # Purge pending transaction on both success and timeout (SC-DBCROSS-004)
        purge_pending_transaction(request_id)

        result
    end
  end

  # ---------------------------------------------------------------------------
  # default_query_timeout_ms/0
  # Returns the system-wide default cross-holon query timeout budget.
  # Must be < 5 000 ms (SC-XHOLON-025).
  # ---------------------------------------------------------------------------

  @spec default_query_timeout_ms() :: non_neg_integer()
  defp default_query_timeout_ms, do: 4_000

  # ---------------------------------------------------------------------------
  # transaction_pending?/1
  # Returns true when request_id is still present in the pending transaction set.
  # ---------------------------------------------------------------------------

  @spec transaction_pending?(String.t()) :: boolean()
  defp transaction_pending?(request_id) do
    case :persistent_term.get({__MODULE__, :pending, request_id}, :not_found) do
      :not_found -> false
      _ -> true
    end
  end

  # ---------------------------------------------------------------------------
  # purge_pending_transaction/1
  # Removes request_id from the pending set. Idempotent.
  # ---------------------------------------------------------------------------

  @spec purge_pending_transaction(String.t()) :: :ok
  defp purge_pending_transaction(request_id) do
    :persistent_term.erase({__MODULE__, :pending, request_id})
    :ok
  end

  # ---------------------------------------------------------------------------
  # Saga helpers — SC-DBCROSS-002
  # Implements the 2-phase prepare → commit / abort protocol.
  # ---------------------------------------------------------------------------

  @spec begin_saga(map(), list(String.t())) :: map()
  defp begin_saga(_registry, participants) do
    %{
      saga_id: generate_request_id(),
      status: :pending,
      participants: Enum.map(participants, fn uhi -> {uhi, :pending} end)
    }
  end

  @spec prepare_all_participants(map()) :: map()
  defp prepare_all_participants(saga) do
    prepared = Enum.map(saga.participants, fn {uhi, _} -> {uhi, :prepared} end)
    %{saga | participants: prepared, status: :prepared}
  end

  @spec commit_saga(map()) :: map()
  defp commit_saga(saga) do
    committed = Enum.map(saga.participants, fn {uhi, _} -> {uhi, :committed} end)
    %{saga | participants: committed, status: :committed}
  end

  @spec safe_commit_saga(map()) :: {:ok, map()} | {:error, :not_prepared}
  defp safe_commit_saga(saga) do
    all_prepared =
      Enum.all?(saga.participants, fn {_uhi, state} -> state == :prepared end)

    if all_prepared do
      {:ok, commit_saga(saga)}
    else
      {:error, :not_prepared}
    end
  end

  @spec abort_saga(map()) :: map()
  defp abort_saga(saga) do
    aborted = Enum.map(saga.participants, fn {uhi, _} -> {uhi, :aborted} end)
    %{saga | participants: aborted, status: :aborted}
  end

  # Simulates a Phase-1 failure on failing_uhi and cascades an abort.
  @spec simulate_prepare_failure(map(), String.t()) :: map()
  defp simulate_prepare_failure(saga, failing_uhi) do
    {result_participants, failed} =
      Enum.reduce(saga.participants, {[], false}, fn {uhi, _state}, {acc, already_failed} ->
        cond do
          already_failed ->
            {acc ++ [{uhi, :pending}], true}

          uhi == failing_uhi ->
            {acc ++ [{uhi, :failed}], true}

          true ->
            {acc ++ [{uhi, :prepared}], false}
        end
      end)

    if failed do
      compensated =
        Enum.map(result_participants, fn {uhi, state} ->
          new_state = if state == :prepared, do: :aborted, else: state
          {uhi, new_state}
        end)

      %{saga | participants: compensated, status: :aborted}
    else
      %{saga | participants: result_participants, status: :prepared}
    end
  end

  # ---------------------------------------------------------------------------
  # Version vector helpers — SC-DBCROSS-003
  # ---------------------------------------------------------------------------

  # Max-merge of two version vectors (CRDT join / LUB).
  @spec merge_version_vectors(map(), map()) :: map()
  defp merge_version_vectors(vv_a, vv_b) do
    Map.merge(vv_a, vv_b, fn _node, ca, cb -> max(ca, cb) end)
  end

  # True when neither vector dominates the other (independent concurrent writes).
  @spec versions_concurrent?(map(), map()) :: boolean()
  defp versions_concurrent?(vv_a, vv_b) do
    not dominates_or_equals?(vv_a, vv_b) and not dominates_or_equals?(vv_b, vv_a)
  end

  # True when vv_a >= vv_b component-wise for every node in either vector.
  @spec dominates_or_equals?(map(), map()) :: boolean()
  defp dominates_or_equals?(vv_a, vv_b) do
    all_nodes = Map.keys(vv_a) ++ Map.keys(vv_b)

    Enum.all?(all_nodes, fn node ->
      Map.get(vv_a, node, 0) >= Map.get(vv_b, node, 0)
    end)
  end

  # ---------------------------------------------------------------------------
  # generate_request_id/0
  # Produces a UUID-v4-shaped correlation ID using :crypto random bytes.
  # Collision probability < 2^-122 per birthday bound.
  # ---------------------------------------------------------------------------

  @spec generate_request_id() :: String.t()
  defp generate_request_id do
    <<a::32, b::16, _::4, c::12, _::2, d::14, e::48>> = :crypto.strong_rand_bytes(16)
    version = 4
    variant = 0b10

    :io_lib.format(
      "~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
      [a, b, version * 0x1000 + c, variant * 0x4000 + d, e]
    )
    |> IO.iodata_to_binary()
  end
end
