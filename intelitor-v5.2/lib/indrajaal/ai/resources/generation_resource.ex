defmodule Indrajaal.AI.GenerationResource do
  @moduledoc """
  GenerationResource - Code synthesis via Claude with Guardian validation.

  ## Purpose

  Generates production-ready Elixir code using Claude Sonnet with:
  - Full Guardian pre-flight validation
  - STAMP constraint compliance
  - Test generation included
  - Documentation generation

  ## STAMP Constraints

  - SC-AI-001: All generated code validated with Guardian
  - SC-NEURO-001: Simplex principle - Guardian MUST approve before execution
  - SC-GDE-061: All proposals include confidence scores
  - SC-GDE-062: AI outputs validated before any execution

  ## Generation Types

  - `:code` - New module/function generation
  - `:fix` - Bug fix synthesis
  - `:test` - Test case generation
  - `:documentation` - Documentation generation
  - `:refactor` - Refactoring suggestions

  ## Usage

      {:ok, generation} = Indrajaal.AIDomain
        |> Ash.Changeset.for_create(:create, %{
          generation_type: :code,
          requirements: "Create a GenServer for rate limiting",
          context: %{domain: "security", patterns: ["circuit_breaker"]}
        })
        |> Ash.create()

      # Generate the code
      {:ok, result} = Indrajaal.AI.GenerationResource.generate(generation.id)
  """

  use Ash.Resource,
    domain: Indrajaal.AIDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  @generation_types [:code, :fix, :test, :documentation, :refactor]

  attributes do
    uuid_primary_key :id

    attribute :generation_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: @generation_types
    end

    attribute :requirements, :string do
      allow_nil? false
      public? true
      constraints max_length: 10_000
      description "What to generate"
    end

    attribute :context, :map do
      public? true
      default %{}
      description "Codebase context from analysis"
    end

    attribute :generated_code, :string do
      public? true
      description "Generated Elixir code"
    end

    attribute :generated_tests, :string do
      public? true
      description "Generated test code"
    end

    attribute :generated_docs, :string do
      public? true
      description "Generated documentation"
    end

    attribute :affected_files, {:array, :string} do
      public? true
      default []
      description "Files that would be modified"
    end

    attribute :confidence, :float do
      public? true
      constraints min: 0.0, max: 1.0
      default 0.0
    end

    attribute :guardian_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :approved, :rejected]
      default :pending
    end

    attribute :guardian_feedback, :string do
      public? true
      description "Guardian validation feedback"
    end

    attribute :validation_errors, {:array, :string} do
      public? true
      default []
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :generating, :validating, :complete, :failed]
      default :pending
    end

    attribute :processing_time_ms, :integer do
      public? true
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
      accept [:generation_type, :requirements, :context, :affected_files, :metadata]
      primary? true
    end

    action :generate, :map do
      argument :generation_id, :uuid, allow_nil?: false

      run fn input, _context ->
        generation_id = input.arguments.generation_id
        start_time = System.monotonic_time(:millisecond)

        case Ash.get(Indrajaal.AI.GenerationResource, generation_id) do
          {:ok, generation} ->
            # Update status to generating
            {:ok, generation} =
              generation
              |> Ash.Changeset.for_update(:update, %{})
              |> Ash.Changeset.force_change_attribute(:status, :generating)
              |> Ash.update()

            # Build generation prompt
            prompt = build_generation_prompt(generation)

            # Call OpenRouter with Claude for code generation
            case OpenRouterClient.chat(prompt, model: :smart) do
              {:ok, response} ->
                # Parse generated code
                {code, tests, docs} = parse_generation_response(response)

                # Update to validating
                changeset =
                  generation
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :validating)
                  |> Ash.Changeset.force_change_attribute(:generated_code, code)

                changeset =
                  changeset
                  |> Ash.Changeset.force_change_attribute(:generated_tests, tests)
                  |> Ash.Changeset.force_change_attribute(:generated_docs, docs)

                {:ok, generation} = Ash.update(changeset)

                # Validate with Guardian (SC-NEURO-001)
                guardian_result =
                  Guardian.validate_proposal(%{
                    action: :code_generation,
                    source: :generation_resource,
                    code: code,
                    type: generation.generation_type
                  })

                end_time = System.monotonic_time(:millisecond)
                processing_time = end_time - start_time

                {guardian_status, feedback} =
                  case guardian_result do
                    {:ok, _} ->
                      {:approved, "Code passed Guardian validation"}

                    {:veto, reason, _fallback} ->
                      {:rejected, "Guardian rejected: #{inspect(reason)}"}
                  end

                # Update with final status
                changeset =
                  generation
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :complete)
                  |> Ash.Changeset.force_change_attribute(:guardian_status, guardian_status)

                changeset =
                  changeset
                  |> Ash.Changeset.force_change_attribute(:guardian_feedback, feedback)
                  |> Ash.Changeset.force_change_attribute(:confidence, calculate_confidence(code))

                {:ok, updated} =
                  Ash.update(
                    Ash.Changeset.force_change_attribute(
                      changeset,
                      :processing_time_ms,
                      processing_time
                    )
                  )

                {:ok,
                 %{
                   generation_id: generation_id,
                   code: code,
                   tests: tests,
                   guardian_status: guardian_status,
                   confidence: updated.confidence
                 }}

              {:error, reason} ->
                {:ok, _} =
                  generation
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :failed)
                  |> Ash.Changeset.force_change_attribute(:validation_errors, [inspect(reason)])
                  |> Ash.update()

                {:error, reason}
            end

          {:error, _} ->
            {:error, :generation_not_found}
        end
      end
    end

    update :update do
      accept [:status, :guardian_status, :metadata]
      primary? true
    end

    read :by_type do
      argument :generation_type, :atom, allow_nil?: false

      filter expr(generation_type == ^arg(:generation_type))
    end

    read :approved do
      filter expr(guardian_status == :approved)
    end

    read :pending_validation do
      filter expr(guardian_status == :pending)
    end
  end

  json_api do
    type "generation"

    routes do
      base("/generations")
      get(:read)
      index :read
      post(:create)
      delete(:destroy)
    end
  end

  # Private helpers

  defp build_generation_prompt(generation) do
    system_prompt = """
    You are an expert Elixir developer generating production-ready code for the Indrajaal security monitoring system.

    Requirements:
    1. Follow SOPv5.11 patterns
    2. Include comprehensive @moduledoc with WHAT/WHY/CONSTRAINTS
    3. Use Ash resources with BaseResource when applicable
    4. Include type specs for all public functions
    5. Generate matching test code
    6. Follow STAMP safety constraints

    Output Format:
    Return your response as JSON with these keys:
    - code: The generated Elixir module code
    - tests: The generated test code
    - docs: Additional documentation
    """

    context_str =
      if map_size(generation.context) > 0 do
        "Context: #{Jason.encode!(generation.context)}"
      else
        ""
      end

    [
      %{"role" => "system", "content" => system_prompt},
      %{
        "role" => "user",
        "content" => """
        Generation Type: #{generation.generation_type}

        Requirements:
        #{generation.requirements}

        #{context_str}

        Generate the code now.
        """
      }
    ]
  end

  defp parse_generation_response(response) do
    case Jason.decode(response) do
      {:ok, %{"code" => code, "tests" => tests, "docs" => docs}} ->
        {code, tests, docs}

      {:ok, %{"code" => code, "tests" => tests}} ->
        {code, tests, nil}

      {:ok, %{"code" => code}} ->
        {code, nil, nil}

      {:error, _} ->
        # Try to extract code blocks from markdown
        code = extract_code_block(response, "elixir")
        {code || response, nil, nil}
    end
  end

  defp extract_code_block(text, lang) do
    regex = ~r/```#{lang}\n(.*?)```/s

    case Regex.run(regex, text) do
      [_, code] -> String.trim(code)
      _ -> nil
    end
  end

  defp calculate_confidence(code) when is_binary(code) do
    # Simple heuristic based on code quality indicators
    has_moduledoc = String.contains?(code, "@moduledoc")
    has_spec = String.contains?(code, "@spec")
    has_doc = String.contains?(code, "@doc")
    reasonable_size = String.length(code) > 100 and String.length(code) < 50_000

    score =
      [has_moduledoc, has_spec, has_doc, reasonable_size]
      |> Enum.count(& &1)
      |> Kernel./(4)
      |> Kernel.*(0.5)
      |> Kernel.+(0.5)

    Float.round(score, 2)
  end

  defp calculate_confidence(_), do: 0.5
end
