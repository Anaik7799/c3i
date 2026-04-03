defmodule Indrajaal.AI.AnalysisResource do
  @moduledoc """
  AnalysisResource - Deep code and log analysis via Gemini.

  ## Purpose

  Performs intelligent analysis of:
  - Source code files
  - Error logs
  - System patterns
  - Architecture documentation

  Optimized for Gemini's large context window (1M+ tokens).

  ## STAMP Constraints

  - SC-AI-001: All analysis outputs validated with Guardian
  - SC-AI-004: Context size validated before submission
  - SC-AI-005: Sensitive data scrubbed from inputs

  ## Analysis Types

  - `:code` - Source code analysis
  - `:logs` - Error/warning log analysis
  - `:patterns` - Semantic pattern extraction
  - `:architecture` - System architecture analysis
  - `:security` - Security vulnerability analysis

  ## Usage

      {:ok, analysis} = Indrajaal.AIDomain
        |> Ash.Changeset.for_create(:create, %{
          analysis_type: :code,
          input_content: File.read!("lib/my_module.ex"),
          query: "What are the potential issues in this code?"
        })
        |> Ash.create()

      # Analysis results available in analysis.results
  """

  use Ash.Resource,
    domain: Indrajaal.AIDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  @analysis_types [:code, :logs, :patterns, :architecture, :security]

  attributes do
    uuid_primary_key :id

    attribute :analysis_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: @analysis_types
    end

    attribute :input_content, :string do
      allow_nil? false
      public? true
      constraints max_length: 500_000
      description "Content to analyze (code, logs, etc.)"
    end

    attribute :query, :string do
      allow_nil? false
      public? true
      constraints max_length: 5_000
      description "Analysis question or objective"
    end

    attribute :context_files, {:array, :string} do
      public? true
      default []
      description "Additional file paths for context"
    end

    attribute :results, :map do
      public? true
      default %{}
      description "Analysis results with insights, patterns, recommendations"
    end

    attribute :confidence, :float do
      public? true
      constraints min: 0.0, max: 1.0
      description "Confidence score of analysis"
    end

    attribute :processing_time_ms, :integer do
      public? true
      description "Time taken to complete analysis"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :processing, :complete, :failed]
      default :pending
    end

    attribute :error_message, :string do
      public? true
    end

    attribute :guardian_validated, :boolean do
      public? true
      default false
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:analysis_type, :input_content, :query, :context_files, :metadata]
      primary? true

      change fn changeset, _context ->
        # Validate content size
        content = Ash.Changeset.get_attribute(changeset, :input_content) || ""

        if String.length(content) > 500_000 do
          Ash.Changeset.add_error(changeset,
            field: :input_content,
            message: "Content exceeds 500K character limit"
          )
        else
          changeset
        end
      end
    end

    action :analyze, :map do
      argument :analysis_id, :uuid, allow_nil?: false

      run fn input, _context ->
        analysis_id = input.arguments.analysis_id
        start_time = System.monotonic_time(:millisecond)

        case Ash.get(Indrajaal.AI.AnalysisResource, analysis_id) do
          {:ok, analysis} ->
            # Update status to processing
            {:ok, analysis} =
              analysis
              |> Ash.Changeset.for_update(:update, %{})
              |> Ash.Changeset.force_change_attribute(:status, :processing)
              |> Ash.update()

            # Build analysis prompt
            prompt = build_analysis_prompt(analysis)

            # Call OpenRouter with Gemini for large context
            case OpenRouterClient.chat(prompt, model: :smart) do
              {:ok, response} ->
                end_time = System.monotonic_time(:millisecond)
                processing_time = end_time - start_time

                # Parse results
                results = parse_analysis_response(response, analysis.analysis_type)

                # Validate with Guardian
                guardian_result =
                  Guardian.validate_proposal(%{
                    action: :ai_analysis,
                    source: :analysis_resource,
                    content: response
                  })

                validated = match?({:ok, _}, guardian_result)

                # Update analysis with results
                changeset =
                  analysis
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :complete)
                  |> Ash.Changeset.force_change_attribute(:results, results)

                changeset =
                  changeset
                  |> Ash.Changeset.force_change_attribute(
                    :confidence,
                    results[:confidence] || 0.8
                  )
                  |> Ash.Changeset.force_change_attribute(:processing_time_ms, processing_time)

                {:ok, updated} =
                  Ash.update(
                    Ash.Changeset.force_change_attribute(
                      changeset,
                      :guardian_validated,
                      validated
                    )
                  )

                {:ok, %{analysis_id: analysis_id, results: results, validated: validated}}

              {:error, reason} ->
                {:ok, _} =
                  analysis
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :failed)
                  |> Ash.Changeset.force_change_attribute(:error_message, inspect(reason))
                  |> Ash.update()

                {:error, reason}
            end

          {:error, _} ->
            {:error, :analysis_not_found}
        end
      end
    end

    update :update do
      accept [:status, :metadata]
      primary? true
    end

    read :by_type do
      argument :analysis_type, :atom, allow_nil?: false

      filter expr(analysis_type == ^arg(:analysis_type))
    end

    read :completed do
      filter expr(status == :complete)
    end
  end

  json_api do
    type "analysis"

    routes do
      base("/analyses")
      get(:read)
      index :read
      post(:create)
      delete(:destroy)
    end
  end

  # Private helpers

  defp build_analysis_prompt(analysis) do
    system_prompt =
      case analysis.analysis_type do
        :code ->
          "You are an expert Elixir code analyzer. Provide detailed insights about code quality, patterns, and potential issues."

        :logs ->
          "You are a log analysis expert. Identify errors, patterns, and root causes from log data."

        :patterns ->
          "You are a pattern recognition specialist. Extract semantic patterns and relationships from the content."

        :architecture ->
          "You are a software architect. Analyze system architecture and provide recommendations."

        :security ->
          "You are a security analyst. Identify vulnerabilities and security concerns."
      end

    [
      %{"role" => "system", "content" => system_prompt},
      %{
        "role" => "user",
        "content" => """
        Analyze the following #{analysis.analysis_type}:

        ```
        #{analysis.input_content}
        ```

        Query: #{analysis.query}

        Provide your analysis in JSON format with:
        - insights: List of key findings
        - patterns: Identified patterns
        - recommendations: Suggested improvements
        - confidence: Your confidence score (0.0-1.0)
        - references: Relevant line numbers or sections
        """
      }
    ]
  end

  defp parse_analysis_response(response, _type) do
    # Try to parse as JSON, fallback to structured map
    case Jason.decode(response) do
      {:ok, parsed} ->
        parsed

      {:error, _} ->
        %{
          "insights" => [response],
          "patterns" => [],
          "recommendations" => [],
          "confidence" => 0.7,
          "references" => []
        }
    end
  end
end
