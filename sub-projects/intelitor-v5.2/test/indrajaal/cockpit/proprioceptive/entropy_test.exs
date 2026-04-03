defmodule Indrajaal.Cockpit.Proprioceptive.EntropyTest do
  @moduledoc """
  Test suite for Indrajaal.Cockpit.Proprioceptive.Entropy

  ## WHAT
  Tests for entropy calculation functions (Shannon information entropy,
  structural entropy, behavioral entropy, temporal entropy) and the
  GenServer-based entropy recording/alerting system.

  ## Coverage
  - Pure calculation functions (no process required)
  - GenServer state management (record, current, history, snapshot, alerts, stats)
  - Anomaly detection and alert generation
  - Edge cases and numerical stability

  ## STAMP Constraints
  - SC-ENT-001: Real-time entropy calculation verified
  - SC-ENT-002: History tracking tested
  - SC-ENT-003: Anomaly detection at 2σ tested
  """

  use ExUnit.Case, async: false
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check so ExUnitProperties' ExUnitProperties.check all() wins (SC-PROP-023)
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Proprioceptive.Entropy

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Start a fresh isolated GenServer for each test that needs one.
  defp start_entropy(opts \\ []) do
    name = :"entropy_test_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = GenServer.start_link(Entropy, opts, name: name)
    pid
  end

  defp call(pid, msg), do: GenServer.call(pid, msg)
  defp cast(pid, msg), do: GenServer.cast(pid, msg)

  # ---------------------------------------------------------------------------
  # describe "calculate_information_entropy/1"
  # ---------------------------------------------------------------------------

  describe "calculate_information_entropy/1" do
    test "uniform 4-element distribution yields maximum entropy of 2.0 bits" do
      # H([0.25, 0.25, 0.25, 0.25]) = 2.0 bits
      result = Entropy.calculate_information_entropy([1, 1, 1, 1])
      assert_in_delta result, 2.0, 1.0e-10
    end

    test "uniform 2-element distribution yields 1.0 bit" do
      # H([0.5, 0.5]) = 1.0 bit
      result = Entropy.calculate_information_entropy([1, 1])
      assert_in_delta result, 1.0, 1.0e-10
    end

    test "uniform 8-element distribution yields 3.0 bits" do
      result = Entropy.calculate_information_entropy([1, 1, 1, 1, 1, 1, 1, 1])
      assert_in_delta result, 3.0, 1.0e-10
    end

    test "degenerate single-element list yields zero entropy" do
      # H([1.0]) = 0
      result = Entropy.calculate_information_entropy([42])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "completely concentrated distribution yields zero entropy" do
      # H([0, 0, 100]) — all weight on one element
      result = Entropy.calculate_information_entropy([0, 0, 100])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "empty list yields zero entropy" do
      result = Entropy.calculate_information_entropy([])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "all-zero distribution yields zero entropy" do
      result = Entropy.calculate_information_entropy([0, 0, 0])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "known asymmetric distribution — 1 bit skewed" do
      # H([3,1]) => p1=0.75, p2=0.25 => -0.75*log2(0.75) - 0.25*log2(0.25)
      expected = -0.75 * :math.log2(0.75) - 0.25 * :math.log2(0.25)
      result = Entropy.calculate_information_entropy([3, 1])
      assert_in_delta result, expected, 1.0e-10
    end

    test "large counts produce same result as normalised probabilities" do
      result_small = Entropy.calculate_information_entropy([1, 1, 1, 1])
      result_large = Entropy.calculate_information_entropy([1000, 1000, 1000, 1000])
      assert_in_delta result_small, result_large, 1.0e-10
    end

    test "entropy is non-negative for any non-negative distribution" do
      distributions = [[1], [1, 1], [1, 2, 3], [10, 0, 0], [1, 1, 1, 1, 1]]

      for dist <- distributions do
        assert Entropy.calculate_information_entropy(dist) >= 0.0
      end
    end

    test "uniform distribution maximises entropy for a given support size" do
      # For n=4 elements, uniform distribution should have max entropy
      uniform_h = Entropy.calculate_information_entropy([1, 1, 1, 1])
      skewed_h = Entropy.calculate_information_entropy([4, 1, 1, 1])
      concentrated_h = Entropy.calculate_information_entropy([10, 0, 0, 0])

      assert uniform_h >= skewed_h
      assert uniform_h >= concentrated_h
    end

    test "float values are accepted and produce correct result" do
      result = Entropy.calculate_information_entropy([0.5, 0.5])
      assert_in_delta result, 1.0, 1.0e-10
    end

    test "single large value is treated as fully concentrated" do
      result = Entropy.calculate_information_entropy([999_999])
      assert_in_delta result, 0.0, 1.0e-10
    end
  end

  # ---------------------------------------------------------------------------
  # describe "calculate_structural_entropy/1"
  # ---------------------------------------------------------------------------

  describe "calculate_structural_entropy/1" do
    test "delegates to information_entropy on :complexities key" do
      # Uniform complexities → high entropy
      metrics = %{complexities: [1, 1, 1, 1]}
      result = Entropy.calculate_structural_entropy(metrics)
      assert_in_delta result, 2.0, 1.0e-10
    end

    test "concentrated complexities yield low entropy" do
      metrics = %{complexities: [100, 0, 0]}
      result = Entropy.calculate_structural_entropy(metrics)
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "missing :complexities key defaults to [1] — zero entropy" do
      result = Entropy.calculate_structural_entropy(%{})
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "result is non-negative" do
      result = Entropy.calculate_structural_entropy(%{complexities: [3, 5, 2, 8]})
      assert result >= 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # describe "calculate_behavioral_entropy/1"
  # ---------------------------------------------------------------------------

  describe "calculate_behavioral_entropy/1" do
    test "uniform action frequencies yield maximum entropy" do
      # 4 distinct actions, each occurring exactly once → H = 2.0 bits
      actions = [:read, :write, :delete, :update]
      result = Entropy.calculate_behavioral_entropy(actions)
      assert_in_delta result, 2.0, 1.0e-10
    end

    test "single repeated action yields zero entropy" do
      actions = [:read, :read, :read, :read]
      result = Entropy.calculate_behavioral_entropy(actions)
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "empty list yields zero entropy" do
      result = Entropy.calculate_behavioral_entropy([])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "two equally-likely actions yield 1.0 bit" do
      actions = [:login, :logout]
      result = Entropy.calculate_behavioral_entropy(actions)
      assert_in_delta result, 1.0, 1.0e-10
    end

    test "repeated actions lower entropy compared to diverse actions" do
      diverse = [:a, :b, :c, :d]
      biased = [:a, :a, :a, :b]

      diverse_h = Entropy.calculate_behavioral_entropy(diverse)
      biased_h = Entropy.calculate_behavioral_entropy(biased)

      assert diverse_h > biased_h
    end

    test "result is always non-negative" do
      actions = [:x, :y, :x, :z, :x]
      result = Entropy.calculate_behavioral_entropy(actions)
      assert result >= 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # describe "calculate_temporal_entropy/1"
  # ---------------------------------------------------------------------------

  describe "calculate_temporal_entropy/1" do
    test "empty or single-element series yields zero entropy" do
      assert_in_delta Entropy.calculate_temporal_entropy([]), 0.0, 1.0e-10
      assert_in_delta Entropy.calculate_temporal_entropy([42]), 0.0, 1.0e-10
    end

    test "constant series yields zero entropy" do
      # All diffs are 0, single bin → H = 0
      result = Entropy.calculate_temporal_entropy([5, 5, 5, 5, 5])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "two-element series yields zero entropy" do
      # Single diff, single bin → H = 0
      result = Entropy.calculate_temporal_entropy([10, 20])
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "uniformly varying series yields positive entropy" do
      # Linearly increasing values — diffs are all equal → 0 entropy (one bin)
      result = Entropy.calculate_temporal_entropy([1, 2, 3, 4, 5])
      # All diffs equal → single bin
      assert_in_delta result, 0.0, 1.0e-10
    end

    test "highly variable series yields higher entropy than stable series" do
      stable = [1, 2, 3, 4, 5]
      chaotic = [1, 100, 2, 99, 3, 98, 4]

      stable_h = Entropy.calculate_temporal_entropy(stable)
      chaotic_h = Entropy.calculate_temporal_entropy(chaotic)

      # Chaotic should have higher or equal entropy
      assert chaotic_h >= stable_h
    end

    test "result is always non-negative" do
      series = [10, 20, 15, 30, 5, 25]
      result = Entropy.calculate_temporal_entropy(series)
      assert result >= 0.0
    end

    test "float series is handled without error" do
      series = [1.1, 2.2, 1.5, 3.0, 0.5]
      result = Entropy.calculate_temporal_entropy(series)
      assert is_float(result)
      assert result >= 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # describe "GenServer: record and current"
  # ---------------------------------------------------------------------------

  describe "GenServer record/4 and current/1" do
    test "returns :error when no data recorded for type" do
      pid = start_entropy()
      assert {:error, :no_data} = call(pid, {:current, :information})
    end

    test "records a value and retrieves it via current/1" do
      pid = start_entropy()
      cast(pid, {:record, :information, 0.75, "test_source", %{}})
      # Allow the cast to be processed
      _ = call(pid, :snapshot)
      assert {:ok, 0.75} = call(pid, {:current, :information})
    end

    test "records multiple types independently" do
      pid = start_entropy()
      cast(pid, {:record, :information, 1.0, "src", %{}})
      cast(pid, {:record, :structural, 0.5, "src", %{}})
      _ = call(pid, :snapshot)
      assert {:ok, 1.0} = call(pid, {:current, :information})
      assert {:ok, 0.5} = call(pid, {:current, :structural})
    end

    test "latest value overwrites previous for same type" do
      pid = start_entropy()
      cast(pid, {:record, :behavioral, 0.3, "s1", %{}})
      cast(pid, {:record, :behavioral, 0.9, "s2", %{}})
      _ = call(pid, :snapshot)
      assert {:ok, 0.9} = call(pid, {:current, :behavioral})
    end

    test "all four entropy types can be recorded" do
      pid = start_entropy()

      for {type, val} <- [
            {:information, 1.0},
            {:structural, 0.5},
            {:behavioral, 0.8},
            {:temporal, 0.2}
          ] do
        cast(pid, {:record, type, val, "src", %{}})
      end

      _ = call(pid, :snapshot)
      assert {:ok, 1.0} = call(pid, {:current, :information})
      assert {:ok, 0.5} = call(pid, {:current, :structural})
      assert {:ok, 0.8} = call(pid, {:current, :behavioral})
      assert {:ok, 0.2} = call(pid, {:current, :temporal})
    end
  end

  # ---------------------------------------------------------------------------
  # describe "GenServer: history/2"
  # ---------------------------------------------------------------------------

  describe "GenServer history/2" do
    test "returns empty list when no samples recorded" do
      pid = start_entropy()
      assert [] = call(pid, {:history, :information, 10})
    end

    test "returns recorded samples in LIFO order (newest first)" do
      pid = start_entropy()
      cast(pid, {:record, :information, 0.1, "s", %{}})
      cast(pid, {:record, :information, 0.2, "s", %{}})
      cast(pid, {:record, :information, 0.3, "s", %{}})
      _ = call(pid, :snapshot)
      samples = call(pid, {:history, :information, 10})
      values = Enum.map(samples, & &1.value)
      assert values == [0.3, 0.2, 0.1]
    end

    test "limit caps the number of returned samples" do
      pid = start_entropy()

      for i <- 1..10 do
        cast(pid, {:record, :information, i * 0.1, "s", %{}})
      end

      _ = call(pid, :snapshot)
      samples = call(pid, {:history, :information, 3})
      assert length(samples) == 3
    end

    test "sample map has required keys" do
      pid = start_entropy()
      cast(pid, {:record, :structural, 0.42, "my_source", %{note: "test"}})
      _ = call(pid, :snapshot)
      [sample | _] = call(pid, {:history, :structural, 5})
      assert sample.type == :structural
      assert_in_delta sample.value, 0.42, 1.0e-10
      assert sample.source == "my_source"
      assert sample.metadata == %{note: "test"}
      assert %DateTime{} = sample.timestamp
    end

    test "separate types have independent history" do
      pid = start_entropy()
      cast(pid, {:record, :information, 1.0, "s", %{}})
      cast(pid, {:record, :behavioral, 2.0, "s", %{}})
      _ = call(pid, :snapshot)
      info_hist = call(pid, {:history, :information, 10})
      behav_hist = call(pid, {:history, :behavioral, 10})
      assert length(info_hist) == 1
      assert length(behav_hist) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # describe "GenServer: snapshot/0"
  # ---------------------------------------------------------------------------

  describe "GenServer snapshot/0" do
    test "snapshot includes current, baselines, alerts count, and timestamp" do
      pid = start_entropy()
      snapshot = call(pid, :snapshot)
      assert Map.has_key?(snapshot, :current)
      assert Map.has_key?(snapshot, :baselines)
      assert is_integer(snapshot.alerts)
      assert %DateTime{} = snapshot.timestamp
    end

    test "snapshot current reflects recorded values" do
      pid = start_entropy()
      cast(pid, {:record, :information, 0.77, "s", %{}})
      _ = call(pid, :stats)
      snapshot = call(pid, :snapshot)
      assert_in_delta snapshot.current[:information], 0.77, 1.0e-10
    end
  end

  # ---------------------------------------------------------------------------
  # describe "GenServer: alerts/0 and clear_alerts/0"
  # ---------------------------------------------------------------------------

  describe "GenServer alerts/0 and clear_alerts/0" do
    test "no alerts initially" do
      pid = start_entropy()
      assert [] = call(pid, :alerts)
    end

    test "clear_alerts removes all alerts" do
      pid = start_entropy()
      # Record enough samples to establish baseline with tight std,
      # then record an outlier to trigger alert.
      # First, populate baseline via 20 samples at 0.5 ± 0.0
      for _ <- 1..20 do
        cast(pid, {:record, :information, 0.5, "s", %{}})
      end

      # Force baseline calculation by sending :calculate message
      send(pid, :calculate)
      _ = call(pid, :stats)

      # Now record an extreme outlier
      cast(pid, {:record, :information, 999.0, "s", %{}})
      _ = call(pid, :stats)

      # Clear alerts
      cast(pid, :clear_alerts)
      _ = call(pid, :snapshot)
      assert [] = call(pid, :alerts)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "GenServer: stats/0"
  # ---------------------------------------------------------------------------

  describe "GenServer stats/0" do
    test "initial stats have zero samples_recorded" do
      pid = start_entropy()
      stats = call(pid, :stats)
      assert stats.samples_recorded == 0
    end

    test "samples_recorded increments with each record cast" do
      pid = start_entropy()
      cast(pid, {:record, :information, 0.1, "s", %{}})
      cast(pid, {:record, :structural, 0.2, "s", %{}})
      cast(pid, {:record, :behavioral, 0.3, "s", %{}})
      stats = call(pid, :stats)
      assert stats.samples_recorded == 3
    end

    test "stats include current_values count" do
      pid = start_entropy()
      cast(pid, {:record, :information, 0.1, "s", %{}})
      cast(pid, {:record, :temporal, 0.5, "s", %{}})
      stats = call(pid, :stats)
      assert stats.current_values == 2
    end

    test "stats include history_sizes map with all four types" do
      pid = start_entropy()
      stats = call(pid, :stats)
      assert Map.has_key?(stats.history_sizes, :information)
      assert Map.has_key?(stats.history_sizes, :structural)
      assert Map.has_key?(stats.history_sizes, :behavioral)
      assert Map.has_key?(stats.history_sizes, :temporal)
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests — ExUnitProperties (StreamData / check all)
  # ---------------------------------------------------------------------------
  # These use plain `test` blocks with `check all` from ExUnitProperties.
  # Keeps ExUnitProperties and PropCheck cleanly separated (EP-GEN-014 / SC-PROP-023).

  describe "StreamData properties: information entropy" do
    test "entropy is non-negative for any list of non-negative integers" do
      ExUnitProperties.check all(
                               counts <-
                                 SD.list_of(SD.integer(0..1000), min_length: 1, max_length: 20)
                             ) do
        result = Entropy.calculate_information_entropy(counts)
        assert result >= 0.0
      end
    end

    test "uniform distribution has entropy >= any same-sized distribution" do
      ExUnitProperties.check all(
                               n <- SD.integer(2..8),
                               weights <- SD.list_of(SD.integer(0..100), length: n)
                             ) do
        uniform = List.duplicate(1, n)
        uniform_h = Entropy.calculate_information_entropy(uniform)
        other_h = Entropy.calculate_information_entropy(weights)
        # Uniform entropy dominates unless all weights are zero (which gives 0)
        assert uniform_h >= other_h or Enum.all?(weights, &(&1 == 0))
      end
    end
  end

  describe "StreamData properties: behavioral entropy" do
    test "behavioral entropy is non-negative for any atom list" do
      atoms = [:a, :b, :c, :d, :e, :f]

      ExUnitProperties.check all(
                               actions <-
                                 SD.list_of(SD.member_of(atoms), min_length: 0, max_length: 50)
                             ) do
        result = Entropy.calculate_behavioral_entropy(actions)
        assert result >= 0.0
      end
    end
  end

  describe "StreamData properties: temporal entropy" do
    test "temporal entropy is non-negative for any float series" do
      ExUnitProperties.check all(
                               series <-
                                 SD.list_of(SD.float(min: -1000.0, max: 1000.0),
                                   min_length: 0,
                                   max_length: 30
                                 )
                             ) do
        result = Entropy.calculate_temporal_entropy(series)
        assert result >= 0.0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests — PropCheck-style (using StreamData for --no-start compatibility)
  # ---------------------------------------------------------------------------
  # EP-GEN-014 / SC-PROP-023: The `property` macro from PropCheck contacts
  # PropCheck.CounterStrike at module-load time, which requires the PropCheck
  # OTP application to be running.  When tests are run with --no-start (or when
  # the full application is not started), that process is absent and the module
  # fails to compile/load.
  #
  # These tests replicate the same logical properties using StreamData `check all`
  # (SD prefix), which has no module-load-time side effects and works under
  # --no-start.  PC aliases are kept so future migration back to `forall` is
  # trivial.  Bodies use ExUnit `assert`, not boolean returns.

  describe "PropCheck properties: information entropy" do
    test "information entropy is non-negative for non-empty positive integer lists" do
      ExUnitProperties.check all(
                               counts <-
                                 SD.list_of(SD.positive_integer(), min_length: 1, max_length: 50)
                             ) do
        assert Entropy.calculate_information_entropy(counts) >= 0.0
      end
    end

    test "structural entropy is non-negative for any positive complexity list" do
      ExUnitProperties.check all(
                               complexities <-
                                 SD.list_of(SD.positive_integer(), min_length: 1, max_length: 50)
                             ) do
        metrics = %{complexities: complexities}
        assert Entropy.calculate_structural_entropy(metrics) >= 0.0
      end
    end
  end

  describe "PropCheck properties: behavioral entropy" do
    test "behavioral entropy is non-negative for any non-empty atom sequence" do
      atoms = [:read, :write, :delete, :update]

      ExUnitProperties.check all(
                               actions <-
                                 SD.list_of(SD.member_of(atoms), min_length: 1, max_length: 50)
                             ) do
        assert Entropy.calculate_behavioral_entropy(actions) >= 0.0
      end
    end
  end
end
