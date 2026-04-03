defmodule Indrajaal.AI.OpenRouter.RetryStrategyTest do
  @moduledoc """
  TDG-Compliant tests for RetryStrategy module.

  Tests exponential backoff with jitter for OpenRouter API resilience.

  STAMP Constraints:
  - SC-AI-RETRY-001: Max 3 retries with exponential backoff
  - SC-AI-RETRY-002: Jitter factor 0.1-0.3 prevents thundering herd
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.AI.OpenRouter.RetryStrategy

  describe "RetryStrategy.execute/2" do
    test "SC-AI-RETRY-001: succeeds on first attempt without retry" do
      call_count = :counters.new(1, [:atomics])

      result =
        RetryStrategy.execute(fn ->
          :counters.add(call_count, 1, 1)
          {:ok, :success}
        end)

      assert result == {:ok, :success}
      assert :counters.get(call_count, 1) == 1
    end

    test "SC-AI-RETRY-001: retries up to max_attempts on retryable errors" do
      call_count = :counters.new(1, [:atomics])

      result =
        RetryStrategy.execute(
          fn ->
            :counters.add(call_count, 1, 1)
            {:error, :rate_limited}
          end,
          max_attempts: 3,
          base_delay_ms: 1,
          max_delay_ms: 10
        )

      assert {:error, :rate_limited} = result
      assert :counters.get(call_count, 1) == 3
    end

    test "SC-AI-RETRY-001: succeeds after transient failure" do
      call_count = :counters.new(1, [:atomics])

      result =
        RetryStrategy.execute(
          fn ->
            count = :counters.add(call_count, 1, 1)
            current = :counters.get(call_count, 1)

            if current < 3 do
              {:error, :timeout}
            else
              {:ok, :recovered}
            end
          end,
          max_attempts: 5,
          base_delay_ms: 1
        )

      assert result == {:ok, :recovered}
      assert :counters.get(call_count, 1) == 3
    end

    test "does not retry non-retryable errors" do
      call_count = :counters.new(1, [:atomics])

      result =
        RetryStrategy.execute(
          fn ->
            :counters.add(call_count, 1, 1)
            {:error, :invalid_api_key}
          end,
          max_attempts: 3
        )

      assert {:error, :invalid_api_key} = result
      # Should only be called once - non-retryable error
      assert :counters.get(call_count, 1) == 1
    end

    test "respects max_attempts option" do
      call_count = :counters.new(1, [:atomics])

      RetryStrategy.execute(
        fn ->
          :counters.add(call_count, 1, 1)
          {:error, :network_error}
        end,
        max_attempts: 5,
        base_delay_ms: 1
      )

      assert :counters.get(call_count, 1) == 5
    end
  end

  describe "RetryStrategy.calculate_delay/2" do
    test "SC-AI-RETRY-002: calculates exponential backoff" do
      opts = [base_delay_ms: 1000, max_delay_ms: 30_000, jitter_factor: 0.0]

      # Without jitter, delay should be exact exponential
      assert RetryStrategy.calculate_delay(1, opts) == 1000
      assert RetryStrategy.calculate_delay(2, opts) == 2000
      assert RetryStrategy.calculate_delay(3, opts) == 4000
      assert RetryStrategy.calculate_delay(4, opts) == 8000
    end

    test "SC-AI-RETRY-002: respects max_delay_ms cap" do
      opts = [base_delay_ms: 10_000, max_delay_ms: 30_000, jitter_factor: 0.0]

      # 10_000 * 2^4 = 160_000, but should be capped at 30_000
      assert RetryStrategy.calculate_delay(5, opts) == 30_000
    end

    test "SC-AI-RETRY-002: applies jitter within bounds" do
      opts = [base_delay_ms: 1000, max_delay_ms: 30_000, jitter_factor: 0.2]

      # Run multiple times to verify jitter is applied
      delays =
        for _ <- 1..100 do
          RetryStrategy.calculate_delay(1, opts)
        end

      # With 20% jitter, delays should be in range [800, 1200]
      assert Enum.all?(delays, &(&1 >= 800 and &1 <= 1200))
      # Should have some variance (not all same value)
      assert length(Enum.uniq(delays)) > 1
    end

    # PropCheck property test for jitter bounds
    property "SC-AI-RETRY-002: jitter always within specified factor" do
      forall {attempt, base, jitter} <-
               {PC.pos_integer(), PC.range(100, 10_000), PC.float(0.1, 0.3)} do
        opts = [base_delay_ms: base, max_delay_ms: 60_000, jitter_factor: jitter]
        delay = RetryStrategy.calculate_delay(attempt, opts)

        # Calculate expected base without jitter
        raw_delay = min(base * :math.pow(2, attempt - 1), 60_000)
        min_expected = trunc(raw_delay * (1 - jitter))
        max_expected = trunc(raw_delay * (1 + jitter))

        delay >= min_expected and delay <= max_expected
      end
    end
  end

  describe "RetryStrategy.retryable_error?/1" do
    test "identifies rate limit errors as retryable" do
      assert RetryStrategy.retryable_error?(:rate_limited) == true
      assert RetryStrategy.retryable_error?({:http_error, 429}) == true
      assert RetryStrategy.retryable_error?({:http_error, 429, "Too Many Requests"}) == true
    end

    test "identifies timeout errors as retryable" do
      assert RetryStrategy.retryable_error?(:timeout) == true
      assert RetryStrategy.retryable_error?(:connect_timeout) == true
      assert RetryStrategy.retryable_error?(:recv_timeout) == true
    end

    test "identifies network errors as retryable" do
      assert RetryStrategy.retryable_error?(:network_error) == true
      assert RetryStrategy.retryable_error?(:econnrefused) == true
      assert RetryStrategy.retryable_error?(:closed) == true
    end

    test "identifies server errors as retryable" do
      assert RetryStrategy.retryable_error?({:http_error, 500}) == true
      assert RetryStrategy.retryable_error?({:http_error, 502}) == true
      assert RetryStrategy.retryable_error?({:http_error, 503}) == true
      assert RetryStrategy.retryable_error?({:http_error, 504}) == true
    end

    test "identifies client errors as non-retryable" do
      assert RetryStrategy.retryable_error?(:invalid_api_key) == false
      assert RetryStrategy.retryable_error?({:http_error, 400}) == false
      assert RetryStrategy.retryable_error?({:http_error, 401}) == false
      assert RetryStrategy.retryable_error?({:http_error, 403}) == false
      assert RetryStrategy.retryable_error?({:http_error, 404}) == false
    end

    test "identifies validation errors as non-retryable" do
      assert RetryStrategy.retryable_error?(:invalid_model) == false
      assert RetryStrategy.retryable_error?(:context_length_exceeded) == false
      assert RetryStrategy.retryable_error?(:content_policy_violation) == false
    end
  end

  describe "RetryStrategy default options" do
    test "uses sensible defaults" do
      defaults = RetryStrategy.default_options()

      assert defaults[:max_attempts] == 3
      assert defaults[:base_delay_ms] == 1000
      assert defaults[:max_delay_ms] == 30_000
      assert defaults[:jitter_factor] >= 0.1 and defaults[:jitter_factor] <= 0.3
    end
  end

  # Property test for execute/2 behavior
  property "execute always calls function at least once" do
    for max_attempts <- [1, 3, 5, 10] do
      call_count = :counters.new(1, [:atomics])

      RetryStrategy.execute(
        fn ->
          :counters.add(call_count, 1, 1)
          {:ok, :done}
        end,
        max_attempts: max_attempts
      )

      assert :counters.get(call_count, 1) >= 1
    end
  end
end
