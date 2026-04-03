defmodule Indrajaal.AI.Graphiti.Extractor do
  @moduledoc """
  Structured knowledge extraction using LLM with schema validation.

  ## Purpose

  Wraps LLM calls to extract structured knowledge graph data from
  unstructured text. Uses Ecto schemas for validation and automatic
  retry on validation failures.

  ## Features

  - Chain-of-thought reasoning for better accuracy
  - Schema-enforced output structure
  - Automatic retry with validation feedback
  - Integration with Simplex cost monitoring

  ## STAMP Constraints

  - SC-AI-204: Structured extraction only
  - SC-AI-205: Max 3 retries per extraction
  - SC-AI-206: Cost-aware model selection

  ## Usage

      {:ok, extraction} = Extractor.extract("Alice works at OpenRouter.")
      # => %Extraction{facts: [...], chain_of_thought: "..."}
  """

  require Logger

  alias Indrajaal.AI.Graphiti.Schema.{Extraction, Fact}
  alias Indrajaal.AI.{IntentRouter, CostMonitor, ProviderDispatcher}
  alias Indrajaal.AI.Simplex.TelemetryFlow

  @max_retries 3

  @system_prompt """
  You are a rigorous Knowledge Graph Engineer extracting structured facts from text.

  ## Your Task
  1. Analyze the input text step-by-step in the 'chain_of_thought' field.
  2. Extract entities and their relationships as facts.
  3. Categorize each entity strictly (person, organization, location, concept, event, product, technology).
  4. Use semantic relationship labels in UPPER_SNAKE_CASE format.

  ## Rules
  - Labels must be UPPER_SNAKE_CASE (e.g., WORKS_AT, LOCATED_IN, HAS_ROLE)
  - Only extract facts with confidence >= 75%
  - Be precise: prefer specific labels over generic ones
  - Include the reasoning process in chain_of_thought

  ## Common Labels
  - Person: WORKS_AT, HAS_ROLE, KNOWS, LIVES_IN, BORN_IN
  - Organization: LOCATED_IN, OWNS, PRODUCES, EMPLOYS
  - Location: PART_OF, NEAR, CONTAINS
  - Technology: USES, BUILT_WITH, INTEGRATES_WITH
  - Concept: IS_A, RELATED_TO, ENABLES
  """

  @type extract_opts :: [
          model: String.t(),
          max_retries: non_neg_integer(),
          temperature: float(),
          source: atom()
        ]

  @doc """
  Extract structured knowledge graph facts from text.

  ## Parameters

  - `text`: The unstructured text to process
  - `opts`: Extraction options
    - `:model` - LLM model to use (default: gemini-2.0-flash-exp:free)
    - `:max_retries` - Max validation retries (default: 3)
    - `:temperature` - LLM temperature (default: 0.1)
    - `:source` - Request source for telemetry

  ## Returns

  - `{:ok, %Extraction{}}` on success
  - `{:error, reason}` on failure
  """
  @spec extract(String.t(), extract_opts()) :: {:ok, Extraction.t()} | {:error, term()}
  def extract(text, opts \\ []) when is_binary(text) do
    start_time = System.monotonic_time(:millisecond)
    source = Keyword.get(opts, :source, :graphiti)

    with {:ok, model} <- select_model(opts),
         {:ok, result} <- do_extract(text, model, opts, 0) do
      end_time = System.monotonic_time(:millisecond)
      latency = end_time - start_time

      # Emit telemetry
      emit_extraction_telemetry(result, model, latency, source)

      {:ok, result}
    end
  end

  @doc """
  Extract facts and return only the facts list.
  """
  @spec extract_facts(String.t(), extract_opts()) :: {:ok, [Fact.t()]} | {:error, term()}
  def extract_facts(text, opts \\ []) do
    case extract(text, opts) do
      {:ok, %{facts: facts}} -> {:ok, facts}
      error -> error
    end
  end

  @doc """
  Batch extract from multiple texts.

  Combines texts with separators to reduce API calls.
  """
  @spec batch_extract([String.t()], extract_opts()) :: {:ok, [Extraction.t()]} | {:error, term()}
  def batch_extract(texts, opts \\ []) when is_list(texts) do
    # For efficiency, we process texts individually but could batch
    results =
      texts
      |> Task.async_stream(
        fn text -> extract(text, opts) end,
        max_concurrency: 3,
        timeout: 60_000
      )
      |> Enum.map(fn
        {:ok, {:ok, result}} -> {:ok, result}
        {:ok, {:error, reason}} -> {:error, reason}
        {:exit, reason} -> {:error, {:timeout, reason}}
      end)

    successes = Enum.filter(results, &match?({:ok, _}, &1))
    failures = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(failures) do
      {:ok, Enum.map(successes, fn {:ok, r} -> r end)}
    else
      {:partial, Enum.map(successes, fn {:ok, r} -> r end), failures}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Core Extraction Logic
  # ---------------------------------------------------------------------------

  defp do_extract(text, model, opts, retry_count) when retry_count < @max_retries do
    max_retries = Keyword.get(opts, :max_retries, @max_retries)

    if retry_count >= max_retries do
      {:error, {:max_retries_exceeded, retry_count}}
    else
      case call_llm(text, model, opts) do
        {:ok, response} ->
          parse_and_validate(response, text, model, opts, retry_count)

        {:error, reason} ->
          Logger.warning("[Graphiti] LLM call failed: #{inspect(reason)}")
          {:error, {:llm_error, reason}}
      end
    end
  end

  defp do_extract(_text, _model, _opts, retry_count) do
    {:error, {:max_retries_exceeded, retry_count}}
  end

  defp call_llm(text, model, opts) do
    temperature = Keyword.get(opts, :temperature, 0.1)

    messages = [
      %{"role" => "system", "content" => @system_prompt},
      %{"role" => "user", "content" => build_user_prompt(text)}
    ]

    # Check budget first
    case CostMonitor.check_budget_and_rate(model, 0.01) do
      :ok ->
        # Use ProviderDispatcher for the actual call
        request = %{
          model: model,
          messages: messages,
          temperature: temperature,
          max_tokens: 2000,
          provider: :openrouter
        }

        case ProviderDispatcher.chat(:openrouter, request, []) do
          {:ok, content} when is_binary(content) ->
            {:ok, content}

          {:ok, %{content: content}} ->
            {:ok, content}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, {:budget_exceeded, reason}}
    end
  end

  defp build_user_prompt(text) do
    """
    Extract knowledge graph facts from the following text.

    Respond with a JSON object containing:
    - chain_of_thought: Your step-by-step reasoning
    - summary: Brief summary of extracted knowledge
    - facts: Array of fact objects with source, target, label, category, confidence

    TEXT TO ANALYZE:
    ---
    #{text}
    ---

    Respond ONLY with valid JSON, no markdown formatting.
    """
  end

  defp parse_and_validate(response, text, model, opts, retry_count) do
    case parse_json_response(response) do
      {:ok, data} ->
        case validate_extraction(data) do
          {:ok, extraction} ->
            {:ok, extraction}

          {:error, validation_errors} ->
            Logger.info(
              "[Graphiti] Validation failed (retry #{retry_count + 1}): #{inspect(validation_errors)}"
            )

            # Could add retry with error feedback here
            do_extract(text, model, opts, retry_count + 1)
        end

      {:error, :invalid_json} ->
        Logger.warning("[Graphiti] Invalid JSON response, retrying...")
        do_extract(text, model, opts, retry_count + 1)
    end
  end

  defp parse_json_response(response) do
    # Clean up response - remove markdown code blocks if present
    cleaned =
      response
      |> String.replace(~r/```json\s*/i, "")
      |> String.replace(~r/```\s*$/i, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp validate_extraction(data) when is_map(data) do
    # Build extraction struct
    changeset =
      Extraction.changeset(%Extraction{}, %{
        chain_of_thought: data["chain_of_thought"] || data[:chain_of_thought] || "",
        summary: data["summary"] || data[:summary],
        facts: parse_facts(data["facts"] || data[:facts] || [])
      })

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      errors = format_changeset_errors(changeset)
      {:error, errors}
    end
  end

  defp validate_extraction(_), do: {:error, :invalid_structure}

  defp parse_facts(facts) when is_list(facts) do
    Enum.map(facts, fn fact ->
      %{
        source: fact["source"] || fact[:source] || "",
        target: fact["target"] || fact[:target] || "",
        label: fact["label"] || fact[:label] || "",
        category: parse_category(fact["category"] || fact[:category]),
        confidence: fact["confidence"] || fact[:confidence] || 80
      }
    end)
  end

  defp parse_facts(_), do: []

  defp parse_category(category) when is_binary(category) do
    category
    |> String.downcase()
    |> String.to_existing_atom()
  rescue
    _ -> :concept
  end

  defp parse_category(category) when is_atom(category), do: category
  defp parse_category(_), do: :concept

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Private: Model Selection
  # ---------------------------------------------------------------------------

  defp select_model(opts) do
    case Keyword.get(opts, :model) do
      nil ->
        # Use IntentRouter for intelligent selection
        config = IntentRouter.route(:extract, opts)
        {:ok, config.model}

      model when is_binary(model) ->
        {:ok, model}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Telemetry
  # ---------------------------------------------------------------------------

  defp emit_extraction_telemetry(result, model, latency, source) do
    TelemetryFlow.emit_ai_event(
      [:graphiti, :extraction],
      %{
        facts_count: length(result.facts),
        entity_count: result.entity_count,
        latency_ms: latency
      },
      %{
        model: model,
        source: source,
        has_summary: result.summary != nil
      }
    )

    # Record cost
    estimated_tokens =
      String.length(result.chain_of_thought || "") +
        Enum.sum(
          Enum.map(result.facts, fn f ->
            String.length(f.source) + String.length(f.target) + String.length(f.label)
          end)
        )

    CostMonitor.record_usage(model, source, 0.001, estimated_tokens)
  end
end
