defmodule Indrajaal.AI.PrometheusPropertyTest do
  use ExUnit.Case
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.AI.OpenRouterClient

  property "verify_routing_graph always returns valid result type" do
    forall {source, model, confidence, approved} <- proposal_generator() do
      result =
        OpenRouterClient.verify_routing_graph(
          source,
          model,
          confidence: confidence,
          guardian_approved: approved
        )

      case result do
        {:ok, :verified} -> true
        {:error, {:constraint_violation, _}} -> true
        _ -> false
      end
    end
  end

  property "high confidence + guardian approved always passes for valid models" do
    forall {source, model} <- {trusted_source_generator(), valid_model_generator()} do
      result =
        OpenRouterClient.verify_routing_graph(
          source,
          model,
          confidence: 1.0,
          guardian_approved: true
        )

      result == {:ok, :verified}
    end
  end

  property "low confidence always fails regardless of other params" do
    forall {source, model, approved} <- {
             PC.oneof([:cortex, :synapse, :agent]),
             model_generator(),
             PC.boolean()
           } do
      result =
        OpenRouterClient.verify_routing_graph(
          source,
          model,
          # Always below threshold
          confidence: 0.3,
          guardian_approved: approved
        )

      match?({:error, {:constraint_violation, :inv_confidence_threshold}}, result)
    end
  end

  property "synapse + direct model always fails exclusivity" do
    forall model <- direct_model_generator() do
      result = OpenRouterClient.check_exclusivity_constraint(:synapse, model)
      match?({:error, {:constraint_violation, :inv_openrouter_exclusivity}}, result)
    end
  end

  # Generators
  defp proposal_generator do
    {
      PC.oneof([:cortex, :synapse, :guardian, :gde, :agent]),
      model_generator(),
      PC.float(0.0, 1.0),
      PC.boolean()
    }
  end

  defp trusted_source_generator do
    PC.oneof([:guardian, :gde])
  end

  defp valid_model_generator do
    PC.oneof([
      "anthropic/claude-3.5-sonnet",
      "google/gemini-pro-1.5",
      "openai/gpt-4o"
    ])
  end

  defp model_generator do
    PC.oneof([
      "anthropic/claude-3.5-sonnet",
      "google/gemini-flash-1.5-8b",
      "openai/gpt-4",
      # Direct (invalid)
      "gpt-4",
      # Direct (invalid)
      "claude-3"
    ])
  end

  defp direct_model_generator do
    PC.oneof(["gpt-4", "claude-3", "gemini", "mistral-7b", "openai-gpt4"])
  end
end
