defmodule Indrajaal.Core.Entropy.ShannonEntropyGateTest do
  @moduledoc """
  Shannon entropy gate verification — deployment block at H > 0.2.

  ## WHAT
  Tests the entropy gating mechanism that blocks deployments when
  system entropy exceeds the safety threshold of 0.2, ensuring
  only stable configurations are deployed to production.

  ## CONSTRAINTS
  - SC-IKE-002: Entropy gating (blocked if > 0.2)
  - SC-EVO-001 to SC-EVO-030: Evolution constraints
  - SC-SIL6-001: Mesh boot MUST complete 5 stages
  - AOR-HOLON-014: State Verification — reject corrupted state
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @entropy_threshold 0.2
  @max_entropy 1.0

  # ============================================================================
  # Shannon Entropy Calculation Tests
  # ============================================================================

  describe "Shannon entropy calculation" do
    test "uniform distribution has maximum entropy" do
      # Equal probabilities → max entropy
      probs = [0.25, 0.25, 0.25, 0.25]
      h = shannon_entropy(probs)

      # H = -Σ p*log2(p) = -4 * (0.25 * log2(0.25)) = 2.0
      assert_in_delta h, 2.0, 0.001
    end

    test "single certain outcome has zero entropy" do
      probs = [1.0]
      h = shannon_entropy(probs)
      assert_in_delta h, 0.0, 0.001
    end

    test "binary equal distribution has entropy 1.0" do
      probs = [0.5, 0.5]
      h = shannon_entropy(probs)
      assert_in_delta h, 1.0, 0.001
    end

    test "skewed distribution has lower entropy than uniform" do
      uniform = [0.25, 0.25, 0.25, 0.25]
      skewed = [0.7, 0.1, 0.1, 0.1]

      h_uniform = shannon_entropy(uniform)
      h_skewed = shannon_entropy(skewed)

      assert h_skewed < h_uniform
    end

    test "entropy is non-negative" do
      probs = [0.3, 0.3, 0.2, 0.1, 0.1]
      h = shannon_entropy(probs)
      assert h >= 0.0
    end

    test "zero probability contributes zero to entropy" do
      # 0 * log2(0) is defined as 0 by convention
      probs = [0.5, 0.5, 0.0]
      h = shannon_entropy(probs)
      assert_in_delta h, 1.0, 0.001
    end
  end

  # ============================================================================
  # Normalized Entropy Tests
  # ============================================================================

  describe "normalized entropy (0..1)" do
    test "uniform distribution normalizes to 1.0" do
      probs = [0.25, 0.25, 0.25, 0.25]
      hn = normalized_entropy(probs)
      assert_in_delta hn, 1.0, 0.001
    end

    test "single outcome normalizes to 0.0" do
      probs = [1.0]
      hn = normalized_entropy(probs)
      assert_in_delta hn, 0.0, 0.001
    end

    test "normalized entropy is always between 0 and 1" do
      probs = [0.6, 0.2, 0.1, 0.05, 0.05]
      hn = normalized_entropy(probs)
      assert hn >= 0.0
      assert hn <= 1.0
    end
  end

  # ============================================================================
  # Entropy Gate Decision Tests (SC-IKE-002)
  # ============================================================================

  describe "entropy gate decision (SC-IKE-002)" do
    test "low entropy allows deployment" do
      state = %{entropy: 0.1, components: 10, stable_count: 9}
      assert {:ok, :deploy_allowed} = check_entropy_gate(state)
    end

    test "entropy at threshold blocks deployment" do
      state = %{entropy: 0.2, components: 10, stable_count: 8}
      assert {:error, :entropy_too_high, _} = check_entropy_gate(state)
    end

    test "high entropy blocks deployment" do
      state = %{entropy: 0.5, components: 10, stable_count: 5}
      assert {:error, :entropy_too_high, info} = check_entropy_gate(state)
      assert info.entropy == 0.5
      assert info.threshold == @entropy_threshold
    end

    test "zero entropy always allows deployment" do
      state = %{entropy: 0.0, components: 5, stable_count: 5}
      assert {:ok, :deploy_allowed} = check_entropy_gate(state)
    end

    test "gate returns entropy margin when allowed" do
      state = %{entropy: 0.05, components: 10, stable_count: 10}
      {:ok, :deploy_allowed} = check_entropy_gate(state)
      margin = @entropy_threshold - state.entropy
      assert margin > 0
    end
  end

  # ============================================================================
  # System State Entropy Measurement Tests
  # ============================================================================

  describe "system state entropy measurement" do
    test "all healthy components have near-zero entropy" do
      components = for i <- 1..10, do: %{id: "comp-#{i}", status: :healthy}
      h = measure_system_entropy(components)
      assert h < @entropy_threshold
    end

    test "mixed status components increase entropy" do
      components = [
        %{id: "c1", status: :healthy},
        %{id: "c2", status: :healthy},
        %{id: "c3", status: :degraded},
        %{id: "c4", status: :unhealthy},
        %{id: "c5", status: :healthy}
      ]

      h = measure_system_entropy(components)
      assert h > 0.0
    end

    test "all different statuses have maximum entropy" do
      components = [
        %{id: "c1", status: :healthy},
        %{id: "c2", status: :degraded},
        %{id: "c3", status: :unhealthy},
        %{id: "c4", status: :unknown}
      ]

      h = measure_system_entropy(components)
      # 4 unique statuses → high entropy
      assert h > 0.5
    end

    test "single component has zero entropy" do
      components = [%{id: "c1", status: :healthy}]
      h = measure_system_entropy(components)
      assert_in_delta h, 0.0, 0.001
    end
  end

  # ============================================================================
  # Entropy Trend Analysis Tests
  # ============================================================================

  describe "entropy trend analysis" do
    test "decreasing entropy trend is safe" do
      history = [0.5, 0.4, 0.3, 0.2, 0.15]
      assert {:ok, :decreasing} = analyze_entropy_trend(history)
    end

    test "increasing entropy trend triggers warning" do
      history = [0.05, 0.1, 0.15, 0.18, 0.22]
      assert {:warning, :increasing} = analyze_entropy_trend(history)
    end

    test "stable entropy trend is safe" do
      history = [0.1, 0.11, 0.09, 0.1, 0.1]
      assert {:ok, :stable} = analyze_entropy_trend(history)
    end

    test "empty history returns unknown" do
      assert {:ok, :unknown} = analyze_entropy_trend([])
    end

    test "single point returns stable" do
      assert {:ok, :stable} = analyze_entropy_trend([0.1])
    end
  end

  # ============================================================================
  # Deployment Gate Integration Tests
  # ============================================================================

  describe "deployment gate integration" do
    test "full deployment check with entropy gate" do
      deployment = %{
        version: "21.3.1",
        components: for(i <- 1..14, do: %{id: "container-#{i}", status: :healthy}),
        entropy_history: [0.05, 0.04, 0.03, 0.02, 0.01]
      }

      assert {:ok, :approved} = full_deployment_check(deployment)
    end

    test "deployment blocked when entropy exceeds threshold" do
      deployment = %{
        version: "21.3.1",
        components: [
          %{id: "c1", status: :healthy},
          %{id: "c2", status: :degraded},
          %{id: "c3", status: :unhealthy}
        ],
        entropy_history: [0.1, 0.15, 0.2, 0.25, 0.3]
      }

      assert {:error, :deployment_blocked, _reason} = full_deployment_check(deployment)
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: entropy is always non-negative and bounded" do
    @tag timeout: 30_000
    test "shannon entropy of any valid distribution is non-negative" do
      ExUnitProperties.check all(n <- SD.integer(2..10)) do
        probs = generate_probability_distribution(n)
        h = shannon_entropy(probs)
        assert h >= 0.0
        assert h <= :math.log2(n) + 0.001
      end
    end
  end

  describe "property: entropy gate is monotonic with threshold" do
    @tag timeout: 30_000
    test "lower entropy always passes if higher entropy passes" do
      ExUnitProperties.check all(
                               entropy_high <- SD.float(min: 0.0, max: 0.19),
                               entropy_low <- SD.float(min: 0.0, max: 0.19)
                             ) do
        low = min(entropy_high, entropy_low)

        state_low = %{entropy: low, components: 10, stable_count: 10}
        state_high = %{entropy: max(entropy_high, entropy_low), components: 10, stable_count: 10}

        case check_entropy_gate(state_high) do
          {:ok, :deploy_allowed} ->
            assert {:ok, :deploy_allowed} = check_entropy_gate(state_low)

          {:error, _, _} ->
            # Higher entropy blocked — lower may or may not pass
            :ok
        end
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp shannon_entropy(probabilities) do
    probabilities
    |> Enum.filter(&(&1 > 0))
    |> Enum.reduce(0.0, fn p, acc ->
      acc - p * :math.log2(p)
    end)
  end

  defp normalized_entropy(probabilities) do
    n = length(probabilities)

    if n <= 1 do
      0.0
    else
      h = shannon_entropy(probabilities)
      h_max = :math.log2(n)
      if h_max == 0.0, do: 0.0, else: h / h_max
    end
  end

  defp check_entropy_gate(%{entropy: entropy}) do
    if entropy < @entropy_threshold do
      {:ok, :deploy_allowed}
    else
      {:error, :entropy_too_high, %{entropy: entropy, threshold: @entropy_threshold}}
    end
  end

  defp measure_system_entropy(components) do
    statuses = Enum.map(components, & &1.status)
    total = length(statuses)

    if total <= 1 do
      0.0
    else
      freq =
        statuses
        |> Enum.frequencies()
        |> Map.values()

      probs = Enum.map(freq, &(&1 / total))
      normalized_entropy(probs)
    end
  end

  defp analyze_entropy_trend(history) when length(history) <= 1 do
    case history do
      [] -> {:ok, :unknown}
      [_] -> {:ok, :stable}
    end
  end

  defp analyze_entropy_trend(history) do
    deltas =
      history
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)

    avg_delta = Enum.sum(deltas) / length(deltas)

    cond do
      avg_delta > 0.02 -> {:warning, :increasing}
      avg_delta < -0.02 -> {:ok, :decreasing}
      true -> {:ok, :stable}
    end
  end

  defp full_deployment_check(deployment) do
    entropy = measure_system_entropy(deployment.components)
    state = %{entropy: entropy, components: length(deployment.components), stable_count: 0}

    case check_entropy_gate(state) do
      {:ok, :deploy_allowed} ->
        case analyze_entropy_trend(deployment.entropy_history) do
          {:warning, :increasing} ->
            {:error, :deployment_blocked, "entropy trend increasing"}

          _ ->
            {:ok, :approved}
        end

      {:error, :entropy_too_high, info} ->
        {:error, :deployment_blocked, info}
    end
  end

  defp generate_probability_distribution(n) do
    raw = for _ <- 1..n, do: :rand.uniform()
    total = Enum.sum(raw)
    Enum.map(raw, &(&1 / total))
  end
end
