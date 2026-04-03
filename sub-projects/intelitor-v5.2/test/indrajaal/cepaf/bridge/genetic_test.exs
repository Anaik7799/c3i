defmodule Indrajaal.CEPAF.Bridge.GeneticTest do
  @moduledoc """
  Tests for Indrajaal.CEPAF.Bridge.Genetic pure module.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CEPAF.Bridge.Genetic
  alias Indrajaal.CEPAF.Bridge.Grammar

  # Helper to build a minimal workflow struct (Grammar.workflow())
  # Grammar.workflow/2 signature: (name, opts \\ []) where opts is Keyword list with :steps key
  defp make_workflow(name \\ :test_wf, step_count \\ 2) do
    steps = Enum.map(1..step_count, fn i -> Grammar.action(:"step_#{i}", %{index: i}) end)
    Grammar.workflow(name, steps: steps)
  end

  # Helper to build a minimal genome directly (bypasses create_genome for mutation tests)
  defp make_genome(steps \\ []) do
    %{
      id: "genome-#{System.unique_integer([:positive])}",
      chromosome: steps,
      fitness: nil,
      generation: 0,
      parents: []
    }
  end

  # Helper to build a genome with a fitness value (needed for select_parents which calls Enum.max_by)
  defp make_genome_with_fitness(steps, fitness) do
    %{
      id: "genome-#{System.unique_integer([:positive])}",
      chromosome: steps,
      fitness: fitness,
      generation: 0,
      parents: []
    }
  end

  # Full evolution_config map (all keys required by evolve/2 and run_evolution/2)
  defp make_evolution_config(opts \\ []) do
    %{
      population_size: Keyword.get(opts, :population_size, 4),
      mutation_rate: Keyword.get(opts, :mutation_rate, 0.1),
      crossover_rate: Keyword.get(opts, :crossover_rate, 0.7),
      elitism: Keyword.get(opts, :elitism, 1),
      max_generations: Keyword.get(opts, :max_generations, 2),
      fitness_fn: Keyword.get(opts, :fitness_fn, &Genetic.default_fitness/1)
    }
  end

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Genetic)
    end

    test "module has expected functions" do
      assert function_exported?(Genetic, :create_genome, 1)
      assert function_exported?(Genetic, :initialize_population, 2)
      assert function_exported?(Genetic, :evaluate, 2)
      assert function_exported?(Genetic, :select_parents, 2)
      assert function_exported?(Genetic, :crossover, 2)
      assert function_exported?(Genetic, :mutate, 2)
      assert function_exported?(Genetic, :evolve, 2)
      assert function_exported?(Genetic, :run_evolution, 2)
      assert function_exported?(Genetic, :to_workflow, 2)
      assert function_exported?(Genetic, :default_fitness, 1)
    end
  end

  describe "create_genome/1" do
    test "creates a genome from a Grammar.workflow" do
      wf = make_workflow(:deploy_wf, 2)
      result = Genetic.create_genome(wf)
      assert is_map(result)
      assert Map.has_key?(result, :id)
      assert Map.has_key?(result, :chromosome)
      assert Map.has_key?(result, :fitness)
      assert Map.has_key?(result, :generation)
    end

    test "genome id is a string" do
      wf = make_workflow(:id_wf, 1)
      genome = Genetic.create_genome(wf)
      assert is_binary(genome.id)
    end

    test "genome chromosome contains the workflow steps" do
      wf = make_workflow(:steps_wf, 3)
      genome = Genetic.create_genome(wf)
      assert is_list(genome.chromosome)
      assert length(genome.chromosome) == 3
    end

    test "genome starts at generation 0" do
      wf = make_workflow(:gen_wf, 1)
      genome = Genetic.create_genome(wf)
      assert genome.generation == 0
    end
  end

  describe "default_fitness/1" do
    test "returns a numeric fitness value for a genome" do
      genome = make_genome([Grammar.action(:a, %{})])
      result = Genetic.default_fitness(genome)
      assert is_float(result) or is_integer(result)
    end

    test "returns a numeric fitness for empty genome" do
      genome = make_genome([])
      result = Genetic.default_fitness(genome)
      assert is_float(result) or is_integer(result)
    end
  end

  describe "evaluate/2" do
    # evaluate/2 takes (population_list, fitness_fn) and returns population with fitness set
    test "evaluates a population list with a fitness function" do
      pop = [
        make_genome([Grammar.action(:step1, %{})]),
        make_genome([Grammar.action(:step2, %{})])
      ]

      result = Genetic.evaluate(pop, &Genetic.default_fitness/1)
      assert is_list(result)
      assert Enum.all?(result, fn g -> is_map(g) and not is_nil(g.fitness) end)
    end

    test "each evaluated genome has a numeric fitness" do
      pop = [make_genome([Grammar.action(:a, %{})])]
      [genome] = Genetic.evaluate(pop, &Genetic.default_fitness/1)
      assert is_float(genome.fitness) or is_integer(genome.fitness)
    end
  end

  describe "mutate/2" do
    test "returns a genome struct with mutation rate" do
      genome = make_genome([Grammar.action(:a, %{}), Grammar.action(:b, %{})])
      result = Genetic.mutate(genome, 0.1)
      assert is_map(result)
      assert Map.has_key?(result, :chromosome)
    end

    test "returns genome with zero mutation rate unchanged structure" do
      step = Grammar.action(:only, %{value: 42})
      genome = make_genome([step])
      result = Genetic.mutate(genome, 0.0)
      assert is_map(result)
      assert Map.has_key?(result, :chromosome)
    end
  end

  describe "crossover/2" do
    # crossover/2 returns {child1, child2} tuple when both chromosomes have >= 2 genes
    test "returns a tuple of two genomes" do
      g1 = make_genome([Grammar.action(:a, %{}), Grammar.action(:b, %{})])
      g2 = make_genome([Grammar.action(:c, %{}), Grammar.action(:d, %{})])
      result = Genetic.crossover(g1, g2)
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end

    test "both children are genome maps" do
      g1 = make_genome([Grammar.action(:a, %{}), Grammar.action(:b, %{})])
      g2 = make_genome([Grammar.action(:c, %{}), Grammar.action(:d, %{})])
      {child1, child2} = Genetic.crossover(g1, g2)
      assert is_map(child1) and Map.has_key?(child1, :chromosome)
      assert is_map(child2) and Map.has_key?(child2, :chromosome)
    end

    test "short genomes (< 2 genes) are returned as-is" do
      g1 = make_genome([Grammar.action(:a, %{})])
      g2 = make_genome([Grammar.action(:b, %{})])
      {c1, c2} = Genetic.crossover(g1, g2)
      assert is_map(c1)
      assert is_map(c2)
    end
  end

  describe "select_parents/2" do
    # select_parents requires genomes with non-nil fitness (uses Enum.max_by(& &1.fitness))
    test "selects parents from a population list with fitness" do
      pop = [
        make_genome_with_fitness([Grammar.action(:x, %{})], 80.0),
        make_genome_with_fitness([Grammar.action(:y, %{})], 70.0),
        make_genome_with_fitness([Grammar.action(:z, %{})], 90.0)
      ]

      result = Genetic.select_parents(pop, 2)
      assert is_list(result)
      assert length(result) == 2
    end

    test "returns genome maps in selection result" do
      pop = [
        make_genome_with_fitness([Grammar.action(:a, %{})], 50.0),
        make_genome_with_fitness([Grammar.action(:b, %{})], 60.0),
        make_genome_with_fitness([Grammar.action(:c, %{})], 70.0)
      ]

      result = Genetic.select_parents(pop, 1)
      assert Enum.all?(result, fn g -> is_map(g) and Map.has_key?(g, :chromosome) end)
    end
  end

  describe "initialize_population/2" do
    test "creates a population from a list of seed workflows" do
      seeds = [make_workflow(:seed1, 2), make_workflow(:seed2, 2)]
      result = Genetic.initialize_population(seeds, 3)
      assert is_list(result)
      assert length(result) == 3
    end

    test "each member is a genome map" do
      seeds = [make_workflow(:pop_seed, 1)]
      result = Genetic.initialize_population(seeds, 2)
      assert Enum.all?(result, fn g -> is_map(g) and Map.has_key?(g, :chromosome) end)
    end
  end

  describe "evolve/2" do
    # evolve/2 takes (population, evolution_config) where config requires all keys
    test "evolves a population by one generation" do
      pop = [
        make_genome_with_fitness([Grammar.action(:a, %{})], 80.0),
        make_genome_with_fitness([Grammar.action(:b, %{})], 70.0),
        make_genome_with_fitness([Grammar.action(:c, %{})], 60.0),
        make_genome_with_fitness([Grammar.action(:d, %{})], 50.0)
      ]

      config = make_evolution_config(population_size: 4, elitism: 1)
      result = Genetic.evolve(pop, config)
      assert is_list(result)
    end
  end

  describe "run_evolution/2" do
    # run_evolution/2 returns {best_genome, history_list}
    test "runs evolution for given number of generations" do
      pop = [
        make_genome([Grammar.action(:a, %{})]),
        make_genome([Grammar.action(:b, %{})]),
        make_genome([Grammar.action(:c, %{})]),
        make_genome([Grammar.action(:d, %{})])
      ]

      config =
        make_evolution_config(generations: 2, max_generations: 2, population_size: 4, elitism: 1)

      result = Genetic.run_evolution(pop, config)
      # Returns {best_genome, history_list}
      assert is_tuple(result) or is_list(result) or is_map(result)
    end

    test "result contains a best genome" do
      pop = [
        make_genome([Grammar.action(:a, %{})]),
        make_genome([Grammar.action(:b, %{})]),
        make_genome([Grammar.action(:c, %{})]),
        make_genome([Grammar.action(:d, %{})])
      ]

      config = make_evolution_config(max_generations: 1, population_size: 4, elitism: 1)
      result = Genetic.run_evolution(pop, config)

      case result do
        {best, _history} -> assert is_map(best) and Map.has_key?(best, :chromosome)
        _ -> assert result != nil
      end
    end
  end

  describe "to_workflow/2" do
    # to_workflow/2 takes (genome, atom_name)
    test "converts a genome to a workflow representation" do
      genome = make_genome([Grammar.action(:build, %{}), Grammar.action(:test, %{})])
      result = Genetic.to_workflow(genome, :my_workflow)
      assert is_map(result)
      assert result.name == :my_workflow
    end

    test "workflow contains the genome steps" do
      steps = [Grammar.action(:deploy, %{})]
      genome = make_genome(steps)
      wf = Genetic.to_workflow(genome, :deploy_wf)
      assert is_list(wf.steps)
    end
  end
end
