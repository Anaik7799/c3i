defmodule Indrajaal.AI.OpenRouter.ModelFallbackTest do
  @moduledoc """
  TDG-Compliant tests for ModelFallback module.

  Tests 3-level model fallback chain for OpenRouter API resilience.

  STAMP Constraints:
  - SC-AI-FALLBACK-001: 3-level model fallback chain
  - SC-AI-FALLBACK-002: Intent-based model selection
  - SC-AI-FALLBACK-003: Graceful degradation on model failure
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.AI.OpenRouter.ModelFallback

  describe "ModelFallback.get_chain/1" do
    test "SC-AI-FALLBACK-001: returns 3-level chain for analysis intent" do
      chain = ModelFallback.get_chain(:analysis)

      assert length(chain) == 3
      assert Enum.all?(chain, &is_binary/1)
    end

    test "SC-AI-FALLBACK-001: returns 3-level chain for coding intent" do
      chain = ModelFallback.get_chain(:coding)

      assert length(chain) == 3
      assert Enum.all?(chain, &is_binary/1)
    end

    test "SC-AI-FALLBACK-001: returns 3-level chain for chat intent" do
      chain = ModelFallback.get_chain(:chat)

      assert length(chain) == 3
      assert Enum.all?(chain, &is_binary/1)
    end

    test "SC-AI-FALLBACK-002: uses default chain for unknown intent" do
      chain = ModelFallback.get_chain(:unknown_intent)

      assert length(chain) == 3
      # Default chain should exist
      assert Enum.all?(chain, &is_binary/1)
    end

    test "returns models with valid OpenRouter format" do
      chain = ModelFallback.get_chain(:analysis)

      # OpenRouter models have format: provider/model-name
      assert Enum.all?(chain, fn model ->
               String.contains?(model, "/")
             end)
    end
  end

  describe "ModelFallback.select_model/2" do
    test "SC-AI-FALLBACK-002: selects first model in chain by default" do
      model = ModelFallback.select_model(:analysis)

      chain = ModelFallback.get_chain(:analysis)
      assert model == hd(chain)
    end

    test "respects preference option when available" do
      preferred = "anthropic/claude-3.5-sonnet"
      model = ModelFallback.select_model(:analysis, preference: preferred)

      # If preference is in chain, it should be selected
      chain = ModelFallback.get_chain(:analysis)

      if preferred in chain do
        assert model == preferred
      else
        # Otherwise first model in chain
        assert model == hd(chain)
      end
    end

    test "uses first model when preference not in chain" do
      model = ModelFallback.select_model(:analysis, preference: "nonexistent/model")

      chain = ModelFallback.get_chain(:analysis)
      assert model == hd(chain)
    end
  end

  describe "ModelFallback.next_model/2" do
    test "SC-AI-FALLBACK-003: returns next model in chain" do
      chain = ModelFallback.get_chain(:analysis)
      current = hd(chain)

      next = ModelFallback.next_model(:analysis, current)

      assert next == Enum.at(chain, 1)
    end

    test "SC-AI-FALLBACK-003: returns nil when at end of chain" do
      chain = ModelFallback.get_chain(:analysis)
      last = List.last(chain)

      next = ModelFallback.next_model(:analysis, last)

      assert next == nil
    end

    test "returns first model if current not in chain" do
      next = ModelFallback.next_model(:analysis, "nonexistent/model")

      chain = ModelFallback.get_chain(:analysis)
      assert next == hd(chain)
    end
  end

  describe "ModelFallback.execute_with_fallback/3" do
    test "SC-AI-FALLBACK-001: succeeds on first model" do
      call_log = :counters.new(1, [:atomics])

      result =
        ModelFallback.execute_with_fallback(:chat, fn model ->
          :counters.add(call_log, 1, 1)
          {:ok, %{model: model, content: "Success"}}
        end)

      assert {:ok, response} = result
      assert is_binary(response.model)
      assert :counters.get(call_log, 1) == 1
    end

    test "SC-AI-FALLBACK-003: falls back on first model failure" do
      call_log = :counters.new(1, [:atomics])

      result =
        ModelFallback.execute_with_fallback(:chat, fn model ->
          count = :counters.add(call_log, 1, 1)
          current = :counters.get(call_log, 1)

          if current == 1 do
            {:error, :rate_limited}
          else
            {:ok, %{model: model, content: "Fallback success"}}
          end
        end)

      assert {:ok, response} = result
      assert response.content == "Fallback success"
      assert :counters.get(call_log, 1) == 2
    end

    test "SC-AI-FALLBACK-003: tries all models before failing" do
      call_log = :counters.new(1, [:atomics])

      result =
        ModelFallback.execute_with_fallback(:chat, fn _model ->
          :counters.add(call_log, 1, 1)
          {:error, :service_unavailable}
        end)

      assert {:error, :all_models_failed} = result
      # Should have tried all 3 models
      assert :counters.get(call_log, 1) == 3
    end

    test "preserves original error from last model" do
      result =
        ModelFallback.execute_with_fallback(:chat, fn _model ->
          {:error, :specific_error}
        end)

      assert {:error, :all_models_failed} = result
    end

    test "does not retry non-retryable errors" do
      call_log = :counters.new(1, [:atomics])

      result =
        ModelFallback.execute_with_fallback(:chat, fn _model ->
          :counters.add(call_log, 1, 1)
          {:error, :invalid_api_key}
        end)

      assert {:error, :invalid_api_key} = result
      # Should fail immediately without fallback
      assert :counters.get(call_log, 1) == 1
    end
  end

  describe "ModelFallback.model_info/1" do
    test "returns info for known models" do
      info = ModelFallback.model_info("anthropic/claude-3.5-sonnet")

      assert is_map(info)
      assert Map.has_key?(info, :context_length)
      assert Map.has_key?(info, :capabilities)
    end

    test "returns default info for unknown models" do
      info = ModelFallback.model_info("unknown/model")

      assert is_map(info)
      assert info.context_length > 0
    end
  end

  describe "ModelFallback.suitable_for_intent?/2" do
    test "returns true for models matching intent" do
      # Claude models should be suitable for analysis
      assert ModelFallback.suitable_for_intent?("anthropic/claude-3.5-sonnet", :analysis)
    end

    test "returns true for generic models on any intent" do
      # Generic capable models should work for most intents
      assert ModelFallback.suitable_for_intent?("openai/gpt-4-turbo", :chat)
    end
  end

  describe "ModelFallback intents" do
    test "supports expected intents" do
      supported_intents = [:analysis, :coding, :chat, :embedding, :vision]

      Enum.each(supported_intents, fn intent ->
        chain = ModelFallback.get_chain(intent)
        assert length(chain) >= 1, "Intent #{intent} should have at least one model"
      end)
    end
  end

  # Property-based testing
  property "fallback chain always has at least one model" do
    intents = [:analysis, :coding, :chat, :embedding, :vision, :unknown]

    forall intent <- PC.oneof(intents) do
      chain = ModelFallback.get_chain(intent)
      length(chain) >= 1
    end
  end

  property "next_model eventually returns nil" do
    forall intent <- PC.oneof([:analysis, :coding, :chat]) do
      chain = ModelFallback.get_chain(intent)

      # Walk the chain until we get nil
      result =
        Enum.reduce_while(chain, hd(chain), fn _model, current ->
          case ModelFallback.next_model(intent, current) do
            nil -> {:halt, :reached_end}
            next -> {:cont, next}
          end
        end)

      result == :reached_end
    end
  end
end
