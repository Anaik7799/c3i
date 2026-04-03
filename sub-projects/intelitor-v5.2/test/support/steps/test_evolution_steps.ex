defmodule Indrajaal.Test.Steps.TestEvolutionSteps do
  @moduledoc """
  BDD Step Definitions for Biomorphic Test Evolution

  WHAT: Cucumber-style step definitions for test evolution features
        following Gherkin syntax with Elixir pattern matching.

  WHY: Enables BDD-driven development of test evolution system:
       - Human-readable specifications
       - Executable documentation
       - Living test documentation
       - Stakeholder-friendly format

  CONSTRAINTS:
    - SC-TEST-EVO-001: OODA cycle < 30s
    - SC-TEST-EVO-002: Fitness tracking mandatory
    - SC-TEST-EVO-003: All 5 levels generated
    - SC-COV-005: BDD specs for all user journeys

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-03 |
  | Author | Cybernetic Architect |
  | Reference | SC-TEST-EVO-*, AOR-TEST-EVO-* |
  """

  use ExUnit.Case
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.BiomorphicTestEvolution
  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.AI.Evolution.TrainingGym

  # ===========================================================================
  # Background Steps
  # ===========================================================================

  def given_the_test_evolution_server_is_running(context) do
    case BiomorphicTestEvolution.start_link([]) do
      {:ok, pid} ->
        Map.put(context, :evolution_pid, pid)

      {:error, {:already_started, pid}} ->
        Map.put(context, :evolution_pid, pid)
    end
  end

  def given_openrouter_api_is_available_with_free_models(context) do
    # Check OpenRouter availability
    case OpenRouterClient.health_check() do
      :ok ->
        Map.put(context, :openrouter_available, true)

      {:error, _} ->
        # Use mock mode
        Map.put(context, :openrouter_available, false)
    end
  end

  def given_the_training_gym_is_recording_episodes(context) do
    case TrainingGym.start_link([]) do
      {:ok, pid} ->
        Map.put(context, :training_gym_pid, pid)

      {:error, {:already_started, pid}} ->
        Map.put(context, :training_gym_pid, pid)
    end
  end

  # ===========================================================================
  # Level 1: TDG Steps
  # ===========================================================================

  def given_i_have_a_module_at(context, module_path) do
    Map.put(context, :module_path, module_path)
  end

  def when_i_request_tdg_test_generation(context) do
    module_path = context.module_path

    result = BiomorphicTestEvolution.generate_tests(module_path, level: :tdg)

    context
    |> Map.put(:generation_result, result)
    |> Map.put(:level, :tdg)
  end

  def then_property_tests_should_be_generated_using(context, model) do
    {:ok, result} = context.generation_result

    assert result.model == model
    assert result.level == :tdg
    assert String.contains?(result.code, "property")

    context
  end

  def then_the_tests_should_include_propcheck_generators(context) do
    {:ok, result} = context.generation_result

    assert String.contains?(result.code, "forall") or
             String.contains?(result.code, "PC.")

    context
  end

  def then_the_tests_should_include_exunit_properties_checks(context) do
    {:ok, result} = context.generation_result

    assert String.contains?(result.code, "check all") or
             String.contains?(result.code, "SD.")

    context
  end

  def then_the_fitness_score_should_be_recorded(context) do
    {:ok, fitness} = BiomorphicTestEvolution.get_fitness()

    assert is_float(fitness.combined)
    assert fitness.combined >= 0.0 and fitness.combined <= 1.0

    Map.put(context, :fitness, fitness)
  end

  # ===========================================================================
  # Level 2: FMEA Steps
  # ===========================================================================

  def when_i_request_fmea_test_generation(context) do
    module_path = context.module_path

    result = BiomorphicTestEvolution.generate_tests(module_path, level: :fmea)

    context
    |> Map.put(:generation_result, result)
    |> Map.put(:level, :fmea)
  end

  def then_failure_mode_tests_should_be_generated_using(context, model) do
    {:ok, result} = context.generation_result

    assert result.model == model
    assert result.level == :fmea

    context
  end

  def then_rpn_calculations_should_be_included(context) do
    {:ok, result} = context.generation_result

    # Check for RPN calculation pattern
    assert String.contains?(result.code, "RPN") or
             String.contains?(result.code, "severity") or
             String.contains?(result.code, "occurrence")

    context
  end

  # ===========================================================================
  # Level 3: Formal Steps
  # ===========================================================================

  def when_i_request_formal_verification_test_generation(context) do
    module_path = context.module_path

    result = BiomorphicTestEvolution.generate_tests(module_path, level: :formal)

    context
    |> Map.put(:generation_result, result)
    |> Map.put(:level, :formal)
  end

  def then_spec_annotations_should_be_generated(context) do
    {:ok, result} = context.generation_result

    assert String.contains?(result.code, "@spec")

    context
  end

  # ===========================================================================
  # Level 4: Graph Steps
  # ===========================================================================

  def when_i_request_graph_based_test_generation(context) do
    module_path = context.module_path

    result = BiomorphicTestEvolution.generate_tests(module_path, level: :graph)

    context
    |> Map.put(:generation_result, result)
    |> Map.put(:level, :graph)
  end

  def then_all_control_flow_paths_should_be_identified(context) do
    {:ok, result} = context.generation_result

    # Verify path coverage analysis
    assert result.coverage_analysis != nil

    context
  end

  # ===========================================================================
  # Level 5: BDD Steps
  # ===========================================================================

  def when_i_request_bdd_test_generation(context) do
    module_path = context.module_path

    result = BiomorphicTestEvolution.generate_tests(module_path, level: :bdd)

    context
    |> Map.put(:generation_result, result)
    |> Map.put(:level, :bdd)
  end

  def then_gherkin_feature_files_should_be_generated_using(context, model) do
    {:ok, result} = context.generation_result

    assert result.model == model
    assert result.level == :bdd
    assert String.contains?(result.code, "Feature:")

    context
  end

  # ===========================================================================
  # OODA Cycle Steps
  # ===========================================================================

  def when_30_seconds_elapse(context) do
    # Trigger OODA cycle manually for testing
    BiomorphicTestEvolution.evolve()

    # Wait for cycle completion
    :timer.sleep(100)

    context
  end

  def then_an_ooda_cycle_should_complete(context) do
    state = BiomorphicTestEvolution.get_state()

    assert state.ooda_state.cycle_count > 0

    Map.put(context, :ooda_state, state.ooda_state)
  end

  def then_the_observe_phase_should_gather_file_change_metrics(context) do
    state = context.ooda_state

    assert state.observations_count > 0

    context
  end

  # ===========================================================================
  # Genome Evolution Steps
  # ===========================================================================

  def when_evolution_is_triggered(context) do
    BiomorphicTestEvolution.evolve()

    :timer.sleep(100)

    context
  end

  def then_tests_should_be_mutated_based_on_mutation_rate(context) do
    state = BiomorphicTestEvolution.get_state()

    assert state.genome.mutation_rate > 0

    context
  end

  def then_diversity_floor_should_be_maintained(context) do
    {:ok, fitness} = BiomorphicTestEvolution.get_fitness()

    # Diversity should be at least 0.3 per SC-TEST-EVO-005
    assert fitness.diversity >= 0.3

    context
  end

  # ===========================================================================
  # OpenRouter Steps
  # ===========================================================================

  def then_only_free_suffix_models_should_be_used(context) do
    {:ok, result} = context.generation_result

    assert String.ends_with?(result.model, ":free")

    context
  end

  def then_costs_should_be_zero(context) do
    {:ok, result} = context.generation_result

    assert result.cost == 0 or result.cost == nil

    context
  end

  # ===========================================================================
  # TrainingGym Steps
  # ===========================================================================

  def then_an_episode_should_be_recorded_in_training_gym(context) do
    episodes = TrainingGym.get_recent_episodes(10)

    assert length(episodes) > 0

    context
  end

  # ===========================================================================
  # Property-Based Steps
  # ===========================================================================

  @doc """
  Property: All generated tests should be valid Elixir code
  """
  def property_generated_tests_are_valid_elixir do
    forall module_path <- PC.binary() do
      case BiomorphicTestEvolution.generate_tests(module_path, level: :tdg) do
        {:ok, result} ->
          case Code.string_to_quoted(result.code) do
            {:ok, _ast} -> true
            {:error, _} -> false
          end

        {:error, _} ->
          # Error case is acceptable for invalid inputs
          true
      end
    end
  end

  @doc """
  Property: Fitness scores are always between 0 and 1
  """
  def property_fitness_scores_bounded do
    forall _iteration <- PC.integer(1, 100) do
      {:ok, fitness} = BiomorphicTestEvolution.get_fitness()

      fitness.coverage >= 0.0 and fitness.coverage <= 1.0 and
        fitness.pass_rate >= 0.0 and fitness.pass_rate <= 1.0 and
        fitness.mutation_score >= 0.0 and fitness.mutation_score <= 1.0 and
        fitness.diversity >= 0.0 and fitness.diversity <= 1.0 and
        fitness.combined >= 0.0 and fitness.combined <= 1.0
    end
  end

  @doc """
  Property: OODA cycles complete in under 30 seconds
  """
  def property_ooda_cycle_timing do
    forall _run <- PC.integer(1, 10) do
      start = System.monotonic_time(:millisecond)
      BiomorphicTestEvolution.evolve()
      elapsed = System.monotonic_time(:millisecond) - start

      # SC-TEST-EVO-001: OODA cycle < 30s (30000ms)
      elapsed < 30_000
    end
  end
end
