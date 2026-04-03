defmodule Indrajaal.Cockpit.Prajna.Guardian.CircuitBreakerTest do
  use ExUnit.Case
  alias Indrajaal.Cockpit.Prajna.Guardian.CircuitBreaker

  setup do
    start_supervised!(CircuitBreaker)
    :ok
  end

  test "starts closed" do
    assert CircuitBreaker.check() == :closed
  end

  test "opens after failures" do
    CircuitBreaker.report_failure()
    CircuitBreaker.report_failure()
    # Threshold is 3
    CircuitBreaker.report_failure()
    assert CircuitBreaker.check() == :open
  end

  test "resets on success" do
    CircuitBreaker.report_failure()
    CircuitBreaker.report_success()
    assert CircuitBreaker.check() == :closed
  end
end
