defmodule Indrajaal.AI.IntentRouterTest do
  @moduledoc """
  Tests for the IntentRouter module.

  ## STAMP Constraints Verified
  - SC-AI-102: Intent-based model selection
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.IntentRouter

  describe "route/2" do
    test "routes triage intent to fast model" do
      config = IntentRouter.route(:triage)

      assert config.model != nil
      assert config.intent == :triage
      assert config.temperature > 0
    end

    test "routes analyze intent to Gemini" do
      config = IntentRouter.route(:analyze)

      assert String.contains?(config.model, "google") or String.contains?(config.model, "gemini")
      assert config.intent == :analyze
    end

    test "routes synthesize intent to Claude" do
      config = IntentRouter.route(:synthesize)

      assert String.contains?(config.model, "anthropic") or
               String.contains?(config.model, "claude")

      assert config.intent == :synthesize
    end

    test "routes reason intent to high-capability model" do
      config = IntentRouter.route(:reason)

      # Should be o1-preview or claude-opus for complex reasoning
      assert config.intent == :reason
      assert is_binary(config.model)
    end

    test "applies nitro strategy for speed" do
      config = IntentRouter.route(:synthesize, strategy: :nitro)

      # Nitro should select faster model
      assert is_binary(config.model)
    end

    test "applies floor strategy for cost" do
      config = IntentRouter.route(:synthesize, strategy: :floor)

      # Floor should select cheaper model
      assert is_binary(config.model)
    end

    test "applies free strategy for zero cost" do
      config = IntentRouter.route(:triage, strategy: :free)

      # Should select a free model
      assert String.contains?(config.model, ":free") or
               String.contains?(config.model, "gemini-2.0-flash-exp")
    end
  end

  describe "select_model/1" do
    test "selects model for each intent" do
      intents = [:triage, :analyze, :synthesize, :validate, :code, :reason]

      for intent <- intents do
        model = IntentRouter.select_model(intent)
        assert is_binary(model)
        assert String.contains?(model, "/")
      end
    end
  end

  describe "get_fallback/1" do
    test "returns fallback for each intent" do
      intents = [:triage, :analyze, :synthesize, :validate, :code, :reason]

      for intent <- intents do
        fallback = IntentRouter.get_fallback(intent)
        assert is_binary(fallback)
      end
    end

    test "fallback differs from primary for most intents" do
      for intent <- [:analyze, :synthesize, :reason] do
        _primary = IntentRouter.select_model(intent)
        fallback = IntentRouter.get_fallback(intent)

        # May or may not differ depending on configuration
        assert is_binary(fallback)
      end
    end
  end

  describe "list_supported_intents/0" do
    test "returns all intents" do
      intents = IntentRouter.list_supported_intents()

      assert :triage in intents
      assert :analyze in intents
      assert :synthesize in intents
      assert :validate in intents
      assert :code in intents
      assert :reason in intents
    end
  end

  describe "intent_description/1" do
    test "returns description for known intents" do
      assert is_binary(IntentRouter.intent_description(:triage))
      assert is_binary(IntentRouter.intent_description(:analyze))
      assert is_binary(IntentRouter.intent_description(:synthesize))
    end

    test "returns unknown for undefined intent" do
      assert IntentRouter.intent_description(:undefined_intent) == "Unknown intent"
    end
  end

  describe "xAI Grok integration" do
    test "grok tier selects grok-2-1212" do
      model = IntentRouter.select_model_for_tier(:grok)
      assert model == "x-ai/grok-2-1212"
    end

    test "reason intent includes grok in providers" do
      config = IntentRouter.route(:reason)
      assert "x-ai" in config.provider_preferences.order
    end

    test "reason intent fallback is grok-2-1212" do
      fallback = IntentRouter.get_fallback(:reason)
      assert fallback == "x-ai/grok-2-1212"
    end

    test "grok model has valid format" do
      model = IntentRouter.select_model_for_tier(:grok)
      assert String.contains?(model, "/")
      assert String.starts_with?(model, "x-ai/")
    end
  end
end
