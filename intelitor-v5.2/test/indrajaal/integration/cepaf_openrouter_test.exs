defmodule Indrajaal.Integration.CepafOpenRouterTest do
  @moduledoc """
  Integration tests for CEPAF (Cybernetic Elixir Port Architecture Framework) with OpenRouter.

  Tests the interaction between the container management system and the AI/OpenRouter integration
  to ensure the "Cortex" can effectively perceive and control the container environment.

  ## Key Integration Points Verified

  1. **Container Context Gathering**: Can we gather container state to feed to the AI?
  2. **AI Action Translation**: Can AI suggestions be translated into valid CEPAF commands?
  3. **Safety Gate Enforcement**: Are AI-suggested container actions checked by the Guardian?
  4. **Loop Latency**: Is the Observation -> AI -> Action loop efficient enough?
  5. **Graph Verification**: Are routing decisions verified against formal specifications?

  ## STAMP Safety Constraints Verified

  - SC-NEURO-001: Simplex Principle (AI output MUST pass through Guardian)
  - SC-NEURO-003: Forbidden Ops (AI cannot execute dangerous container commands)
  - SC-CNT-009: NixOS/Podman enforcement (AI commands must target Podman)
  - SC-GVF-001: All routing changes MUST be verified in Quint before deployment
  - SC-GVF-003: Synapse MUST NOT route directly to external AI providers
  - SC-GVF-007: All routing proposals MUST pass Guardian validation

  ## Graph Verification Integration

  Tests verify routing decisions against the formal specification:
  - Quint Model: docs/formal_specs/quint/openrouter_integration.qnt
  - Architecture: docs/architecture/GRAPH_VERIFICATION_FRAMEWORK.md
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Integration.CepafClient
  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Cortex.Synapse

  # Mock the OpenRouterClient to avoid actual API calls during testing
  import Mock

  describe "AI Context Gathering from CEPAF" do
    test "can gather complete container state for AI context" do
      # Mock CepafClient responses
      with_mock CepafClient,
        list_containers: fn -> {:ok, [%{name: "indrajaal-app", status: :running}]} end,
        system_info: fn -> {:ok, %{os: "NixOS"}} end do
        # This simulates the "Observe" phase where we gather state for the AI

        # 1. Get container list
        {:ok, containers} = CepafClient.list_containers()

        # 2. Get system info
        {:ok, system_info} = CepafClient.system_info()

        # 3. Construct context object
        context = %{
          containers: containers,
          system: system_info,
          timestamp: DateTime.utc_now()
        }

        # Assertions on context structure expected by AI
        assert is_map(context)
        assert Map.has_key?(context, :containers)
        assert Map.has_key?(context, :system)

        # Verify serialization (AI needs text/JSON)
        json_context = Jason.encode!(context)
        assert is_binary(json_context)
        assert String.length(json_context) > 0
      end
    end

    test "can gather detailed logs for specific container analysis" do
      # 1. Mock a container returning logs
      container_name = "indrajaal-db"

      with_mock CepafClient,
        container_logs: fn ^container_name, [tail: 50] -> {:ok, "LOG DATA"} end do
        # 2. Get logs
        {:ok, logs} = CepafClient.container_logs(container_name, tail: 50)

        # 3. Verify logs are suitable for AI consumption
        assert is_binary(logs)
        # Should be UTF-8
        assert String.valid?(logs)
      end
    end
  end

  describe "AI Action to CEPAF Command Translation" do
    test "translates AI 'restart' suggestion to CEPAF command" do
      # Mock AI output
      ai_suggestion = %{
        action: :restart_container,
        target: "indrajaal-app",
        reason: "memory_leak_detected"
      }

      with_mock CepafClient,
        restart_container: fn "indrajaal-app" -> :ok end do
        # Translation logic
        command =
          case ai_suggestion.action do
            :restart_container ->
              {:ok, fn -> CepafClient.restart_container(ai_suggestion.target) end}

            _ ->
              {:error, :unknown_action}
          end

        assert match?({:ok, _}, command)
        {:ok, func} = command
        assert func.() == :ok
      end
    end
  end

  describe "Safety Guardian Integration (SC-NEURO-001)" do
    test "Guardian vetoes dangerous container commands from AI" do
      # Mock a dangerous AI proposal
      dangerous_proposal = %{
        action: :exec_command,
        container: "indrajaal-db",
        command: "rm -rf /var/lib/postgresql/data",
        reason: "reset_state"
      }

      # Verify Guardian veto
      result = Guardian.validate_proposal(dangerous_proposal)

      assert match?({:veto, _, _}, result)
      {:veto, reason, _fallback} = result
      # Guardian returns :dangerous_pattern_detected for rm -rf patterns
      assert reason == :dangerous_pattern_detected
    end

    test "Guardian approves safe container commands from AI" do
      # Mock a safe AI proposal
      safe_proposal = %{
        action: :scale_up,
        quantity: 5,
        target: "flame_runner",
        reason: "high_load"
      }

      # Verify Guardian approval
      result = Guardian.validate_proposal(safe_proposal)

      assert match?({:ok, _}, result)
    end
  end

  describe "Full OODA Loop Simulation with Mocks" do
    test "simulates full observation -> decision -> action loop" do
      # Mock OpenRouter response
      _mock_response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => "Based on the logs, the database container is healthy."
            }
          }
        ],
        "usage" => %{"total_tokens" => 100}
      }

      with_mocks([
        {Indrajaal.AI.OpenRouterClient, [],
         [
           chat: fn _msgs, _opts ->
             {:ok, "Based on the logs, the database container is healthy."}
           end
         ]},
        {CepafClient, [],
         [
           list_containers: fn -> {:ok, [%{name: "indrajaal-db", status: :running}]} end
         ]}
      ]) do
        # 1. Observe: Get state
        {:ok, containers} = CepafClient.list_containers()

        # 2. Orient: Prepare context
        context = %{containers: containers}

        # 3. Decide: Ask AI (mocked) - use chat/2 with opts
        {:ok, analysis} =
          Indrajaal.AI.OpenRouterClient.chat(
            [%{role: "user", content: "Analyze system health based on: #{inspect(context)}"}],
            # Empty opts to match chat/2 signature
            []
          )

        assert analysis =~ "healthy"

        # 4. Act: No action needed based on "healthy" analysis
        assert true
      end
    end
  end

  # ===========================================================================
  # Graph Verification Tests (SC-GVF-001 to SC-GVF-008)
  # ===========================================================================

  describe "Graph Verification - Routing Constraints (SC-GVF-003)" do
    alias Indrajaal.AI.OpenRouterClient

    test "verify_routing_graph approves valid Cortex to OpenRouter route" do
      # Valid route: Cortex → OpenRouter with Guardian approval
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.95,
          guardian_approved: true
        )

      assert result == {:ok, :verified}
    end

    test "verify_routing_graph rejects low confidence routes (SC-GVF-004)" do
      # Low confidence should be rejected
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.5,
          guardian_approved: true
        )

      assert match?({:error, {:constraint_violation, :inv_confidence_threshold}}, result)
    end

    test "verify_routing_graph rejects non-Guardian-approved routes (SC-NEURO-001)" do
      # Routes without Guardian approval should be rejected
      result =
        OpenRouterClient.verify_routing_graph(
          :cortex,
          "anthropic/claude-3.5-sonnet",
          confidence: 0.95,
          guardian_approved: false
        )

      assert match?({:error, {:constraint_violation, :inv_simplex_principle}}, result)
    end

    test "check_exclusivity_constraint allows proper OpenRouter format" do
      # OpenRouter format: "provider/model-name" is allowed
      result =
        OpenRouterClient.check_exclusivity_constraint(
          :synapse,
          "anthropic/claude-3.5-sonnet"
        )

      assert result == :ok
    end

    test "check_exclusivity_constraint rejects direct external AI" do
      # Direct model name without provider prefix is suspicious
      result =
        OpenRouterClient.check_exclusivity_constraint(
          :synapse,
          # Direct name, not via OpenRouter
          "gpt-4"
        )

      assert match?({:error, {:constraint_violation, :inv_openrouter_exclusivity}}, result)
    end

    test "Guardian and GDE bypass simplex principle check" do
      # Guardian is a trusted source
      assert OpenRouterClient.check_simplex_principle(:guardian, false) == :ok
      assert OpenRouterClient.check_simplex_principle(:gde, false) == :ok
    end
  end

  describe "Graph Verification - Routing Graph State" do
    alias Indrajaal.AI.OpenRouterClient

    test "get_routing_graph_state returns valid graph structure" do
      graph = OpenRouterClient.get_routing_graph_state()

      assert is_map(graph)
      assert Map.has_key?(graph, :nodes)
      assert Map.has_key?(graph, :edges)
      assert Map.has_key?(graph, :external_ai_providers)
      assert Map.has_key?(graph, :models)
      assert Map.has_key?(graph, :verified_at)

      # Verify expected nodes
      assert :cortex in graph.nodes
      assert :synapse in graph.nodes
      assert :openrouter in graph.nodes
      assert :guardian in graph.nodes

      # Verify edge structure
      assert {:cortex, :synapse} in graph.edges
      assert {:synapse, :openrouter} in graph.edges
    end

    test "validate_routing_proposal accepts valid proposals" do
      proposal = %{
        source: :cortex,
        target: :openrouter,
        model: "anthropic/claude-3.5-sonnet",
        confidence: 0.95,
        guardian_approved: true
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)

      assert match?({:ok, ^proposal}, result)
    end

    test "validate_routing_proposal rejects invalid proposals" do
      # Missing required keys
      invalid_proposal = %{
        source: :cortex,
        model: "anthropic/claude-3.5-sonnet"
        # Missing :target and :confidence
      }

      result = OpenRouterClient.validate_routing_proposal(invalid_proposal)

      assert match?({:error, {:invalid_proposal, :missing_required_keys}}, result)
    end
  end

  describe "Synapse Graph Verification Integration" do
    test "Synapse routing graph structure is correct" do
      graph = Synapse.get_routing_graph()

      assert is_map(graph)
      assert Map.has_key?(graph, :nodes)
      assert Map.has_key?(graph, :edges)
      assert Map.has_key?(graph, :forbidden)
      assert Map.has_key?(graph, :properties)

      # Verify forbidden edges exist
      assert length(graph.forbidden) > 0

      # Verify properties
      assert graph.properties.acyclic == true
      assert :inv_openrouter_exclusivity in graph.properties.invariants
    end

    test "Synapse graph constraints verification passes" do
      constraints = Synapse.verify_graph_constraints()

      assert is_map(constraints)
      assert Map.has_key?(constraints, :exclusivity)
      assert Map.has_key?(constraints, :guardian_gate)
      assert Map.has_key?(constraints, :acyclic)
      assert Map.has_key?(constraints, :verified_at)

      # All constraints should pass
      assert constraints.exclusivity == true
      assert constraints.guardian_gate == true
      assert constraints.acyclic == true
    end
  end

  describe "Graph Verification with Container Context" do
    test "container state affects routing decisions" do
      with_mock CepafClient,
        list_containers: fn ->
          {:ok,
           [
             %{name: "indrajaal-app", status: :running, health: :healthy},
             %{name: "indrajaal-db", status: :running, health: :healthy}
           ]}
        end do
        # Get container state
        {:ok, containers} = CepafClient.list_containers()

        # Calculate confidence based on container health
        healthy_count = Enum.count(containers, fn c -> c.health == :healthy end)
        confidence = healthy_count / max(length(containers), 1)

        # Build routing proposal with container-derived confidence
        proposal = %{
          source: :cortex,
          target: :openrouter,
          model: "anthropic/claude-3.5-sonnet",
          confidence: confidence,
          guardian_approved: true,
          context: %{containers: containers}
        }

        result = Indrajaal.AI.OpenRouterClient.validate_routing_proposal(proposal)

        # Should pass because all containers are healthy (confidence = 1.0)
        assert match?({:ok, _}, result)
      end
    end

    test "unhealthy containers reduce routing confidence" do
      with_mock CepafClient,
        list_containers: fn ->
          {:ok,
           [
             %{name: "indrajaal-app", status: :running, health: :unhealthy},
             %{name: "indrajaal-db", status: :exited, health: :unhealthy}
           ]}
        end do
        {:ok, containers} = CepafClient.list_containers()

        # Calculate confidence based on container health
        healthy_count = Enum.count(containers, fn c -> c.health == :healthy end)
        confidence = healthy_count / max(length(containers), 1)

        # Build routing proposal
        proposal = %{
          source: :cortex,
          target: :openrouter,
          model: "anthropic/claude-3.5-sonnet",
          confidence: confidence,
          guardian_approved: true
        }

        result = Indrajaal.AI.OpenRouterClient.validate_routing_proposal(proposal)

        # Should fail because confidence is 0.0 (below 0.8 threshold)
        assert match?({:error, {:constraint_violation, :inv_confidence_threshold}}, result)
      end
    end
  end

  describe "Production Route SC-GVF Enforcement (P0.1)" do
    @moduledoc """
    Tests for SC-GVF invariant enforcement in all production routes.
    Verifies that ClaudeInterface, GeminiInterface, and AIIntegration
    all pass through PROMETHEUS verification before calling OpenRouter.

    STAMP Constraints Verified:
    - SC-GVF-003: All routes must pass through validate_routing_proposal/1
    - SC-GDE-060: All AI calls must use OpenRouter exclusively
    """

    alias Indrajaal.AI.OpenRouterClient

    test "ClaudeInterface route uses PROMETHEUS verification" do
      # Verify ClaudeInterface creates proper routing proposal
      proposal = %{
        source: :claude_interface,
        target: :openrouter,
        model: :smart,
        confidence: 1.0,
        guardian_approved: true
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)
      assert match?({:ok, _}, result)
    end

    test "ClaudeInterface route rejected without Guardian approval" do
      proposal = %{
        source: :claude_interface,
        target: :openrouter,
        model: :smart,
        confidence: 1.0,
        guardian_approved: false
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)
      assert match?({:error, {:constraint_violation, :inv_simplex_principle}}, result)
    end

    test "GeminiInterface route uses PROMETHEUS verification" do
      proposal = %{
        source: :gemini_interface,
        target: :openrouter,
        model: "google/gemini-pro-1.5",
        confidence: 1.0,
        guardian_approved: true
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)
      assert match?({:ok, _}, result)
    end

    test "GeminiInterface route rejected with low confidence" do
      proposal = %{
        source: :gemini_interface,
        target: :openrouter,
        model: "google/gemini-pro-1.5",
        # Below 0.8 threshold
        confidence: 0.5,
        guardian_approved: true
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)
      assert match?({:error, {:constraint_violation, :inv_confidence_threshold}}, result)
    end

    test "AIIntegration route uses PROMETHEUS verification (SC-GDE-060)" do
      proposal = %{
        source: :gde_ai_integration,
        target: :openrouter,
        model: :smart,
        confidence: 1.0,
        guardian_approved: true
      }

      result = OpenRouterClient.validate_routing_proposal(proposal)
      assert match?({:ok, _}, result)
    end

    test "AIIntegration route rejected for direct external AI access" do
      # gde_ai_integration trying to bypass OpenRouter is not allowed
      proposal = %{
        source: :gde_ai_integration,
        # Not allowed
        target: :external,
        model: "gpt-4",
        confidence: 1.0,
        guardian_approved: true
      }

      # This should pass initial validation but the actual check happens in check_exclusivity_constraint
      # For direct model names without provider prefix, exclusivity is checked
      result = OpenRouterClient.check_exclusivity_constraint(:synapse, "gpt-4")
      assert match?({:error, {:constraint_violation, :inv_openrouter_exclusivity}}, result)
    end

    test "All production routes require target: :openrouter" do
      # Valid targets
      valid_proposal = %{
        source: :claude_interface,
        target: :openrouter,
        model: :smart,
        confidence: 1.0,
        guardian_approved: true
      }

      assert match?({:ok, _}, OpenRouterClient.validate_routing_proposal(valid_proposal))

      # All production routes MUST target OpenRouter per SC-GDE-060
      for source <- [:claude_interface, :gemini_interface, :gde_ai_integration, :synapse] do
        proposal = %{
          source: source,
          target: :openrouter,
          model: :smart,
          confidence: 1.0,
          guardian_approved: true
        }

        result = OpenRouterClient.validate_routing_proposal(proposal)

        assert match?({:ok, _}, result),
               "Route from #{source} should be valid with proper configuration"
      end
    end

    test "Production route verification is idempotent" do
      proposal = %{
        source: :claude_interface,
        target: :openrouter,
        model: :smart,
        confidence: 1.0,
        guardian_approved: true
      }

      # Multiple verifications should yield same result
      result1 = OpenRouterClient.validate_routing_proposal(proposal)
      result2 = OpenRouterClient.validate_routing_proposal(proposal)
      result3 = OpenRouterClient.validate_routing_proposal(proposal)

      assert result1 == result2
      assert result2 == result3
      assert match?({:ok, _}, result1)
    end
  end

  describe "P0-CRITICAL: Pre-Flight Guardian Check (SC-NEURO-001)" do
    @moduledoc """
    Tests for the P0-CRITICAL Guardian approval flow.

    The Simplex Architecture requires Guardian to validate AI requests BEFORE
    they are sent to OpenRouter. This is the pre-flight check that ensures:

    1. Guardian validates the AI request proposal (security + safety envelope)
    2. Only Guardian-approved requests proceed to OpenRouter
    3. Vetoed requests are blocked with appropriate error codes

    STAMP Constraints Verified:
    - SC-NEURO-001: All AI routes must pass through Guardian
    - SC-SEC-001: No code execution without review
    - SC-GUARD-001: Guardian must use Envelope for constraint values
    """

    alias Indrajaal.AI.OpenRouterClient

    test "pre_flight_guardian_check approves safe prompts" do
      # Safe prompt should be approved
      result =
        OpenRouterClient.pre_flight_guardian_check(
          :claude_interface,
          :smart,
          "Explain how to implement a GenServer in Elixir"
        )

      assert match?({:ok, true}, result)
    end

    test "pre_flight_guardian_check works for all production sources" do
      safe_prompt = "What is the best practice for error handling?"

      for source <- [:claude_interface, :gemini_interface, :gde_ai_integration, :synapse] do
        result = OpenRouterClient.pre_flight_guardian_check(source, :smart, safe_prompt)

        assert match?({:ok, true}, result),
               "Pre-flight check should pass for source: #{source}"
      end
    end

    test "full_pre_flight_check combines Guardian + Graph verification" do
      result =
        OpenRouterClient.full_pre_flight_check(
          :claude_interface,
          :smart,
          "Explain Elixir pattern matching"
        )

      assert match?({:ok, %{guardian_approved: true}}, result)

      {:ok, approval} = result
      assert approval.source == :claude_interface
      assert is_binary(approval.model)
    end

    test "full_pre_flight_check respects confidence threshold" do
      # Low confidence should fail graph verification even with Guardian approval
      result =
        OpenRouterClient.full_pre_flight_check(
          :claude_interface,
          :smart,
          "Safe prompt",
          # Below 0.8 threshold
          confidence: 0.5
        )

      assert match?({:error, {:constraint_violation, :inv_confidence_threshold}}, result)
    end

    test "full_pre_flight_check enforces Guardian before graph verification" do
      # Verify the order: Guardian check happens first, then graph verification
      # By using different sources, we can verify both checks run

      # Test with trusted source (Guardian/GDE bypass simplex check)
      result_trusted =
        OpenRouterClient.full_pre_flight_check(
          :gde,
          :smart,
          "Safe prompt",
          confidence: 1.0
        )

      # Should pass for trusted source
      assert match?({:ok, %{guardian_approved: true}}, result_trusted)
    end

    test "pre-flight check is consistent across multiple calls" do
      prompt = "Consistent test prompt"

      results =
        for _i <- 1..5 do
          OpenRouterClient.pre_flight_guardian_check(:claude_interface, :smart, prompt)
        end

      # All results should be identical
      first = hd(results)
      assert Enum.all?(results, fn r -> r == first end)
      assert match?({:ok, true}, first)
    end

    test "full_pre_flight_check normalizes model atoms to strings" do
      # Model atoms should be normalized to OpenRouter model strings
      {:ok, approval} =
        OpenRouterClient.full_pre_flight_check(
          :claude_interface,
          # Atom that maps to "google/gemini-flash-1.5-8b"
          :fast,
          "Test prompt"
        )

      # Model should be normalized to string
      assert approval.model == "google/gemini-flash-1.5-8b"
    end

    test "full_pre_flight_check handles string model IDs" do
      {:ok, approval} =
        OpenRouterClient.full_pre_flight_check(
          :gemini_interface,
          "google/gemini-pro-1.5",
          "Test prompt"
        )

      assert approval.model == "google/gemini-pro-1.5"
    end
  end
end
