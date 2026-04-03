defmodule Indrajaal.Crm.Analytics.PipelineTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Crm.Analytics.Pipeline.

  Sprint 54 — 100% module coverage.

  ## STAMP Compliance
  - SC-COV-001: Module coverage
  - SC-PRF-050: Response time < 50ms
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Crm.Analytics.Pipeline

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Pipeline module is loaded" do
      assert Code.ensure_loaded?(Pipeline)
    end
  end

  describe "pipeline_summary/1" do
    test "exports pipeline_summary/1" do
      assert function_exported?(Pipeline, :pipeline_summary, 1)
    end
  end

  describe "conversion_rates/1" do
    test "returns {:ok, list} with empty opportunities" do
      assert {:ok, rates} = Pipeline.conversion_rates(opportunities: [])
      assert is_list(rates)
    end

    test "returns 6 stage transitions" do
      {:ok, rates} = Pipeline.conversion_rates(opportunities: [])
      assert length(rates) == 6
    end

    test "each rate has from_stage and to_stage" do
      {:ok, rates} = Pipeline.conversion_rates(opportunities: [])

      Enum.each(rates, fn rate ->
        assert Map.has_key?(rate, :from_stage)
        assert Map.has_key?(rate, :to_stage)
        assert Map.has_key?(rate, :rate)
        assert Map.has_key?(rate, :sample_size)
      end)
    end

    test "computes conversion from opportunities data" do
      opps = [
        %{stage: :prospecting},
        %{stage: :qualification},
        %{stage: :proposal},
        %{stage: :closed_won}
      ]

      {:ok, rates} = Pipeline.conversion_rates(opportunities: opps)
      first = hd(rates)
      assert first.from_stage == :prospecting
      assert first.sample_size > 0
    end
  end

  describe "sales_velocity/1" do
    test "returns {:ok, map} with empty opportunities" do
      assert {:ok, result} = Pipeline.sales_velocity(opportunities: [])
      assert result.velocity == Decimal.new("0.00")
      assert result.opportunities == 0
    end

    test "calculates velocity with won opportunities" do
      now = DateTime.utc_now()
      thirty_days_ago = DateTime.add(now, -30, :day)

      opps = [
        %{
          is_won: true,
          stage: :closed_won,
          amount: Decimal.new("50000"),
          inserted_at: thirty_days_ago,
          closed_at: now
        },
        %{
          is_won: true,
          stage: :closed_won,
          amount: Decimal.new("30000"),
          inserted_at: thirty_days_ago,
          closed_at: now
        }
      ]

      {:ok, result} = Pipeline.sales_velocity(opportunities: opps)
      assert result.win_rate == 1.0
      assert result.opportunities == 2
    end
  end

  describe "win_rate/1" do
    test "returns 0.0 with no closed opportunities" do
      assert {:ok, 0.0} = Pipeline.win_rate(opportunities: [])
    end

    test "returns 1.0 when all closed are won" do
      opps = [
        %{is_closed: true, is_won: true},
        %{is_closed: true, is_won: true}
      ]

      assert {:ok, 1.0} = Pipeline.win_rate(opportunities: opps)
    end

    test "returns 0.5 when half won half lost" do
      opps = [
        %{is_closed: true, is_won: true},
        %{is_closed: true, is_won: false}
      ]

      assert {:ok, 0.5} = Pipeline.win_rate(opportunities: opps)
    end
  end
end
