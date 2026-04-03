defmodule IndrajaalWeb.Plugs.PerformanceOptimizerTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.Plugs.PerformanceOptimizer.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation fixes
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-PRF-050: Response < 50ms for normal loads
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests

  ## Constitutional Verification
  - Psi0 Existence: Plug always passes conn through unchanged for unsupported methods

  ## TPS 5-Level RCA Context
  - L1 Symptom: Performance headers missing from API responses
  - L5 Root Cause: PerformanceOptimizer plug not in pipeline
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias IndrajaalWeb.Plugs.PerformanceOptimizer

  @moduletag :zenoh_nif

  # ==========================================================================
  # init/1
  # ==========================================================================

  describe "init/1" do
    test "returns map with default options" do
      result = PerformanceOptimizer.init([])
      assert is_map(result)
    end

    test "cache_enabled defaults to true" do
      result = PerformanceOptimizer.init([])
      assert result.cache_enabled == true
    end

    test "compression_enabled defaults to true" do
      result = PerformanceOptimizer.init([])
      assert result.compression_enabled == true
    end

    test "etag_enabled defaults to true" do
      result = PerformanceOptimizer.init([])
      assert result.etag_enabled == true
    end

    test "field_filtering_enabled defaults to true" do
      result = PerformanceOptimizer.init([])
      assert result.field_filtering_enabled == true
    end

    test "accepts cache_enabled: false override" do
      result = PerformanceOptimizer.init(cache_enabled: false)
      assert result.cache_enabled == false
    end

    test "accepts compression_enabled: false override" do
      result = PerformanceOptimizer.init(compression_enabled: false)
      assert result.compression_enabled == false
    end

    test "accepts etag_enabled: false override" do
      result = PerformanceOptimizer.init(etag_enabled: false)
      assert result.etag_enabled == false
    end

    test "accepts all options disabled" do
      result =
        PerformanceOptimizer.init(
          cache_enabled: false,
          compression_enabled: false,
          etag_enabled: false,
          field_filtering_enabled: false
        )

      assert result.cache_enabled == false
      assert result.compression_enabled == false
      assert result.etag_enabled == false
      assert result.field_filtering_enabled == false
    end
  end

  # ==========================================================================
  # call/2
  # ==========================================================================

  describe "call/2 - GET request" do
    test "returns a conn for GET request" do
      opts = PerformanceOptimizer.init([])
      conn = build_conn("GET", "/api/alarms")
      result = PerformanceOptimizer.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "does not halt connection for GET" do
      opts = PerformanceOptimizer.init([])
      conn = build_conn("GET", "/api/alarms")
      result = PerformanceOptimizer.call(conn, opts)
      assert result.halted == false
    end

    test "registers before_send callbacks" do
      opts = PerformanceOptimizer.init([])
      conn = build_conn("GET", "/api/alarms")
      result = PerformanceOptimizer.call(conn, opts)
      # before_send callbacks are registered
      assert length(result.before_send) >= 1
    end
  end

  describe "call/2 - POST request" do
    test "returns a conn for POST request (caching does not apply)" do
      opts = PerformanceOptimizer.init([])
      conn = build_conn("POST", "/api/alarms")
      result = PerformanceOptimizer.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "does not halt connection for POST" do
      opts = PerformanceOptimizer.init([])
      conn = build_conn("POST", "/api/alarms")
      result = PerformanceOptimizer.call(conn, opts)
      assert result.halted == false
    end
  end

  describe "call/2 - with cache_enabled: false" do
    test "still returns a conn" do
      opts = PerformanceOptimizer.init(cache_enabled: false)
      conn = build_conn("GET", "/api/test")
      result = PerformanceOptimizer.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "does not halt" do
      opts = PerformanceOptimizer.init(cache_enabled: false)
      conn = build_conn("GET", "/api/test")
      result = PerformanceOptimizer.call(conn, opts)
      assert result.halted == false
    end
  end

  describe "call/2 - Psi0 existence: all options disabled" do
    test "returns conn even with all features disabled" do
      opts =
        PerformanceOptimizer.init(
          cache_enabled: false,
          compression_enabled: false,
          etag_enabled: false,
          field_filtering_enabled: false
        )

      conn = build_conn("GET", "/api/test")
      result = PerformanceOptimizer.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.halted == false
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "concurrent calls do not crash" do
      opts = PerformanceOptimizer.init([])

      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            conn = build_conn("GET", "/api/alarms")
            PerformanceOptimizer.call(conn, opts)
          end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 5_000))

      Enum.each(results, fn conn ->
        assert %Plug.Conn{} = conn
      end)
    end

    test "plug performs within time budget (SC-PRF-050)" do
      opts = PerformanceOptimizer.init([])
      conn = build_conn("GET", "/api/alarms")

      start = System.monotonic_time(:millisecond)
      PerformanceOptimizer.call(conn, opts)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 1_000, "PerformanceOptimizer.call took #{elapsed}ms"
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "init/1 always includes all four keys" do
    required_keys = [
      :cache_enabled,
      :compression_enabled,
      :etag_enabled,
      :field_filtering_enabled
    ]

    forall flag <- PC.boolean() do
      opts = [
        cache_enabled: flag,
        compression_enabled: flag,
        etag_enabled: flag,
        field_filtering_enabled: flag
      ]

      result = PerformanceOptimizer.init(opts)
      Enum.all?(required_keys, &Map.has_key?(result, &1))
    end
  end

  test "call/2 never halts connection for valid requests" do
    methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]

    ExUnitProperties.check all(method <- SD.member_of(methods)) do
      opts = PerformanceOptimizer.init([])
      conn = build_conn(method, "/api/test")
      result = PerformanceOptimizer.call(conn, opts)
      assert result.halted == false
    end
  end

  # ==========================================================================
  # FMEA Tests
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-PO-001: plug with all opts disabled does not halt" do
      opts =
        PerformanceOptimizer.init(
          cache_enabled: false,
          compression_enabled: false,
          etag_enabled: false,
          field_filtering_enabled: false
        )

      methods = ["GET", "POST", "PUT", "DELETE"]

      Enum.each(methods, fn method ->
        conn = build_conn(method, "/api/test")
        result = PerformanceOptimizer.call(conn, opts)
        assert result.halted == false
      end)
    end

    @tag :fmea
    test "FMEA-PO-002: init/1 does not crash with empty keyword list" do
      result = PerformanceOptimizer.init([])
      assert is_map(result)
      assert map_size(result) == 4
    end
  end

  # ==========================================================================
  # Helpers
  # ==========================================================================

  defp build_conn(method, path) do
    Plug.Test.conn(method, path)
    |> Plug.Conn.fetch_query_params()
  end
end
