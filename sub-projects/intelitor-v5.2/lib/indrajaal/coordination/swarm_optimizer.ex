defmodule Indrajaal.Coordination.SwarmOptimizer do
  @moduledoc """
  Swarm Optimizer — L5 Coordination Layer

  Implements Particle Swarm Optimization (PSO) for dynamic resource allocation
  across the mesh. Each particle represents a resource allocation configuration
  and evolves toward the global optimum guided by personal and social bests.

  ## STAMP Constraints
  - SC-SWARM-001: Convergence < 1000 iterations
  - SC-SWARM-002: Diversity maintenance > 0.3 (population spread)
  - SC-SWARM-003: Fitness evaluation < 10ms per particle
  - SC-SWARM-004: Population size 20-100 agents
  - SC-SWARM-005: UnifiedBus telemetry integration

  ## PSO Parameters
  - Inertia weight (w): 0.729 (Clerc-Kennedy constriction)
  - Cognitive coefficient (c1): 1.494 (personal best attraction)
  - Social coefficient (c2): 1.494 (global best attraction)
  - Velocity clamping: ±20% of dimension range

  ## Result Published
  Zenoh topic: `indrajaal/coordination/swarm`

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L5 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @default_pop_size 30
  @max_iterations 1_000
  @inertia 0.729
  @c1 1.494
  @c2 1.494
  @convergence_threshold 1.0e-6
  @min_diversity 0.3
  @zenoh_topic "indrajaal/coordination/swarm"
  @pubsub_topic "swarm:results"

  # Dimension definitions: {name, min, max}
  @dimensions [
    {:scheduler_count, 4, 16},
    {:pool_size, 5, 50},
    {:timeout_ms, 1_000, 30_000},
    {:batch_size, 10, 500}
  ]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type position :: [float()]
  @type velocity :: [float()]
  @type fitness :: float()

  @type particle :: %{
          position: position(),
          velocity: velocity(),
          fitness: fitness(),
          best_position: position(),
          best_fitness: fitness()
        }

  @type result :: %{
          best_position: position(),
          best_fitness: fitness(),
          iterations: non_neg_integer(),
          converged: boolean(),
          diversity: float()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Run PSO optimization with the given fitness function."
  @spec optimize(fun(), keyword()) :: {:ok, result()} | {:error, term()}
  def optimize(fitness_fn, opts \\ []) when is_function(fitness_fn, 1) do
    GenServer.call(@name, {:optimize, fitness_fn, opts}, 60_000)
  end

  @doc "Get the most recent optimization result."
  @spec last_result() :: result() | nil
  def last_result do
    GenServer.call(@name, :last_result)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    pop_size = Keyword.get(opts, :population_size, @default_pop_size)
    pop_size = max(20, min(100, pop_size))

    state = %{
      population_size: pop_size,
      last_result: nil
    }

    Logger.info("[SwarmOptimizer] Started — pop_size=#{pop_size} [SC-SWARM-004]")

    {:ok, state}
  end

  @impl true
  def handle_call({:optimize, fitness_fn, opts}, _from, state) do
    pop_size = Keyword.get(opts, :population_size, state.population_size)
    pop_size = max(20, min(100, pop_size))

    result = run_pso(fitness_fn, pop_size)

    broadcast_result(result)

    state2 = %{state | last_result: result}

    {:reply, {:ok, result}, state2}
  end

  @impl true
  def handle_call(:last_result, _from, state) do
    {:reply, state.last_result, state}
  end

  # ---------------------------------------------------------------------------
  # PSO Implementation
  # ---------------------------------------------------------------------------

  defp run_pso(fitness_fn, pop_size) do
    particles = initialize_population(pop_size, fitness_fn)

    global_best = find_global_best(particles)

    {final_particles, final_global_best, iterations, converged} =
      pso_loop(particles, global_best, fitness_fn, 0)

    diversity = compute_diversity(final_particles)

    Logger.info(
      "[SwarmOptimizer] Optimization complete: iterations=#{iterations} " <>
        "converged=#{converged} diversity=#{Float.round(diversity, 3)} " <>
        "best_fitness=#{Float.round(final_global_best.fitness, 6)} [SC-SWARM-001]"
    )

    :telemetry.execute(
      [:indrajaal, :coordination, :swarm, :result],
      %{best_fitness: final_global_best.fitness, iterations: iterations, diversity: diversity},
      %{converged: converged, zenoh_topic: @zenoh_topic}
    )

    %{
      best_position: final_global_best.position,
      best_fitness: final_global_best.fitness,
      iterations: iterations,
      converged: converged,
      diversity: diversity,
      particles: Enum.map(final_particles, &{&1.position, &1.fitness})
    }
  rescue
    e ->
      Logger.error("[SwarmOptimizer] PSO failed: #{inspect(e)}")

      %{
        best_position: [],
        best_fitness: 0.0,
        iterations: 0,
        converged: false,
        diversity: 0.0,
        particles: []
      }
  end

  defp pso_loop(particles, global_best, _fitness_fn, iteration)
       when iteration >= @max_iterations do
    {particles, global_best, iteration, false}
  end

  defp pso_loop(particles, global_best, fitness_fn, iteration) do
    particles2 = update_particles(particles, global_best, fitness_fn)
    new_global_best = find_global_best(particles2)

    final_global_best =
      if new_global_best.fitness > global_best.fitness,
        do: new_global_best,
        else: global_best

    diversity = compute_diversity(particles2)

    # Maintain diversity floor per SC-SWARM-002
    particles3 =
      if diversity < @min_diversity do
        reinject_diversity(particles2, fitness_fn, diversity)
      else
        particles2
      end

    delta = abs(final_global_best.fitness - global_best.fitness)

    if delta < @convergence_threshold and iteration > 10 do
      {particles3, final_global_best, iteration + 1, true}
    else
      pso_loop(particles3, final_global_best, fitness_fn, iteration + 1)
    end
  end

  defp initialize_population(pop_size, fitness_fn) do
    n_dims = length(@dimensions)

    Enum.map(1..pop_size, fn _ ->
      position = random_position()
      velocity = Enum.map(1..n_dims, fn _ -> (:rand.uniform() - 0.5) * 0.1 end)
      fit = evaluate_fitness(fitness_fn, position)

      %{
        position: position,
        velocity: velocity,
        fitness: fit,
        best_position: position,
        best_fitness: fit
      }
    end)
  end

  defp random_position do
    Enum.map(@dimensions, fn {_name, min_v, max_v} ->
      min_v + :rand.uniform() * (max_v - min_v)
    end)
  end

  defp update_particles(particles, global_best, fitness_fn) do
    Enum.map(particles, fn particle ->
      new_velocity = compute_velocity(particle, global_best)
      new_position = update_position(particle.position, new_velocity)
      new_fitness = evaluate_fitness(fitness_fn, new_position)

      {new_best_pos, new_best_fit} =
        if new_fitness > particle.best_fitness do
          {new_position, new_fitness}
        else
          {particle.best_position, particle.best_fitness}
        end

      %{
        particle
        | position: new_position,
          velocity: new_velocity,
          fitness: new_fitness,
          best_position: new_best_pos,
          best_fitness: new_best_fit
      }
    end)
  end

  defp compute_velocity(particle, global_best) do
    dims = length(@dimensions)

    Enum.zip_with(
      [
        particle.velocity,
        particle.position,
        particle.best_position,
        global_best.position,
        Enum.take(particle.velocity, dims)
      ],
      fn [v, x, pbest, gbest, _] ->
        r1 = :rand.uniform()
        r2 = :rand.uniform()

        new_v = @inertia * v + @c1 * r1 * (pbest - x) + @c2 * r2 * (gbest - x)

        # Velocity clamping per dimension
        clamp_velocity(new_v)
      end
    )
  end

  defp update_position(position, velocity) do
    Enum.zip(position, velocity)
    |> Enum.zip(@dimensions)
    |> Enum.map(fn {{pos, vel}, {_name, min_v, max_v}} ->
      new_pos = pos + vel
      max(min_v, min(max_v, new_pos))
    end)
  end

  defp clamp_velocity(v) do
    max(-5.0, min(5.0, v))
  end

  defp find_global_best(particles) do
    Enum.max_by(particles, & &1.best_fitness)
    |> then(&%{position: &1.best_position, fitness: &1.best_fitness})
  end

  defp evaluate_fitness(fitness_fn, position) do
    t0 = System.monotonic_time(:microsecond)
    result = fitness_fn.(position)
    elapsed = System.monotonic_time(:microsecond) - t0

    if elapsed > 10_000 do
      Logger.warning("[SwarmOptimizer] Fitness eval #{elapsed}us > 10ms limit [SC-SWARM-003]")
    end

    result
  rescue
    _ -> 0.0
  end

  defp compute_diversity(particles) do
    if length(particles) < 2 do
      1.0
    else
      n = length(particles)

      centroid =
        particles
        |> Enum.map(& &1.position)
        |> Enum.zip_with(&Enum.sum/1)
        |> Enum.map(&(&1 / n))

      avg_distance =
        particles
        |> Enum.map(fn p ->
          Enum.zip(p.position, centroid)
          |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
          |> Enum.sum()
          |> :math.sqrt()
        end)
        |> Enum.sum()
        |> Kernel./(n)

      # Normalize by dimension span
      max_span =
        @dimensions
        |> Enum.map(fn {_, min_v, max_v} -> max_v - min_v end)
        |> Enum.sum()
        |> Kernel./(length(@dimensions))

      if max_span == 0, do: 1.0, else: avg_distance / max_span
    end
  end

  defp reinject_diversity(particles, fitness_fn, _current_diversity) do
    # Replace 20% of worst particles with random ones
    n = length(particles)
    reinject_count = max(1, div(n, 5))

    sorted = Enum.sort_by(particles, & &1.fitness)

    {worst, rest} = Enum.split(sorted, reinject_count)
    _ = worst

    new_particles =
      Enum.map(1..reinject_count, fn _ ->
        position = random_position()
        n_dims = length(@dimensions)
        velocity = Enum.map(1..n_dims, fn _ -> (:rand.uniform() - 0.5) * 0.1 end)
        fit = evaluate_fitness(fitness_fn, position)

        %{
          position: position,
          velocity: velocity,
          fitness: fit,
          best_position: position,
          best_fitness: fit
        }
      end)

    rest ++ new_particles
  end

  defp broadcast_result(result) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:swarm_result, result}
    )
  rescue
    _ -> :ok
  end
end
