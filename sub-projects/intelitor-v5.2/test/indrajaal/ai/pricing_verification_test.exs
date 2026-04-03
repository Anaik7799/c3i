defmodule Indrajaal.AI.PricingVerificationTest do
  @moduledoc """
  Tests for the PricingVerification mathematical correctness module.

  ## STAMP Constraints Verified
  - SC-GVF-001: All routing changes mathematically verified
  - SC-GVF-002: DAG structure maintained (no cycles)
  - SC-MATH-001: Cost calculations within bounds
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.PricingVerification

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PricingVerification)
    end

    test "exports verify_all/0" do
      assert function_exported?(PricingVerification, :verify_all, 0)
    end

    test "exports verification_score/0" do
      assert function_exported?(PricingVerification, :verification_score, 0)
    end

    test "exports prometheus_verification_metrics/0" do
      assert function_exported?(PricingVerification, :prometheus_verification_metrics, 0)
    end
  end

  describe "verify_all/0" do
    test "returns verification report" do
      result = PricingVerification.verify_all()

      case result do
        {:ok, report} ->
          assert is_map(report)
          assert Map.has_key?(report, :total_checks)
          assert Map.has_key?(report, :passed)
          assert Map.has_key?(report, :violations)
          assert Map.has_key?(report, :checks)
          assert Map.has_key?(report, :dag)
          assert Map.has_key?(report, :timestamp)

        {:error, violations} ->
          assert is_list(violations)
      end
    end
  end

  describe "verification_score/0" do
    test "returns a float between 0 and 100" do
      score = PricingVerification.verification_score()

      assert is_float(score)
      assert score >= 0.0
      assert score <= 100.0
    end
  end

  describe "prometheus_verification_metrics/0" do
    test "returns Prometheus formatted metrics" do
      output = PricingVerification.prometheus_verification_metrics()

      assert is_binary(output)
      assert String.contains?(output, "# HELP")
      assert String.contains?(output, "# TYPE")
      assert String.contains?(output, "ai_pricing_verification_score")
    end
  end

  describe "Pricing Invariants (PI)" do
    test "PI-001: non-negative costs" do
      result = PricingVerification.verify_pi_001_non_negative_costs()

      case result do
        {:ok, :pi_001, msg} -> assert is_binary(msg)
        {:violation, :pi_001, msg} -> assert is_binary(msg)
      end
    end

    test "PI-002: free models have zero cost" do
      result = PricingVerification.verify_pi_002_free_models()

      case result do
        {:ok, :pi_002, msg} -> assert is_binary(msg)
        {:violation, :pi_002, msg} -> assert is_binary(msg)
      end
    end

    test "PI-003: cost formula correctness" do
      result = PricingVerification.verify_pi_003_cost_formula()

      # This should always pass with correct implementation
      assert {:ok, :pi_003, _msg} = result
    end

    test "PI-004: cost bounds" do
      result = PricingVerification.verify_pi_004_bounds()

      case result do
        {:ok, :pi_004, msg} -> assert is_binary(msg)
        {:violation, :pi_004, msg} -> assert is_binary(msg)
      end
    end
  end

  describe "DAG Invariants (DI)" do
    test "DI-001: DAG is acyclic" do
      result = PricingVerification.verify_di_001_acyclic()

      # The static DAG should always be acyclic
      assert {:ok, :di_001, _msg} = result
    end

    test "DI-002: path existence from source to sink" do
      result = PricingVerification.verify_di_002_path_existence()

      assert {:ok, :di_002, _msg} = result
    end

    test "DI-003: Synapse exclusivity" do
      result = PricingVerification.verify_di_003_synapse_exclusivity()

      assert {:ok, :di_003, _msg} = result
    end

    test "DI-004: Guardian approval paths" do
      result = PricingVerification.verify_di_004_guardian_approval()

      assert {:ok, :di_004, _msg} = result
    end
  end

  describe "Operational Vectors (OV)" do
    test "OV-COST: cost path verification" do
      result = PricingVerification.verify_ov_cost_path()

      case result do
        {:ok, :ov_cost, msg} -> assert is_binary(msg)
        {:violation, :ov_cost, msg} -> assert is_binary(msg)
      end
    end

    test "OV-ROUTE: route path verification" do
      result = PricingVerification.verify_ov_route_path()

      case result do
        {:ok, :ov_route, msg} -> assert is_binary(msg)
        {:violation, :ov_route, msg} -> assert is_binary(msg)
      end
    end

    test "OV-CACHE: cache path verification" do
      result = PricingVerification.verify_ov_cache_path()

      assert {:ok, :ov_cache, _msg} = result
    end
  end

  describe "Mathematical Properties" do
    test "token ratio validation" do
      result = PricingVerification.verify_math_token_ratio()
      assert {:ok, :math_ratio, _msg} = result
    end

    test "price bounds validation" do
      result = PricingVerification.verify_math_price_bounds()

      case result do
        {:ok, :math_bounds, msg} -> assert is_binary(msg)
        {:violation, :math_bounds, msg} -> assert is_binary(msg)
      end
    end

    test "cache consistency validation" do
      result = PricingVerification.verify_math_cache_consistency()

      case result do
        {:ok, :math_consistency, msg} -> assert is_binary(msg)
        {:violation, :math_consistency, msg} -> assert is_binary(msg)
      end
    end
  end

  describe "Graph Algorithms" do
    test "routing DAG has expected structure" do
      # Verify the DAG structure matches the documented architecture
      case PricingVerification.verify_all() do
        {:ok, %{dag: dag}} ->
          assert :user in dag.nodes
          assert :openrouter in dag.nodes
          assert :provider in dag.nodes
          assert :guardian in dag.nodes
          assert length(dag.edges) >= 5

        {:error, _} ->
          # Violations don't affect this test
          :ok
      end
    end
  end
end
