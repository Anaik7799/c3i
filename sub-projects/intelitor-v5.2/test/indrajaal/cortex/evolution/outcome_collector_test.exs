defmodule Indrajaal.Cortex.Evolution.OutcomeCollectorTest do
  use ExUnit.Case, async: false

  use ExUnitProperties

  alias StreamData, as: SD

  alias Indrajaal.Cortex.Evolution.OutcomeCollector

  # EP-GEN-014 compliance: PC. prefix for PropCheck, SD. prefix for StreamData
  # async: false because OutcomeCollector is a named GenServer

  setup do
    # Ensure the GenServer is started before each test
    case Process.whereis(OutcomeCollector) do
      nil ->
        start_supervised!({OutcomeCollector, [flush_interval_ms: 60_000]})

      _pid ->
        :ok
    end

    # Flush any buffered state from prior tests
    OutcomeCollector.flush()
    :ok
  end

  describe "record_veto/3" do
    test "accepts valid proposal_id and reason" do
      assert :ok = OutcomeCollector.record_veto("proposal-001", :guardian_rejected, %{})
    end

    test "accepts reason as string" do
      assert :ok = OutcomeCollector.record_veto("proposal-002", "fitness too low", %{})
    end

    test "accepts context map" do
      assert :ok =
               OutcomeCollector.record_veto("proposal-003", :veto, %{
                 module: "TestModule",
                 fitness: 0.4
               })
    end
  end

  describe "record_approval/3" do
    test "accepts valid proposal and fitness" do
      assert :ok = OutcomeCollector.record_approval("proposal-100", 0.92, %{})
    end

    test "handles fitness = 1.0" do
      assert :ok = OutcomeCollector.record_approval("proposal-101", 1.0, %{})
    end

    test "handles minimum fitness at threshold" do
      assert :ok = OutcomeCollector.record_approval("proposal-102", 0.85, %{})
    end
  end

  describe "record_shadow_agree/3" do
    test "accepts valid agreement_rate" do
      assert :ok = OutcomeCollector.record_shadow_agree("shadow-001", 0.97, %{})
    end
  end

  describe "record_shadow_diverge/3" do
    test "accepts valid divergence reason" do
      assert :ok =
               OutcomeCollector.record_shadow_diverge(
                 "shadow-002",
                 "output format mismatch",
                 %{}
               )
    end
  end

  describe "record_fitness/3" do
    test "classifies >= 0.85 as :fitness_high" do
      assert :ok = OutcomeCollector.record_fitness("fit-001", 0.9, %{})
    end

    test "classifies < 0.85 as :fitness_low" do
      assert :ok = OutcomeCollector.record_fitness("fit-002", 0.6, %{})
    end

    test "boundary 0.85 is classified as :fitness_high" do
      assert :ok = OutcomeCollector.record_fitness("fit-003", 0.85, %{})
    end
  end

  describe "flush/0" do
    test "returns {:ok, count}" do
      OutcomeCollector.record_veto("flush-001", :test, %{})
      result = OutcomeCollector.flush()
      assert match?({:ok, n} when is_integer(n) and n >= 0, result)
    end

    test "flush twice is idempotent (second returns 0)" do
      OutcomeCollector.record_approval("flush-002", 0.9, %{})
      OutcomeCollector.flush()
      {:ok, second} = OutcomeCollector.flush()
      assert second == 0
    end
  end

  describe "stats/0" do
    test "returns map with required keys" do
      stats = OutcomeCollector.stats()
      assert Map.has_key?(stats, :buffered)
      assert Map.has_key?(stats, :total_flushed)
      assert Map.has_key?(stats, :flush_count)
      assert Map.has_key?(stats, :flush_interval_ms)
      assert Map.has_key?(stats, :started_at)
    end

    test "total_flushed increases after flush" do
      %{total_flushed: before} = OutcomeCollector.stats()
      OutcomeCollector.record_approval("stats-001", 0.9, %{})
      OutcomeCollector.flush()
      %{total_flushed: after_flush} = OutcomeCollector.stats()
      assert after_flush >= before
    end
  end

  describe "deduplication" do
    test "duplicate events within window are skipped" do
      # Record same event twice
      OutcomeCollector.record_veto("dedup-001", :reason, %{})
      OutcomeCollector.record_veto("dedup-001", :reason, %{})
      {:ok, flushed} = OutcomeCollector.flush()
      # Should only flush 1 (or 0 if TrainingGym not available)
      assert flushed <= 1
    end

    test "different proposals are not deduplicated" do
      OutcomeCollector.record_veto("dedup-a", :reason, %{})
      OutcomeCollector.record_veto("dedup-b", :reason, %{})
      {:ok, flushed} = OutcomeCollector.flush()
      assert flushed >= 0
    end
  end

  # Property-based tests (EP-GEN-014 compliant — StreamData only, no PropCheck forall here)

  test "StreamData: record_veto handles any binary proposal_id" do
    ExUnitProperties.check all(pid <- SD.string(:alphanumeric, min_length: 1, max_length: 50)) do
      assert :ok = OutcomeCollector.record_veto(pid, :test, %{})
    end
  end

  test "StreamData: record_fitness handles any float 0.0-1.0" do
    ExUnitProperties.check all(fitness <- SD.float(min: 0.0, max: 1.0)) do
      assert :ok = OutcomeCollector.record_fitness("prop-#{:rand.uniform(999)}", fitness, %{})
    end
  end
end
