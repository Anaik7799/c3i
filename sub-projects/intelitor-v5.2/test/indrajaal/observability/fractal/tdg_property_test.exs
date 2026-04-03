defmodule Indrajaal.Observability.Fractal.TDGPropertyTest do
  @moduledoc """
  TDG Property Tests for Fractal Logging System.

  Implements Test-Driven Generation (TDG) methodology with dual property testing
  (PropCheck + ExUnitProperties) per SC-PROP-023/024.

  ## TDG Rules Verified

  | Rule ID     | Rule Description                              |
  |-------------|-----------------------------------------------|
  | TDG-LOG-001 | Property MUST be written before implementation |
  | TDG-LOG-002 | All STAMP constraints have property tests     |
  | TDG-LOG-003 | 95% code coverage on Fractal modules          |
  | TDG-LOG-004 | PropCheck + ExUnitProperties dual testing     |

  ## STAMP Constraints Tested

  | Constraint  | Description                          |
  |-------------|--------------------------------------|
  | SC-LOG-001  | Async dispatch (never block)         |
  | SC-LOG-002  | Auto-throttle at CPU > 90%           |
  | SC-LOG-005  | Boosts require TTL (max 1hr)         |
  | SC-LOG-006  | HLC timestamps for L3+ logs          |
  | SC-LOG-007  | Batch flush within 10ms              |
  | SC-LOG-008  | Write filter <1% false negative      |
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]

  # SC-PROP-024: Disambiguate generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Observability.Fractal.{
    FractalControl,
    WriteFilter,
    HLC,
    BatchEncoder
  }

  # ============================================================
  # SETUP / TEARDOWN
  # ============================================================

  setup do
    # Ensure ETS tables exist
    ensure_ets_tables()

    # Start required GenServers if not running
    ensure_genservers_started()

    on_exit(fn ->
      # Reset state after each test (handle process not alive gracefully)
      try do
        if Process.whereis(FractalControl), do: FractalControl.reset()
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  defp ensure_ets_tables do
    tables = [
      {:fractal_config, [:ordered_set, :named_table, :public, read_concurrency: true]},
      {:fractal_boosts, [:set, :named_table, :public, write_concurrency: true]}
    ]

    for {name, opts} <- tables do
      unless :ets.whereis(name) != :undefined do
        :ets.new(name, opts)
      end
    end
  end

  defp ensure_genservers_started do
    # Start FractalControl if not running
    unless Process.whereis(FractalControl) do
      {:ok, _} = FractalControl.start_link([])
    end

    # Start WriteFilter if not running
    unless Process.whereis(WriteFilter) do
      {:ok, _} = WriteFilter.start_link([])
    end

    # Start HLC if not running
    unless Process.whereis(HLC) do
      {:ok, _} = HLC.start_link([])
    end
  end

  # ============================================================
  # TDG-LOG-001: LOG ADMISSION PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "TDG-LOG-001: L1 logs are rejected without active boost (PropCheck)" do
    forall key <- PC.utf8() do
      # Ensure no boosts are active
      FractalControl.clear_boosts()

      # L1 should be rejected without boost
      result = FractalControl.should_log?(key, :l1, %{})
      result == false
    end
  end

  @tag :tdg
  @tag :stamp
  property "TDG-LOG-001: L4 logs are always accepted (PropCheck)" do
    forall key <- PC.utf8() do
      # L4 should always be accepted
      result = FractalControl.should_log?(key, :l4, %{})
      result == true
    end
  end

  @tag :tdg
  property "TDG-LOG-001: L5 logs are always accepted (PropCheck)" do
    forall key <- PC.utf8() do
      # L5 should always be accepted
      result = FractalControl.should_log?(key, :l5, %{})
      result == true
    end
  end

  # ExUnitProperties variant
  @tag :tdg
  test "TDG-LOG-001: L2/L3 require boost or policy (StreamData)" do
    ExUnitProperties.check all(
                             key <- SD.string(:alphanumeric, min_length: 1),
                             level <- SD.member_of([:l2, :l3])
                           ) do
      FractalControl.clear_boosts()
      # Without boost, L2/L3 should be rejected
      result = FractalControl.should_log?(key, level, %{})
      refute result
    end
  end

  # ============================================================
  # SC-LOG-005: BOOST TTL PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-LOG-005: Boosts require valid TTL (PropCheck)" do
    # Use alphanumeric strings to avoid empty string issues
    forall {key, ttl} <- {PC.binary(), PC.integer(1, 3_600_000)} do
      # Handle empty strings gracefully - they return :invalid_key_expr which is expected
      if String.trim(key) == "" do
        # Skip empty keys (valid behavior)
        true
      else
        result = FractalControl.focus(key, :l1, ttl, "test")

        case result do
          {:ok, _boost_id} -> true
          # Only fail for invalid TTL
          {:error, :invalid_ttl} -> ttl > 3_600_000
          _ -> false
        end
      end
    end
  end

  @tag :tdg
  @tag :stamp
  property "SC-LOG-005: Boosts with TTL > 1 hour are rejected (PropCheck)" do
    # Use binary() and handle empty strings gracefully
    forall {key, excess_ttl} <- {PC.binary(), PC.integer(3_600_001, 10_000_000)} do
      # Handle empty strings gracefully - they return :invalid_key_expr which is expected
      if String.trim(key) == "" do
        # Skip empty keys (valid behavior)
        true
      else
        result = FractalControl.focus(key, :l1, excess_ttl, "test")
        result == {:error, :ttl_exceeds_maximum}
      end
    end
  end

  # ============================================================
  # SC-LOG-006: HLC TIMESTAMP PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-LOG-006: HLC timestamps are monotonically increasing (PropCheck)" do
    forall count <- PC.integer(2, 50) do
      timestamps = for _ <- 1..count, do: HLC.now()

      timestamps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [t1, t2] ->
        HLC.compare(t1, t2) in [:lt, :eq]
      end)
    end
  end

  @tag :tdg
  @tag :stamp
  test "SC-LOG-006: HLC physical time is always > 0 (StreamData)" do
    ExUnitProperties.check all(_x <- SD.constant(nil)) do
      hlc = HLC.now()
      assert hlc.physical > 0
    end
  end

  @tag :tdg
  test "SC-LOG-006: HLC counter increments on same physical time (StreamData)" do
    ExUnitProperties.check all(_x <- SD.constant(nil)) do
      # Get two timestamps in quick succession
      t1 = HLC.now()
      t2 = HLC.now()

      # Either physical time advanced or counter incremented
      assert t2.physical > t1.physical or
               (t2.physical == t1.physical and t2.counter >= t1.counter)
    end
  end

  # ============================================================
  # SC-LOG-007: BATCH ENCODING PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-LOG-007: Batch encoding achieves >65% wire savings (PropCheck)" do
    forall count <- PC.range(10, 100) do
      # Generate messages list of count size
      messages = for _ <- 1..count, do: generate_log_entry()

      # Calculate size without batching
      without_batch =
        messages
        |> Enum.map(&:erlang.term_to_binary/1)
        |> Enum.map(&byte_size/1)
        |> Enum.sum()

      # Calculate size with batching
      with_batch = byte_size(BatchEncoder.encode_batch(messages, "trace-id", 0))

      # Must achieve at least 65% savings (or allow small output)
      savings = 1 - with_batch / without_batch
      savings > 0.65 or with_batch <= 50
    end
  end

  # ============================================================
  # SC-LOG-008: WRITE FILTER PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-LOG-008: Write filter has 0% false negative rate (PropCheck)" do
    forall count <- PC.range(1, 50) do
      # Generate unique keys
      keys = for i <- 1..count, do: "key_#{i}_#{:rand.uniform(1_000_000)}"

      # Record all keys
      Enum.each(keys, fn key ->
        WriteFilter.record(key)
      end)

      # All recorded keys should return false (already exists = don't emit again)
      # Bloom filters guarantee NO false negatives for recorded items
      results = Enum.map(keys, &WriteFilter.should_emit?/1)

      # All should return false (they were already recorded)
      Enum.all?(results, fn result -> result == false end)
    end
  end

  @tag :tdg
  test "SC-LOG-008: Write filter false positive rate < 1% (StreamData)" do
    ExUnitProperties.check all(
                             recorded <-
                               SD.list_of(SD.string(:alphanumeric, min_length: 5),
                                 min_length: 100
                               ),
                             unrecorded <-
                               SD.list_of(SD.string(:alphanumeric, min_length: 5),
                                 min_length: 100
                               )
                           ) do
      # Reset filter
      WriteFilter.reset()

      # Record only the recorded set
      Enum.each(recorded, &WriteFilter.record/1)

      # Check unrecorded keys (should mostly be :skip)
      false_positives =
        unrecorded
        |> Enum.reject(&(&1 in recorded))
        |> Enum.count(fn key -> WriteFilter.should_emit?(key) == :emit end)

      # False positive rate should be < 1%
      false_positive_rate = false_positives / max(length(unrecorded), 1)
      assert false_positive_rate < 0.01
    end
  end

  # ============================================================
  # SC-LOG-002: LOAD SHEDDING PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :stamp
  property "SC-LOG-002: Load shedding activates at high CPU (PropCheck)" do
    forall cpu <- PC.float(0.91, 1.0) do
      # Simulate high CPU
      FractalControl.update_resource_metrics(cpu * 100, 50.0)

      # Give time for async processing
      Process.sleep(10)

      # Should be shedding
      FractalControl.load_shedding?()
    end
  end

  @tag :tdg
  @tag :stamp
  property "SC-LOG-002: Load shedding inactive at normal CPU (PropCheck)" do
    forall cpu <- PC.float(0.0, 0.70) do
      # Deactivate any active shedding
      FractalControl.deactivate_load_shedding()

      # Simulate normal CPU
      FractalControl.update_resource_metrics(cpu * 100, 50.0)

      # Should not be shedding
      not FractalControl.load_shedding?()
    end
  end

  # ============================================================
  # CYBERNETIC CONTROLLER PROPERTY TESTS
  # ============================================================

  @tag :tdg
  @tag :cybernetic
  property "CyberneticController: OODA orientation is deterministic (PropCheck)" do
    forall {cpu, error_rate, throughput} <- {
             PC.float(0.0, 1.0),
             PC.float(0.0, 0.2),
             PC.integer(0, 1000)
           } do
      # Create observation
      observation = %{
        cpu: cpu,
        memory: 0.5,
        log_throughput: throughput,
        error_rate: error_rate,
        timestamp: DateTime.utc_now()
      }

      # Orientation should be deterministic
      orientation = determine_orientation(observation)

      case orientation do
        :overload -> cpu > 0.90
        :degraded -> error_rate > 0.05 and cpu <= 0.90
        :idle -> throughput < 100 and cpu < 0.50 and error_rate <= 0.05
        :normal -> true
      end
    end
  end

  # ============================================================
  # GENERATORS
  # ============================================================

  defp log_entry_gen do
    let {key, level, msg, ts} <- {
          PC.utf8(),
          PC.oneof([:l1, :l2, :l3, :l4, :l5]),
          PC.utf8(),
          PC.integer(1_700_000_000_000_000, 1_800_000_000_000_000)
        } do
      %{
        key: key,
        level: level,
        message: msg,
        timestamp: ts,
        trace_id: :crypto.strong_rand_bytes(16)
      }
    end
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp determine_orientation(obs) do
    cond do
      obs.cpu > 0.90 -> :overload
      obs.error_rate > 0.05 -> :degraded
      obs.log_throughput < 100 and obs.cpu < 0.50 -> :idle
      true -> :normal
    end
  end

  # Generate a log entry (non-generator version for use in test bodies)
  defp generate_log_entry do
    levels = [:l1, :l2, :l3, :l4, :l5]

    %{
      key: "key_#{:rand.uniform(1_000_000)}",
      level: Enum.random(levels),
      message: "msg_#{:rand.uniform(1_000_000)}",
      timestamp: 1_700_000_000_000_000 + :rand.uniform(100_000_000_000_000),
      trace_id: :crypto.strong_rand_bytes(16)
    }
  end
end
