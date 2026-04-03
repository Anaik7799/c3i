defmodule Indrajaal.AI.Security.TwoKeyTurnTest do
  @moduledoc """
  Tests for the TwoKeyTurn module.

  ## STAMP Constraints Verified
  - SC-SEC-AI-001: Two-key authorization for high-risk ops
  - SC-NEURO-001: Guardian approval required
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.Security.TwoKeyTurn

  describe "requires_two_key?/1" do
    test "requires two key for high cost requests" do
      proposal = %{estimated_cost_usd: 1.50}
      assert TwoKeyTurn.requires_two_key?(proposal)
    end

    test "requires two key for expensive models" do
      proposal = %{model: "openai/o1-preview", estimated_cost_usd: 0.10}
      assert TwoKeyTurn.requires_two_key?(proposal)
    end

    test "requires two key for claude-3-opus" do
      proposal = %{model: "anthropic/claude-3-opus", estimated_cost_usd: 0.10}
      assert TwoKeyTurn.requires_two_key?(proposal)
    end

    test "requires two key for reason intent" do
      proposal = %{intent: :reason, estimated_cost_usd: 0.10}
      assert TwoKeyTurn.requires_two_key?(proposal)
    end

    test "requires two key for high token count" do
      proposal = %{
        estimated_input_tokens: 8000,
        estimated_output_tokens: 3000,
        estimated_cost_usd: 0.10
      }

      assert TwoKeyTurn.requires_two_key?(proposal)
    end

    test "does not require two key for normal requests" do
      proposal = %{
        model: "google/gemini-flash-1.5",
        intent: :triage,
        estimated_cost_usd: 0.01,
        estimated_input_tokens: 100,
        estimated_output_tokens: 200
      }

      refute TwoKeyTurn.requires_two_key?(proposal)
    end
  end

  describe "authorize/2" do
    test "authorizes system-initiated requests" do
      proposal = %{
        request_id: "test-123",
        guardian_approved: true
      }

      context = %{
        source: :guardian,
        actor: nil
      }

      assert {:ok, :authorized} = TwoKeyTurn.authorize(proposal, context)
    end

    test "authorizes actor with correct permission" do
      proposal = %{
        request_id: "test-123",
        intent: :synthesize,
        guardian_approved: true
      }

      context = %{
        actor: %{permissions: [:ai_standard]}
      }

      assert {:ok, :authorized} = TwoKeyTurn.authorize(proposal, context)
    end

    test "rejects without guardian approval" do
      proposal = %{
        request_id: "test-123",
        intent: :synthesize,
        guardian_approved: false
      }

      context = %{
        actor: %{permissions: [:ai_advanced, :admin]}
      }

      assert {:error, :system_not_authorized} = TwoKeyTurn.authorize(proposal, context)
    end

    test "rejects actor without permission" do
      proposal = %{
        request_id: "test-123",
        # Requires ai_advanced
        intent: :reason,
        guardian_approved: true
      }

      context = %{
        actor: %{permissions: [:ai_basic]}
      }

      assert {:error, {:actor_not_authorized, :ai_advanced}} =
               TwoKeyTurn.authorize(proposal, context)
    end

    test "rejects missing actor for non-system requests" do
      proposal = %{
        request_id: "test-123",
        guardian_approved: true
      }

      context = %{
        source: :web,
        actor: nil,
        actor_id: nil
      }

      assert {:error, :no_actor} = TwoKeyTurn.authorize(proposal, context)
    end
  end

  describe "intent_to_permission/1" do
    test "maps triage to ai_basic" do
      assert TwoKeyTurn.intent_to_permission(:triage) == :ai_basic
    end

    test "maps analyze to ai_standard" do
      assert TwoKeyTurn.intent_to_permission(:analyze) == :ai_standard
    end

    test "maps synthesize to ai_standard" do
      assert TwoKeyTurn.intent_to_permission(:synthesize) == :ai_standard
    end

    test "maps reason to ai_advanced" do
      assert TwoKeyTurn.intent_to_permission(:reason) == :ai_advanced
    end

    test "maps unknown to ai_basic" do
      assert TwoKeyTurn.intent_to_permission(:unknown) == :ai_basic
    end
  end

  describe "has_permission?/2" do
    test "admin has all permissions" do
      actor = %{permissions: [:admin]}

      assert TwoKeyTurn.has_permission?(actor, :ai_basic)
      assert TwoKeyTurn.has_permission?(actor, :ai_standard)
      assert TwoKeyTurn.has_permission?(actor, :ai_advanced)
    end

    test "ai_advanced implies lower permissions" do
      actor = %{permissions: [:ai_advanced]}

      assert TwoKeyTurn.has_permission?(actor, :ai_basic)
      assert TwoKeyTurn.has_permission?(actor, :ai_standard)
      assert TwoKeyTurn.has_permission?(actor, :ai_advanced)
    end

    test "ai_standard implies ai_basic" do
      actor = %{permissions: [:ai_standard]}

      assert TwoKeyTurn.has_permission?(actor, :ai_basic)
      assert TwoKeyTurn.has_permission?(actor, :ai_standard)
      refute TwoKeyTurn.has_permission?(actor, :ai_advanced)
    end

    test "ai_basic only allows ai_basic" do
      actor = %{permissions: [:ai_basic]}

      assert TwoKeyTurn.has_permission?(actor, :ai_basic)
      refute TwoKeyTurn.has_permission?(actor, :ai_standard)
      refute TwoKeyTurn.has_permission?(actor, :ai_advanced)
    end

    test "nil actor has no permissions" do
      refute TwoKeyTurn.has_permission?(nil, :ai_basic)
    end
  end
end
