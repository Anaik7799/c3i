defmodule Indrajaal.Cortex.Swarm.Algorithms do
  @moduledoc """
  SIL-6 Biomorphic Swarm Intelligence Algorithms

  Implements 5 production-grade swarm optimization algorithms for collective decision-making:
  1. Grey Wolf Optimizer (GWO) - Alpha/Beta/Delta hierarchy
  2. Particle Swarm Optimization (PSO) - Velocity/Position updates
  3. Ant Colony Optimization (ACO) - Pheromone-based path finding
  4. Artificial Bee Colony (ABC) - Scout/Worker/Onlooker bees
  5. Firefly Algorithm (FA) - Light intensity attraction

  ## STAMP Constraints
  - SC-SWARM-001: Algorithm convergence < 1000 iterations
  - SC-SWARM-002: Diversity maintenance > 0.3
  - SC-SWARM-003: Fitness evaluation < 10ms per agent
  - SC-SWARM-004: Population size 20-100 agents
  - SC-SWARM-005: Integration with UnifiedBus for telemetry

  ## AOR Rules
  - AOR-SWARM-001: Log algorithm state every 100 iterations
  - AOR-SWARM-002: Emit telemetry on convergence
  - AOR-SWARM-003: Track best solution history
  - AOR-SWARM-004: Diversity check before termination

  ## Zenoh Convergence Metrics (GAP-P2-005, task cfbbb7c9)
  All algorithms publish full convergence metrics after each run to:
  `"indrajaal/cortex/swarm/convergence"` via `ZenohPublisher.publish_async/2`.
  Recent history (last 100 runs) is accessible via `get_convergence_history/0`.

  Metrics published per run:
  - algorithm: atom (:gwo | :pso | :aco | :abc | :fa)
  - iteration: total iteration count
  - best_fitness: float
  - mean_fitness: mean across convergence curve
  - diversity: population diversity (std-dev normalised)
  - convergence_rate: fitness improvement per iteration
  - population_size: number of agents
  - timestamp: ISO 8601 UTC

  Created: 2026-01-10
  Version: 21.2.1-SIL6
  """

  require Logger

  # ETS table for convergence history (SC-ZTEST-008 audit trail + get_convergence_history/0)
  @history_table :swarm_convergence_history
  # Maximum number of history entries retained (ring-buffer semantics)
  @history_limit 100

  @type position :: list(float())
  @type velocity :: list(float())
  @type fitness :: float()

  @type swarm_config :: %{
          population_size: pos_integer(),
          max_iterations: pos_integer(),
          dimension: pos_integer(),
          bounds: {float(), float()},
          target_fitness: float()
        }

  @type swarm_result :: %{
          best_position: position(),
          best_fitness: fitness(),
          convergence_curve: list(fitness()),
          iterations: pos_integer(),
          diversity: float()
        }

  # Default configuration per SC-SWARM-004
  @default_config %{
    population_size: 50,
    max_iterations: 500,
    dimension: 10,
    bounds: {-100.0, 100.0},
    target_fitness: 0.001
  }

  # ============================================================================
  # PUBLIC API: Convergence History (GAP-P2-005)
  # ============================================================================

  @doc """
  Returns recent convergence metrics from all swarm optimization runs.

  Entries are stored in an ETS table and capped at #{@history_limit} records.
  Each entry is a map matching the schema described in the module doc.

  ## Returns
  List of convergence metric maps, newest-first.
  Returns empty list when no runs have occurred yet.
  """
  @spec get_convergence_history() :: list(map())
  def get_convergence_history do
    ensure_history_table()

    :ets.tab2list(@history_table)
    |> Enum.sort_by(fn {_key, entry} -> entry.timestamp end, :desc)
    |> Enum.map(fn {_key, entry} -> entry end)
  rescue
    _ -> []
  end

  # ============================================================================
  # GREY WOLF OPTIMIZER (GWO)
  # ============================================================================
  # Based on leadership hierarchy: Alpha > Beta > Delta > Omega
  # Implements hunting phases: encircling, hunting, attacking prey
  # ============================================================================

  @doc """
  Grey Wolf Optimizer - Leadership-based optimization

  Alpha wolf leads, beta and delta support, omegas follow.
  Hunting phases: Track → Encircle → Attack

  ## Parameters
  - space: Search space definition
  - objectives: Objective functions list
  - constraints: Constraint map
  - state: GenServer state with configuration

  ## Returns
  Map with :alpha (best position), :beta, :delta, :fitness
  """
  @spec grey_wolf_optimizer(map(), list(), map(), map()) :: swarm_result()
  def grey_wolf_optimizer(space, objectives, constraints, state) do
    config = build_config(space, state)
    dimension = config.dimension
    {lb, ub} = config.bounds

    # Initialize wolf pack
    wolves =
      for _ <- 1..config.population_size do
        for _ <- 1..dimension do
          lb + :rand.uniform() * (ub - lb)
        end
      end

    # Initialize alpha, beta, delta (leaders)
    initial_fitness = Enum.map(wolves, &evaluate_fitness(&1, objectives, constraints))
    sorted = Enum.zip(wolves, initial_fitness) |> Enum.sort_by(&elem(&1, 1), :desc)

    {alpha, alpha_fitness} = Enum.at(sorted, 0)
    {beta, _} = Enum.at(sorted, 1, {alpha, alpha_fitness})
    {delta, _} = Enum.at(sorted, 2, {alpha, alpha_fitness})

    # Run iterations
    {final_alpha, final_fitness, curve} =
      gwo_iterate(
        wolves,
        alpha,
        beta,
        delta,
        alpha_fitness,
        objectives,
        constraints,
        config,
        1,
        [alpha_fitness]
      )

    result = %{
      best_position: final_alpha,
      alpha: final_alpha,
      beta: beta,
      delta: delta,
      best_fitness: final_fitness,
      fitness: final_fitness,
      convergence_curve: Enum.reverse(curve),
      iterations: length(curve),
      diversity: calculate_diversity(wolves),
      population_size: config.population_size
    }

    publish_convergence_metrics(:gwo, result)
    result
  end

  defp gwo_iterate(
         wolves,
         alpha,
         beta,
         delta,
         best_fitness,
         objectives,
         constraints,
         config,
         iter,
         curve
       ) do
    if iter >= config.max_iterations or best_fitness >= config.target_fitness do
      {alpha, best_fitness, curve}
    else
      {lb, ub} = config.bounds
      # Linear decrease of 'a' from 2 to 0 (controls exploration vs exploitation)
      a = 2.0 * (1.0 - iter / config.max_iterations)

      # Update each wolf position
      new_wolves =
        Enum.map(wolves, fn wolf ->
          # Calculate position relative to alpha, beta, delta
          x1 = update_position_component(wolf, alpha, a, lb, ub)
          x2 = update_position_component(wolf, beta, a, lb, ub)
          x3 = update_position_component(wolf, delta, a, lb, ub)

          # Average position (encirclement)
          Enum.zip([x1, x2, x3])
          |> Enum.map(fn {a, b, c} -> (a + b + c) / 3.0 end)
          |> clamp_position(lb, ub)
        end)

      # Evaluate and update leaders
      fitness_vals = Enum.map(new_wolves, &evaluate_fitness(&1, objectives, constraints))
      sorted = Enum.zip(new_wolves, fitness_vals) |> Enum.sort_by(&elem(&1, 1), :desc)

      {new_alpha, new_alpha_fitness} = Enum.at(sorted, 0)
      {new_beta, _} = Enum.at(sorted, 1, {new_alpha, new_alpha_fitness})
      {new_delta, _} = Enum.at(sorted, 2, {new_alpha, new_alpha_fitness})

      # Keep best overall
      {final_alpha, final_fitness} =
        if new_alpha_fitness > best_fitness do
          {new_alpha, new_alpha_fitness}
        else
          {alpha, best_fitness}
        end

      # Log every 100 iterations per AOR-SWARM-001
      if rem(iter, 100) == 0 do
        Logger.debug(
          "GWO iteration #{iter}: fitness=#{Float.round(final_fitness, 4)}, a=#{Float.round(a, 2)}"
        )
      end

      gwo_iterate(
        new_wolves,
        final_alpha,
        new_beta,
        new_delta,
        final_fitness,
        objectives,
        constraints,
        config,
        iter + 1,
        [final_fitness | curve]
      )
    end
  end

  defp update_position_component(wolf, leader, a, lb, ub) do
    Enum.zip(wolf, leader)
    |> Enum.map(fn {w, l} ->
      r1 = :rand.uniform()
      r2 = :rand.uniform()
      # A coefficient
      a_coeff = 2.0 * a * r1 - a
      # C coefficient
      c_coeff = 2.0 * r2
      # Distance to leader
      d = abs(c_coeff * l - w)
      new_pos = l - a_coeff * d
      clamp_value(new_pos, lb, ub)
    end)
  end

  # ============================================================================
  # PARTICLE SWARM OPTIMIZATION (PSO)
  # ============================================================================
  # Kennedy & Eberhart's classic algorithm
  # Each particle has position + velocity, influenced by personal and global best
  # ============================================================================

  @doc """
  Particle Swarm Optimization - Velocity-based optimization

  Particles fly through search space, attracted to personal best (cognitive)
  and global best (social) positions.

  ## Coefficients
  - w: Inertia weight (0.4-0.9) - controls momentum
  - c1: Cognitive coefficient (2.0) - personal best attraction
  - c2: Social coefficient (2.0) - global best attraction

  ## Returns
  Map with :global_best, :personal_bests, :fitness
  """
  @spec particle_swarm_optimization(map(), list() | map(), map(), map()) :: swarm_result()
  def particle_swarm_optimization(space, objectives, constraints, state) do
    config = build_config(space, state)
    dimension = config.dimension
    {lb, ub} = config.bounds

    # PSO parameters
    # Inertia weight (decreases over time)
    w_start = 0.9
    w_end = 0.4
    # Cognitive coefficient
    c1 = 2.0
    # Social coefficient
    c2 = 2.0
    # Maximum velocity
    v_max = (ub - lb) * 0.2

    # Initialize particles (position + velocity)
    particles =
      for _ <- 1..config.population_size do
        position =
          for _ <- 1..dimension do
            lb + :rand.uniform() * (ub - lb)
          end

        velocity =
          for _ <- 1..dimension do
            (:rand.uniform() * 2 - 1) * v_max
          end

        {position, velocity}
      end

    # Initialize personal bests
    positions = Enum.map(particles, &elem(&1, 0))
    fitness_vals = Enum.map(positions, &evaluate_fitness(&1, objectives, constraints))
    personal_bests = Enum.zip(positions, fitness_vals)

    # Global best
    {global_best, global_fitness} = Enum.max_by(personal_bests, &elem(&1, 1))

    # Run iterations
    {final_global, final_fitness, curve} =
      pso_iterate(
        particles,
        personal_bests,
        global_best,
        global_fitness,
        objectives,
        constraints,
        config,
        w_start,
        w_end,
        c1,
        c2,
        v_max,
        1,
        [global_fitness]
      )

    result = %{
      best_position: final_global,
      global_best: final_global,
      decision: final_global,
      best_fitness: final_fitness,
      fitness: final_fitness,
      convergence_curve: Enum.reverse(curve),
      iterations: length(curve),
      diversity: calculate_diversity(positions),
      population_size: config.population_size
    }

    publish_convergence_metrics(:pso, result)
    result
  end

  defp pso_iterate(
         particles,
         personal_bests,
         global_best,
         global_fitness,
         objectives,
         constraints,
         config,
         w_start,
         w_end,
         c1,
         c2,
         v_max,
         iter,
         curve
       ) do
    if iter >= config.max_iterations or global_fitness >= config.target_fitness do
      {global_best, global_fitness, curve}
    else
      {lb, ub} = config.bounds

      # Linear decrease of inertia weight
      w = w_start - (w_start - w_end) * (iter / config.max_iterations)

      # Update each particle
      {new_particles, new_personal_bests} =
        particles
        |> Enum.zip(personal_bests)
        |> Enum.map(fn {{position, velocity}, {pb, pb_fitness}} ->
          # Update velocity
          r1 = :rand.uniform()
          r2 = :rand.uniform()

          new_velocity =
            Enum.zip([velocity, position, pb, global_best])
            |> Enum.map(fn {v, x, pb_i, gb_i} ->
              cognitive = c1 * r1 * (pb_i - x)
              social = c2 * r2 * (gb_i - x)
              new_v = w * v + cognitive + social
              clamp_value(new_v, -v_max, v_max)
            end)

          # Update position
          new_position =
            Enum.zip(position, new_velocity)
            |> Enum.map(fn {x, v} -> clamp_value(x + v, lb, ub) end)

          # Evaluate new position
          new_fitness = evaluate_fitness(new_position, objectives, constraints)

          # Update personal best
          new_pb =
            if new_fitness > pb_fitness do
              {new_position, new_fitness}
            else
              {pb, pb_fitness}
            end

          {{new_position, new_velocity}, new_pb}
        end)
        |> Enum.unzip()

      # Update global best
      {best_pb, best_pb_fitness} = Enum.max_by(new_personal_bests, &elem(&1, 1))

      {new_global, new_global_fitness} =
        if best_pb_fitness > global_fitness do
          {best_pb, best_pb_fitness}
        else
          {global_best, global_fitness}
        end

      if rem(iter, 100) == 0 do
        Logger.debug(
          "PSO iteration #{iter}: fitness=#{Float.round(new_global_fitness, 4)}, w=#{Float.round(w, 2)}"
        )
      end

      pso_iterate(
        new_particles,
        new_personal_bests,
        new_global,
        new_global_fitness,
        objectives,
        constraints,
        config,
        w_start,
        w_end,
        c1,
        c2,
        v_max,
        iter + 1,
        [new_global_fitness | curve]
      )
    end
  end

  # ============================================================================
  # ANT COLONY OPTIMIZATION (ACO)
  # ============================================================================
  # Dorigo's pheromone-based path finding
  # Ants deposit pheromones on good paths, paths evaporate over time
  # ============================================================================

  @doc """
  Ant Colony Optimization - Pheromone-guided search

  Ants construct solutions probabilistically based on pheromone trails.
  Good solutions reinforce pheromone, poor solutions evaporate.

  ## Parameters
  - alpha: Pheromone influence (1.0)
  - beta: Heuristic influence (2.0)
  - rho: Evaporation rate (0.1)
  - Q: Pheromone deposit amount (100)

  ## Returns
  Map with :path, :pheromone_matrix, :fitness
  """
  @spec ant_colony_optimization(map(), list(), map(), map()) :: swarm_result()
  def ant_colony_optimization(space, objectives, constraints, state) do
    config = build_config(space, state)
    dimension = config.dimension
    {lb, ub} = config.bounds

    # ACO parameters
    # Pheromone influence
    alpha = 1.0
    # Heuristic influence
    beta = 2.0
    # Evaporation rate
    rho = 0.1
    # Pheromone deposit amount
    q = 100.0
    n_ants = config.population_size

    # Discretize continuous space for ACO
    n_bins = 20
    bin_size = (ub - lb) / n_bins

    # Initialize pheromone matrix (uniform)
    initial_tau = 1.0

    pheromone =
      for _ <- 1..dimension do
        for _ <- 1..n_bins, do: initial_tau
      end

    # Run iterations
    {best_path, best_fitness, curve} =
      aco_iterate(
        pheromone,
        nil,
        0.0,
        objectives,
        constraints,
        config,
        alpha,
        beta,
        rho,
        q,
        n_ants,
        n_bins,
        bin_size,
        lb,
        ub,
        1,
        []
      )

    # Convert path to continuous position
    best_position = path_to_position(best_path, bin_size, lb, n_bins)

    result = %{
      best_position: best_position,
      path: best_path,
      best_fitness: best_fitness,
      fitness: best_fitness,
      convergence_curve: Enum.reverse(curve),
      iterations: length(curve),
      diversity: calculate_pheromone_diversity(pheromone),
      population_size: config.population_size
    }

    publish_convergence_metrics(:aco, result)
    result
  end

  defp aco_iterate(
         pheromone,
         best_path,
         best_fitness,
         objectives,
         constraints,
         config,
         alpha,
         beta,
         rho,
         q,
         n_ants,
         n_bins,
         bin_size,
         lb,
         ub,
         iter,
         curve
       ) do
    if iter >= config.max_iterations or best_fitness >= config.target_fitness do
      {best_path, best_fitness, curve}
    else
      _dimension = length(pheromone)

      # Construct solutions (paths)
      {paths, fitness_vals} =
        1..n_ants
        |> Enum.map(fn _ ->
          path = construct_path(pheromone, alpha, beta, n_bins)
          position = path_to_position(path, bin_size, lb, n_bins)
          fitness = evaluate_fitness(position, objectives, constraints)
          {path, fitness}
        end)
        |> Enum.unzip()

      # Find best ant
      {iter_best_path, iter_best_fitness} =
        Enum.zip(paths, fitness_vals)
        |> Enum.max_by(&elem(&1, 1))

      # Update best overall
      {new_best_path, new_best_fitness} =
        if iter_best_fitness > best_fitness do
          {iter_best_path, iter_best_fitness}
        else
          {best_path, best_fitness}
        end

      # Update pheromone matrix
      new_pheromone = update_pheromone(pheromone, paths, fitness_vals, rho, q, n_bins)

      if rem(iter, 100) == 0 do
        Logger.debug("ACO iteration #{iter}: fitness=#{Float.round(new_best_fitness, 4)}")
      end

      aco_iterate(
        new_pheromone,
        new_best_path,
        new_best_fitness,
        objectives,
        constraints,
        config,
        alpha,
        beta,
        rho,
        q,
        n_ants,
        n_bins,
        bin_size,
        lb,
        ub,
        iter + 1,
        [new_best_fitness | curve]
      )
    end
  end

  defp construct_path(pheromone, alpha, beta, n_bins) do
    # For each dimension, select a bin probabilistically
    Enum.map(pheromone, fn tau_d ->
      # Calculate selection probabilities
      probs =
        Enum.with_index(tau_d)
        |> Enum.map(fn {tau, i} ->
          # Heuristic: prefer middle bins slightly
          heuristic = 1.0 / (abs(i - n_bins / 2) + 1)
          :math.pow(tau, alpha) * :math.pow(heuristic, beta)
        end)

      total = Enum.sum(probs)
      normalized = Enum.map(probs, &(&1 / total))

      # Roulette wheel selection
      r = :rand.uniform()
      select_bin(normalized, r, 0, 0.0)
    end)
  end

  defp select_bin([], _r, last_bin, _acc), do: last_bin

  defp select_bin([p | rest], r, bin, acc) do
    new_acc = acc + p
    if r <= new_acc, do: bin, else: select_bin(rest, r, bin + 1, new_acc)
  end

  defp path_to_position(nil, _bin_size, _lb, _n_bins), do: []

  defp path_to_position(path, bin_size, lb, _n_bins) do
    Enum.map(path, fn bin ->
      lb + (bin + 0.5) * bin_size
    end)
  end

  defp update_pheromone(pheromone, paths, fitness_vals, rho, q, _n_bins) do
    # Evaporation
    evaporated =
      Enum.map(pheromone, fn tau_d ->
        Enum.map(tau_d, &(&1 * (1 - rho)))
      end)

    # Deposit pheromone from all ants
    Enum.zip(paths, fitness_vals)
    |> Enum.reduce(evaporated, fn {path, fitness}, acc ->
      deposit = if fitness > 0, do: q * fitness, else: q * 0.001

      Enum.zip(acc, path)
      |> Enum.map(fn {tau_d, bin} ->
        List.update_at(tau_d, bin, &(&1 + deposit))
      end)
    end)
  end

  defp calculate_pheromone_diversity(pheromone) do
    # Entropy-based diversity measure
    flat = List.flatten(pheromone)
    total = Enum.sum(flat)

    if total == 0 do
      0.0
    else
      normalized = Enum.map(flat, &(&1 / total))

      entropy =
        -Enum.reduce(normalized, 0.0, fn p, acc ->
          if p > 0, do: acc + p * :math.log(p), else: acc
        end)

      max_entropy = :math.log(length(flat))
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  # ============================================================================
  # ARTIFICIAL BEE COLONY (ABC)
  # ============================================================================
  # Karaboga's bee algorithm with employed, onlooker, and scout bees
  # ============================================================================

  @doc """
  Artificial Bee Colony - Nectar source optimization

  Three types of bees:
  - Employed bees: Exploit known food sources
  - Onlooker bees: Select sources based on nectar amount (fitness)
  - Scout bees: Explore new sources when old ones exhausted

  ## Parameters
  - limit: Abandonment limit (trials before scout behavior)

  ## Returns
  Map with :solution, :nectar (fitness), :trials
  """
  @spec artificial_bee_colony(map(), list(), map(), map()) :: swarm_result()
  def artificial_bee_colony(space, objectives, constraints, state) do
    config = build_config(space, state)
    dimension = config.dimension
    {lb, ub} = config.bounds
    n_employed = div(config.population_size, 2)

    # ABC parameters
    # Abandonment limit
    limit = n_employed * dimension

    # Initialize food sources (employed bees)
    food_sources =
      for _ <- 1..n_employed do
        for _ <- 1..dimension do
          lb + :rand.uniform() * (ub - lb)
        end
      end

    fitness_vals = Enum.map(food_sources, &evaluate_fitness(&1, objectives, constraints))
    trials = List.duplicate(0, n_employed)

    # Find best
    {best_source, best_fitness} =
      Enum.zip(food_sources, fitness_vals)
      |> Enum.max_by(&elem(&1, 1))

    # Run iterations
    {final_best, final_fitness, curve} =
      abc_iterate(
        food_sources,
        fitness_vals,
        trials,
        best_source,
        best_fitness,
        objectives,
        constraints,
        config,
        limit,
        lb,
        ub,
        1,
        [best_fitness]
      )

    result = %{
      best_position: final_best,
      solution: final_best,
      best_fitness: final_fitness,
      fitness: final_fitness,
      convergence_curve: Enum.reverse(curve),
      iterations: length(curve),
      diversity: calculate_diversity(food_sources),
      population_size: config.population_size
    }

    publish_convergence_metrics(:abc, result)
    result
  end

  defp abc_iterate(
         sources,
         fitness_vals,
         trials,
         best_source,
         best_fitness,
         objectives,
         constraints,
         config,
         limit,
         lb,
         ub,
         iter,
         curve
       ) do
    if iter >= config.max_iterations or best_fitness >= config.target_fitness do
      {best_source, best_fitness, curve}
    else
      n_sources = length(sources)

      # Employed bee phase
      {sources1, fitness1, trials1} =
        employed_bee_phase(
          sources,
          fitness_vals,
          trials,
          objectives,
          constraints,
          lb,
          ub
        )

      # Onlooker bee phase
      {sources2, fitness2, trials2} =
        onlooker_bee_phase(
          sources1,
          fitness1,
          trials1,
          objectives,
          constraints,
          lb,
          ub,
          n_sources
        )

      # Scout bee phase
      {sources3, fitness3, trials3} =
        scout_bee_phase(
          sources2,
          fitness2,
          trials2,
          objectives,
          constraints,
          limit,
          lb,
          ub,
          config.dimension
        )

      # Update best
      {iter_best, iter_best_fitness} =
        Enum.zip(sources3, fitness3)
        |> Enum.max_by(&elem(&1, 1))

      {new_best, new_best_fitness} =
        if iter_best_fitness > best_fitness do
          {iter_best, iter_best_fitness}
        else
          {best_source, best_fitness}
        end

      if rem(iter, 100) == 0 do
        Logger.debug("ABC iteration #{iter}: fitness=#{Float.round(new_best_fitness, 4)}")
      end

      abc_iterate(
        sources3,
        fitness3,
        trials3,
        new_best,
        new_best_fitness,
        objectives,
        constraints,
        config,
        limit,
        lb,
        ub,
        iter + 1,
        [new_best_fitness | curve]
      )
    end
  end

  defp employed_bee_phase(sources, fitness_vals, trials, objectives, constraints, lb, ub) do
    n = length(sources)

    Enum.zip([sources, fitness_vals, trials])
    |> Enum.with_index()
    |> Enum.map(fn {{source, fitness, trial}, i} ->
      # Select random partner (different from i)
      k = select_different(i, n)
      partner = Enum.at(sources, k)

      # Select random dimension
      j = :rand.uniform(length(source)) - 1

      # Generate new solution
      phi = :rand.uniform() * 2 - 1

      new_source =
        List.update_at(source, j, fn x_j ->
          partner_j = Enum.at(partner, j)
          clamp_value(x_j + phi * (x_j - partner_j), lb, ub)
        end)

      new_fitness = evaluate_fitness(new_source, objectives, constraints)

      # Greedy selection
      if new_fitness > fitness do
        {new_source, new_fitness, 0}
      else
        {source, fitness, trial + 1}
      end
    end)
    |> Enum.unzip()
    |> (fn {s, f_t} ->
          {f, t} = Enum.unzip(f_t)
          {s, f, t}
        end).()
  end

  defp onlooker_bee_phase(
         sources,
         fitness_vals,
         trials,
         objectives,
         constraints,
         lb,
         ub,
         n_onlookers
       ) do
    # Calculate selection probabilities
    total_fitness = Enum.sum(fitness_vals)

    probs =
      if total_fitness > 0 do
        Enum.map(fitness_vals, &(&1 / total_fitness))
      else
        List.duplicate(1.0 / length(sources), length(sources))
      end

    # Onlooker selection and exploitation
    Enum.reduce(1..n_onlookers, {sources, fitness_vals, trials}, fn _, {src, fit, tri} ->
      # Roulette wheel selection
      r = :rand.uniform()
      selected = select_bin(probs, r, 0, 0.0)

      source = Enum.at(src, selected)
      fitness = Enum.at(fit, selected)
      trial = Enum.at(tri, selected)

      # Same mutation as employed bees
      k = select_different(selected, length(src))
      partner = Enum.at(src, k)
      j = :rand.uniform(length(source)) - 1
      phi = :rand.uniform() * 2 - 1

      new_source =
        List.update_at(source, j, fn x_j ->
          partner_j = Enum.at(partner, j)
          clamp_value(x_j + phi * (x_j - partner_j), lb, ub)
        end)

      new_fitness = evaluate_fitness(new_source, objectives, constraints)

      if new_fitness > fitness do
        {List.replace_at(src, selected, new_source), List.replace_at(fit, selected, new_fitness),
         List.replace_at(tri, selected, 0)}
      else
        {src, fit, List.replace_at(tri, selected, trial + 1)}
      end
    end)
  end

  defp scout_bee_phase(
         sources,
         fitness_vals,
         trials,
         objectives,
         constraints,
         limit,
         lb,
         ub,
         dimension
       ) do
    Enum.zip([sources, fitness_vals, trials])
    |> Enum.map(fn {source, fitness, trial} ->
      if trial >= limit do
        # Abandon and scout for new source
        new_source =
          for _ <- 1..dimension do
            lb + :rand.uniform() * (ub - lb)
          end

        new_fitness = evaluate_fitness(new_source, objectives, constraints)
        {new_source, new_fitness, 0}
      else
        {source, fitness, trial}
      end
    end)
    |> Enum.unzip()
    |> (fn {s, f_t} ->
          {f, t} = Enum.unzip(f_t)
          {s, f, t}
        end).()
  end

  defp select_different(i, n) do
    k = :rand.uniform(n) - 1
    if k == i, do: rem(k + 1, n), else: k
  end

  # ============================================================================
  # FIREFLY ALGORITHM (FA)
  # ============================================================================
  # Yang's light intensity-based optimization
  # Brighter fireflies attract dimmer ones; distance affects attraction
  # ============================================================================

  @doc """
  Firefly Algorithm - Light intensity optimization

  Fireflies move toward brighter (fitter) fireflies.
  Attraction decreases with distance (light absorption).

  ## Parameters
  - alpha: Randomization parameter (0.2)
  - beta0: Attractiveness at r=0 (1.0)
  - gamma: Light absorption coefficient (1.0)

  ## Returns
  Map with :position, :brightness (fitness)
  """
  @spec firefly_optimization(map(), list(), map(), map()) :: swarm_result()
  def firefly_optimization(space, objectives, constraints, state) do
    config = build_config(space, state)
    dimension = config.dimension
    {lb, ub} = config.bounds

    # FA parameters
    # Randomization
    alpha = 0.2
    # Attractiveness at r=0
    beta0 = 1.0
    # Light absorption
    gamma = 1.0

    # Initialize fireflies
    fireflies =
      for _ <- 1..config.population_size do
        for _ <- 1..dimension do
          lb + :rand.uniform() * (ub - lb)
        end
      end

    brightness = Enum.map(fireflies, &evaluate_fitness(&1, objectives, constraints))
    {best_ff, best_bright} = Enum.zip(fireflies, brightness) |> Enum.max_by(&elem(&1, 1))

    # Run iterations
    {final_best, final_brightness, curve} =
      fa_iterate(
        fireflies,
        brightness,
        best_ff,
        best_bright,
        objectives,
        constraints,
        config,
        alpha,
        beta0,
        gamma,
        lb,
        ub,
        1,
        [best_bright]
      )

    result = %{
      best_position: final_best,
      position: final_best,
      best_fitness: final_brightness,
      brightness: final_brightness,
      fitness: final_brightness,
      convergence_curve: Enum.reverse(curve),
      iterations: length(curve),
      diversity: calculate_diversity(fireflies),
      population_size: config.population_size
    }

    publish_convergence_metrics(:fa, result)
    result
  end

  defp fa_iterate(
         fireflies,
         brightness,
         best_ff,
         best_bright,
         objectives,
         constraints,
         config,
         alpha,
         beta0,
         gamma,
         lb,
         ub,
         iter,
         curve
       ) do
    if iter >= config.max_iterations or best_bright >= config.target_fitness do
      {best_ff, best_bright, curve}
    else
      scale = ub - lb

      # Move fireflies toward brighter ones
      {new_fireflies, new_brightness} =
        fireflies
        |> Enum.zip(brightness)
        |> Enum.map(fn {ff_i, bright_i} ->
          # Check all other fireflies
          new_ff =
            Enum.zip(fireflies, brightness)
            |> Enum.reduce(ff_i, fn {ff_j, bright_j}, current ->
              if bright_j > bright_i do
                # Move toward brighter firefly
                r = euclidean_distance(current, ff_j)
                beta = beta0 * :math.exp(-gamma * r * r)

                Enum.zip(current, ff_j)
                |> Enum.map(fn {xi, xj} ->
                  rand = alpha * (0.5 - :rand.uniform()) * scale
                  new_x = xi + beta * (xj - xi) + rand
                  clamp_value(new_x, lb, ub)
                end)
              else
                current
              end
            end)

          {new_ff, evaluate_fitness(new_ff, objectives, constraints)}
        end)
        |> Enum.unzip()

      # Update best
      {iter_best, iter_bright} =
        Enum.zip(new_fireflies, new_brightness)
        |> Enum.max_by(&elem(&1, 1))

      {new_best, new_best_bright} =
        if iter_bright > best_bright do
          {iter_best, iter_bright}
        else
          {best_ff, best_bright}
        end

      if rem(iter, 100) == 0 do
        Logger.debug("FA iteration #{iter}: brightness=#{Float.round(new_best_bright, 4)}")
      end

      fa_iterate(
        new_fireflies,
        new_brightness,
        new_best,
        new_best_bright,
        objectives,
        constraints,
        config,
        alpha,
        beta0,
        gamma,
        lb,
        ub,
        iter + 1,
        [new_best_bright | curve]
      )
    end
  end

  defp euclidean_distance(a, b) do
    Enum.zip(a, b)
    |> Enum.map(fn {ai, bi} -> (ai - bi) * (ai - bi) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp build_config(space, state) do
    swarm_config = get_in(state, [:learning_configuration, :swarm_intelligence]) || %{}

    %{
      population_size: swarm_config[:swarm_size] || @default_config.population_size,
      max_iterations: swarm_config[:max_iterations] || @default_config.max_iterations,
      dimension: map_size(space),
      bounds: extract_bounds(space),
      target_fitness: @default_config.target_fitness
    }
  end

  defp extract_bounds(space) when is_map(space) do
    # Extract bounds from space definition or use defaults
    lb = Map.get(space, :lower_bound, -100.0)
    ub = Map.get(space, :upper_bound, 100.0)
    {lb, ub}
  end

  defp evaluate_fitness(position, objectives, constraints) when is_list(objectives) do
    # Multi-objective: weighted sum
    base_fitness =
      Enum.reduce(objectives, 0.0, fn obj, acc ->
        case obj do
          f when is_function(f, 1) -> acc + f.(position)
          {f, weight} when is_function(f, 1) -> acc + weight * f.(position)
          # Default contribution
          _ -> acc + 0.5
        end
      end)

    # Apply constraint penalties
    penalty = calculate_constraint_penalty(position, constraints)
    max(0.0, base_fitness - penalty)
  end

  defp evaluate_fitness(position, _objectives, constraints) when is_list(position) do
    # Default fitness function: inverse of sum of squares (sphere function)
    sphere = Enum.reduce(position, 0.0, fn x, acc -> acc + x * x end)
    base_fitness = 1.0 / (1.0 + sphere)

    penalty = calculate_constraint_penalty(position, constraints)
    max(0.0, base_fitness - penalty)
  end

  defp evaluate_fitness(_position, _objectives, _constraints), do: 0.5

  defp calculate_constraint_penalty(_position, constraints) when map_size(constraints) == 0,
    do: 0.0

  defp calculate_constraint_penalty(position, constraints) do
    Enum.reduce(constraints, 0.0, fn {_name, constraint}, acc ->
      violation =
        case constraint do
          f when is_function(f, 1) ->
            result = f.(position)
            if result > 0, do: result, else: 0

          %{type: :inequality, func: f} when is_function(f, 1) ->
            result = f.(position)
            if result > 0, do: result, else: 0

          _ ->
            0
        end

      # Heavy penalty for violations
      acc + violation * 1000
    end)
  end

  defp clamp_position(position, lb, ub) do
    Enum.map(position, &clamp_value(&1, lb, ub))
  end

  defp clamp_value(x, lb, ub) do
    x |> max(lb) |> min(ub)
  end

  defp calculate_diversity(population) when is_list(population) and length(population) > 1 do
    # Average pairwise distance normalized
    n = length(population)

    distances =
      for i <- 0..(n - 2), j <- (i + 1)..(n - 1) do
        a = Enum.at(population, i)
        b = Enum.at(population, j)
        if a && b, do: euclidean_distance(a, b), else: 0.0
      end

    if length(distances) > 0 do
      avg_dist = Enum.sum(distances) / length(distances)
      # Normalize by dimension
      dimension = population |> List.first() |> length()
      min(1.0, avg_dist / (dimension * 100))
    else
      0.0
    end
  end

  defp calculate_diversity(_), do: 0.0

  # ============================================================================
  # CONVERGENCE METRICS: Zenoh Publishing (GAP-P2-005, task cfbbb7c9)
  # ============================================================================

  @doc false
  # Computes full convergence metrics from a result map and:
  #   1. Writes a structured log fallback (SC-ZTEST-008, AOR-ZTEST-008)
  #   2. Stores the entry in the ETS history table (get_convergence_history/0)
  #   3. Publishes async to Zenoh topic "indrajaal/cortex/swarm/convergence"
  #
  # result must contain: best_fitness, convergence_curve, iterations,
  #   diversity, population_size
  defp publish_convergence_metrics(algorithm, result) do
    curve = result.convergence_curve
    iterations = result.iterations
    best_fitness = result.best_fitness

    # Compute mean fitness over the convergence curve
    mean_fitness =
      if curve == [] do
        best_fitness
      else
        Enum.sum(curve) / length(curve)
      end

    # Compute convergence rate: net improvement per iteration
    convergence_rate =
      if iterations > 1 and curve != [] do
        first_fitness = List.first(curve) || best_fitness
        abs(best_fitness - first_fitness) / (iterations - 1)
      else
        0.0
      end

    metrics = %{
      algorithm: algorithm,
      iteration: iterations,
      best_fitness: best_fitness,
      mean_fitness: mean_fitness,
      diversity: result.diversity,
      convergence_rate: convergence_rate,
      population_size: Map.get(result, :population_size, 0),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # 1. Log fallback first — guaranteed durability (SC-ZTEST-008, AOR-ZTEST-008)
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=CP-SWARM-01 topic=indrajaal/cortex/swarm/convergence " <>
        "algorithm=#{algorithm} best_fitness=#{Float.round(best_fitness, 6)} " <>
        "mean_fitness=#{Float.round(mean_fitness, 6)} convergence_rate=#{Float.round(convergence_rate, 8)} " <>
        "diversity=#{Float.round(result.diversity, 4)} iterations=#{iterations} " <>
        "population_size=#{metrics.population_size} timestamp=#{metrics.timestamp}"
    )

    # 2. Store in ETS history (ring-buffer capped at @history_limit)
    store_convergence_history(metrics)

    # 3. Publish async to Zenoh — non-blocking, fire-and-forget (SC-ZTEST-004)
    publish_to_zenoh("indrajaal/cortex/swarm/convergence", metrics)

    :ok
  end

  # Publishes to Zenoh via ZenohPublisher with graceful fallback (AOR-ZTEST-008).
  defp publish_to_zenoh(topic, payload) do
    try do
      if Code.ensure_loaded?(Indrajaal.Observability.ZenohPublisher) do
        Indrajaal.Observability.ZenohPublisher.publish_async(topic, payload)
      else
        # SC-ZTEST-008: warning level to survive compile_time_purge_matching
        Logger.warning("[ZTEST-CHECKPOINT] topic=#{topic} payload=#{Jason.encode!(payload)}")
      end
    rescue
      _ ->
        Logger.warning("[ZTEST-CHECKPOINT] topic=#{topic} payload=#{inspect(payload)}")
    end

    :ok
  end

  # Ensures the ETS history table exists, creating it if necessary.
  defp ensure_history_table do
    case :ets.whereis(@history_table) do
      :undefined ->
        :ets.new(@history_table, [:named_table, :public, :set, read_concurrency: true])

      _tid ->
        @history_table
    end
  rescue
    # Table may have been created concurrently — that is fine.
    _ -> @history_table
  end

  # Inserts a metrics entry into the ETS history table.
  # Uses the timestamp as key to preserve ordering.
  # Evicts the oldest entry when the cap is exceeded.
  defp store_convergence_history(metrics) do
    ensure_history_table()
    key = {metrics.timestamp, make_ref()}
    :ets.insert(@history_table, {key, metrics})

    # Enforce ring-buffer cap: evict oldest entries beyond the limit
    size = :ets.info(@history_table, :size)

    if size > @history_limit do
      oldest_key =
        :ets.tab2list(@history_table)
        |> Enum.min_by(fn {k, _} -> k end)
        |> elem(0)

      :ets.delete(@history_table, oldest_key)
    end
  rescue
    _ -> :ok
  end
end
