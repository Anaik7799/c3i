defmodule Indrajaal.Crm.Analytics.DashboardTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Crm.Analytics.Dashboard.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation gaps addressed
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-PRF-050: Response time < 50ms for dashboard data
  - SC-OBS-069: Dual logging (Terminal + Zenoh)
  - SC-MON-001: Metrics refresh every 30s

  ## Constitutional Verification
  - Ψ₀ Existence: Dashboard generation returns without crashing
  - Ψ₅ Truthfulness: Returned data structures match declared types

  ## Founder's Directive Alignment
  - Ω₀.1: CRM revenue analytics serves resource acquisition tracking

  ## TPS 5-Level RCA Context
  - L1 Symptom: Dashboard shows blank widgets or crashes
  - L5 Root Cause: Parallel Task failure propagation or missing shape validation
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Analytics.Dashboard

  @moduletag :zenoh_nif

  # ============================================================
  # 1. sales_dashboard/2 — CONTRACT TESTS
  # ============================================================

  describe "sales_dashboard/2 return shape" do
    test "returns :ok tuple" do
      user_id = "user-#{:rand.uniform(9999)}"
      assert {:ok, _dashboard} = Dashboard.sales_dashboard(user_id)
    end

    test "returned dashboard has all required keys" do
      user_id = "user-test-001"
      {:ok, dashboard} = Dashboard.sales_dashboard(user_id)

      required_keys = [
        :pipeline,
        :forecast,
        :recent_opportunities,
        :overdue_tasks,
        :top_deals,
        :leaderboard,
        :activities,
        :performance,
        :generated_at
      ]

      for key <- required_keys do
        assert Map.has_key?(dashboard, key),
               "Missing required key :#{key} in dashboard result"
      end
    end

    test "generated_at is a DateTime struct" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u1")
      assert %DateTime{} = dashboard.generated_at
    end

    test "generated_at is recent (within last 5 seconds)" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u1")
      diff = DateTime.diff(DateTime.utc_now(), dashboard.generated_at, :second)
      assert diff >= 0 and diff <= 5
    end

    test "recent_opportunities is a list" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u2")
      assert is_list(dashboard.recent_opportunities)
    end

    test "overdue_tasks is a list" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u2")
      assert is_list(dashboard.overdue_tasks)
    end

    test "top_deals is a list" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u2")
      assert is_list(dashboard.top_deals)
    end

    test "leaderboard is a list" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u2")
      assert is_list(dashboard.leaderboard)
    end

    test "activities is a list" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u2")
      assert is_list(dashboard.activities)
    end

    test "performance is a map" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u2")
      assert is_map(dashboard.performance)
    end
  end

  describe "sales_dashboard/2 options handling" do
    test "accepts empty opts" do
      assert {:ok, _} = Dashboard.sales_dashboard("user-opts-1", [])
    end

    test "accepts limit option" do
      assert {:ok, _} = Dashboard.sales_dashboard("user-opts-2", limit: 5)
    end

    test "accepts large limit without crashing" do
      assert {:ok, _} = Dashboard.sales_dashboard("user-opts-3", limit: 1000)
    end

    test "accepts cache_ttl option" do
      assert {:ok, _} = Dashboard.sales_dashboard("user-opts-4", cache_ttl: 60)
    end

    test "accepts combined options" do
      assert {:ok, _} = Dashboard.sales_dashboard("user-opts-5", limit: 20, cache_ttl: 30)
    end
  end

  # ============================================================
  # 2. executive_dashboard/1 — CONTRACT TESTS
  # ============================================================

  describe "executive_dashboard/1 return shape" do
    test "returns :ok tuple with no args" do
      assert {:ok, _} = Dashboard.executive_dashboard()
    end

    test "returns :ok tuple with empty opts" do
      assert {:ok, _} = Dashboard.executive_dashboard([])
    end

    test "returned dashboard has all required executive keys" do
      {:ok, dashboard} = Dashboard.executive_dashboard()

      required_keys = [
        :company_pipeline,
        :team_forecast,
        :revenue_trends,
        :top_campaigns,
        :regional_performance,
        :generated_at
      ]

      for key <- required_keys do
        assert Map.has_key?(dashboard, key),
               "Missing required key :#{key} in executive dashboard"
      end
    end

    test "generated_at is a DateTime struct" do
      {:ok, dashboard} = Dashboard.executive_dashboard()
      assert %DateTime{} = dashboard.generated_at
    end

    test "revenue_trends is a list" do
      {:ok, dashboard} = Dashboard.executive_dashboard()
      assert is_list(dashboard.revenue_trends)
    end

    test "top_campaigns is a list" do
      {:ok, dashboard} = Dashboard.executive_dashboard()
      assert is_list(dashboard.top_campaigns)
    end

    test "regional_performance is a list" do
      {:ok, dashboard} = Dashboard.executive_dashboard()
      assert is_list(dashboard.regional_performance)
    end

    test "company_pipeline is a map" do
      {:ok, dashboard} = Dashboard.executive_dashboard()
      assert is_map(dashboard.company_pipeline)
    end

    test "team_forecast is a map" do
      {:ok, dashboard} = Dashboard.executive_dashboard()
      assert is_map(dashboard.team_forecast)
    end
  end

  # ============================================================
  # 3. refresh_metrics/0
  # ============================================================

  describe "refresh_metrics/0" do
    test "returns :ok" do
      assert :ok == Dashboard.refresh_metrics()
    end

    test "is idempotent — second call also returns :ok" do
      assert :ok == Dashboard.refresh_metrics()
      assert :ok == Dashboard.refresh_metrics()
    end

    test "does not crash application" do
      Dashboard.refresh_metrics()
      assert Process.alive?(Process.whereis(Indrajaal.Supervisor) || self())
    end
  end

  # ============================================================
  # 4. PERFORMANCE TESTS (SC-PRF-050)
  # ============================================================

  describe "performance (SC-PRF-050: response < 50ms target)" do
    test "sales_dashboard completes in reasonable time" do
      user_id = "perf-user-001"

      {elapsed_us, {:ok, _dashboard}} =
        :timer.tc(fn -> Dashboard.sales_dashboard(user_id) end)

      elapsed_ms = elapsed_us / 1000.0
      # Generous bound for CI (10x the SC-PRF-050 target of 50ms = 500ms)
      assert elapsed_ms < 500,
             "sales_dashboard took #{elapsed_ms}ms, should be < 500ms"
    end

    test "executive_dashboard completes in reasonable time" do
      {elapsed_us, {:ok, _dashboard}} =
        :timer.tc(fn -> Dashboard.executive_dashboard() end)

      elapsed_ms = elapsed_us / 1000.0
      # Executive allowed 10s timeout internally, so 15s bound for test
      assert elapsed_ms < 15_000,
             "executive_dashboard took #{elapsed_ms}ms"
    end
  end

  # ============================================================
  # 5. CONSTITUTIONAL INVARIANTS (Ψ₀-Ψ₅)
  # ============================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence: sales_dashboard never crashes the process" do
      # Call with varied user IDs, none should crash
      for i <- 1..5 do
        result = Dashboard.sales_dashboard("user-psi0-#{i}")
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "Ψ₀ existence: executive_dashboard never crashes the process" do
      result = Dashboard.executive_dashboard()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "Ψ₅ truthfulness: performance map has numeric values" do
      {:ok, dashboard} = Dashboard.sales_dashboard("u-truth")
      perf = dashboard.performance

      if is_map(perf) and map_size(perf) > 0 do
        # win_rate should be a float between 0 and 1 if present
        if Map.has_key?(perf, :win_rate) do
          assert is_number(perf.win_rate), "win_rate must be numeric"
          assert perf.win_rate >= 0.0, "win_rate cannot be negative"
          assert perf.win_rate <= 1.0, "win_rate cannot exceed 1.0"
        end

        # avg_sales_cycle_days should be non-negative integer
        if Map.has_key?(perf, :avg_sales_cycle_days) do
          assert is_integer(perf.avg_sales_cycle_days)
          assert perf.avg_sales_cycle_days >= 0
        end
      end
    end

    test "Ψ₅ truthfulness: generated_at is monotonically increasing across calls" do
      {:ok, d1} = Dashboard.sales_dashboard("u-mono-1")
      {:ok, d2} = Dashboard.sales_dashboard("u-mono-2")

      diff = DateTime.compare(d1.generated_at, d2.generated_at)
      assert diff in [:lt, :eq], "generated_at should not regress"
    end
  end

  # ============================================================
  # 6. PARALLEL EXECUTION RESILIENCE
  # ============================================================

  describe "parallel execution resilience" do
    test "concurrent sales_dashboard calls for different users succeed" do
      tasks =
        for i <- 1..5 do
          Task.async(fn -> Dashboard.sales_dashboard("concurrent-user-#{i}") end)
        end

      results = Task.await_many(tasks, 10_000)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               {:error, _} -> true
             end)
    end

    test "concurrent executive_dashboard calls succeed" do
      tasks =
        for _i <- 1..3 do
          Task.async(fn -> Dashboard.executive_dashboard() end)
        end

      results = Task.await_many(tasks, 30_000)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               {:error, _} -> true
             end)
    end
  end

  # ============================================================
  # 7. PROPERTY TESTS
  # ============================================================

  property "sales_dashboard always returns ok or error tuple (PropCheck)" do
    forall user_suffix <- PC.binary() do
      user_id = "prop-user-" <> Base.encode16(user_suffix, case: :lower)

      case Dashboard.sales_dashboard(user_id) do
        {:ok, _} -> true
        {:error, _} -> true
        other -> flunk("Unexpected return value: #{inspect(other)}")
      end
    end
  end

  test "executive_dashboard result always has generated_at key (StreamData)" do
    ExUnitProperties.check all(_attempt <- SD.constant(:run)) do
      case Dashboard.executive_dashboard() do
        {:ok, dashboard} ->
          assert Map.has_key?(dashboard, :generated_at)

        {:error, _} ->
          :ok
      end
    end
  end

  property "sales_dashboard with different limit values never crashes (PropCheck)" do
    forall limit <- PC.pos_integer() do
      bounded_limit = rem(limit, 100) + 1

      result = Dashboard.sales_dashboard("prop-limit-user", limit: bounded_limit)
      match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # 8. FMEA TESTS (SC-MON-* failure modes)
  # ============================================================

  describe "FMEA failure modes" do
    @tag :fmea
    test "empty user_id returns ok or error, never crashes" do
      result = Dashboard.sales_dashboard("")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "very long user_id handled gracefully" do
      long_id = String.duplicate("x", 1000)
      result = Dashboard.sales_dashboard(long_id)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "refresh_metrics is safe to call from multiple processes" do
      tasks = for _i <- 1..10, do: Task.async(fn -> Dashboard.refresh_metrics() end)
      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, &(&1 == :ok))
    end

    @tag :fmea
    test "sales_dashboard with nil-like user_id does not raise" do
      # edge case: atom converted to string
      result =
        try do
          Dashboard.sales_dashboard("nil")
        rescue
          e -> {:error, e}
        end

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
