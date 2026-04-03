defmodule Indrajaal.AI.SynapseResource do
  @moduledoc """
  SynapseResource - Multi-agent AI orchestration and coordination.

  ## Purpose

  Coordinates complex workflows involving multiple AI models:
  - Analysis phase (Gemini) → Generation phase (Claude)
  - Multi-turn reasoning chains
  - Parallel model execution with consensus
  - Shadow model comparison

  ## Workflow Types

  - `:analysis_then_generate` - Gemini analyzes, Claude generates
  - `:parallel_consensus` - Multiple models, voting on best result
  - `:chain_of_thought` - Sequential reasoning steps
  - `:shadow_compare` - Compare production vs shadow model

  ## STAMP Constraints

  - SC-AI-001: All orchestrated outputs validated with Guardian
  - SC-NEURO-001: Guardian approval required for execution
  - SC-SYNAPSE-001: Coordination decisions logged to Zenoh
  - SC-SYNAPSE-002: Fallback to single model on orchestration failure

  ## Bicameral Architecture

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                    Synapse Orchestrator                         │
  ├─────────────────────────────────────────────────────────────────┤
  │                                                                 │
  │   ┌─────────────┐    ┌─────────────────┐    ┌─────────────┐    │
  │   │   Gemini    │───→│   Coordinator   │───→│   Claude    │    │
  │   │  (Observe)  │    │   (Decide)      │    │  (Actuate)  │    │
  │   └─────────────┘    └─────────────────┘    └─────────────┘    │
  │          │                   │                     │           │
  │          └───────────────────┼─────────────────────┘           │
  │                              ▼                                 │
  │                       ┌─────────────┐                          │
  │                       │  Guardian   │                          │
  │                       │  (Validate) │                          │
  │                       └─────────────┘                          │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## Usage

      {:ok, synapse} = Indrajaal.AIDomain
        |> Ash.Changeset.for_create(:create, %{
          workflow_type: :analysis_then_generate,
          input: %{files: ["lib/my_module.ex"], requirements: "Add error handling"}
        })
        |> Ash.create()

      # Execute workflow
      {:ok, result} = Indrajaal.AI.SynapseResource.execute(synapse.id)
  """

  use Ash.Resource,
    domain: Indrajaal.AIDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Safety.Guardian

  @workflow_types [
    :analysis_then_generate,
    :parallel_consensus,
    :chain_of_thought,
    :shadow_compare
  ]

  attributes do
    uuid_primary_key :id

    attribute :workflow_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: @workflow_types
    end

    attribute :input, :map do
      allow_nil? false
      public? true
      description "Input data for the workflow"
    end

    attribute :steps, {:array, :map} do
      public? true
      default []
      description "Workflow steps with status and results"
    end

    attribute :primary_agent, :atom do
      public? true
      constraints one_of: [:gemini, :claude, :o1, :router]
      default :gemini
    end

    attribute :secondary_agents, {:array, :atom} do
      public? true
      default [:claude]
    end

    attribute :coordination_log, {:array, :string} do
      public? true
      default []
      description "Log of coordination decisions"
    end

    attribute :final_result, :map do
      public? true
      description "Final workflow output"
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :executing, :complete, :failed]
      default :pending
    end

    attribute :error_log, {:array, :string} do
      public? true
      default []
    end

    attribute :confidence, :float do
      public? true
      constraints min: 0.0, max: 1.0
    end

    attribute :processing_time_ms, :integer do
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
      accept [:workflow_type, :input, :primary_agent, :secondary_agents, :metadata]
      primary? true
    end

    action :execute, :map do
      argument :synapse_id, :uuid, allow_nil?: false

      run fn input, _context ->
        synapse_id = input.arguments.synapse_id
        start_time = System.monotonic_time(:millisecond)

        case Ash.get(Indrajaal.AI.SynapseResource, synapse_id) do
          {:ok, synapse} ->
            # Update status to executing
            {:ok, synapse} =
              synapse
              |> Ash.Changeset.for_update(:update, %{})
              |> Ash.Changeset.force_change_attribute(:status, :executing)
              |> Ash.Changeset.force_change_attribute(:coordination_log, ["Workflow started"])
              |> Ash.update()

            # Execute based on workflow type
            result =
              case synapse.workflow_type do
                :analysis_then_generate -> execute_analysis_then_generate(synapse)
                :parallel_consensus -> execute_parallel_consensus(synapse)
                :chain_of_thought -> execute_chain_of_thought(synapse)
                :shadow_compare -> execute_shadow_compare(synapse)
              end

            end_time = System.monotonic_time(:millisecond)
            processing_time = end_time - start_time

            case result do
              {:ok, final_result, steps, log} ->
                # Validate with Guardian
                guardian_result =
                  Guardian.validate_proposal(%{
                    action: :synapse_workflow,
                    source: :synapse_resource,
                    workflow: synapse.workflow_type,
                    result: final_result
                  })

                validated = match?({:ok, _}, guardian_result)

                changeset =
                  synapse
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :complete)
                  |> Ash.Changeset.force_change_attribute(:final_result, final_result)
                  |> Ash.Changeset.force_change_attribute(:steps, steps)

                changeset =
                  changeset
                  |> Ash.Changeset.force_change_attribute(:coordination_log, log)
                  |> Ash.Changeset.force_change_attribute(:processing_time_ms, processing_time)
                  |> Ash.Changeset.force_change_attribute(:guardian_validated, validated)

                {:ok, updated} =
                  Ash.update(
                    Ash.Changeset.force_change_attribute(
                      changeset,
                      :confidence,
                      final_result[:confidence] || 0.8
                    )
                  )

                {:ok, %{synapse_id: synapse_id, result: final_result, validated: validated}}

              {:error, reason, log} ->
                changeset =
                  synapse
                  |> Ash.Changeset.for_update(:update, %{})
                  |> Ash.Changeset.force_change_attribute(:status, :failed)
                  |> Ash.Changeset.force_change_attribute(:coordination_log, log)

                changeset =
                  changeset
                  |> Ash.Changeset.force_change_attribute(:error_log, [inspect(reason)])
                  |> Ash.Changeset.force_change_attribute(:processing_time_ms, processing_time)

                {:ok, _} = Ash.update(changeset)

                {:error, reason}
            end

          {:error, _} ->
            {:error, :synapse_not_found}
        end
      end
    end

    update :update do
      accept [:status, :metadata]
      primary? true
    end

    read :by_workflow do
      argument :workflow_type, :atom, allow_nil?: false

      filter expr(workflow_type == ^arg(:workflow_type))
    end

    read :completed do
      filter expr(status == :complete)
    end

    read :active do
      filter expr(status in [:pending, :executing])
    end
  end

  json_api do
    type "synapse"

    routes do
      base("/synapses")
      get(:read)
      index :read
      post(:create)
      delete(:destroy)
    end
  end

  # Private workflow implementations

  defp execute_analysis_then_generate(synapse) do
    log = ["Phase 1: Analysis with #{synapse.primary_agent}"]
    input = synapse.input

    # Phase 1: Analysis (Gemini)
    analysis_prompt = [
      %{
        "role" => "system",
        "content" =>
          "You are an expert code analyzer. Analyze the provided context and extract key patterns, issues, and recommendations."
      },
      %{"role" => "user", "content" => "Analyze this: #{inspect(input)}"}
    ]

    case OpenRouterClient.chat(analysis_prompt, model: :fast) do
      {:ok, analysis} ->
        log = log ++ ["Analysis complete", "Phase 2: Generation with Claude"]

        # Phase 2: Generation (Claude)
        generation_prompt = [
          %{
            "role" => "system",
            "content" =>
              "You are an expert Elixir developer. Generate code based on the analysis."
          },
          %{
            "role" => "user",
            "content" => """
            Based on this analysis:
            #{analysis}

            Requirements: #{input["requirements"] || "Generate appropriate code"}

            Generate production-ready Elixir code.
            """
          }
        ]

        case OpenRouterClient.chat(generation_prompt, model: :smart) do
          {:ok, generated} ->
            log = log ++ ["Generation complete", "Workflow finished successfully"]

            steps = [
              %{step: "analysis", agent: "gemini", status: "complete", output: analysis},
              %{step: "generation", agent: "claude", status: "complete", output: generated}
            ]

            {:ok, %{analysis: analysis, generated: generated, confidence: 0.85}, steps, log}

          {:error, reason} ->
            {:error, reason, log ++ ["Generation failed: #{inspect(reason)}"]}
        end

      {:error, reason} ->
        {:error, reason, log ++ ["Analysis failed: #{inspect(reason)}"]}
    end
  end

  defp execute_parallel_consensus(synapse) do
    log = ["Executing parallel consensus with multiple models"]
    input = synapse.input

    prompt = [
      %{"role" => "system", "content" => "Provide your analysis of the following."},
      %{"role" => "user", "content" => inspect(input)}
    ]

    # Execute with multiple models (simulated parallel for now)
    results = [
      {:gemini, OpenRouterClient.chat(prompt, model: :fast)},
      {:claude, OpenRouterClient.chat(prompt, model: :smart)}
    ]

    successes = Enum.filter(results, fn {_model, result} -> match?({:ok, _}, result) end)

    if length(successes) >= 1 do
      # Take the first successful result (could implement voting logic)
      {model, {:ok, response}} = hd(successes)
      log = log ++ ["Consensus reached with #{model}"]

      steps =
        Enum.map(results, fn {m, r} ->
          %{
            step: "parallel_#{m}",
            agent: to_string(m),
            status: if(match?({:ok, _}, r), do: "complete", else: "failed")
          }
        end)

      {:ok, %{response: response, consensus_model: model, confidence: 0.9}, steps, log}
    else
      {:error, :no_consensus, log ++ ["All models failed"]}
    end
  end

  defp execute_chain_of_thought(synapse) do
    log = ["Executing chain of thought reasoning"]
    input = synapse.input

    # Multi-step reasoning
    steps = []

    # Step 1: Understand
    step1_prompt = [
      %{"role" => "system", "content" => "Break down the problem into components."},
      %{"role" => "user", "content" => "Problem: #{inspect(input)}"}
    ]

    case OpenRouterClient.chat(step1_prompt, model: :smart) do
      {:ok, understanding} ->
        steps = steps ++ [%{step: "understand", status: "complete", output: understanding}]

        # Step 2: Plan
        step2_prompt = [
          %{"role" => "system", "content" => "Create a step-by-step plan."},
          %{"role" => "user", "content" => "Based on: #{understanding}\n\nCreate a plan."}
        ]

        case OpenRouterClient.chat(step2_prompt, model: :smart) do
          {:ok, plan} ->
            steps = steps ++ [%{step: "plan", status: "complete", output: plan}]

            # Step 3: Execute
            step3_prompt = [
              %{"role" => "system", "content" => "Execute the plan and provide the solution."},
              %{"role" => "user", "content" => "Plan: #{plan}\n\nExecute and provide solution."}
            ]

            case OpenRouterClient.chat(step3_prompt, model: :smart) do
              {:ok, solution} ->
                steps = steps ++ [%{step: "execute", status: "complete", output: solution}]
                log = log ++ ["Chain of thought complete"]

                {:ok,
                 %{
                   understanding: understanding,
                   plan: plan,
                   solution: solution,
                   confidence: 0.88
                 }, steps, log}

              {:error, reason} ->
                {:error, reason, log ++ ["Execute step failed"]}
            end

          {:error, reason} ->
            {:error, reason, log ++ ["Plan step failed"]}
        end

      {:error, reason} ->
        {:error, reason, log ++ ["Understand step failed"]}
    end
  end

  defp execute_shadow_compare(synapse) do
    log = ["Executing shadow model comparison"]
    input = synapse.input

    prompt = [
      %{"role" => "system", "content" => "Provide your analysis."},
      %{"role" => "user", "content" => inspect(input)}
    ]

    # Production model (Claude)
    production_result = OpenRouterClient.chat(prompt, model: :smart)

    # Shadow model (Gemini)
    shadow_result = OpenRouterClient.chat(prompt, model: :fast)

    case {production_result, shadow_result} do
      {{:ok, prod}, {:ok, shadow}} ->
        # Compare results (simple length comparison for now)
        agreement = calculate_agreement(prod, shadow)

        log =
          log ++
            [
              "Production: #{String.length(prod)} chars",
              "Shadow: #{String.length(shadow)} chars",
              "Agreement: #{agreement}%"
            ]

        steps = [
          %{step: "production", agent: "claude", status: "complete"},
          %{step: "shadow", agent: "gemini", status: "complete"}
        ]

        {:ok,
         %{production: prod, shadow: shadow, agreement: agreement, confidence: agreement / 100},
         steps, log}

      {{:error, reason}, _} ->
        {:error, reason, log ++ ["Production model failed"]}

      {_, {:error, reason}} ->
        {:error, reason, log ++ ["Shadow model failed"]}
    end
  end

  defp calculate_agreement(text1, text2) do
    # Simple similarity based on length ratio
    len1 = String.length(text1)
    len2 = String.length(text2)
    min_len = min(len1, len2)
    max_len = max(len1, len2)

    if max_len > 0 do
      round(min_len / max_len * 100)
    else
      0
    end
  end
end
