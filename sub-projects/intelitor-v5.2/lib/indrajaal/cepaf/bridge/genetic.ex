defmodule Indrajaal.CEPAF.Bridge.Genetic do
  @moduledoc """
  CEPAF Genetic - Evolutionary Algorithm Components for v20.0.0

  Implements genetic programming for workflow optimization:
  - Genome representation
  - Crossover operators
  - Mutation operators
  - Fitness evaluation

  ## Genetic Model

  Workflows as genomes:
  - Genes = workflow steps
  - Chromosomes = step sequences
  - Fitness = performance + correctness

  Evolution: select → crossover → mutate → evaluate → repeat

  ## STAMP Constraints
  - SC-GEN-001: Mutations MUST preserve validity
  - SC-GEN-002: Crossover MUST maintain structure
  - SC-GEN-003: Fitness MUST be deterministic
  - SC-GEN-004: Population diversity MUST be maintained
  """

  require Logger

  alias Indrajaal.CEPAF.Bridge.Grammar

  @type gene :: Grammar.step()
  @type chromosome :: [gene()]
  @type genome :: %{
          id: String.t(),
          chromosome: chromosome(),
          fitness: float() | nil,
          generation: non_neg_integer(),
          parents: [String.t()]
        }

  @type population :: [genome()]

  @type evolution_config :: %{
          population_size: non_neg_integer(),
          mutation_rate: float(),
          crossover_rate: float(),
          elitism: non_neg_integer(),
          max_generations: non_neg_integer(),
          fitness_fn: (genome() -> float())
        }

  # Default population size
  @default_population_size 50

  # Default mutation rate
  @default_mutation_rate 0.1

  @doc """
  Creates a new genome from a workflow.
  """
  @spec create_genome(Grammar.workflow()) :: genome()
  def create_genome(workflow) do
    %{
      id: generate_id(),
      chromosome: workflow.steps,
      fitness: nil,
      generation: 0,
      parents: []
    }
  end

  @doc """
  Creates initial population from seed workflows.
  """
  @spec initialize_population([Grammar.workflow()], non_neg_integer()) :: population()
  def initialize_population(seeds, population_size \\ @default_population_size) do
    seed_genomes = seeds |> Enum.map(&create_genome/1)
    seed_count = length(seed_genomes)

    # Fill remaining with mutations of seeds
    additional =
      if seed_count < population_size do
        1..(population_size - seed_count)
        |> Enum.map(fn _ ->
          base = Enum.random(seed_genomes)
          mutate(base, @default_mutation_rate)
        end)
      else
        []
      end

    (seed_genomes ++ additional)
    |> Enum.take(population_size)
  end

  @doc """
  Evaluates fitness for all genomes in population.
  """
  @spec evaluate(population(), (genome() -> float())) :: population()
  def evaluate(population, fitness_fn) do
    population
    |> Enum.map(fn genome ->
      fitness = fitness_fn.(genome)
      %{genome | fitness: fitness}
    end)
  end

  @doc """
  Selects parents using tournament selection.
  """
  @spec select_parents(population(), non_neg_integer()) :: [genome()]
  def select_parents(population, count) do
    tournament_size = 3

    Enum.map(1..count, fn _ ->
      population
      |> Enum.take_random(tournament_size)
      |> Enum.max_by(& &1.fitness)
    end)
  end

  @doc """
  Performs crossover between two genomes.
  """
  @spec crossover(genome(), genome()) :: {genome(), genome()}
  def crossover(parent1, parent2) do
    len1 = length(parent1.chromosome)
    len2 = length(parent2.chromosome)

    if len1 < 2 or len2 < 2 do
      {parent1, parent2}
    else
      # Single-point crossover
      point1 = :rand.uniform(len1 - 1)
      point2 = :rand.uniform(len2 - 1)

      {head1, tail1} = Enum.split(parent1.chromosome, point1)
      {head2, tail2} = Enum.split(parent2.chromosome, point2)

      child1 = %{
        id: generate_id(),
        chromosome: head1 ++ tail2,
        fitness: nil,
        generation: max(parent1.generation, parent2.generation) + 1,
        parents: [parent1.id, parent2.id]
      }

      child2 = %{
        id: generate_id(),
        chromosome: head2 ++ tail1,
        fitness: nil,
        generation: max(parent1.generation, parent2.generation) + 1,
        parents: [parent1.id, parent2.id]
      }

      {child1, child2}
    end
  end

  @doc """
  Mutates a genome with given probability.
  """
  @spec mutate(genome(), float()) :: genome()
  def mutate(genome, rate \\ @default_mutation_rate) do
    if :rand.uniform() < rate do
      mutation_type = Enum.random([:swap, :insert, :delete, :modify])
      mutated_chromosome = apply_mutation(genome.chromosome, mutation_type)

      %{
        genome
        | id: generate_id(),
          chromosome: mutated_chromosome,
          fitness: nil
      }
    else
      genome
    end
  end

  @doc """
  Evolves population for one generation.
  """
  @spec evolve(population(), evolution_config()) :: population()
  def evolve(population, config) do
    # Evaluate fitness
    evaluated = evaluate(population, config.fitness_fn)

    # Sort by fitness (descending)
    sorted = Enum.sort_by(evaluated, & &1.fitness, :desc)

    # Elitism: keep top performers
    elite = Enum.take(sorted, config.elitism)

    # Select parents for remaining slots
    offspring_count = config.population_size - config.elitism
    parents = select_parents(sorted, offspring_count * 2)

    # Generate offspring
    offspring =
      parents
      |> Enum.chunk_every(2)
      |> Enum.flat_map(fn
        [p1, p2] ->
          if :rand.uniform() < config.crossover_rate do
            {c1, c2} = crossover(p1, p2)
            [mutate(c1, config.mutation_rate), mutate(c2, config.mutation_rate)]
          else
            [mutate(p1, config.mutation_rate), mutate(p2, config.mutation_rate)]
          end

        [p1] ->
          [mutate(p1, config.mutation_rate)]
      end)
      |> Enum.take(offspring_count)

    elite ++ offspring
  end

  @doc """
  Runs full evolution process.
  """
  @spec run_evolution(population(), evolution_config()) :: {genome(), [map()]}
  def run_evolution(population, config) do
    run_evolution(population, config, 0, [])
  end

  defp run_evolution(population, config, generation, history)
       when generation >= config.max_generations do
    best = population |> evaluate(config.fitness_fn) |> Enum.max_by(& &1.fitness)
    {best, Enum.reverse(history)}
  end

  defp run_evolution(population, config, generation, history) do
    new_population = evolve(population, config)

    # Track statistics
    evaluated = evaluate(new_population, config.fitness_fn)
    fitnesses = evaluated |> Enum.map(& &1.fitness)

    stats = %{
      generation: generation,
      best_fitness: Enum.max(fitnesses),
      avg_fitness: Enum.sum(fitnesses) / length(fitnesses),
      worst_fitness: Enum.min(fitnesses),
      diversity: calculate_diversity(new_population)
    }

    Logger.debug("Generation #{generation}: best=#{stats.best_fitness}, avg=#{stats.avg_fitness}")

    run_evolution(new_population, config, generation + 1, [stats | history])
  end

  @doc """
  Converts genome back to workflow.
  """
  @spec to_workflow(genome(), atom()) :: Grammar.workflow()
  def to_workflow(genome, name) do
    %{
      name: name,
      steps: genome.chromosome,
      inputs: [],
      outputs: [],
      metadata: %{
        genome_id: genome.id,
        generation: genome.generation,
        fitness: genome.fitness
      }
    }
  end

  @doc """
  Default fitness function based on step count and estimated performance.
  """
  @spec default_fitness(genome()) :: float()
  def default_fitness(genome) do
    step_count = length(genome.chromosome)
    parallel_count = count_parallel_steps(genome.chromosome)

    # Favor workflows with:
    # - Fewer total steps (efficiency)
    # - More parallel steps (throughput)
    # - Proper structure (validity)

    base_score = 100.0
    step_penalty = step_count * 2.0
    parallel_bonus = parallel_count * 5.0
    validity_score = if valid_structure?(genome.chromosome), do: 50.0, else: 0.0

    max(0.0, base_score - step_penalty + parallel_bonus + validity_score)
  end

  # Private helpers

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(bytes, case: :lower)
  end

  defp apply_mutation(chromosome, :swap) when length(chromosome) >= 2 do
    idx1 = :rand.uniform(length(chromosome)) - 1
    idx2 = :rand.uniform(length(chromosome)) - 1

    if idx1 != idx2 do
      list = Enum.to_list(chromosome)
      elem1 = Enum.at(list, idx1)
      elem2 = Enum.at(list, idx2)

      list
      |> List.replace_at(idx1, elem2)
      |> List.replace_at(idx2, elem1)
    else
      chromosome
    end
  end

  defp apply_mutation(chromosome, :insert) do
    # Insert a random simple step
    new_step = %{
      type: :action,
      name: Enum.random([:log, :delay, :checkpoint]),
      body: [],
      constraints: [],
      metadata: %{mutated: true}
    }

    idx = :rand.uniform(length(chromosome) + 1) - 1
    List.insert_at(chromosome, idx, new_step)
  end

  defp apply_mutation(chromosome, :delete) when length(chromosome) > 1 do
    idx = :rand.uniform(length(chromosome)) - 1
    List.delete_at(chromosome, idx)
  end

  defp apply_mutation(chromosome, :modify) when length(chromosome) >= 1 do
    idx = :rand.uniform(length(chromosome)) - 1
    step = Enum.at(chromosome, idx)

    modified_step =
      case step.type do
        :action ->
          # Modify constraints
          new_constraints =
            if Enum.empty?(step.constraints) do
              [%{type: :timeout, value: :rand.uniform(10_000)}]
            else
              []
            end

          %{step | constraints: new_constraints}

        :parallel ->
          # Shuffle parallel steps
          %{step | body: Enum.shuffle(step.body)}

        _ ->
          step
      end

    List.replace_at(chromosome, idx, modified_step)
  end

  defp apply_mutation(chromosome, _), do: chromosome

  defp count_parallel_steps(chromosome) do
    Enum.count(chromosome, fn step -> step.type == :parallel end)
  end

  defp valid_structure?(chromosome) do
    # Check basic structural validity
    chromosome
    |> Enum.all?(fn step ->
      step.type in [:action, :parallel, :choice, :loop, :sequence]
    end)
  end

  defp calculate_diversity(population) do
    # Simple diversity metric based on chromosome lengths
    lengths = population |> Enum.map(fn g -> length(g.chromosome) end)

    if length(lengths) > 1 do
      mean = Enum.sum(lengths) / length(lengths)

      variance =
        (lengths |> Enum.map(fn l -> :math.pow(l - mean, 2) end) |> Enum.sum()) / length(lengths)

      :math.sqrt(variance)
    else
      0.0
    end
  end
end
