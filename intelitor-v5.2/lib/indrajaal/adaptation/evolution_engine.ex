defmodule Indrajaal.Adaptation.EvolutionEngine do
  @moduledoc """
  Evolution Engine — L6 Adaptation Layer

  Implements a genetic algorithm (GA) for continuous system configuration
  optimization. The GA evolves chromosomes representing operational parameters
  toward configurations that maximize the composite system health score.

  ## STAMP Constraints
  - SC-EVO-001: Evolution MUST follow hardened protocol (Genetic Selection, Wire-Level Proofs, KL Throttling)
  - SC-EVO-002: Genetic selection MUST be reproducible
  - SC-EVO-003: Mutation MUST be bounded — no runaway parameter changes
  - SC-EVO-004: Generation history MUST be tracked for lineage preservation
  - SC-HA-011: Chaos testing validates SIL-6 resilience (evolution driver)
  - SC-SWARM-001: Convergence required (shared with PSO)

  ## Chromosome Encoding
  Each chromosome encodes operational parameters:
  - scheduler_count: Erlang scheduler threads (4–16)
  - pool_size: Database connection pool size (5–50)
  - timeout_ms: Operation timeout (1000–30000)
  - batch_size: Processing batch size (10–500)
  - cache_ttl_s: Cache TTL in seconds (30–3600)

  ## GA Operators
  - **Selection**: Tournament selection (k=3)
  - **Crossover**: Single-point crossover (rate: 0.8)
  - **Mutation**: Bounded Gaussian perturbation (rate: 0.1, σ=0.05)
  - **Elitism**: Top 10% carry over unchanged

  Generation history is stored in-memory (last 100 generations) for lineage.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L6 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @default_pop_size 40
  @max_generations 200
  @crossover_rate 0.8
  @mutation_rate 0.1
  @tournament_k 3
  @elitism_pct 0.10
  @convergence_eps 1.0e-5
  @history_limit 100
  @pubsub_topic "evolution:results"

  # Chromosome gene definitions: {name, min, max, type}
  @genes [
    {:scheduler_count, 4, 16, :integer},
    {:pool_size, 5, 50, :integer},
    {:timeout_ms, 1_000, 30_000, :integer},
    {:batch_size, 10, 500, :integer},
    {:cache_ttl_s, 30, 3_600, :integer}
  ]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type chromosome :: [number()]
  @type individual :: %{genes: chromosome(), fitness: float()}
  @type generation_record :: %{
          generation: non_neg_integer(),
          best_fitness: float(),
          avg_fitness: float(),
          best_genes: chromosome(),
          timestamp: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Run genetic algorithm evolution with a fitness function."
  @spec evolve(fun(), keyword()) :: {:ok, map()} | {:error, term()}
  def evolve(fitness_fn, opts \\ []) when is_function(fitness_fn, 1) do
    GenServer.call(@name, {:evolve, fitness_fn, opts}, 120_000)
  end

  @doc "Get the last N generation records."
  @spec generation_history(non_neg_integer()) :: [generation_record()]
  def generation_history(n \\ 10) do
    GenServer.call(@name, {:generation_history, n})
  end

  @doc "Returns the gene names (chromosome dimension labels)."
  @spec gene_names() :: [atom()]
  def gene_names do
    Enum.map(@genes, fn {name, _, _, _} -> name end)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    pop_size = Keyword.get(opts, :population_size, @default_pop_size)

    state = %{
      population_size: pop_size,
      history: []
    }

    Logger.info(
      "[EvolutionEngine] Started — pop_size=#{pop_size} genes=#{length(@genes)} [SC-EVO-001]"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:evolve, fitness_fn, opts}, _from, state) do
    pop_size = Keyword.get(opts, :population_size, state.population_size)
    max_gen = Keyword.get(opts, :max_generations, @max_generations)

    {result, history} = run_ga(fitness_fn, pop_size, max_gen)

    all_history =
      (history ++ state.history)
      |> Enum.take(@history_limit)

    state2 = %{state | history: all_history}

    broadcast_result(result)

    {:reply, {:ok, result}, state2}
  end

  @impl true
  def handle_call({:generation_history, n}, _from, state) do
    {:reply, Enum.take(state.history, n), state}
  end

  # ---------------------------------------------------------------------------
  # Genetic Algorithm Implementation
  # ---------------------------------------------------------------------------

  defp run_ga(fitness_fn, pop_size, max_gen) do
    population = initialize_population(pop_size, fitness_fn)

    {final_pop, history, gen, converged} =
      ga_loop(population, fitness_fn, 0, max_gen, [])

    best = Enum.max_by(final_pop, & &1.fitness)

    Logger.info(
      "[EvolutionEngine] Evolution complete: gen=#{gen} converged=#{converged} " <>
        "best_fitness=#{Float.round(best.fitness, 6)} [SC-EVO-001]"
    )

    :telemetry.execute(
      [:indrajaal, :adaptation, :evolution, :complete],
      %{best_fitness: best.fitness, generations: gen},
      %{converged: converged}
    )

    result = %{
      best_genes: decode_chromosome(best.genes),
      best_fitness: best.fitness,
      generations: gen,
      converged: converged,
      population_size: length(final_pop)
    }

    {result, history}
  rescue
    e ->
      Logger.error("[EvolutionEngine] GA failed: #{inspect(e)}")

      {%{
         best_genes: %{},
         best_fitness: 0.0,
         generations: 0,
         converged: false,
         population_size: 0
       }, []}
  end

  defp ga_loop(population, _fitness_fn, gen, max_gen, history) when gen >= max_gen do
    {population, history, gen, false}
  end

  defp ga_loop(population, fitness_fn, gen, max_gen, history) do
    best = Enum.max_by(population, & &1.fitness)
    avg = Enum.sum(Enum.map(population, & &1.fitness)) / length(population)

    record = %{
      generation: gen,
      best_fitness: best.fitness,
      avg_fitness: avg,
      best_genes: best.genes,
      timestamp: System.system_time(:millisecond)
    }

    history2 = [record | history]

    # Check convergence over last 10 generations
    converged =
      if length(history2) >= 10 do
        recent = Enum.take(history2, 10) |> Enum.map(& &1.best_fitness)
        max_fit = Enum.max(recent)
        min_fit = Enum.min(recent)
        abs(max_fit - min_fit) < @convergence_eps
      else
        false
      end

    if converged do
      {population, history2, gen + 1, true}
    else
      next_gen = evolve_generation(population, fitness_fn)
      ga_loop(next_gen, fitness_fn, gen + 1, max_gen, history2)
    end
  end

  defp evolve_generation(population, fitness_fn) do
    n = length(population)
    elite_count = max(1, round(n * @elitism_pct))

    # Elitism: keep top individuals unchanged
    elites =
      population
      |> Enum.sort_by(& &1.fitness, :desc)
      |> Enum.take(elite_count)

    # Fill rest via selection → crossover → mutation
    offspring_count = n - elite_count

    offspring =
      Enum.map(1..offspring_count, fn _ ->
        parent1 = tournament_select(population)
        parent2 = tournament_select(population)

        child_genes =
          if :rand.uniform() < @crossover_rate do
            single_point_crossover(parent1.genes, parent2.genes)
          else
            parent1.genes
          end

        mutated_genes = mutate(child_genes)
        fitness = evaluate_fitness(fitness_fn, mutated_genes)

        %{genes: mutated_genes, fitness: fitness}
      end)

    elites ++ offspring
  end

  defp initialize_population(pop_size, fitness_fn) do
    Enum.map(1..pop_size, fn _ ->
      genes = random_chromosome()
      fitness = evaluate_fitness(fitness_fn, genes)
      %{genes: genes, fitness: fitness}
    end)
  end

  defp random_chromosome do
    Enum.map(@genes, fn {_name, min_v, max_v, :integer} ->
      min_v + :rand.uniform(max_v - min_v + 1) - 1
    end)
  end

  defp tournament_select(population) do
    k = min(@tournament_k, length(population))

    1..k
    |> Enum.map(fn _ -> Enum.random(population) end)
    |> Enum.max_by(& &1.fitness)
  end

  defp single_point_crossover(genes1, genes2) do
    n = length(genes1)
    point = :rand.uniform(n - 1)

    Enum.take(genes1, point) ++ Enum.drop(genes2, point)
  end

  defp mutate(genes) do
    genes
    |> Enum.zip(@genes)
    |> Enum.map(fn {gene, {_name, min_v, max_v, :integer}} ->
      if :rand.uniform() < @mutation_rate do
        range = max_v - min_v
        delta = round(:rand.normal() * range * 0.05)
        new_val = gene + delta
        max(min_v, min(max_v, new_val))
      else
        gene
      end
    end)
  end

  defp decode_chromosome(genes) do
    Enum.zip(@genes, genes)
    |> Enum.map(fn {{name, _, _, _}, val} -> {name, val} end)
    |> Map.new()
  end

  defp evaluate_fitness(fitness_fn, genes) do
    decoded = decode_chromosome(genes)
    fitness_fn.(decoded)
  rescue
    _ -> 0.0
  end

  defp broadcast_result(result) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:evolution_result, result}
    )
  rescue
    _ -> :ok
  end
end
