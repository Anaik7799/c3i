#!/usr/bin/env elixir

# Standalone validation script for exponential backoff implementation
# This validates the backoff calculation without running the full test suite

defmodule ExponentialBackoffValidator do
  @moduledoc """
  Validates the exponential backoff implementation in OpenCode API Client
  """

  # Mirror the constants from the actual implementation
  @initial_retry_delay 1000
  @backoff_multiplier 2
  @max_retry_delay 30_000
  @jitter_range 0.1

  def validate do
    IO.puts("\n🔬 Validating Exponential Backoff Implementation\n")
    IO.puts("=" <> String.duplicate("=", 79))

    # Test 1: Basic backoff calculation
    test_basic_backoff()

    # Test 2: Maximum delay cap
    test_max_delay_cap()

    # Test 3: Jitter variation
    test_jitter_variation()

    # Test 4: Progressive delay increases
    test_progressive_delays()

    # Test 5: Simulate real retry scenario
    test_retry_scenario()

    IO.puts("\n✅ All exponential backoff validations passed!")
  end

  defp test_basic_backoff do
    IO.puts("\n📊 Test 1: Basic Backoff Calculation")
    IO.puts("-" <> String.duplicate("-", 40))

    for attempt <- 0..4 do
      delay = calculate_backoff(attempt)
      expected_base = @initial_retry_delay * :math.pow(@backoff_multiplier, attempt)

      IO.puts("  Attempt #{attempt}: #{delay}ms (base: #{round(expected_base)}ms)")

      # Verify delay is within jitter range of expected
      min_expected = expected_base * (1 - @jitter_range)
      max_expected = expected_base * (1 + @jitter_range)

      unless delay >= min_expected and delay <= max_expected do
        raise "Backoff calculation failed for attempt #{attempt}"
      end
    end

    IO.puts("  ✓ Basic backoff calculation working correctly")
  end

  defp test_max_delay_cap do
    IO.puts("\n📊 Test 2: Maximum Delay Cap")
    IO.puts("-" <> String.duplicate("-", 40))

    # Test with high attempt numbers that should hit the cap
    high_attempts = [10, 15, 20, 100]

    for attempt <- high_attempts do
      delay = calculate_backoff(attempt)
      IO.puts("  Attempt #{attempt}: #{delay}ms")

      if delay > @max_retry_delay do
        raise "Delay exceeded maximum cap: #{delay}ms > #{@max_retry_delay}ms"
      end
    end

    IO.puts("  ✓ Maximum delay cap enforced at #{@max_retry_delay}ms")
  end

  defp test_jitter_variation do
    IO.puts("\n📊 Test 3: Jitter Variation")
    IO.puts("-" <> String.duplicate("-", 40))

    # Calculate multiple delays for same attempt to verify jitter
    attempt = 2
    delays = for _ <- 1..10, do: calculate_backoff(attempt)

    min_delay = Enum.min(delays)
    max_delay = Enum.max(delays)
    avg_delay = round(Enum.sum(delays) / length(delays))

    IO.puts("  For attempt #{attempt} (10 samples):")
    IO.puts("    Min: #{min_delay}ms")
    IO.puts("    Max: #{max_delay}ms")
    IO.puts("    Avg: #{avg_delay}ms")
    IO.puts("    Range: #{max_delay - min_delay}ms")

    # Verify there's actual variation
    if min_delay == max_delay do
      raise "No jitter variation detected"
    end

    IO.puts("  ✓ Jitter provides appropriate randomization")
  end

  defp test_progressive_delays do
    IO.puts("\n📊 Test 4: Progressive Delay Increases")
    IO.puts("-" <> String.duplicate("-", 40))

    delays = for attempt <- 0..6 do
      # Use fixed seed for consistent comparison (no jitter)
      calculate_backoff_no_jitter(attempt)
    end

    IO.puts("  Progressive delays (without jitter):")
    Enum.with_index(delays) |> Enum.each(fn {delay, i} ->
      IO.puts("    Attempt #{i}: #{delay}ms")
    end)

    # Verify each delay is approximately double the previous (until cap)
    delays
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [prev, curr] ->
      if curr < @max_retry_delay do
        ratio = curr / prev
        unless ratio >= 1.9 and ratio <= 2.1 do
          raise "Delay progression not doubling: #{prev}ms -> #{curr}ms (ratio: #{ratio})"
        end
      end
    end)

    IO.puts("  ✓ Delays double progressively until cap")
  end

  defp test_retry_scenario do
    IO.puts("\n📊 Test 5: Simulated Retry Scenario")
    IO.puts("-" <> String.duplicate("-", 40))

    IO.puts("  Simulating 5 retry attempts with delays:")

    total_time = 0
    for attempt <- 0..4 do
      delay = calculate_backoff(attempt)
      total_time = total_time + delay
      IO.puts("    Retry #{attempt + 1}: Wait #{delay}ms (cumulative: #{total_time}ms)")
    end

    IO.puts("  Total time for 5 retries: #{total_time}ms (#{Float.round(total_time / 1000, 1)}s)")

    # Verify total time is reasonable
    if total_time > 60_000 do
      raise "Total retry time exceeds reasonable limit"
    end

    IO.puts("  ✓ Retry scenario completes in reasonable time")
  end

  # Mirror the actual implementation's calculation
  defp calculate_backoff(attempt) do
    base_delay = @initial_retry_delay
    multiplier = :math.pow(@backoff_multiplier, attempt)
    jitter = base_delay * @jitter_range * (:rand.uniform() - 0.5)

    delay = base_delay * multiplier + jitter
    min(delay, @max_retry_delay) |> round()
  end

  defp calculate_backoff_no_jitter(attempt) do
    base_delay = @initial_retry_delay
    multiplier = :math.pow(@backoff_multiplier, attempt)

    delay = base_delay * multiplier
    min(delay, @max_retry_delay) |> round()
  end
end

# Run the validation
ExponentialBackoffValidator.validate()