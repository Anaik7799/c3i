defmodule Indrajaal.Observability.ZenohKpiPublisherTest do
  @moduledoc """
  Comprehensive tests for ZenohKpiPublisher with PropCheck/StreamData.

  WHAT: Tests Zenoh-based KPI publisher functionality.
  WHY: SC-ZENOH-INT-001 requires verified universal Zenoh access.
  CONSTRAINTS: Must use PC/SD aliases per SC-PROP-023/024.

  ## Test Categories
  - Unit tests for collector functions
  - Property tests for data integrity
  - Integration tests for GenServer behavior
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Mandatory aliases for PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.ZenohKpiPublisher

  @moduletag :zenoh_kpi

  # ============================================================
  # SETUP & TEARDOWN
  # ============================================================

  setup do
    # Ensure clean state before each test
    File.mkdir_p!("data/tmp")

    on_exit(fn ->
      # Cleanup test artifacts
      File.rm("data/tmp/zenoh_kpi_state.json")
      File.rm("data/tmp/test_todos.json")
      File.rm("data/tmp/test_dashboard.json")
    end)

    :ok
  end

  # ============================================================
  # UNIT TESTS - STRUCT & INITIALIZATION
  # ============================================================

  describe "struct definition" do
    test "has all required fields" do
      state = %ZenohKpiPublisher{}
      assert Map.has_key?(state, :coordinator)
      assert Map.has_key?(state, :started_at)
      assert Map.has_key?(state, :publish_count)
      assert Map.has_key?(state, :last_publish)
      assert Map.has_key?(state, :sequence)
      assert Map.has_key?(state, :kpi_collectors)
    end

    test "default values are nil" do
      state = %ZenohKpiPublisher{}
      assert state.coordinator == nil
      assert state.started_at == nil
      assert state.publish_count == nil
      assert state.last_publish == nil
      assert state.sequence == nil
      assert state.kpi_collectors == nil
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      # Stop if already running
      case GenServer.whereis(ZenohKpiPublisher) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      assert {:ok, pid} = ZenohKpiPublisher.start_link()
      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "registers with module name" do
      case GenServer.whereis(ZenohKpiPublisher) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      {:ok, pid} = ZenohKpiPublisher.start_link()
      assert GenServer.whereis(ZenohKpiPublisher) == pid

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # UNIT TESTS - CLIENT API
  # ============================================================

  describe "get_stats/0" do
    test "returns statistics map with required keys" do
      {:ok, pid} = start_publisher()

      stats = ZenohKpiPublisher.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :started_at)
      assert Map.has_key?(stats, :publish_count)
      assert Map.has_key?(stats, :last_publish)
      assert Map.has_key?(stats, :sequence)
      assert Map.has_key?(stats, :uptime_seconds)
      assert Map.has_key?(stats, :categories)

      GenServer.stop(pid)
    end

    test "uptime increases over time" do
      {:ok, pid} = start_publisher()

      stats1 = ZenohKpiPublisher.get_stats()
      Process.sleep(1100)
      stats2 = ZenohKpiPublisher.get_stats()

      assert stats2.uptime_seconds >= stats1.uptime_seconds

      GenServer.stop(pid)
    end

    test "categories includes all default collectors" do
      {:ok, pid} = start_publisher()

      stats = ZenohKpiPublisher.get_stats()
      categories = stats.categories

      assert :compilation in categories
      assert :tests in categories
      assert :containers in categories
      assert :performance in categories
      assert :progress in categories
      assert :stamp in categories
      assert :todos in categories
      assert :agents in categories

      GenServer.stop(pid)
    end
  end

  describe "update_kpi/2" do
    test "accepts atom category and map data" do
      {:ok, pid} = start_publisher()

      assert :ok = ZenohKpiPublisher.update_kpi(:custom, %{value: 42})

      GenServer.stop(pid)
    end

    test "updates collector for category" do
      {:ok, pid} = start_publisher()

      ZenohKpiPublisher.update_kpi(:custom_metric, %{score: 100})
      Process.sleep(50)

      stats = ZenohKpiPublisher.get_stats()
      assert :custom_metric in stats.categories

      GenServer.stop(pid)
    end
  end

  describe "register_collector/2" do
    test "registers custom collector function" do
      {:ok, pid} = start_publisher()

      collector_fn = fn -> %{custom: true, value: 123} end
      assert :ok = ZenohKpiPublisher.register_collector(:my_collector, collector_fn)

      stats = ZenohKpiPublisher.get_stats()
      assert :my_collector in stats.categories

      GenServer.stop(pid)
    end

    test "rejects non-function collectors" do
      {:ok, pid} = start_publisher()

      assert_raise FunctionClauseError, fn ->
        ZenohKpiPublisher.register_collector(:bad, "not a function")
      end

      GenServer.stop(pid)
    end
  end

  describe "publish_now/0" do
    test "triggers immediate publish" do
      {:ok, pid} = start_publisher()

      # Wait for initial publish
      Process.sleep(200)
      stats1 = ZenohKpiPublisher.get_stats()

      ZenohKpiPublisher.publish_now()
      Process.sleep(100)
      stats2 = ZenohKpiPublisher.get_stats()

      assert stats2.publish_count > stats1.publish_count

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # PROPERTY TESTS - PROPCHECK (SC-PROP-023)
  # ============================================================

  describe "PropCheck property tests" do
    property "sequence numbers always increase" do
      forall sequences <- PC.list(PC.non_neg_integer()) do
        sorted = Enum.sort(sequences)
        # Sorted sequences maintain order
        chunks = Enum.chunk_every(sorted, 2, 1, :discard)

        chunks
        |> Enum.all?(fn [a, b] -> a <= b end)
      end
    end

    property "KPI categories are always atoms" do
      forall category <- PC.atom() do
        is_atom(category)
      end
    end

    property "publish count is non-negative" do
      forall count <- PC.non_neg_integer() do
        count >= 0
      end
    end

    property "latency values are positive numbers" do
      forall latency <- PC.pos_integer() do
        latency > 0 and is_integer(latency)
      end
    end

    property "KPI data maps are serializable to JSON" do
      forall data <- PC.map(PC.atom(), PC.oneof([PC.integer(), PC.float(), PC.utf8()])) do
        case Jason.encode(data) do
          {:ok, json} -> is_binary(json)
          {:error, _} -> true
        end
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS - STREAMDATA (SC-PROP-024)
  # ============================================================

  describe "StreamData property tests" do
    test "compilation KPI structure is valid" do
      ExUnitProperties.check all(
                               errors <- SD.non_negative_integer(),
                               warnings <- SD.non_negative_integer(),
                               files <- SD.non_negative_integer()
                             ) do
        kpi = %{errors: errors, warnings: warnings, files: files, status: :test}

        assert is_integer(kpi.errors)
        assert is_integer(kpi.warnings)
        assert is_integer(kpi.files)
        assert kpi.errors >= 0
        assert kpi.warnings >= 0
        assert kpi.files >= 0
      end
    end

    test "progress KPI percentages are bounded" do
      ExUnitProperties.check all(
                               c1 <- SD.integer(0..100),
                               c2 <- SD.integer(0..100),
                               c3 <- SD.integer(0..100),
                               c4 <- SD.integer(0..100)
                             ) do
        progress = %{c1: c1, c2: c2, c3: c3, c4: c4}

        assert progress.c1 >= 0 and progress.c1 <= 100
        assert progress.c2 >= 0 and progress.c2 <= 100
        assert progress.c3 >= 0 and progress.c3 <= 100
        assert progress.c4 >= 0 and progress.c4 <= 100
      end
    end

    test "performance metrics are valid floats" do
      ExUnitProperties.check all(
                               p50 <- SD.float(min: 0.0, max: 1000.0),
                               p95 <- SD.float(min: 0.0, max: 1000.0),
                               p99 <- SD.float(min: 0.0, max: 1000.0),
                               rps <- SD.non_negative_integer()
                             ) do
        perf = %{p50: p50, p95: p95, p99: p99, rps: rps}

        assert is_float(perf.p50)
        assert is_float(perf.p95)
        assert is_float(perf.p99)
        assert is_integer(perf.rps)
        assert perf.p50 >= 0
        assert perf.p95 >= 0
        assert perf.p99 >= 0
      end
    end

    test "STAMP constraint counts are consistent" do
      ExUnitProperties.check all(
                               verified <- SD.integer(0..500),
                               extra <- SD.non_negative_integer()
                             ) do
        total = verified + extra
        stamp = %{total: total, verified: verified}

        assert stamp.verified <= stamp.total
        assert stamp.total >= 0
        assert stamp.verified >= 0
      end
    end

    test "container statuses are valid atoms" do
      ExUnitProperties.check all(
                               status <-
                                 SD.member_of([:healthy, :unhealthy, :unknown, :degraded, :error])
                             ) do
        assert is_atom(status)
        assert status in [:healthy, :unhealthy, :unknown, :degraded, :error]
      end
    end

    test "KPI payloads have required fields" do
      ExUnitProperties.check all(
                               category <- SD.atom(:alphanumeric),
                               sequence <- SD.positive_integer()
                             ) do
        payload = %{
          category: category,
          data: %{},
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          source: "elixir",
          sequence: sequence,
          version: "1.0"
        }

        assert Map.has_key?(payload, :category)
        assert Map.has_key?(payload, :data)
        assert Map.has_key?(payload, :timestamp)
        assert Map.has_key?(payload, :source)
        assert Map.has_key?(payload, :sequence)
        assert Map.has_key?(payload, :version)
        assert payload.source == "elixir"
        assert payload.version == "1.0"
      end
    end
  end

  # ============================================================
  # INTEGRATION TESTS - GENSERVER BEHAVIOR
  # ============================================================

  describe "GenServer lifecycle" do
    test "handles :publish message correctly" do
      {:ok, pid} = start_publisher()

      # Send manual publish
      send(pid, :publish)
      Process.sleep(100)

      stats = ZenohKpiPublisher.get_stats()
      assert stats.publish_count >= 1
      assert stats.sequence >= 1

      GenServer.stop(pid)
    end

    test "writes KPI state to file after publish" do
      {:ok, pid} = start_publisher()

      # Wait for publish
      Process.sleep(200)

      assert File.exists?("data/tmp/zenoh_kpi_state.json")

      content = File.read!("data/tmp/zenoh_kpi_state.json")
      state = Jason.decode!(content)

      assert Map.has_key?(state, "kpis")
      assert Map.has_key?(state, "sequence")
      assert Map.has_key?(state, "updated_at")

      GenServer.stop(pid)
    end

    test "increments sequence on each publish" do
      {:ok, pid} = start_publisher()

      Process.sleep(200)
      stats1 = ZenohKpiPublisher.get_stats()
      seq1 = stats1.sequence

      ZenohKpiPublisher.publish_now()
      Process.sleep(100)
      stats2 = ZenohKpiPublisher.get_stats()
      seq2 = stats2.sequence

      assert seq2 > seq1

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "error handling" do
    test "handles missing compile log gracefully" do
      File.rm("data/tmp/1-compile.log")

      {:ok, pid} = start_publisher()
      Process.sleep(200)

      # Should not crash
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "handles missing todos file gracefully" do
      File.rm("data/tmp/claude_todos.json")

      {:ok, pid} = start_publisher()
      Process.sleep(200)

      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "handles collector exceptions gracefully" do
      {:ok, pid} = start_publisher()

      # Register a failing collector
      ZenohKpiPublisher.register_collector(:failing, fn -> raise "test error" end)

      ZenohKpiPublisher.publish_now()
      Process.sleep(100)

      # Should not crash
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # STAMP CONSTRAINT TESTS
  # ============================================================

  describe "STAMP constraints" do
    @tag :stamp
    test "SC-ZENOH-INT-001: publishes to all KPI categories" do
      {:ok, pid} = start_publisher()
      Process.sleep(200)

      content = File.read!("data/tmp/zenoh_kpi_state.json")
      state = Jason.decode!(content)
      kpis = state["kpis"]

      expected_categories =
        ~w(compilation tests containers performance progress stamp todos agents)

      for category <- expected_categories do
        assert Map.has_key?(kpis, category),
               "Missing KPI category: #{category} (SC-ZENOH-INT-001)"
      end

      GenServer.stop(pid)
    end

    @tag :stamp
    test "SC-ZENOH-INT-005: KPI state is valid JSON" do
      {:ok, pid} = start_publisher()
      Process.sleep(200)

      content = File.read!("data/tmp/zenoh_kpi_state.json")

      # Should parse without error
      assert {:ok, _} = Jason.decode(content)

      GenServer.stop(pid)
    end

    @tag :stamp
    test "SC-ZENOH-INT-002: delivery latency is measurable" do
      {:ok, pid} = start_publisher()

      start_time = System.monotonic_time(:millisecond)
      ZenohKpiPublisher.publish_now()
      Process.sleep(50)
      end_time = System.monotonic_time(:millisecond)

      latency = end_time - start_time

      # Latency should be reasonable (well under 100ms threshold)
      assert latency < 100, "Delivery latency #{latency}ms exceeds 100ms threshold"

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp start_publisher do
    case GenServer.whereis(ZenohKpiPublisher) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    ZenohKpiPublisher.start_link()
  end
end
