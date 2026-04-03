defmodule Indrajaal.AI.Evolution.ShadowMode do
  @moduledoc """
  Shadow mode evaluation for comparing model outputs safely.

  ## Purpose

  Shadow mode allows safe evaluation of new or alternative models by running
  them in parallel with the primary model without affecting production output.

  ## How It Works

  1. Primary model handles the request normally
  2. Shadow model runs in parallel without actuator access
  3. Outputs are compared for divergence
  4. Results feed into TrainingGym for continuous learning

  ## Use Cases

  - Evaluating new models before production deployment
  - A/B testing model configurations
  - Detecting model drift over time
  - Generating training data for fine-tuning

  ## STAMP Constraints

  - SC-AI-103: ShadowMode for new models
  - SC-AI-107: Learning cycles < 1 hour

  ## Usage

      {:ok, result} = ShadowMode.execute_with_shadow(request,
        shadow_model: "openai/gpt-4o"
      )
  """

  alias Indrajaal.AI.Simplex.{SimplexController, TelemetryFlow}
  alias Indrajaal.AI.Evolution.TrainingGym

  require Logger

  @doc """
  Execute primary request with optional shadow evaluation.

  The shadow model runs in parallel but its output is not returned to the caller.
  Instead, it's compared with the primary output and recorded for learning.

  ## Options

  - `:shadow_model` - Model ID for shadow execution
  - `:compare_threshold` - Divergence threshold (default: 0.3)
  - `:timeout` - Max wait time for shadow in ms (default: 120_000)
  """
  @spec execute_with_shadow(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute_with_shadow(request, opts \\ []) do
    shadow_model = Keyword.get(opts, :shadow_model)
    timeout = Keyword.get(opts, :timeout, 120_000)

    # Primary execution (normal Simplex flow)
    primary_task =
      Task.async(fn ->
        SimplexController.execute(request, opts)
      end)

    # Shadow execution (if configured)
    shadow_task =
      if shadow_model do
        Task.async(fn ->
          shadow_request =
            Map.merge(request, %{
              model: shadow_model,
              source: :shadow_mode
            })

          # Don't emit production telemetry for shadow
          shadow_opts = Keyword.put(opts, :shadow, true)
          SimplexController.execute(shadow_request, shadow_opts)
        end)
      end

    # Wait for primary result (this is what we return)
    primary_result = Task.await(primary_task, timeout)

    # Evaluate shadow in background if present
    if shadow_task do
      spawn(fn ->
        try do
          shadow_result = Task.await(shadow_task, timeout)
          compare_threshold = Keyword.get(opts, :compare_threshold, 0.3)

          evaluate_divergence(
            request,
            primary_result,
            shadow_result,
            shadow_model,
            compare_threshold
          )
        rescue
          e ->
            Logger.warning("[ShadowMode] Shadow task failed: #{inspect(e)}")
        end
      end)
    end

    primary_result
  end

  @doc """
  Run shadow evaluation only (for testing/analysis).

  Returns both primary and shadow results for comparison.
  """
  @spec compare_models(map(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def compare_models(request, model_a, model_b, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 120_000)

    # Run both models in parallel
    task_a =
      Task.async(fn ->
        request_a = Map.put(request, :model, model_a)
        SimplexController.execute(request_a, opts)
      end)

    task_b =
      Task.async(fn ->
        request_b = Map.put(request, :model, model_b)
        SimplexController.execute(request_b, opts)
      end)

    result_a = Task.await(task_a, timeout)
    result_b = Task.await(task_b, timeout)

    case {result_a, result_b} do
      {{:ok, a}, {:ok, b}} ->
        divergence = calculate_divergence(a, b)

        {:ok,
         %{
           model_a: %{model: model_a, result: a},
           model_b: %{model: model_b, result: b},
           divergence: divergence,
           agreement: divergence <= 0.3
         }}

      {{:error, reason}, _} ->
        {:error, {:model_a_failed, reason}}

      {_, {:error, reason}} ->
        {:error, {:model_b_failed, reason}}
    end
  end

  @doc """
  Calculate divergence score between two responses.

  Returns a float between 0.0 (identical) and 1.0 (completely different).
  """
  @spec calculate_divergence(map(), map()) :: float()
  def calculate_divergence(result_a, result_b) do
    content_a = get_content(result_a)
    content_b = get_content(result_b)

    # Length ratio divergence
    len_a = String.length(content_a)
    len_b = String.length(content_b)
    max_len = max(len_a, len_b)

    length_divergence =
      if max_len > 0 do
        abs(len_a - len_b) / max_len
      else
        0.0
      end

    # Word-level Jaccard distance
    words_a = tokenize(content_a)
    words_b = tokenize(content_b)

    jaccard_distance =
      if MapSet.size(MapSet.union(words_a, words_b)) > 0 do
        intersection = words_a |> MapSet.intersection(words_b) |> MapSet.size()
        union = words_a |> MapSet.union(words_b) |> MapSet.size()
        1.0 - intersection / union
      else
        0.0
      end

    # Combined score (weighted average)
    (length_divergence * 0.3 + jaccard_distance * 0.7)
    |> Float.round(4)
  end

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp evaluate_divergence(request, {:ok, primary}, {:ok, shadow}, shadow_model, threshold) do
    divergence = calculate_divergence(primary, shadow)

    episode_type =
      cond do
        divergence > threshold -> :shadow_diverge
        divergence > threshold / 2 -> :near_miss
        true -> :shadow_agree
      end

    episode = %{
      type: episode_type,
      primary_model: request[:model] || "unknown",
      shadow_model: shadow_model,
      divergence_score: divergence,
      request_intent: request[:intent],
      timestamp: DateTime.utc_now()
    }

    # Record to TrainingGym
    TrainingGym.record_episode(episode)

    # Emit telemetry
    TelemetryFlow.emit_training_episode(episode)

    Logger.debug("[ShadowMode] Evaluated: #{episode_type} (divergence: #{divergence})")
  end

  defp evaluate_divergence(_request, _primary, {:error, reason}, shadow_model, _threshold) do
    Logger.debug("[ShadowMode] Shadow model #{shadow_model} failed: #{inspect(reason)}")
  end

  defp evaluate_divergence(_request, {:error, _}, _shadow, _shadow_model, _threshold) do
    # Primary failed - nothing to compare
    :ok
  end

  defp get_content(%{content: content}) when is_binary(content), do: content
  defp get_content(_), do: ""

  defp tokenize(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> MapSet.new()
  end
end
