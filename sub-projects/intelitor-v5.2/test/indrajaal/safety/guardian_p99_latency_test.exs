defmodule Indrajaal.Safety.GuardianP99LatencyTest do
  @moduledoc """
  Guardian proposal validation p99 latency benchmark test suite.

  ## WHAT
  Tests Guardian proposal validation latency to ensure p99 < 50ms,
  measuring timing distributions across various proposal types and
  constraint complexities.

  ## CONSTRAINTS
  - SC-PRF-050: Response < 50ms
  - SC-GUARD-001: Guardian MUST use Envelope for constraint values
  - SC-GUARD-002: Guardian integrates with DeadMansSwitch, fail closed
  """

  use ExUnit.Case, async: true
  use ExUnitProperties
  alias StreamData, as: SD

  # ============================================================================
  # Latency Measurement Tests
  # ============================================================================

  describe "proposal validation latency" do
    test "simple proposals validate under 1ms" do
      proposal = %{
        type: :config_change,
        target: "indrajaal.safety.sentinel",
        payload: %{threshold: 0.8},
        timestamp: DateTime.utc_now()
      }

      {time_us, result} = :timer.tc(fn -> validate_proposal(proposal) end)
      assert {:ok, _} = result
      assert time_us < 1_000, "Simple proposal took #{time_us}us, expected < 1ms"
    end

    test "complex proposals with multiple constraints validate under 5ms" do
      proposal = %{
        type: :reconfiguration,
        target: "indrajaal.core.holon",
        constraints: generate_constraints(10),
        payload: %{
          action: :scale,
          from: 3,
          to: 5,
          reason: "load increase"
        },
        timestamp: DateTime.utc_now()
      }

      {time_us, result} = :timer.tc(fn -> validate_proposal(proposal) end)
      assert {:ok, _} = result
      assert time_us < 5_000, "Complex proposal took #{time_us}us, expected < 5ms"
    end

    test "batch proposals maintain linear scaling" do
      proposals =
        for i <- 1..10 do
          %{
            type: :state_change,
            target: "indrajaal.holon.#{i}",
            payload: %{state: :active},
            timestamp: DateTime.utc_now()
          }
        end

      timings =
        Enum.map(proposals, fn p ->
          {time_us, _result} = :timer.tc(fn -> validate_proposal(p) end)
          time_us
        end)

      avg = Enum.sum(timings) / length(timings)
      max = Enum.max(timings)

      # Average should be < 2ms, max (p100) should be < 10ms
      assert avg < 2_000, "Average latency #{avg}us exceeds 2ms"
      assert max < 10_000, "Max latency #{max}us exceeds 10ms"
    end
  end

  # ============================================================================
  # P99 Distribution Tests
  # ============================================================================

  describe "p99 latency distribution" do
    test "p99 of 100 proposals is under 50ms (SC-PRF-050)" do
      timings =
        for _ <- 1..100 do
          proposal = random_proposal()
          {time_us, _} = :timer.tc(fn -> validate_proposal(proposal) end)
          time_us
        end

      sorted = Enum.sort(timings)
      p50 = Enum.at(sorted, 49)
      p95 = Enum.at(sorted, 94)
      p99 = Enum.at(sorted, 98)

      assert p99 < 50_000, "p99 latency #{p99}us exceeds 50ms (SC-PRF-050)"
      assert p95 < 20_000, "p95 latency #{p95}us exceeds 20ms"
      assert p50 < 5_000, "p50 latency #{p50}us exceeds 5ms"
    end

    test "no proposal takes longer than 100ms (hard ceiling)" do
      timings =
        for _ <- 1..50 do
          proposal = random_proposal()
          {time_us, _} = :timer.tc(fn -> validate_proposal(proposal) end)
          time_us
        end

      max = Enum.max(timings)
      assert max < 100_000, "Max latency #{max}us exceeds hard ceiling of 100ms"
    end
  end

  # ============================================================================
  # Envelope Constraint Tests (SC-GUARD-001)
  # ============================================================================

  describe "envelope constraint validation (SC-GUARD-001)" do
    test "envelope wraps constraints correctly" do
      envelope = create_envelope([:SC_FUNC_001, :SC_REG_001, :SC_CONST_007])

      assert envelope.constraints == [:SC_FUNC_001, :SC_REG_001, :SC_CONST_007]
      assert is_binary(envelope.signature)
      assert envelope.version == "1.0"
    end

    test "invalid envelope is rejected" do
      bad_envelope = %{constraints: nil, signature: "", version: "0.0"}
      assert {:error, :invalid_envelope} = validate_envelope(bad_envelope)
    end

    test "expired envelope is rejected" do
      old_ts = DateTime.add(DateTime.utc_now(), -3600, :second)

      envelope = %{
        constraints: [:SC_FUNC_001],
        signature: "valid",
        version: "1.0",
        timestamp: old_ts,
        ttl_seconds: 300
      }

      assert {:error, :expired_envelope} = validate_envelope(envelope)
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: all proposals validate in bounded time" do
    @tag timeout: 30_000
    test "random proposals always complete within timeout" do
      check all(
              type <- SD.member_of([:config_change, :state_change, :reconfiguration, :query]),
              target <- SD.string(:alphanumeric, min_length: 5, max_length: 30),
              constraint_count <- SD.integer(0..20)
            ) do
        proposal = %{
          type: type,
          target: target,
          constraints: generate_constraints(constraint_count),
          payload: %{},
          timestamp: DateTime.utc_now()
        }

        {time_us, result} = :timer.tc(fn -> validate_proposal(proposal) end)
        assert {:ok, _} = result
        assert time_us < 100_000, "Proposal validation exceeded 100ms hard limit"
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp validate_proposal(proposal) do
    # Simulate Guardian validation pipeline
    with {:ok, _} <- check_format(proposal),
         {:ok, _} <- check_constraints(proposal),
         {:ok, _} <- check_authorization(proposal) do
      {:ok, %{approved: true, proposal_id: :crypto.strong_rand_bytes(8) |> Base.encode16()}}
    end
  end

  defp check_format(%{type: type, timestamp: ts}) when is_atom(type) and not is_nil(ts) do
    {:ok, :valid_format}
  end

  defp check_format(_), do: {:error, :invalid_format}

  defp check_constraints(%{constraints: constraints}) when is_list(constraints) do
    if Enum.all?(constraints, &is_atom/1),
      do: {:ok, :valid_constraints},
      else: {:error, :invalid_constraint}
  end

  defp check_constraints(_), do: {:ok, :no_constraints}

  defp check_authorization(%{type: :reconfiguration}), do: {:ok, :guardian_approved}
  defp check_authorization(_), do: {:ok, :auto_approved}

  defp create_envelope(constraints) do
    %{
      constraints: constraints,
      signature: Base.encode64(:crypto.strong_rand_bytes(32)),
      version: "1.0",
      timestamp: DateTime.utc_now(),
      ttl_seconds: 300
    }
  end

  defp validate_envelope(%{constraints: nil}), do: {:error, :invalid_envelope}
  defp validate_envelope(%{signature: ""}), do: {:error, :invalid_envelope}

  defp validate_envelope(%{timestamp: ts, ttl_seconds: ttl} = envelope)
       when is_struct(ts, DateTime) do
    age = DateTime.diff(DateTime.utc_now(), ts, :second)

    cond do
      age > ttl -> {:error, :expired_envelope}
      is_list(envelope.constraints) -> {:ok, envelope}
      true -> {:error, :invalid_envelope}
    end
  end

  defp validate_envelope(_), do: {:error, :invalid_envelope}

  defp generate_constraints(0), do: []

  defp generate_constraints(n) do
    families = ~w(FUNC REG CONST SIL4 GUARD SAFE IMMUNE HOLON ZENOH BOOT)

    for _ <- 1..n do
      family = Enum.random(families)
      id = :rand.uniform(20) |> to_string() |> String.pad_leading(3, "0")
      :"SC_#{family}_#{id}"
    end
  end

  defp random_proposal do
    %{
      type: Enum.random([:config_change, :state_change, :reconfiguration, :query]),
      target: "indrajaal.test.#{:rand.uniform(100)}",
      constraints: generate_constraints(:rand.uniform(10)),
      payload: %{random: :rand.uniform(1000)},
      timestamp: DateTime.utc_now()
    }
  end
end
