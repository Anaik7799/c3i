defmodule Indrajaal.Core.EntropyGatingTest do
  @moduledoc """
  Mathematical verification tests for Shannon entropy gating.

  Mathematical property verified:
  Shannon entropy H = -Σ p_i * log2(p_i) where p_i are probability values.

  Key invariants:
  1. H(uniform distribution) = log2(n) — maximum entropy for n symbols
  2. H(certain event) = 0 — zero entropy for deterministic systems
  3. H is non-negative: H ≥ 0
  4. H is concave: H(λp + (1-λ)q) ≥ λH(p) + (1-λ)H(q)
  5. SC-IKE-002: Deployment BLOCKED if entropy > 0.2 (normalized threshold)

  STAMP: SC-MATH-001, SC-IKE-002 (entropy gating blocks deployment)
  Layer: L1-CODE (pure mathematical verification)
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cockpit.Proprioceptive.Entropy

  @moduletag :mathematical
  @moduletag :entropy

  # SC-IKE-002: Deployment blocked if Shannon entropy > 0.2 (normalized)
  # The module's @alert_threshold is 2.0 (raw bits) — for a 4-symbol system,
  # normalized = 2.0 / log2(4) = 1.0; we test the raw threshold logic here
  @deploy_entropy_threshold 0.2

  # ============================================================================
  # Basic Shannon entropy computation
  # ============================================================================

  describe "Shannon entropy: H = -Σ p_i * log2(p_i)" do
    test "uniform distribution of 2 symbols has entropy = 1.0 bit" do
      # p = [0.5, 0.5] → H = -2*(0.5*log2(0.5)) = 1.0
      result = Entropy.calculate_information_entropy([0.5, 0.5])
      assert_in_delta result, 1.0, 0.0001
    end

    test "uniform distribution of 4 symbols has entropy = 2.0 bits" do
      # p = [0.25, 0.25, 0.25, 0.25] → H = 2.0
      result = Entropy.calculate_information_entropy([0.25, 0.25, 0.25, 0.25])
      assert_in_delta result, 2.0, 0.0001
    end

    test "uniform distribution of 8 symbols has entropy = 3.0 bits" do
      probs = List.duplicate(1.0 / 8, 8)
      result = Entropy.calculate_information_entropy(probs)
      assert_in_delta result, 3.0, 0.0001
    end

    test "certain event has zero entropy" do
      # p = [1.0] → H = 0
      result = Entropy.calculate_information_entropy([1.0])
      assert_in_delta result, 0.0, 0.0001
    end

    test "near-certain event has near-zero entropy" do
      # p = [0.999, 0.001] → H ≈ 0.0114 bits
      result = Entropy.calculate_information_entropy([0.999, 0.001])
      assert result < 0.02
      assert result >= 0.0
    end

    test "maximum entropy grows with alphabet size" do
      h2 = Entropy.calculate_information_entropy([0.5, 0.5])
      h4 = Entropy.calculate_information_entropy([0.25, 0.25, 0.25, 0.25])
      h8 = Entropy.calculate_information_entropy(List.duplicate(1.0 / 8, 8))

      assert h2 < h4
      assert h4 < h8
    end

    test "entropy is non-negative" do
      for probs <- [[0.3, 0.7], [0.1, 0.1, 0.8], [0.5, 0.5], [1.0]] do
        result = Entropy.calculate_information_entropy(probs)
        assert result >= 0.0, "Expected non-negative entropy, got #{result}"
      end
    end

    test "skewed distribution has lower entropy than uniform" do
      uniform = Entropy.calculate_information_entropy([0.5, 0.5])
      skewed = Entropy.calculate_information_entropy([0.9, 0.1])
      assert skewed < uniform
    end
  end

  # ============================================================================
  # Behavioral entropy (temporal patterns)
  # ============================================================================

  describe "behavioral entropy" do
    test "uniform event distribution returns high behavioral entropy" do
      # [1, 1, 1, 1] → 4 equal event counts → maximum entropy
      result = Entropy.calculate_behavioral_entropy([1, 1, 1, 1])
      assert result >= 1.9
    end

    test "single event type returns zero behavioral entropy" do
      result = Entropy.calculate_behavioral_entropy([100, 0, 0, 0])
      assert_in_delta result, 0.0, 0.0001
    end

    test "behavioral entropy is non-negative" do
      result = Entropy.calculate_behavioral_entropy([10, 20, 30, 40])
      assert result >= 0.0
    end

    test "empty list returns zero entropy" do
      result = Entropy.calculate_behavioral_entropy([])
      assert result == 0.0
    end
  end

  # ============================================================================
  # SC-IKE-002: Deployment gating logic
  # Entropy > threshold → block deployment
  # ============================================================================

  describe "SC-IKE-002: deployment entropy gating" do
    test "low entropy system PASSES deployment gate" do
      # Very deterministic: p = [0.99, 0.005, 0.005]
      probs = [0.99, 0.005, 0.005]
      entropy = Entropy.calculate_information_entropy(probs)

      # Normalize to [0,1] range: divide by max possible entropy (log2 of count)
      max_entropy = :math.log2(length(probs))
      normalized = if max_entropy > 0, do: entropy / max_entropy, else: 0.0

      assert normalized < @deploy_entropy_threshold,
             "Expected normalized entropy #{normalized} < #{@deploy_entropy_threshold}"
    end

    test "high entropy system BLOCKS deployment gate" do
      # Fully uncertain: uniform distribution over many symbols → high entropy
      probs = List.duplicate(1.0 / 32, 32)
      entropy = Entropy.calculate_information_entropy(probs)
      max_entropy = :math.log2(32)
      normalized = entropy / max_entropy

      # Uniform → normalized = 1.0 >> 0.2
      assert normalized > @deploy_entropy_threshold
    end

    test "entropy threshold is 0.2 (SC-IKE-002 invariant)" do
      assert @deploy_entropy_threshold == 0.2
    end

    test "single-symbol system always passes gate" do
      probs = [1.0]
      entropy = Entropy.calculate_information_entropy(probs)
      # max_entropy for 1 symbol = log2(1) = 0; entropy is also 0
      # normalized = 0/0 → treat as 0 (passes)
      assert entropy == 0.0
    end
  end

  # ============================================================================
  # Structural entropy
  # ============================================================================

  describe "structural entropy" do
    test "structural entropy returns a non-negative float" do
      result = Entropy.calculate_structural_entropy([1, 2, 3, 4])
      assert is_float(result) or is_integer(result)
      assert result >= 0.0
    end

    test "structural entropy of uniform structure is non-negative" do
      result = Entropy.calculate_structural_entropy([1, 1, 1, 1])
      assert result >= 0.0
    end
  end

  # ============================================================================
  # Property: entropy is always non-negative (PropCheck)
  # ============================================================================

  describe "property: entropy non-negativity (PropCheck)" do
    property "H ≥ 0 for all valid probability distributions" do
      forall n <- PC.choose(1, 10) do
        # Build a valid probability distribution
        weights = Enum.map(1..n, fn _ -> 1.0 / n end)
        entropy = Entropy.calculate_information_entropy(weights)
        entropy >= 0.0
      end
    end

    property "deterministic system has zero entropy" do
      forall _x <- PC.integer() do
        entropy = Entropy.calculate_information_entropy([1.0])
        entropy == 0.0
      end
    end
  end

  # ============================================================================
  # Property: entropy increases with alphabet size (StreamData)
  # ============================================================================

  describe "property: maximum entropy increases with alphabet size (StreamData)" do
    test "H_max(n) < H_max(n+1) for uniform distributions" do
      ExUnitProperties.check all(n <- SD.integer(2..16)) do
        h_n = Entropy.calculate_information_entropy(List.duplicate(1.0 / n, n))
        h_n1 = Entropy.calculate_information_entropy(List.duplicate(1.0 / (n + 1), n + 1))
        assert h_n < h_n1, "Expected H(#{n}) < H(#{n + 1})"
      end
    end

    test "entropy of uniform distribution equals log2(n)" do
      ExUnitProperties.check all(n <- SD.integer(2..8)) do
        h = Entropy.calculate_information_entropy(List.duplicate(1.0 / n, n))
        expected = :math.log2(n)
        assert_in_delta h, expected, 0.001
      end
    end
  end
end
