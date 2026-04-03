defmodule Indrajaal.Cockpit.Prajna.BackoffTest do
  @moduledoc """
  Tests for the Backoff module.

  STAMP Constraints Tested:
    - SC-API-003: Exponential backoff on 429 (base 2s, max 60s)
    - SC-BIO-007: Graceful degradation on rate limit
    - AOR-API-002: Never retry immediately on 429/503
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Re-import to exclude check/2 (PropCheck's check conflicts with ExUnitProperties)
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Conflict resolution - import StreamData as empty, alias as SD
  import StreamData, only: []

  # EP-GEN-014: Keep ExUnitProperties check for `ExUnitProperties.check all()` syntax (PropCheck's check already excluded)
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Backoff

  describe "exponential_backoff/2" do
    test "returns correct delay for first attempt (base delay)" do
      {:ok, delay} = Backoff.exponential_backoff(1)

      # With 20% jitter, delay should be between 800 and 1200 for base 1000
      assert delay >= 800
      assert delay <= 1200
    end

    test "returns exponentially increasing delays" do
      # Without jitter to verify pure exponential
      {:ok, delay1} = Backoff.exponential_backoff(1, jitter: false)
      {:ok, delay2} = Backoff.exponential_backoff(2, jitter: false)
      {:ok, delay3} = Backoff.exponential_backoff(3, jitter: false)
      {:ok, delay4} = Backoff.exponential_backoff(4, jitter: false)

      assert delay1 == 1_000
      assert delay2 == 2_000
      assert delay3 == 4_000
      assert delay4 == 8_000
    end

    test "respects maximum delay cap" do
      # Use max_attempts: 100 to allow attempt 10
      {:ok, delay} =
        Backoff.exponential_backoff(10, jitter: false, max_ms: 60_000, max_attempts: 100)

      # 1000 * 2^9 = 512_000, but should be capped at 60_000
      assert delay == 60_000
    end

    test "returns error when max attempts exceeded" do
      result = Backoff.exponential_backoff(6, max_attempts: 5)

      assert result == {:error, :max_attempts_exceeded}
    end

    test "returns error when circuit is open" do
      result = Backoff.exponential_backoff(1, circuit_state: :open)

      assert result == {:error, :circuit_open}
    end

    test "applies 1.5x multiplier in half_open circuit state" do
      {:ok, delay_closed} = Backoff.exponential_backoff(1, jitter: false, circuit_state: :closed)

      {:ok, delay_half_open} =
        Backoff.exponential_backoff(1, jitter: false, circuit_state: :half_open)

      assert delay_half_open == round(delay_closed * 1.5)
    end

    test "custom base_ms is respected" do
      {:ok, delay} = Backoff.exponential_backoff(1, base_ms: 2_000, jitter: false)

      assert delay == 2_000
    end

    test "custom max_ms is respected" do
      {:ok, delay} = Backoff.exponential_backoff(5, base_ms: 1_000, max_ms: 10_000, jitter: false)

      # 1000 * 2^4 = 16_000, capped at 10_000
      assert delay == 10_000
    end
  end

  describe "exponential_backoff/3 (three-arity legacy form)" do
    test "works with positional arguments" do
      {:ok, delay} = Backoff.exponential_backoff(1_000, 60_000, 1)

      # Should be around 1000 with jitter
      assert delay >= 800
      assert delay <= 1200
    end

    test "returns exponentially increasing delays" do
      {:ok, delay2} = Backoff.exponential_backoff(1_000, 60_000, 2)

      # Should be around 2000 with jitter
      assert delay2 >= 1_600
      assert delay2 <= 2_400
    end
  end

  describe "jitter" do
    test "jitter is approximately +/- 20%" do
      base = 1_000
      jitter_factor = 0.20
      min_expected = base - round(base * jitter_factor)
      max_expected = base + round(base * jitter_factor)

      # Run multiple times to verify jitter range
      delays =
        for _ <- 1..100 do
          {:ok, delay} = Backoff.exponential_backoff(1, base_ms: base)
          delay
        end

      # All delays should be within jitter range
      assert Enum.all?(delays, &(&1 >= min_expected and &1 <= max_expected))

      # Verify there's actual variance (not just returning same value)
      unique_delays = Enum.uniq(delays)
      assert length(unique_delays) > 1
    end

    test "jitter can be disabled" do
      delays =
        for _ <- 1..10 do
          {:ok, delay} = Backoff.exponential_backoff(1, jitter: false)
          delay
        end

      # All delays should be exactly the same without jitter
      assert Enum.uniq(delays) == [1_000]
    end
  end

  describe "delay_for_attempt/2" do
    test "returns raw delay without circuit breaker checks" do
      delay = Backoff.delay_for_attempt(1)
      assert delay == 1_000

      delay = Backoff.delay_for_attempt(3)
      assert delay == 4_000
    end

    test "respects custom options" do
      delay = Backoff.delay_for_attempt(1, base_ms: 500)
      assert delay == 500

      delay = Backoff.delay_for_attempt(10, max_ms: 5_000)
      assert delay == 5_000
    end
  end

  describe "schedule/1" do
    test "returns full backoff schedule" do
      schedule = Backoff.schedule(max_attempts: 5, base_ms: 1_000)

      assert schedule == [1_000, 2_000, 4_000, 8_000, 16_000]
    end

    test "respects max_ms cap" do
      schedule = Backoff.schedule(max_attempts: 5, base_ms: 1_000, max_ms: 5_000)

      assert schedule == [1_000, 2_000, 4_000, 5_000, 5_000]
    end
  end

  describe "should_retry?/2" do
    test "returns true when within max attempts and circuit closed" do
      assert Backoff.should_retry?(1, max_attempts: 5) == true
      assert Backoff.should_retry?(5, max_attempts: 5) == true
    end

    test "returns false when exceeding max attempts" do
      assert Backoff.should_retry?(6, max_attempts: 5) == false
    end

    test "returns false when circuit is open" do
      assert Backoff.should_retry?(1, circuit_state: :open) == false
    end
  end

  describe "defaults/0" do
    test "returns expected default values" do
      defaults = Backoff.defaults()

      assert defaults.base_ms == 1_000
      assert defaults.max_ms == 60_000
      assert defaults.max_attempts == 5
      # SIL-6 FIX: Jitter reduced from ±20% to ±10% per PRAJNA_5LEVEL_SPECIFICATION.md
      assert defaults.jitter_factor == 0.10
    end
  end

  describe "with_retry/2" do
    test "returns success on first attempt" do
      result = Backoff.with_retry(fn -> {:ok, :success} end)

      assert result == {:ok, :success}
    end

    test "returns error after max retries" do
      result =
        Backoff.with_retry(
          fn -> {:error, :timeout} end,
          max_attempts: 2,
          base_ms: 10
        )

      # Final error is the original error from the function, not :max_retries_exceeded
      # The function exhausted retries and returned the last error
      assert result == {:error, :timeout}
    end

    test "retries on transient errors" do
      # Use a counter to track attempts
      counter = :counters.new(1, [])

      result =
        Backoff.with_retry(
          fn ->
            count = :counters.get(counter, 1)
            :counters.add(counter, 1, 1)

            if count < 2 do
              {:error, :timeout}
            else
              {:ok, :eventually_succeeded}
            end
          end,
          max_attempts: 5,
          base_ms: 10
        )

      assert result == {:ok, :eventually_succeeded}
      # Counter is incremented before check, so:
      # - Call 1: count=0, incr to 1, returns :error (retry)
      # - Call 2: count=1, incr to 2, returns :error (retry)
      # - Call 3: count=2, incr to 3, returns :ok
      assert :counters.get(counter, 1) == 3
    end

    test "does not retry non-retryable errors" do
      counter = :counters.new(1, [])

      result =
        Backoff.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, :permanent_failure}
          end,
          max_attempts: 5,
          base_ms: 10
        )

      # Should only be called once
      assert result == {:error, :permanent_failure}
      assert :counters.get(counter, 1) == 1
    end
  end

  # Property-based tests
  describe "property tests" do
    property "delay is always positive" do
      forall {attempt, base, max} <- {PC.pos_integer(), PC.pos_integer(), PC.pos_integer()} do
        # Ensure max > base for valid config
        max = max(base + 1, max)

        case Backoff.exponential_backoff(attempt, base_ms: base, max_ms: max, max_attempts: 100) do
          {:ok, delay} -> delay > 0
          {:error, _} -> true
        end
      end
    end

    property "delay never exceeds max_ms + jitter" do
      forall attempt <- PC.pos_integer() do
        base = 1_000
        max = 60_000
        max_with_jitter = round(max * 1.2)

        case Backoff.exponential_backoff(attempt, base_ms: base, max_ms: max, max_attempts: 100) do
          {:ok, delay} -> delay <= max_with_jitter
          {:error, _} -> true
        end
      end
    end

    property "schedule length equals max_attempts" do
      forall max_attempts <- PC.pos_integer() do
        max_attempts = min(max_attempts, 20)
        schedule = Backoff.schedule(max_attempts: max_attempts)
        length(schedule) == max_attempts
      end
    end
  end

  # StreamData tests for ExUnitProperties
  describe "StreamData property tests" do
    test "delay with jitter is within expected range" do
      ExUnitProperties.check all(attempt <- SD.integer(1..10)) do
        base = 1_000
        expected_raw = min(base * :math.pow(2, attempt - 1), 60_000)
        min_expected = round(expected_raw * 0.8)
        max_expected = round(expected_raw * 1.2)

        # Use max_attempts: 100 to allow higher attempt numbers
        {:ok, delay} = Backoff.exponential_backoff(attempt, max_attempts: 100)

        assert delay >= min_expected
        assert delay <= max_expected
      end
    end

    test "schedule is monotonically increasing up to max" do
      ExUnitProperties.check all(
                               base <- SD.integer(100..1000),
                               max_factor <- SD.integer(10..100)
                             ) do
        max = base * max_factor
        schedule = Backoff.schedule(max_attempts: 10, base_ms: base, max_ms: max)

        # Each delay should be >= previous (monotonic)
        pairs = Enum.zip(schedule, Enum.drop(schedule, 1))
        assert Enum.all?(pairs, fn {a, b} -> b >= a end)
      end
    end
  end
end
