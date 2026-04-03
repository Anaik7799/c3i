defmodule Indrajaal.Crm.Analytics.ForecastingAgingBucketTest do
  @moduledoc """
  CRM forecasting aging bucket logic test suite.

  ## WHAT
  Tests the pipeline aging bucket classification logic that categorizes
  open opportunities by how long they have been in the pipeline.

  ## CONSTRAINTS
  - SC-PRF-050: Response < 50ms
  - SC-OBS-069: Dual logging (Terminal + Zenoh)
  - AOR-HOLON-007: DuckDB for historical forecast analysis

  ## Aging Buckets
  - **Fresh** (0-30 days): Active deals
  - **Maturing** (31-60 days): Monitor closely
  - **Aging** (61-90 days): At-risk deals
  - **Stale** (91+ days): Immediate action required
  """

  use ExUnit.Case, async: true
  use ExUnitProperties
  alias StreamData, as: SD

  alias Indrajaal.Crm.Analytics.Forecasting

  # ============================================================================
  # Aging Bucket Classification Tests
  # ============================================================================

  describe "aging bucket classification" do
    test "opportunity opened today falls in fresh bucket (0-30 days)" do
      opp = build_opportunity(days_open: 0, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :fresh
    end

    test "opportunity opened 30 days ago is still fresh" do
      opp = build_opportunity(days_open: 30, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :fresh
    end

    test "opportunity opened 31 days ago is maturing" do
      opp = build_opportunity(days_open: 31, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :maturing
    end

    test "opportunity opened 60 days ago is still maturing" do
      opp = build_opportunity(days_open: 60, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :maturing
    end

    test "opportunity opened 61 days ago is aging" do
      opp = build_opportunity(days_open: 61, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :aging
    end

    test "opportunity opened 90 days ago is still aging" do
      opp = build_opportunity(days_open: 90, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :aging
    end

    test "opportunity opened 91 days ago is stale" do
      opp = build_opportunity(days_open: 91, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :stale
    end

    test "opportunity opened 365 days ago is stale" do
      opp = build_opportunity(days_open: 365, amount: Decimal.new("50000"))

      result = Forecasting.classify_aging_bucket(opp)

      assert result == :stale
    end
  end

  # ============================================================================
  # Pipeline Aging Report Tests
  # ============================================================================

  describe "pipeline aging report" do
    test "empty pipeline returns empty buckets with zero totals" do
      {:ok, report} = Forecasting.pipeline_aging_report([])

      assert report.fresh.count == 0
      assert report.maturing.count == 0
      assert report.aging.count == 0
      assert report.stale.count == 0
      assert Decimal.eq?(report.fresh.total, Decimal.new("0"))
      assert Decimal.eq?(report.stale.total, Decimal.new("0"))
    end

    test "single fresh opportunity appears in fresh bucket" do
      opps = [build_opportunity(days_open: 10, amount: Decimal.new("100000"))]

      {:ok, report} = Forecasting.pipeline_aging_report(opps)

      assert report.fresh.count == 1
      assert Decimal.eq?(report.fresh.total, Decimal.new("100000"))
      assert report.maturing.count == 0
      assert report.aging.count == 0
      assert report.stale.count == 0
    end

    test "opportunities are distributed across correct buckets" do
      opps = [
        build_opportunity(days_open: 15, amount: Decimal.new("10000")),
        build_opportunity(days_open: 45, amount: Decimal.new("20000")),
        build_opportunity(days_open: 75, amount: Decimal.new("30000")),
        build_opportunity(days_open: 120, amount: Decimal.new("40000"))
      ]

      {:ok, report} = Forecasting.pipeline_aging_report(opps)

      assert report.fresh.count == 1
      assert Decimal.eq?(report.fresh.total, Decimal.new("10000"))

      assert report.maturing.count == 1
      assert Decimal.eq?(report.maturing.total, Decimal.new("20000"))

      assert report.aging.count == 1
      assert Decimal.eq?(report.aging.total, Decimal.new("30000"))

      assert report.stale.count == 1
      assert Decimal.eq?(report.stale.total, Decimal.new("40000"))
    end

    test "multiple opportunities in same bucket aggregate correctly" do
      opps = [
        build_opportunity(days_open: 5, amount: Decimal.new("50000")),
        build_opportunity(days_open: 15, amount: Decimal.new("75000")),
        build_opportunity(days_open: 25, amount: Decimal.new("25000"))
      ]

      {:ok, report} = Forecasting.pipeline_aging_report(opps)

      assert report.fresh.count == 3
      assert Decimal.eq?(report.fresh.total, Decimal.new("150000"))
    end

    test "report includes summary statistics" do
      opps = [
        build_opportunity(days_open: 10, amount: Decimal.new("100000")),
        build_opportunity(days_open: 100, amount: Decimal.new("50000"))
      ]

      {:ok, report} = Forecasting.pipeline_aging_report(opps)

      assert report.total_count == 2
      assert Decimal.eq?(report.total_amount, Decimal.new("150000"))
      assert is_float(report.average_age_days)
    end

    test "stale percentage is computed" do
      opps = [
        build_opportunity(days_open: 10, amount: Decimal.new("100000")),
        build_opportunity(days_open: 50, amount: Decimal.new("100000")),
        build_opportunity(days_open: 120, amount: Decimal.new("100000")),
        build_opportunity(days_open: 200, amount: Decimal.new("100000"))
      ]

      {:ok, report} = Forecasting.pipeline_aging_report(opps)

      # 2 out of 4 are stale (91+ days)
      assert report.stale_percentage == 50.0
    end

    test "report completes under 50ms (SC-PRF-050)" do
      opps =
        for i <- 1..50 do
          build_opportunity(days_open: rem(i * 7, 200), amount: Decimal.new("10000"))
        end

      {time_us, {:ok, _report}} = :timer.tc(fn -> Forecasting.pipeline_aging_report(opps) end)

      assert time_us < 50_000,
             "pipeline_aging_report took #{time_us}us, expected < 50ms (SC-PRF-050)"
    end
  end

  # ============================================================================
  # Aging Risk Score Tests
  # ============================================================================

  describe "aging risk score" do
    test "fresh opportunity has zero risk score" do
      opp = build_opportunity(days_open: 15, amount: Decimal.new("50000"))

      score = Forecasting.aging_risk_score(opp)

      assert score == 0
    end

    test "stale opportunity has maximum risk score" do
      opp = build_opportunity(days_open: 150, amount: Decimal.new("50000"))

      score = Forecasting.aging_risk_score(opp)

      assert score == 3
    end

    test "risk score increases with bucket level" do
      fresh =
        Forecasting.aging_risk_score(build_opportunity(days_open: 10, amount: Decimal.new("1")))

      maturing =
        Forecasting.aging_risk_score(build_opportunity(days_open: 45, amount: Decimal.new("1")))

      aging =
        Forecasting.aging_risk_score(build_opportunity(days_open: 75, amount: Decimal.new("1")))

      stale =
        Forecasting.aging_risk_score(build_opportunity(days_open: 120, amount: Decimal.new("1")))

      assert fresh < maturing
      assert maturing < aging
      assert aging < stale
    end

    test "risk scores are bounded 0-3" do
      for days <- [0, 30, 31, 60, 61, 90, 91, 365] do
        opp = build_opportunity(days_open: days, amount: Decimal.new("1"))
        score = Forecasting.aging_risk_score(opp)
        assert score in 0..3, "days=#{days} gave score=#{score}, expected 0..3"
      end
    end
  end

  # ============================================================================
  # Telemetry Tests
  # ============================================================================

  describe "telemetry emission" do
    test "pipeline_aging_report emits telemetry event" do
      test_pid = self()

      :telemetry.attach(
        "test-aging-report-#{System.unique_integer()}",
        [:crm, :forecasting, :aging_report],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      opps = [build_opportunity(days_open: 50, amount: Decimal.new("10000"))]
      {:ok, _report} = Forecasting.pipeline_aging_report(opps)

      assert_receive {:telemetry, [:crm, :forecasting, :aging_report], measurements, _metadata},
                     1_000

      assert Map.has_key?(measurements, :duration_us)
      assert Map.has_key?(measurements, :opportunity_count)
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: bucket classification is exhaustive and deterministic" do
    @tag timeout: 30_000
    test "every non-negative age maps to exactly one bucket" do
      check all(days <- SD.integer(0..500)) do
        opp = build_opportunity(days_open: days, amount: Decimal.new("1"))
        bucket = Forecasting.classify_aging_bucket(opp)

        assert bucket in [:fresh, :maturing, :aging, :stale],
               "days=#{days} returned invalid bucket: #{inspect(bucket)}"
      end
    end

    @tag timeout: 30_000
    test "classification is monotonic: more days => same or higher risk bucket" do
      check all(
              days_a <- SD.integer(0..499),
              delta <- SD.integer(1..10)
            ) do
        days_b = days_a + delta
        opp_a = build_opportunity(days_open: days_a, amount: Decimal.new("1"))
        opp_b = build_opportunity(days_open: days_b, amount: Decimal.new("1"))

        score_a = Forecasting.aging_risk_score(opp_a)
        score_b = Forecasting.aging_risk_score(opp_b)

        assert score_a <= score_b,
               "Non-monotonic: days #{days_a} risk #{score_a} > days #{days_b} risk #{score_b}"
      end
    end

    @tag timeout: 30_000
    test "total count and amount in report equals sum of bucket stats" do
      check all(
              count <- SD.integer(1..20),
              amounts <-
                SD.list_of(SD.integer(1_000..1_000_000), length: count),
              ages <- SD.list_of(SD.integer(0..365), length: count)
            ) do
        opps =
          Enum.zip(ages, amounts)
          |> Enum.map(fn {days, amount} ->
            build_opportunity(days_open: days, amount: Decimal.new(Integer.to_string(amount)))
          end)

        {:ok, report} = Forecasting.pipeline_aging_report(opps)

        bucket_count =
          report.fresh.count + report.maturing.count + report.aging.count + report.stale.count

        bucket_total =
          report.fresh.total
          |> Decimal.add(report.maturing.total)
          |> Decimal.add(report.aging.total)
          |> Decimal.add(report.stale.total)

        assert bucket_count == report.total_count,
               "Bucket count #{bucket_count} != total_count #{report.total_count}"

        assert Decimal.eq?(bucket_total, report.total_amount),
               "Bucket total != report.total_amount"
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp build_opportunity(opts) do
    days_open = Keyword.fetch!(opts, :days_open)
    amount = Keyword.fetch!(opts, :amount)

    opened_at = Date.add(Date.utc_today(), -days_open)

    %{
      id: Ecto.UUID.generate(),
      amount: amount,
      opened_at: opened_at,
      days_open: days_open,
      forecast_category: :pipeline,
      probability: 50,
      is_won: false
    }
  end
end
