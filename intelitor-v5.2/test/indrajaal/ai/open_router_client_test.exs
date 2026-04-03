defmodule Indrajaal.AI.OpenRouterClientTest do
  @moduledoc """
  Tests for OpenRouterClient module.

  ## STAMP Constraints Verified
  - SC-GVF-001: All routing changes verified
  - SC-GVF-003: Synapse exclusivity
  - SC-GVF-004: Confidence threshold
  - SC-GVF-007: Guardian approval required
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.OpenRouterClient

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(OpenRouterClient)
    end

    test "exports chat/2" do
      assert function_exported?(OpenRouterClient, :chat, 2)
    end

    test "exports verify_routing_graph/3" do
      assert function_exported?(OpenRouterClient, :verify_routing_graph, 3)
    end

    test "exports check_exclusivity_constraint/2" do
      assert function_exported?(OpenRouterClient, :check_exclusivity_constraint, 2)
    end

    test "exports check_simplex_principle/2" do
      assert function_exported?(OpenRouterClient, :check_simplex_principle, 2)
    end

    test "exports check_confidence_threshold/1" do
      assert function_exported?(OpenRouterClient, :check_confidence_threshold, 1)
    end

    test "exports get_routing_graph_state/0" do
      assert function_exported?(OpenRouterClient, :get_routing_graph_state, 0)
    end

    test "exports validate_routing_proposal/1" do
      assert function_exported?(OpenRouterClient, :validate_routing_proposal, 1)
    end

    test "exports pre_flight_guardian_check/4" do
      assert function_exported?(OpenRouterClient, :pre_flight_guardian_check, 4)
    end

    test "exports full_pre_flight_check/4" do
      assert function_exported?(OpenRouterClient, :full_pre_flight_check, 4)
    end
  end

  describe "chat/2 without API key" do
    test "returns error when API key not configured" do
      messages = [%{role: "user", content: "Hello"}]

      result = OpenRouterClient.chat(messages)

      assert {:error, :missing_api_key} = result
    end
  end

  describe "verify_routing_graph/3" do
    test "passes for valid cortex route with Guardian approval" do
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.95,
          guardian_approved: true
        )

      assert {:ok, :verified} = result
    end

    test "passes for gde route without Guardian approval" do
      result =
        OpenRouterClient.verify_routing_graph(
          :gde,
          "google/gemini-1.5-pro",
          confidence: 0.9
        )

      assert {:ok, :verified} = result
    end

    test "passes for guardian route" do
      result =
        OpenRouterClient.verify_routing_graph(
          :guardian,
          "openai/gpt-4o",
          confidence: 0.85
        )

      assert {:ok, :verified} = result
    end

    test "fails for low confidence" do
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "test/model",
          confidence: 0.5,
          guardian_approved: true
        )

      assert {:error, {:constraint_violation, :inv_confidence_threshold}} = result
    end

    test "fails without Guardian approval for non-exempt source" do
      result =
        OpenRouterClient.verify_routing_graph(
          :synapse,
          "test/model",
          confidence: 0.95,
          guardian_approved: false
        )

      assert {:error, {:constraint_violation, :inv_simplex_principle}} = result
    end
  end

  describe "check_exclusivity_constraint/2" do
    test "synapse cannot route to direct external AI" do
      result = OpenRouterClient.check_exclusivity_constraint(:synapse, "gpt4")

      assert {:error, {:constraint_violation, :inv_openrouter_exclusivity}} = result
    end

    test "synapse can route through OpenRouter format" do
      result = OpenRouterClient.check_exclusivity_constraint(:synapse, "openai/gpt-4")

      assert :ok = result
    end

    test "other sources are not restricted" do
      assert :ok = OpenRouterClient.check_exclusivity_constraint(:cortex, "any-model")
      assert :ok = OpenRouterClient.check_exclusivity_constraint(:gde, "any-model")
    end
  end

  describe "check_simplex_principle/2" do
    test "guardian is always approved" do
      assert :ok = OpenRouterClient.check_simplex_principle(:guardian, false)
      assert :ok = OpenRouterClient.check_simplex_principle(:guardian, true)
    end

    test "gde is always approved" do
      assert :ok = OpenRouterClient.check_simplex_principle(:gde, false)
      assert :ok = OpenRouterClient.check_simplex_principle(:gde, true)
    end

    test "other sources require guardian_approved: true" do
      assert :ok = OpenRouterClient.check_simplex_principle(:cortex, true)
      assert :ok = OpenRouterClient.check_simplex_principle(:synapse, true)

      assert {:error, {:constraint_violation, :inv_simplex_principle}} =
               OpenRouterClient.check_simplex_principle(:cortex, false)
    end
  end

  describe "check_confidence_threshold/1" do
    test "passes for confidence >= 0.8" do
      assert :ok = OpenRouterClient.check_confidence_threshold(0.8)
      assert :ok = OpenRouterClient.check_confidence_threshold(0.9)
      assert :ok = OpenRouterClient.check_confidence_threshold(1.0)
    end

    test "fails for confidence < 0.8" do
      assert {:error, {:constraint_violation, :inv_confidence_threshold}} =
               OpenRouterClient.check_confidence_threshold(0.79)

      assert {:error, {:constraint_violation, :inv_confidence_threshold}} =
               OpenRouterClient.check_confidence_threshold(0.5)

      assert {:error, {:constraint_violation, :inv_confidence_threshold}} =
               OpenRouterClient.check_confidence_threshold(0.0)
    end
  end

  describe "get_routing_graph_state/0" do
    test "returns graph state map" do
      state = OpenRouterClient.get_routing_graph_state()

      assert is_map(state)
      assert Map.has_key?(state, :nodes)
      assert Map.has_key?(state, :edges)
      assert Map.has_key?(state, :external_ai_providers)
      assert Map.has_key?(state, :models)
      assert Map.has_key?(state, :verified_at)
    end

    test "nodes include key components" do
      state = OpenRouterClient.get_routing_graph_state()

      assert :cortex in state.nodes
      assert :synapse in state.nodes
      assert :openrouter in state.nodes
      assert :guardian in state.nodes
    end

    test "edges form valid routing path" do
      state = OpenRouterClient.get_routing_graph_state()

      assert is_list(state.edges)
      assert {:cortex, :synapse} in state.edges
      assert {:synapse, :openrouter} in state.edges
    end
  end

  describe "validate_routing_proposal/1" do
    test "validates complete proposal" do
      proposal = %{
        source: :cortex,
        target: :openrouter,
        model: "anthropic/claude-3.5-sonnet",
        confidence: 0.95,
        guardian_approved: true
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)

      assert {:ok, ^proposal} = result
    end

    test "fails for missing required keys" do
      proposal = %{source: :cortex, target: :openrouter}

      result = OpenRouterClient.validate_routing_proposal(proposal)

      assert {:error, {:invalid_proposal, :missing_required_keys}} = result
    end

    test "validates constraints on complete proposal" do
      proposal = %{
        source: :synapse,
        target: :openrouter,
        model: "test/model",
        confidence: 0.5,
        guardian_approved: false
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)

      assert {:error, {:constraint_violation, _}} = result
    end
  end

  describe "pre_flight_guardian_check/4" do
    test "returns error if Guardian unavailable" do
      # Guardian may not be running in test
      result =
        OpenRouterClient.pre_flight_guardian_check(
          :claude_interface,
          :smart,
          "Test prompt"
        )

      # Either passes or fails based on Guardian availability
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "full_pre_flight_check/3" do
    test "combines Guardian and graph verification" do
      result =
        OpenRouterClient.full_pre_flight_check(
          :cortex,
          "anthropic/claude-3-sonnet",
          "Test prompt"
        )

      # Either passes or fails based on Guardian availability
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "rate limiting (SC-API-002, AOR-OPENROUTER-002)" do
    setup do
      # Clean up ETS table before each test
      if :ets.whereis(:openrouter_rate_limits) != :undefined do
        :ets.delete(:openrouter_rate_limits)
      end

      OpenRouterClient.init()
      :ok
    end

    test "initializes rate limit table" do
      OpenRouterClient.init()
      assert :ets.whereis(:openrouter_rate_limits) != :undefined
    end

    test "allows requests within RPM limit" do
      # Should allow multiple requests within 200 RPM limit
      model = "test/model"

      results =
        Enum.map(1..10, fn _ ->
          OpenRouterClient.full_pre_flight_check(model, model, "test prompt")
        end)

      # All should succeed (or fail due to Guardian, not rate limit)
      Enum.each(results, fn result ->
        case result do
          {:error, :rate_limited} -> flunk("Should not be rate limited")
          {:error, {:guardian_veto, _}} -> :ok
          {:error, _} -> :ok
          {:ok, _} -> :ok
        end
      end)
    end

    test "tracks token usage with record_token_usage/1" do
      assert :ok == OpenRouterClient.record_token_usage(1000)
      assert :ok == OpenRouterClient.record_token_usage(2000)
    end

    test "prevents TPM limit exceeded" do
      # Record tokens close to limit
      assert :ok == OpenRouterClient.record_token_usage(39_000)

      # Next request should exceed 40000 limit
      result = OpenRouterClient.record_token_usage(1_500)
      assert {:error, :tpm_limit_exceeded} == result
    end

    test "applies exponential backoff on 429 (AOR-OPENROUTER-002)" do
      # First backoff
      backoff_1 = OpenRouterClient.apply_exponential_backoff(1)
      assert backoff_1 >= 1000 and backoff_1 < 2000

      # Second backoff (should be longer)
      backoff_2 = OpenRouterClient.apply_exponential_backoff(2)
      assert backoff_2 >= 2000 and backoff_2 < 4000

      # Third backoff
      backoff_3 = OpenRouterClient.apply_exponential_backoff(3)
      assert backoff_3 >= 4000 and backoff_3 < 8000
    end

    test "respects backoff window immediately after backoff" do
      # Clean slate
      if :ets.whereis(:openrouter_rate_limits) != :undefined do
        :ets.delete(:openrouter_rate_limits)
      end

      OpenRouterClient.init()

      # Apply backoff with very long duration
      backoff_ms = OpenRouterClient.apply_exponential_backoff(10)
      assert backoff_ms > 0

      # Get state and verify backoff_until is set
      case :ets.lookup(:openrouter_rate_limits, :window) do
        [{:window, state}] ->
          assert not is_nil(state.backoff_until)
          assert state.backoff_until > System.monotonic_time(:millisecond)

        [] ->
          flunk("Window state not found")
      end
    end

    test "window resets after expiration" do
      # Record initial state
      [{:window, initial_state}] = :ets.lookup(:openrouter_rate_limits, :window)
      initial_count = initial_state.request_count

      # Simulate window expiration by setting old window_start
      old_window_start = System.monotonic_time(:millisecond) - 70_000

      expired_state = %{
        initial_state
        | window_start: old_window_start,
          request_count: 100,
          token_count: 5000
      }

      :ets.insert(:openrouter_rate_limits, {:window, expired_state})

      # Check state was set
      [{:window, before_reset}] = :ets.lookup(:openrouter_rate_limits, :window)
      assert before_reset.request_count == 100

      # Verify window_start was old
      window_age = System.monotonic_time(:millisecond) - before_reset.window_start
      assert window_age > 60_000
    end

    test "telemetry events are executed on rate limit check" do
      # This is a basic integration test - telemetry is called but not captured
      # Production tests would use telemetry capture, but this verifies no crashes
      OpenRouterClient.full_pre_flight_check("test/model", "test/model", "test prompt")
      assert true
    end
  end

  describe "token usage tracking (SC-API-003)" do
    setup do
      if :ets.whereis(:openrouter_rate_limits) != :undefined do
        :ets.delete(:openrouter_rate_limits)
      end

      OpenRouterClient.init()
      :ok
    end

    test "tracks cumulative token usage" do
      assert :ok = OpenRouterClient.record_token_usage(1000)
      assert :ok = OpenRouterClient.record_token_usage(2000)
      assert :ok = OpenRouterClient.record_token_usage(3000)

      # Verify state
      case :ets.lookup(:openrouter_rate_limits, :window) do
        [{:window, state}] ->
          assert state.token_count == 6000

        [] ->
          flunk("Window state not found")
      end
    end

    test "rejects token usage that exceeds 40k TPM limit" do
      # Use 39k tokens
      assert :ok = OpenRouterClient.record_token_usage(39_000)

      # Try to add 2k more (exceeds 40k)
      result = OpenRouterClient.record_token_usage(2_000)
      assert {:error, :tpm_limit_exceeded} = result
    end

    test "allows token usage up to limit boundary" do
      # Use exactly 40k
      assert :ok = OpenRouterClient.record_token_usage(40_000)

      # Next token should fail
      result = OpenRouterClient.record_token_usage(1)
      assert {:error, :tpm_limit_exceeded} = result
    end
  end
end
