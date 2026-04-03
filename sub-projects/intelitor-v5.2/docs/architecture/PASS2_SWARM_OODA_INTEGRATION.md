# PASS-2: Swarm Intelligence & OODA Loop Integration

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)
**Prerequisite**: FRACTAL_8LAYER_CHANGE_MANAGEMENT_COMPLETE.md

---

## Document Control

| Field | Value |
|-------|-------|
| Document ID | SWARM-OODA-21.3.0-002 |
| Classification | INTERNAL |
| Review Cycle | Quarterly |
| Owner | Architecture Team |
| STAMP Coverage | SC-SWARM-*, SC-OODA-*, SC-GWO-* |
| Lines | 500+ |

---

## Table of Contents

1. **Swarm Intelligence Architecture** - 5 algorithms, agent mapping
2. **OODA Loop Hierarchy** - 4-tier timing model (Micro to Strategic)
3. **Swarm-OODA Coupling** - Pheromone trails, emergent behavior
4. **50-Agent Grey Wolf Pack** - Hierarchy, roles, communication
5. **Implementation** - Elixir (Fast OODA), F# (Strategic OODA)
6. **STAMP Constraints & AOR Rules** - Complete safety framework

---

# 1. SWARM INTELLIGENCE ARCHITECTURE

## 1.1 Five Swarm Algorithms Overview

```
+============================================================================+
|                    SWARM ALGORITHM INTEGRATION MATRIX                       |
+============================================================================+
|                                                                             |
|  GREY WOLF OPTIMIZATION (GWO) - Leadership Hierarchy                       |
|  +-----------+     +-----------+     +-----------+     +-----------+       |
|  |   ALPHA   | --> |   BETA    | --> |   DELTA   | --> |   OMEGA   |       |
|  | Executive |     | Supervisor|     | Functional|     |  Workers  |       |
|  |    (1)    |     |   (10)    |     |   (15)    |     |   (24)    |       |
|  +-----------+     +-----------+     +-----------+     +-----------+       |
|        |                |                 |                  |              |
|        v                v                 v                  v              |
|  +---------------------------------------------------------------------+   |
|  |                        UNIFIED CONTROL BUS                          |   |
|  +---------------------------------------------------------------------+   |
|        |                |                 |                  |              |
|        v                v                 v                  v              |
|  +===========+   +===========+   +===========+   +===========+             |
|  |    PSO    |   |    ACO    |   |    BEE    |   | FIREFLY   |             |
|  | Parameter |   |   Path    |   | Resource  |   | Quality   |             |
|  |  Tuning   |   |  Finding  |   |  Alloc    |   | Attract   |             |
|  +===========+   +===========+   +===========+   +===========+             |
|        |                |                 |                  |              |
|        +----------------+-----------------+------------------+              |
|                                   |                                         |
|                                   v                                         |
|                    +============================+                           |
|                    |  EMERGENT OPTIMIZATION     |                           |
|                    |  (Change Quality Index)    |                           |
|                    +============================+                           |
|                                                                             |
+============================================================================+
```

## 1.2 Algorithm Specifications

### 1.2.1 Grey Wolf Optimization (GWO) - Leadership Hierarchy

**Purpose**: Establish hierarchical leadership for coordinated decision-making.

```elixir
defmodule Indrajaal.Swarm.GreyWolf do
  @moduledoc """
  Grey Wolf Optimization for hierarchical agent leadership.

  ## Hierarchy
  - Alpha (alpha): Executive agent, makes final decisions
  - Beta (beta): Domain supervisors, coordinate sub-packs
  - Delta (delta): Functional agents, execute complex tasks
  - Omega (omega): Worker agents, perform atomic operations

  ## STAMP Constraints
  - SC-GWO-001: Alpha has absolute veto authority
  - SC-GWO-002: Beta wolves coordinate within domain boundaries
  - SC-GWO-003: Delta wolves cannot override Beta decisions
  - SC-GWO-004: Omega wolves report to nearest Delta
  """

  @type rank :: :alpha | :beta | :delta | :omega
  @type wolf_id :: String.t()

  defstruct [
    :id,
    :rank,
    :position,          # Current search position in solution space
    :fitness,           # Current fitness score
    :domain,            # Domain assignment (for beta wolves)
    :pack_leader,       # Immediate superior
    :subordinates       # List of reporting wolves
  ]

  # Hunting algorithm parameters
  @a_initial 2.0        # Exploration coefficient (decreases over iterations)
  @convergence_factor 0.001

  @doc """
  Execute GWO hunting behavior for optimization.
  Alpha, Beta, Delta guide the pack toward optimal solution.
  """
  @spec hunt(list(t()), target :: map()) :: list(t())
  def hunt(pack, target) do
    # Extract alpha, beta, delta positions (top 3 solutions)
    sorted = Enum.sort_by(pack, & &1.fitness, :desc)
    [alpha | rest] = sorted
    [beta | rest2] = rest
    [delta | omegas] = rest2

    # Calculate 'a' coefficient (decreases from 2 to 0)
    iteration = Process.get(:gwo_iteration, 0)
    max_iterations = 100
    a = @a_initial * (1 - iteration / max_iterations)

    # Update omega positions based on alpha, beta, delta
    updated_omegas = Enum.map(omegas, fn omega ->
      new_position = calculate_encircling_position(
        omega.position,
        alpha.position,
        beta.position,
        delta.position,
        a
      )

      %{omega | position: new_position, fitness: evaluate_fitness(new_position, target)}
    end)

    # Re-rank pack based on new fitness
    [alpha, beta, delta | updated_omegas]
    |> Enum.sort_by(& &1.fitness, :desc)
    |> assign_ranks()
  end

  @spec calculate_encircling_position(
    current :: list(float()),
    alpha_pos :: list(float()),
    beta_pos :: list(float()),
    delta_pos :: list(float()),
    a :: float()
  ) :: list(float())
  defp calculate_encircling_position(current, alpha_pos, beta_pos, delta_pos, a) do
    # Random coefficients
    r1 = :rand.uniform()
    r2 = :rand.uniform()

    a_coeff = 2 * a * r1 - a
    c_coeff = 2 * r2

    # Distance to alpha, beta, delta
    d_alpha = distance_vector(current, alpha_pos, c_coeff)
    d_beta = distance_vector(current, beta_pos, c_coeff)
    d_delta = distance_vector(current, delta_pos, c_coeff)

    # New position is average of positions guided by alpha, beta, delta
    x1 = vector_subtract(alpha_pos, vector_scale(d_alpha, a_coeff))
    x2 = vector_subtract(beta_pos, vector_scale(d_beta, a_coeff))
    x3 = vector_subtract(delta_pos, vector_scale(d_delta, a_coeff))

    # Average position
    Enum.zip([x1, x2, x3])
    |> Enum.map(fn {v1, v2, v3} -> (v1 + v2 + v3) / 3 end)
  end

  defp assign_ranks(wolves) do
    wolves
    |> Enum.with_index()
    |> Enum.map(fn {wolf, idx} ->
      rank = cond do
        idx == 0 -> :alpha
        idx <= 10 -> :beta
        idx <= 25 -> :delta
        true -> :omega
      end
      %{wolf | rank: rank}
    end)
  end
end
```

### 1.2.2 Particle Swarm Optimization (PSO) - Parameter Tuning

**Purpose**: Optimize system parameters (OODA timing, agent scaling, thresholds).

```elixir
defmodule Indrajaal.Swarm.ParticleSwarm do
  @moduledoc """
  Particle Swarm Optimization for continuous parameter tuning.

  ## Parameters Optimized
  - OODA cycle timing budgets
  - Agent scaling thresholds
  - Quality gate thresholds
  - Hysteresis margins

  ## STAMP Constraints
  - SC-PSO-001: Particles MUST stay within safe parameter bounds
  - SC-PSO-002: Best position updates require Guardian validation
  - SC-PSO-003: Inertia weight decays to prevent oscillation
  """

  # PSO coefficients
  @inertia_weight 0.729      # w
  @cognitive_coefficient 1.49 # c1 (self-best attraction)
  @social_coefficient 1.49    # c2 (global-best attraction)

  defstruct [
    :id,
    :position,          # Current parameter vector
    :velocity,          # Current velocity vector
    :personal_best,     # Best position this particle has found
    :personal_best_fit, # Fitness at personal best
    :bounds             # [min, max] for each dimension
  ]

  @type t :: %__MODULE__{}

  @doc """
  Update particle swarm for one iteration.
  """
  @spec update_swarm(list(t()), global_best :: list(float())) :: {list(t()), list(float())}
  def update_swarm(particles, global_best) do
    updated_particles = Enum.map(particles, fn p ->
      update_particle(p, global_best)
    end)

    # Find new global best
    best_particle = Enum.max_by(updated_particles, & &1.personal_best_fit)
    new_global_best =
      if evaluate_fitness(best_particle.personal_best) > evaluate_fitness(global_best) do
        best_particle.personal_best
      else
        global_best
      end

    {updated_particles, new_global_best}
  end

  @spec update_particle(t(), global_best :: list(float())) :: t()
  defp update_particle(particle, global_best) do
    r1 = :rand.uniform()
    r2 = :rand.uniform()

    # Calculate new velocity
    # v(t+1) = w*v(t) + c1*r1*(pbest - x) + c2*r2*(gbest - x)
    new_velocity =
      particle.velocity
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        pos = Enum.at(particle.position, i)
        pbest = Enum.at(particle.personal_best, i)
        gbest = Enum.at(global_best, i)

        inertia = @inertia_weight * v
        cognitive = @cognitive_coefficient * r1 * (pbest - pos)
        social = @social_coefficient * r2 * (gbest - pos)

        inertia + cognitive + social
      end)

    # Calculate new position
    new_position =
      particle.position
      |> Enum.zip(new_velocity)
      |> Enum.with_index()
      |> Enum.map(fn {{pos, vel}, i} ->
        {min_bound, max_bound} = Enum.at(particle.bounds, i)
        new_pos = pos + vel
        # Clamp to bounds (SC-PSO-001)
        max(min_bound, min(max_bound, new_pos))
      end)

    # Evaluate fitness
    new_fitness = evaluate_fitness(new_position)

    # Update personal best if improved
    {new_pbest, new_pbest_fit} =
      if new_fitness > particle.personal_best_fit do
        {new_position, new_fitness}
      else
        {particle.personal_best, particle.personal_best_fit}
      end

    %{particle |
      position: new_position,
      velocity: new_velocity,
      personal_best: new_pbest,
      personal_best_fit: new_pbest_fit
    }
  end

  @doc """
  Fitness function for parameter optimization.
  Higher is better.
  """
  @spec evaluate_fitness(params :: list(float())) :: float()
  def evaluate_fitness(params) do
    # params: [ooda_budget_ms, agent_scale_threshold, quality_threshold, hysteresis]
    [ooda_budget, agent_threshold, quality_threshold, hysteresis] = params

    # Penalize extreme values
    ooda_score = 1.0 - abs(ooda_budget - 50.0) / 50.0  # Optimal around 50ms
    agent_score = 1.0 - abs(agent_threshold - 0.7) / 0.3  # Optimal around 70%
    quality_score = 1.0 - abs(quality_threshold - 0.8) / 0.2  # Optimal around 80%
    hysteresis_score = 1.0 - abs(hysteresis - 0.1) / 0.1  # Optimal around 10%

    # Weighted combination
    0.3 * ooda_score + 0.25 * agent_score + 0.25 * quality_score + 0.2 * hysteresis_score
  end
end
```

### 1.2.3 Ant Colony Optimization (ACO) - Path Finding

**Purpose**: Find optimal sequence of changes through the codebase.

```elixir
defmodule Indrajaal.Swarm.AntColony do
  @moduledoc """
  Ant Colony Optimization for finding optimal change paths.

  ## Use Cases
  - Migration sequence optimization
  - Refactoring dependency ordering
  - Test execution ordering
  - Deployment sequence planning

  ## Pheromone Trails via Zenoh
  - Topic: indrajaal/swarm/aco/pheromone/{path_id}
  - Decay: 10% per iteration
  - Deposit: Proportional to path quality

  ## STAMP Constraints
  - SC-ACO-001: Pheromone levels bounded [0.1, 10.0]
  - SC-ACO-002: Ants MUST respect dependency constraints
  - SC-ACO-003: Evaporation rate tuned per layer
  """

  @alpha 1.0        # Pheromone importance
  @beta 2.0         # Heuristic importance
  @evaporation 0.1  # Pheromone decay rate
  @q 100.0          # Pheromone deposit constant
  @min_pheromone 0.1
  @max_pheromone 10.0

  defstruct [
    :id,
    :path,              # List of nodes visited
    :path_cost,         # Total cost of path
    :pheromone_deposit  # Amount to deposit
  ]

  @type node :: atom() | String.t()
  @type edge :: {node(), node()}
  @type pheromone_map :: %{edge() => float()}

  @doc """
  Run ACO to find optimal path through change graph.
  """
  @spec find_optimal_path(
    graph :: map(),
    start_node :: node(),
    end_node :: node(),
    num_ants :: pos_integer(),
    iterations :: pos_integer()
  ) :: {list(node()), pheromone_map()}
  def find_optimal_path(graph, start_node, end_node, num_ants \\ 10, iterations \\ 50) do
    # Initialize pheromone on all edges
    pheromones = initialize_pheromones(graph)

    best_path = nil
    best_cost = :infinity

    {final_pheromones, final_best_path, _} =
      Enum.reduce(1..iterations, {pheromones, best_path, best_cost}, fn _iter, {ph, bp, bc} ->
        # Deploy ants
        ants = Enum.map(1..num_ants, fn ant_id ->
          construct_path(graph, ph, start_node, end_node, ant_id)
        end)

        # Find iteration best
        valid_ants = Enum.filter(ants, & &1.path != nil)

        {iter_best_path, iter_best_cost} =
          case Enum.min_by(valid_ants, & &1.path_cost, fn -> nil end) do
            nil -> {bp, bc}
            ant ->
              if ant.path_cost < bc do
                {ant.path, ant.path_cost}
              else
                {bp, bc}
              end
          end

        # Evaporate pheromones
        evaporated = evaporate_pheromones(ph)

        # Deposit pheromones
        updated = deposit_pheromones(evaporated, valid_ants)

        {updated, iter_best_path, iter_best_cost}
      end)

    {final_best_path || [], final_pheromones}
  end

  @spec construct_path(map(), pheromone_map(), node(), node(), integer()) :: t()
  defp construct_path(graph, pheromones, start_node, end_node, ant_id) do
    construct_path_recursive(graph, pheromones, [start_node], end_node, 0, MapSet.new([start_node]))
    |> case do
      {:ok, path, cost} ->
        %__MODULE__{
          id: "ANT-#{ant_id}",
          path: path,
          path_cost: cost,
          pheromone_deposit: @q / cost
        }
      :no_path ->
        %__MODULE__{id: "ANT-#{ant_id}", path: nil, path_cost: :infinity, pheromone_deposit: 0}
    end
  end

  defp construct_path_recursive(_graph, _pheromones, path, end_node, cost, _visited)
       when hd(path) == end_node do
    {:ok, Enum.reverse(path), cost}
  end

  defp construct_path_recursive(graph, pheromones, path, end_node, cost, visited) do
    current = hd(path)
    neighbors = Map.get(graph, current, [])
    unvisited = Enum.reject(neighbors, fn {n, _} -> MapSet.member?(visited, n) end)

    case unvisited do
      [] -> :no_path
      candidates ->
        # Calculate probabilities
        total = Enum.reduce(candidates, 0.0, fn {neighbor, edge_cost}, acc ->
          tau = Map.get(pheromones, {current, neighbor}, @min_pheromone)
          eta = 1.0 / edge_cost
          acc + :math.pow(tau, @alpha) * :math.pow(eta, @beta)
        end)

        # Roulette wheel selection
        rand_val = :rand.uniform() * total
        {selected, edge_cost} = select_next(candidates, pheromones, current, rand_val, 0.0)

        construct_path_recursive(
          graph,
          pheromones,
          [selected | path],
          end_node,
          cost + edge_cost,
          MapSet.put(visited, selected)
        )
    end
  end

  defp select_next([{node, cost} | rest], pheromones, current, target, cumulative) do
    tau = Map.get(pheromones, {current, node}, @min_pheromone)
    eta = 1.0 / cost
    prob = :math.pow(tau, @alpha) * :math.pow(eta, @beta)
    new_cumulative = cumulative + prob

    if new_cumulative >= target or rest == [] do
      {node, cost}
    else
      select_next(rest, pheromones, current, target, new_cumulative)
    end
  end

  defp evaporate_pheromones(pheromones) do
    Map.new(pheromones, fn {edge, value} ->
      new_value = value * (1 - @evaporation)
      {edge, max(@min_pheromone, new_value)}
    end)
  end

  defp deposit_pheromones(pheromones, ants) do
    Enum.reduce(ants, pheromones, fn ant, acc ->
      deposit_on_path(acc, ant.path, ant.pheromone_deposit)
    end)
  end

  defp deposit_on_path(pheromones, path, deposit) when length(path) < 2, do: pheromones
  defp deposit_on_path(pheromones, [a, b | rest], deposit) do
    edge = {a, b}
    current = Map.get(pheromones, edge, @min_pheromone)
    new_value = min(@max_pheromone, current + deposit)

    pheromones
    |> Map.put(edge, new_value)
    |> deposit_on_path([b | rest], deposit)
  end
end
```

### 1.2.4 Bee Algorithm - Resource Allocation

**Purpose**: Allocate agents to tasks based on task quality/priority.

```elixir
defmodule Indrajaal.Swarm.BeeAlgorithm do
  @moduledoc """
  Bee Algorithm for resource (agent) allocation.

  ## Bee Types
  - Scout Bees: Explore new tasks/solutions
  - Employed Bees: Work on assigned tasks
  - Onlooker Bees: Choose tasks based on waggle dance quality

  ## Integration with Agent Swarm
  - Worker agents act as bees
  - Tasks are "food sources"
  - Quality = fitness of completing task

  ## STAMP Constraints
  - SC-BEE-001: Scout allocation <= 20% of swarm
  - SC-BEE-002: Task abandonment after limit trials
  - SC-BEE-003: Resource reallocation respects OODA timing
  """

  @scout_percentage 0.2
  @abandonment_limit 5

  defstruct [
    :id,
    :role,          # :scout | :employed | :onlooker
    :assigned_task,
    :task_fitness,
    :trial_count
  ]

  @type task :: %{
    id: String.t(),
    priority: float(),
    fitness: float(),
    agents_assigned: list(String.t())
  }

  @doc """
  Allocate agents to tasks using bee algorithm.
  Returns mapping of agent_id -> task_id
  """
  @spec allocate(list(t()), list(task())) :: %{String.t() => String.t()}
  def allocate(bees, tasks) do
    # Phase 1: Employed bees evaluate their tasks
    {employed, scouts} = split_by_role(bees)

    evaluated_tasks = Enum.map(tasks, fn task ->
      fitness = calculate_task_fitness(task)
      %{task | fitness: fitness}
    end)

    # Phase 2: Onlooker bees choose based on waggle dance
    total_fitness = Enum.sum(Enum.map(evaluated_tasks, & &1.fitness))

    probabilities = Enum.map(evaluated_tasks, fn task ->
      {task.id, task.fitness / total_fitness}
    end)

    # Phase 3: Allocate onlookers based on probability
    {allocations, updated_tasks} =
      Enum.reduce(employed, {%{}, evaluated_tasks}, fn bee, {alloc, tasks} ->
        selected_task = select_by_probability(tasks, probabilities)
        {Map.put(alloc, bee.id, selected_task.id), tasks}
      end)

    # Phase 4: Scouts explore new tasks
    scout_discoveries = Enum.map(scouts, fn scout ->
      # Scouts look for underexplored tasks
      underexplored = Enum.min_by(updated_tasks, fn t ->
        length(t.agents_assigned)
      end)
      {scout.id, underexplored.id}
    end)

    Map.merge(allocations, Map.new(scout_discoveries))
  end

  defp calculate_task_fitness(task) do
    # Combine priority with current progress
    base_fitness = task.priority
    # Boost tasks with fewer agents (needs help)
    agent_factor = 1.0 / (1 + length(task.agents_assigned))
    base_fitness * agent_factor
  end

  defp select_by_probability(tasks, probabilities) do
    rand_val = :rand.uniform()

    {selected_id, _} =
      Enum.reduce_while(probabilities, {nil, 0.0}, fn {task_id, prob}, {_, cumulative} ->
        new_cumulative = cumulative + prob
        if new_cumulative >= rand_val do
          {:halt, {task_id, new_cumulative}}
        else
          {:cont, {task_id, new_cumulative}}
        end
      end)

    Enum.find(tasks, & &1.id == selected_id)
  end

  defp split_by_role(bees) do
    Enum.split_with(bees, & &1.role != :scout)
  end
end
```

### 1.2.5 Firefly Algorithm - Quality Attraction

**Purpose**: Agents attracted to higher-quality solutions (code quality, test coverage).

```elixir
defmodule Indrajaal.Swarm.Firefly do
  @moduledoc """
  Firefly Algorithm for quality-based attraction.

  ## Principles
  - Brighter fireflies (higher quality) attract dimmer ones
  - Attractiveness decreases with distance
  - Movement is toward brighter + random component

  ## Quality Metrics (Brightness)
  - Code coverage percentage
  - Credo issue count (inverse)
  - Test pass rate
  - Complexity score (inverse)

  ## STAMP Constraints
  - SC-FIREFLY-001: Brightness bounded [0.0, 1.0]
  - SC-FIREFLY-002: Random movement bounded by layer
  - SC-FIREFLY-003: Attraction coefficient tuned by domain
  """

  @beta_0 1.0       # Maximum attractiveness
  @gamma 1.0        # Light absorption coefficient
  @alpha 0.2        # Randomization parameter

  defstruct [
    :id,
    :position,      # Solution position in N-dimensional space
    :brightness,    # Quality metric (higher = better)
    :domain         # Domain for domain-specific tuning
  ]

  @doc """
  Move fireflies toward brighter ones.
  Returns updated positions.
  """
  @spec illuminate(list(t())) :: list(t())
  def illuminate(fireflies) do
    # Sort by brightness (brightest last to avoid double-movement)
    sorted = Enum.sort_by(fireflies, & &1.brightness)

    # Each firefly moves toward all brighter fireflies
    Enum.map(sorted, fn firefly ->
      brighter = Enum.filter(fireflies, fn f ->
        f.id != firefly.id and f.brightness > firefly.brightness
      end)

      case brighter do
        [] ->
          # Brightest firefly moves randomly
          random_walk(firefly)
        attractors ->
          # Move toward brightest nearby
          move_toward_brightest(firefly, attractors)
      end
    end)
  end

  @spec move_toward_brightest(t(), list(t())) :: t()
  defp move_toward_brightest(firefly, attractors) do
    # Find most attractive (brightness / distance)
    best_attractor = Enum.max_by(attractors, fn a ->
      dist = euclidean_distance(firefly.position, a.position)
      attractiveness(a.brightness, dist)
    end)

    dist = euclidean_distance(firefly.position, best_attractor.position)
    beta = attractiveness(best_attractor.brightness, dist)

    # New position: x_i = x_i + beta * (x_j - x_i) + alpha * (rand - 0.5)
    new_position =
      firefly.position
      |> Enum.zip(best_attractor.position)
      |> Enum.map(fn {xi, xj} ->
        attraction = beta * (xj - xi)
        randomness = @alpha * (:rand.uniform() - 0.5)
        xi + attraction + randomness
      end)

    new_brightness = calculate_brightness(new_position, firefly.domain)

    %{firefly | position: new_position, brightness: new_brightness}
  end

  defp random_walk(firefly) do
    new_position = Enum.map(firefly.position, fn x ->
      x + @alpha * (:rand.uniform() - 0.5)
    end)

    new_brightness = calculate_brightness(new_position, firefly.domain)
    %{firefly | position: new_position, brightness: new_brightness}
  end

  # Attractiveness decreases with distance
  defp attractiveness(brightness, distance) do
    @beta_0 * brightness * :math.exp(-@gamma * distance * distance)
  end

  defp euclidean_distance(pos1, pos2) do
    pos1
    |> Enum.zip(pos2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  @doc """
  Calculate brightness from quality metrics.
  """
  @spec calculate_brightness(list(float()), atom()) :: float()
  def calculate_brightness(position, domain) do
    # Position encodes quality metrics
    # [coverage, inverse_credo_issues, test_pass_rate, inverse_complexity]
    [coverage, credo, tests, complexity] = position

    # Domain-specific weighting
    weights = case domain do
      :safety -> [0.2, 0.3, 0.3, 0.2]   # Safety cares more about issues
      :performance -> [0.3, 0.2, 0.2, 0.3]  # Performance cares about complexity
      _ -> [0.25, 0.25, 0.25, 0.25]  # Balanced default
    end

    Enum.zip(weights, [coverage, credo, tests, complexity])
    |> Enum.map(fn {w, v} -> w * v end)
    |> Enum.sum()
    |> max(0.0)
    |> min(1.0)
  end
end
```

---

# 2. OODA LOOP HIERARCHY

## 2.1 Four-Tier OODA Architecture

```
+============================================================================+
|                       OODA LOOP HIERARCHY (4 TIERS)                         |
+============================================================================+
|                                                                             |
|  TIER 4: STRATEGIC OODA (L6-L7) ─────────────────────────────────────────  |
|  │ Cycle: 1s - 10min | Executor: F# Cortex | Observer: BEAM Telemetry     |
|  │ Scope: Federation consensus, cluster coordination, evolution planning   |
|  │ Decisions: Major architecture changes, policy updates, GDE proposals   |
|  │                                                                         |
|  │  ┌─────────────────────────────────────────────────────────────────┐   |
|  │  │  OBSERVE (200ms): Federation health, cluster state, trends      │   |
|  │  │  ORIENT (300ms): Constitutional analysis, 5-order effects       │   |
|  │  │  DECIDE (250ms): Guardian consultation, quorum voting           │   |
|  │  │  ACT (250ms): Submit proposal, await consensus                  │   |
|  │  └─────────────────────────────────────────────────────────────────┘   |
|  │                                                                         |
|  └─────────────────────────────────────────────────────────────────────────|
|                                                                             |
|  TIER 3: DISTRIBUTED OODA (L4-L5) ───────────────────────────────────────  |
|  │ Cycle: 100ms | Executor: Elixir Supervisor | Observer: Digital Twin    |
|  │ Scope: Container health, node scaling, resource allocation             |
|  │ Decisions: Container restart, agent scaling, health responses          |
|  │                                                                         |
|  │  ┌─────────────────────────────────────────────────────────────────┐   |
|  │  │  OBSERVE (20ms): Container health, port status, CPU/memory      │   |
|  │  │  ORIENT (30ms): Trend analysis, anomaly detection               │   |
|  │  │  DECIDE (25ms): Scale up/down, restart decisions                │   |
|  │  │  ACT (25ms): Execute podman commands, update state              │   |
|  │  └─────────────────────────────────────────────────────────────────┘   |
|  │                                                                         |
|  └─────────────────────────────────────────────────────────────────────────|
|                                                                             |
|  TIER 2: FAST OODA (L2-L3) ──────────────────────────────────────────────  |
|  │ Cycle: 50ms | Executor: GenServer | Observer: Telemetry Bus            |
|  │ Scope: Agent coordination, domain logic, holon state                   |
|  │ Decisions: Task dispatch, state mutations, event routing               |
|  │                                                                         |
|  │  ┌─────────────────────────────────────────────────────────────────┐   |
|  │  │  OBSERVE (5ms): Pending tasks, buffer state, agent status       │   |
|  │  │  ORIENT (15ms): Priority calculation, dependency check          │   |
|  │  │  DECIDE (15ms): Task selection with hysteresis                  │   |
|  │  │  ACT (15ms): Dispatch task, emit telemetry                      │   |
|  │  └─────────────────────────────────────────────────────────────────┘   |
|  │                                                                         |
|  └─────────────────────────────────────────────────────────────────────────|
|                                                                             |
|  TIER 1: MICRO OODA (L0-L1) ─────────────────────────────────────────────  |
|  │ Cycle: <1ms | Executor: Inline Elixir | Observer: None (too fast)     |
|  │ Scope: Function execution, I/O contracts, pattern matching             |
|  │ Decisions: Branch selection, error handling, value transformation      |
|  │                                                                         |
|  │  ┌─────────────────────────────────────────────────────────────────┐   |
|  │  │  OBSERVE: Pattern match input                                   │   |
|  │  │  ORIENT: Guard clause evaluation                                │   |
|  │  │  DECIDE: Function clause selection                              │   |
|  │  │  ACT: Execute function body, return value                       │   |
|  │  └─────────────────────────────────────────────────────────────────┘   |
|  │                                                                         |
|  └─────────────────────────────────────────────────────────────────────────|
|                                                                             |
+============================================================================+
```

## 2.2 Micro OODA (L0-L1) - Elixir Inline

```elixir
defmodule Indrajaal.OODA.MicroOODA do
  @moduledoc """
  Micro OODA loop embedded in function execution.
  Cycle time: <1ms (compiler-optimized pattern matching)

  This is the OBSERVE-ORIENT-DECIDE-ACT pattern at the function level.
  It's so fast that explicit telemetry would add overhead.

  ## Example: API request handling

  ```elixir
  # OBSERVE: Pattern match on input
  def handle_request(%{method: method, path: path} = request)
      # ORIENT: Guard clause evaluation
      when method in [:get, :post] and is_binary(path) do
    # DECIDE: Function clause selected (this one)
    # ACT: Execute the handler
    process_valid_request(request)
  end

  def handle_request(_invalid) do
    # Alternative DECIDE: Invalid input path
    {:error, :invalid_request}
  end
  ```

  ## STAMP Constraints
  - SC-MICRO-001: No blocking operations in micro OODA
  - SC-MICRO-002: Pattern matching MUST be exhaustive
  - SC-MICRO-003: Guard clauses MUST be pure functions
  """

  @doc """
  Inline OODA macro for documenting micro-level decisions.
  Zero runtime overhead - purely documentation.
  """
  defmacro ooda(observe_pattern, orient_guard, decide_action) do
    quote do
      case unquote(observe_pattern) do
        value when unquote(orient_guard) ->
          unquote(decide_action).(value)
        _ ->
          {:error, :ooda_pattern_mismatch}
      end
    end
  end

  @doc """
  Example: Value transformation with micro OODA.
  """
  @spec transform_value(term()) :: {:ok, term()} | {:error, atom()}
  def transform_value(value) do
    # OBSERVE: What is the value?
    # ORIENT: What type is it? Is it valid?
    # DECIDE: Which transformation path?
    # ACT: Execute transformation

    case value do
      # Integer path
      n when is_integer(n) and n > 0 ->
        {:ok, n * 2}

      # String path
      s when is_binary(s) and byte_size(s) > 0 ->
        {:ok, String.upcase(s)}

      # List path
      l when is_list(l) and length(l) > 0 ->
        {:ok, Enum.reverse(l)}

      # Map path
      m when is_map(m) and map_size(m) > 0 ->
        {:ok, Map.keys(m)}

      # Invalid/empty path
      _ ->
        {:error, :invalid_value}
    end
  end
end
```

## 2.3 Fast OODA (L2-L3) - GenServer Level

```elixir
defmodule Indrajaal.OODA.FastOODA do
  @moduledoc """
  Fast OODA loop for agent-level coordination.
  Cycle time: 50ms | Budget: 5ms + 15ms + 15ms + 15ms

  ## STAMP Constraints
  - SC-FAST-001: Cycle MUST complete in <100ms
  - SC-FAST-002: OBSERVE phase < 10ms
  - SC-FAST-003: Hysteresis prevents oscillation (10% margin, 3 cycle hold)
  - SC-FAST-004: All phases emit telemetry
  """

  use GenServer
  require Logger

  @cycle_ms 50
  @observe_budget_ms 5
  @orient_budget_ms 15
  @decide_budget_ms 15
  @act_budget_ms 15

  defstruct [
    :cycle_count,
    :last_decision,
    :hysteresis_hold,
    :metrics_buffer,
    :swarm_state
  ]

  # ============ PUBLIC API ============

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # ============ CALLBACKS ============

  @impl true
  def init(_opts) do
    # Start the OODA cycle
    schedule_cycle()

    {:ok, %__MODULE__{
      cycle_count: 0,
      last_decision: nil,
      hysteresis_hold: 0,
      metrics_buffer: [],
      swarm_state: %{agents: [], tasks: []}
    }}
  end

  @impl true
  def handle_info(:ooda_cycle, state) do
    start_time = System.monotonic_time(:microsecond)

    # ===== OBSERVE (5ms budget) =====
    {observations, observe_time} = measure(fn -> observe(state) end)

    # ===== ORIENT (15ms budget) =====
    {analysis, orient_time} = measure(fn -> orient(observations, state) end)

    # ===== DECIDE (15ms budget) =====
    {decision, decide_time} = measure(fn -> decide(analysis, state) end)

    # ===== ACT (15ms budget) =====
    {new_state, act_time} = measure(fn -> act(decision, state) end)

    total_time = System.monotonic_time(:microsecond) - start_time

    # Emit telemetry (for F# DigitalTwin observation)
    emit_cycle_telemetry(%{
      cycle: state.cycle_count + 1,
      observe_us: observe_time,
      orient_us: orient_time,
      decide_us: decide_time,
      act_us: act_time,
      total_us: total_time,
      decision: decision
    })

    # Check timing budget
    if total_time > @cycle_ms * 1000 do
      Logger.warning("[FAST-OODA] Cycle #{state.cycle_count} exceeded budget: #{total_time}us")
    end

    # Schedule next cycle
    schedule_cycle()

    {:noreply, %{new_state | cycle_count: state.cycle_count + 1}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics_buffer, state}
  end

  # ============ OODA PHASES ============

  defp observe(state) do
    %{
      pending_tasks: get_pending_tasks(),
      agent_status: get_agent_status(state.swarm_state.agents),
      system_health: check_system_health(),
      buffer_depth: length(state.metrics_buffer)
    }
  end

  defp orient(observations, state) do
    %{
      stress_level: calculate_stress(observations),
      priority_queue: prioritize_tasks(observations.pending_tasks),
      agent_availability: count_available_agents(observations.agent_status),
      trend: analyze_trend(state.metrics_buffer)
    }
  end

  defp decide(analysis, state) do
    raw_decision =
      cond do
        # High stress - escalate to distributed OODA
        analysis.stress_level > 0.8 ->
          {:escalate, :high_stress}

        # Low availability - scale up
        analysis.agent_availability < 0.3 ->
          {:scale, :up}

        # Work available - dispatch
        length(analysis.priority_queue) > 0 ->
          {:dispatch, hd(analysis.priority_queue)}

        # Idle state
        true ->
          {:idle, :no_work}
      end

    # Apply hysteresis (SC-FAST-003)
    apply_hysteresis(raw_decision, state)
  end

  defp act({:escalate, reason}, state) do
    # Notify distributed OODA layer
    Indrajaal.UnifiedBus.broadcast({:escalation, reason})
    %{state | last_decision: {:escalate, reason}}
  end

  defp act({:scale, direction}, state) do
    case direction do
      :up -> Indrajaal.Swarm.Coordinator.request_scale_up()
      :down -> Indrajaal.Swarm.Coordinator.request_scale_down()
    end
    %{state | last_decision: {:scale, direction}}
  end

  defp act({:dispatch, task}, state) do
    # Use bee algorithm to find best agent
    available = Enum.filter(state.swarm_state.agents, & &1.status == :idle)

    case available do
      [] ->
        # Queue for later
        state
      [agent | _] ->
        Indrajaal.Swarm.Coordinator.assign_task(agent.id, task)
        %{state | last_decision: {:dispatch, task}}
    end
  end

  defp act({:idle, _}, state) do
    %{state | last_decision: {:idle, :no_work}}
  end

  # ============ HELPERS ============

  defp apply_hysteresis(decision, state) do
    # If same decision as last time and hold count > 0, reduce hold
    if decision == state.last_decision and state.hysteresis_hold > 0 do
      decision
    else
      # Different decision - start hold period
      decision
    end
  end

  defp schedule_cycle do
    Process.send_after(self(), :ooda_cycle, @cycle_ms)
  end

  defp measure(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    elapsed = System.monotonic_time(:microsecond) - start
    {result, elapsed}
  end

  defp emit_cycle_telemetry(metrics) do
    :telemetry.execute(
      [:indrajaal, :ooda, :fast, :cycle],
      %{
        observe_us: metrics.observe_us,
        orient_us: metrics.orient_us,
        decide_us: metrics.decide_us,
        act_us: metrics.act_us,
        total_us: metrics.total_us
      },
      %{cycle: metrics.cycle, decision: metrics.decision}
    )
  end

  # Stubs for actual implementations
  defp get_pending_tasks, do: []
  defp get_agent_status(_), do: %{}
  defp check_system_health, do: :healthy
  defp calculate_stress(_), do: 0.5
  defp prioritize_tasks(tasks), do: tasks
  defp count_available_agents(_), do: 0.5
  defp analyze_trend(_), do: :stable
end
```

## 2.4 Distributed OODA (L4-L5) - Container Coordination

```elixir
defmodule Indrajaal.OODA.DistributedOODA do
  @moduledoc """
  Distributed OODA for container and node-level coordination.
  Cycle time: 100ms | Scope: Container health, node scaling

  ## STAMP Constraints
  - SC-DIST-001: Cycle MUST complete in <200ms
  - SC-DIST-002: Container health check via FPPS consensus
  - SC-DIST-003: Scaling decisions require 2oo3 voting (production)
  """

  use GenServer
  require Logger

  @cycle_ms 100

  defstruct [
    :cycle_count,
    :container_states,
    :last_health_check,
    :scaling_proposal,
    :consensus_votes
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_cycle()
    {:ok, %__MODULE__{
      cycle_count: 0,
      container_states: %{},
      last_health_check: nil,
      scaling_proposal: nil,
      consensus_votes: []
    }}
  end

  @impl true
  def handle_info(:distributed_ooda_cycle, state) do
    # OBSERVE: Container and node health
    containers = observe_containers()
    node_metrics = observe_node()

    # ORIENT: Analyze health trends, anomalies
    health_analysis = orient_health(containers, node_metrics)

    # DECIDE: Scaling, restart, or maintain
    decision = decide_action(health_analysis, state)

    # ACT: Execute with consensus (for production)
    new_state = act_with_consensus(decision, state)

    # Emit telemetry for strategic OODA
    :telemetry.execute(
      [:indrajaal, :ooda, :distributed, :cycle],
      %{cycle: state.cycle_count, health: health_analysis.overall},
      %{decision: decision}
    )

    schedule_cycle()
    {:noreply, %{new_state | cycle_count: state.cycle_count + 1}}
  end

  defp observe_containers do
    # Check all 4 containers
    %{
      "zenoh-router" => check_container_health("zenoh-router"),
      "indrajaal-db-prod" => check_container_health("indrajaal-db-prod"),
      "indrajaal-obs-prod" => check_container_health("indrajaal-obs-prod"),
      "indrajaal-ex-app-1" => check_container_health("indrajaal-ex-app-1")
    }
  end

  defp observe_node do
    %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      disk_usage: get_disk_usage(),
      scheduler_utilization: get_scheduler_util()
    }
  end

  defp orient_health(containers, node) do
    container_health = containers
      |> Map.values()
      |> Enum.map(& &1.status)
      |> calculate_container_score()

    node_health = calculate_node_score(node)

    %{
      container_score: container_health,
      node_score: node_health,
      overall: (container_health + node_health) / 2,
      anomalies: detect_anomalies(containers, node)
    }
  end

  defp decide_action(analysis, state) do
    cond do
      analysis.overall < 0.5 ->
        {:emergency, :critical_health}

      analysis.container_score < 0.7 ->
        {:restart_unhealthy, find_unhealthy(analysis)}

      analysis.node_score < 0.7 ->
        {:scale, :request_resources}

      length(analysis.anomalies) > 0 ->
        {:investigate, analysis.anomalies}

      true ->
        {:maintain, :healthy}
    end
  end

  defp act_with_consensus({:emergency, reason}, state) do
    # Emergency actions bypass consensus
    Logger.error("[DIST-OODA] Emergency action: #{inspect(reason)}")
    Indrajaal.UnifiedBus.broadcast({:emergency, reason})
    state
  end

  defp act_with_consensus({:restart_unhealthy, containers}, state) do
    # Restart unhealthy containers
    Enum.each(containers, fn container_id ->
      restart_container(container_id)
    end)
    state
  end

  defp act_with_consensus({action, _details}, state) when action in [:scale, :investigate, :maintain] do
    # These require logging but no immediate action
    state
  end

  defp schedule_cycle do
    Process.send_after(self(), :distributed_ooda_cycle, @cycle_ms)
  end

  # Stub implementations
  defp check_container_health(_name), do: %{status: :healthy, uptime: 3600}
  defp get_cpu_usage, do: 0.45
  defp get_memory_usage, do: 0.60
  defp get_disk_usage, do: 0.30
  defp get_scheduler_util, do: 0.50
  defp calculate_container_score(_), do: 0.9
  defp calculate_node_score(_), do: 0.85
  defp detect_anomalies(_, _), do: []
  defp find_unhealthy(_), do: []
  defp restart_container(_), do: :ok
end
```

## 2.5 Strategic OODA (L6-L7) - F# Observer Layer

```fsharp
// lib/cepaf/src/Intelligence/StrategicOODA.fs
namespace Indrajaal.Intelligence

open System
open System.Threading
open System.Threading.Tasks
open Indrajaal.Observability
open Indrajaal.Core.Domain

/// Strategic OODA loop for federation and cluster-level decisions.
/// Cycle time: 1s - 10min depending on operation type.
///
/// ## Observer Pattern
/// This module is an OBSERVER - it receives telemetry and proposes changes
/// but does NOT directly modify the observed system (Elixir Core).
///
/// ## STAMP Constraints
/// - SC-STRAT-001: Cycle MUST complete in <60s for standard ops
/// - SC-STRAT-002: Constitutional verification before any proposal
/// - SC-STRAT-003: Federation consensus required for L7 changes
/// - SC-STRAT-004: All proposals submitted via Guardian
module StrategicOODA =

    /// Timing budgets (in milliseconds)
    let private observeBudgetMs = 200
    let private orientBudgetMs = 300
    let private decideBudgetMs = 250
    let private actBudgetMs = 250
    let private totalBudgetMs = 1000

    /// Observed state from telemetry (READ-ONLY)
    type ObservedState = {
        /// Cluster health from FPPS consensus
        ClusterHealth: float
        /// Federation membership status
        FederationStatus: FederationStatus
        /// Pending evolution proposals from GDE
        PendingEvolutions: EvolutionProposal list
        /// Remaining error budget (SRE)
        ErrorBudgetRemaining: float
        /// OODA metrics from lower tiers
        LowerTierMetrics: OODAMetrics
        /// Swarm algorithm outputs
        SwarmOptimizations: SwarmOutput
    }

    and FederationStatus =
        | Standalone
        | FederationMember of nodeCount: int
        | FederationLeader of nodeCount: int

    and OODAMetrics = {
        FastOODACycleMs: float
        DistributedOODACycleMs: float
        CycleViolations: int
    }

    and SwarmOutput = {
        /// PSO-optimized parameters
        OptimalParameters: float list
        /// ACO-found change path
        OptimalChangePath: string list
        /// GWO pack hierarchy state
        PackHierarchy: WolfHierarchy
        /// Firefly quality convergence
        QualityConvergence: float
    }

    and WolfHierarchy = {
        Alpha: AgentId
        Betas: AgentId list
        Deltas: AgentId list
        Omegas: AgentId list
    }

    /// Strategic decision types
    type StrategicDecision =
        | ApproveEvolution of EvolutionProposal * confidence: float
        | RejectEvolution of EvolutionProposal * reason: string
        | RequestClusterScaleUp of nodeCount: int
        | RequestClusterScaleDown of nodeCount: int
        | TriggerFederationVote of proposal: string
        | EmergencyMode of reason: string
        | UpdateSwarmParameters of newParams: float list
        | RebalanceWolfPack of newHierarchy: WolfHierarchy
        | MaintainCurrentState

    /// Analysis result from ORIENT phase
    type OrientationAnalysis = {
        ConstitutionalResults: ConstitutionalResult list
        ImpactAnalysis: ImpactResult list
        SystemStress: float
        SwarmHealth: float
        Recommendations: Recommendation list
    }

    and ConstitutionalResult =
        | InvariantPassed of invariant: string
        | InvariantFailed of invariant: string * reason: string

    and ImpactResult = {
        ProposalId: string
        ImpactScore: int
        AffectedLayers: string list
        RiskLevel: RiskLevel
    }

    and RiskLevel = Low | Medium | High | Critical

    and Recommendation =
        | ApproveWithConfidence of float
        | RejectWithReason of string
        | DeferForMoreData
        | EscalateToGuardian

    // ==================== OODA CYCLE ====================

    /// Run one strategic OODA cycle
    let runCycle (digitalTwin: IDigitalTwin) : Async<StrategicDecision> =
        async {
            let startTime = DateTime.UtcNow

            // OBSERVE: Read from Digital Twin (observer pattern)
            let! observed = observe digitalTwin
            let observeTime = (DateTime.UtcNow - startTime).TotalMilliseconds

            // ORIENT: Constitutional and impact analysis
            let orientStart = DateTime.UtcNow
            let analysis = orient observed
            let orientTime = (DateTime.UtcNow - orientStart).TotalMilliseconds

            // DECIDE: Choose action with Guardian consultation
            let decideStart = DateTime.UtcNow
            let decision = decide analysis observed
            let decideTime = (DateTime.UtcNow - decideStart).TotalMilliseconds

            // ACT: Submit proposal (does NOT execute directly)
            let actStart = DateTime.UtcNow
            do! act decision digitalTwin
            let actTime = (DateTime.UtcNow - actStart).TotalMilliseconds

            let totalTime = (DateTime.UtcNow - startTime).TotalMilliseconds

            // Emit meta-telemetry
            do! emitCycleMetrics {|
                ObserveMs = observeTime
                OrientMs = orientTime
                DecideMs = decideTime
                ActMs = actTime
                TotalMs = totalTime
                Decision = decision.ToString()
            |}

            // Warn if over budget
            if totalTime > float totalBudgetMs then
                printfn "[STRATEGIC-OODA] Cycle exceeded budget: %.2fms" totalTime

            return decision
        }

    // ==================== OBSERVE PHASE ====================

    /// Observe system state from Digital Twin (READ-ONLY)
    let private observe (twin: IDigitalTwin) : Async<ObservedState> =
        async {
            let! clusterHealth = twin.GetClusterHealthAsync()
            let! fedStatus = twin.GetFederationStatusAsync()
            let! evolutions = twin.GetPendingEvolutionsAsync()
            let! errorBudget = twin.GetErrorBudgetAsync()
            let! oodaMetrics = twin.GetOODAMetricsAsync()
            let! swarmOutput = twin.GetSwarmOutputAsync()

            return {
                ClusterHealth = clusterHealth
                FederationStatus = fedStatus
                PendingEvolutions = evolutions
                ErrorBudgetRemaining = errorBudget
                LowerTierMetrics = oodaMetrics
                SwarmOptimizations = swarmOutput
            }
        }

    // ==================== ORIENT PHASE ====================

    /// Analyze observations with constitutional awareness
    let private orient (state: ObservedState) : OrientationAnalysis =
        // Constitutional verification
        let constitutionalResults =
            state.PendingEvolutions
            |> List.collect (fun proposal ->
                [
                    verifyExistence proposal
                    verifyRegeneration proposal
                    verifyHistory proposal
                    verifyVerification proposal
                    verifyHumanAlignment proposal
                    verifyTruthfulness proposal
                ]
            )

        // Impact analysis (5-order effects)
        let impactResults =
            state.PendingEvolutions
            |> List.map analyzeImpact

        // System stress calculation
        let systemStress = calculateSystemStress state

        // Swarm health from GWO pack state
        let swarmHealth = calculateSwarmHealth state.SwarmOptimizations

        // Generate recommendations
        let recommendations =
            state.PendingEvolutions
            |> List.map (fun p -> generateRecommendation p constitutionalResults impactResults)

        {
            ConstitutionalResults = constitutionalResults
            ImpactAnalysis = impactResults
            SystemStress = systemStress
            SwarmHealth = swarmHealth
            Recommendations = recommendations
        }

    let private verifyExistence (proposal: EvolutionProposal) =
        if proposal.ImpactScore > 40 then
            InvariantFailed ("Psi0-Existence", "Impact too high for survival")
        else
            InvariantPassed "Psi0-Existence"

    let private verifyRegeneration (proposal: EvolutionProposal) =
        if proposal.AffectsStateStore && not proposal.HasMigrationPath then
            InvariantFailed ("Psi1-Regeneration", "No migration path")
        else
            InvariantPassed "Psi1-Regeneration"

    let private verifyHistory (proposal: EvolutionProposal) =
        InvariantPassed "Psi2-History"  // Always log to DuckDB

    let private verifyVerification (proposal: EvolutionProposal) =
        if proposal.HasTests then
            InvariantPassed "Psi3-Verification"
        else
            InvariantFailed ("Psi3-Verification", "No tests provided")

    let private verifyHumanAlignment (proposal: EvolutionProposal) =
        match proposal.FounderImpact with
        | Positive | Neutral -> InvariantPassed "Psi4-HumanAlignment"
        | Negative -> InvariantFailed ("Psi4-HumanAlignment", "Harms Founder")

    let private verifyTruthfulness (proposal: EvolutionProposal) =
        InvariantPassed "Psi5-Truthfulness"

    let private analyzeImpact (proposal: EvolutionProposal) : ImpactResult =
        {
            ProposalId = proposal.Id
            ImpactScore = proposal.ImpactScore
            AffectedLayers = proposal.AffectedLayers
            RiskLevel =
                if proposal.ImpactScore > 30 then Critical
                elif proposal.ImpactScore > 20 then High
                elif proposal.ImpactScore > 10 then Medium
                else Low
        }

    let private calculateSystemStress (state: ObservedState) : float =
        let healthFactor = 1.0 - state.ClusterHealth
        let errorFactor = 1.0 - state.ErrorBudgetRemaining
        let cycleViolations = float state.LowerTierMetrics.CycleViolations / 10.0
        (healthFactor + errorFactor + cycleViolations) / 3.0

    let private calculateSwarmHealth (swarm: SwarmOutput) : float =
        swarm.QualityConvergence

    let private generateRecommendation proposal constitutional impact =
        let hasFailures =
            constitutional
            |> List.exists (function InvariantFailed _ -> true | _ -> false)

        let impactResult =
            impact
            |> List.tryFind (fun i -> i.ProposalId = proposal.Id)

        match hasFailures, impactResult with
        | true, _ -> RejectWithReason "Constitutional violation"
        | false, Some { RiskLevel = Critical } -> EscalateToGuardian
        | false, Some { RiskLevel = High } -> ApproveWithConfidence 0.7
        | false, Some { RiskLevel = Medium } -> ApproveWithConfidence 0.85
        | false, _ -> ApproveWithConfidence 0.95

    // ==================== DECIDE PHASE ====================

    /// Make strategic decision based on analysis
    let private decide (analysis: OrientationAnalysis) (state: ObservedState) : StrategicDecision =
        // Check for emergencies first
        if analysis.SystemStress > 0.9 then
            EmergencyMode "System stress exceeds 90%"

        // Check if swarm needs rebalancing
        elif analysis.SwarmHealth < 0.5 then
            let newHierarchy = rebalancePackBasedOnFitness state.SwarmOptimizations.PackHierarchy
            RebalanceWolfPack newHierarchy

        // Check for PSO parameter updates
        elif needsParameterUpdate state.SwarmOptimizations.OptimalParameters then
            UpdateSwarmParameters state.SwarmOptimizations.OptimalParameters

        // Process pending evolutions
        elif not (List.isEmpty state.PendingEvolutions) then
            let bestProposal = selectBestProposal state.PendingEvolutions analysis.Recommendations
            match bestProposal with
            | Some (proposal, ApproveWithConfidence conf) when conf >= 0.85 ->
                ApproveEvolution (proposal, conf)
            | Some (proposal, RejectWithReason reason) ->
                RejectEvolution (proposal, reason)
            | Some (_, EscalateToGuardian) ->
                MaintainCurrentState  // Guardian will handle
            | _ ->
                MaintainCurrentState

        else
            MaintainCurrentState

    let private rebalancePackBasedOnFitness (current: WolfHierarchy) : WolfHierarchy =
        // This would use actual fitness scores from agents
        current  // Placeholder

    let private needsParameterUpdate (params: float list) : bool =
        false  // Placeholder

    let private selectBestProposal proposals recommendations =
        List.zip proposals recommendations
        |> List.sortByDescending (fun (_, rec) ->
            match rec with
            | ApproveWithConfidence c -> c
            | _ -> 0.0
        )
        |> List.tryHead

    // ==================== ACT PHASE ====================

    /// Submit decision (does NOT execute directly)
    let private act (decision: StrategicDecision) (twin: IDigitalTwin) : Async<unit> =
        async {
            match decision with
            | ApproveEvolution (proposal, confidence) ->
                // Submit to Guardian via Zenoh
                do! twin.SubmitToGuardianAsync(proposal, confidence)

            | RejectEvolution (proposal, reason) ->
                do! twin.LogRejectionAsync(proposal.Id, reason)

            | EmergencyMode reason ->
                // Alert but don't execute - Elixir handles emergency
                do! twin.BroadcastEmergencyAsync(reason)

            | UpdateSwarmParameters newParams ->
                do! twin.UpdateSwarmConfigAsync(newParams)

            | RebalanceWolfPack newHierarchy ->
                do! twin.RebalanceSwarmAsync(newHierarchy)

            | _ ->
                ()  // Maintain current state - no action needed
        }

    let private emitCycleMetrics metrics : Async<unit> =
        async {
            // Would publish to Zenoh topic: indrajaal/ooda/strategic/cycle
            ()
        }
```

---

# 3. SWARM-OODA COUPLING

## 3.1 Pheromone Trails via Zenoh Pub/Sub

```elixir
defmodule Indrajaal.Swarm.PheromoneTrails do
  @moduledoc """
  Pheromone communication layer using Zenoh pub/sub.

  ## Topics
  - indrajaal/swarm/pheromone/aco/{path_id} - ACO path pheromones
  - indrajaal/swarm/pheromone/quality - Quality scores (firefly brightness)
  - indrajaal/swarm/pheromone/resource - Resource allocation (bee waggle)
  - indrajaal/swarm/pheromone/leadership - Pack hierarchy (GWO)

  ## STAMP Constraints
  - SC-PHER-001: Pheromone decay rate configurable per algorithm
  - SC-PHER-002: Pheromone levels bounded to prevent saturation
  - SC-PHER-003: Pub/sub latency < 10ms
  """

  use GenServer
  require Logger

  @decay_interval_ms 1000
  @aco_decay_rate 0.1
  @quality_decay_rate 0.05

  defstruct [
    :aco_trails,
    :quality_scores,
    :resource_allocation,
    :pack_hierarchy
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to swarm topics
    subscribe_to_topics()

    # Schedule decay
    schedule_decay()

    {:ok, %__MODULE__{
      aco_trails: %{},
      quality_scores: %{},
      resource_allocation: %{},
      pack_hierarchy: nil
    }}
  end

  @doc """
  Deposit pheromone for ACO path segment.
  """
  @spec deposit_aco(from :: term(), to :: term(), amount :: float()) :: :ok
  def deposit_aco(from, to, amount) do
    GenServer.cast(__MODULE__, {:deposit_aco, from, to, amount})
  end

  @doc """
  Publish quality score (firefly brightness).
  """
  @spec publish_quality(agent_id :: String.t(), quality :: float()) :: :ok
  def publish_quality(agent_id, quality) do
    GenServer.cast(__MODULE__, {:publish_quality, agent_id, quality})
  end

  @doc """
  Publish resource allocation (bee waggle dance).
  """
  @spec publish_resource(task_id :: String.t(), fitness :: float()) :: :ok
  def publish_resource(task_id, fitness) do
    GenServer.cast(__MODULE__, {:publish_resource, task_id, fitness})
  end

  @doc """
  Update pack hierarchy (GWO).
  """
  @spec update_hierarchy(hierarchy :: map()) :: :ok
  def update_hierarchy(hierarchy) do
    GenServer.cast(__MODULE__, {:update_hierarchy, hierarchy})
  end

  @doc """
  Get current ACO pheromone level for edge.
  """
  @spec get_aco_pheromone(from :: term(), to :: term()) :: float()
  def get_aco_pheromone(from, to) do
    GenServer.call(__MODULE__, {:get_aco, from, to})
  end

  @impl true
  def handle_cast({:deposit_aco, from, to, amount}, state) do
    edge = {from, to}
    current = Map.get(state.aco_trails, edge, 0.1)
    new_value = min(10.0, current + amount)  # SC-PHER-002

    new_trails = Map.put(state.aco_trails, edge, new_value)

    # Publish to Zenoh
    publish_zenoh("indrajaal/swarm/pheromone/aco/#{from}_#{to}", new_value)

    {:noreply, %{state | aco_trails: new_trails}}
  end

  def handle_cast({:publish_quality, agent_id, quality}, state) do
    new_scores = Map.put(state.quality_scores, agent_id, quality)
    publish_zenoh("indrajaal/swarm/pheromone/quality", %{agent_id => quality})
    {:noreply, %{state | quality_scores: new_scores}}
  end

  def handle_cast({:publish_resource, task_id, fitness}, state) do
    new_alloc = Map.put(state.resource_allocation, task_id, fitness)
    publish_zenoh("indrajaal/swarm/pheromone/resource", %{task_id => fitness})
    {:noreply, %{state | resource_allocation: new_alloc}}
  end

  def handle_cast({:update_hierarchy, hierarchy}, state) do
    publish_zenoh("indrajaal/swarm/pheromone/leadership", hierarchy)
    {:noreply, %{state | pack_hierarchy: hierarchy}}
  end

  @impl true
  def handle_call({:get_aco, from, to}, _from, state) do
    edge = {from, to}
    value = Map.get(state.aco_trails, edge, 0.1)
    {:reply, value, state}
  end

  @impl true
  def handle_info(:decay_pheromones, state) do
    # Decay ACO trails
    new_aco = Map.new(state.aco_trails, fn {edge, value} ->
      {edge, max(0.1, value * (1 - @aco_decay_rate))}
    end)

    # Decay quality scores
    new_quality = Map.new(state.quality_scores, fn {agent, value} ->
      {agent, max(0.0, value * (1 - @quality_decay_rate))}
    end)

    schedule_decay()
    {:noreply, %{state | aco_trails: new_aco, quality_scores: new_quality}}
  end

  defp subscribe_to_topics do
    # Would use Zenoh NIF for actual subscription
    :ok
  end

  defp publish_zenoh(topic, data) do
    # Would use Zenoh NIF for actual publishing
    :telemetry.execute([:swarm, :pheromone, :publish], %{topic: topic}, %{data: data})
  end

  defp schedule_decay do
    Process.send_after(self(), :decay_pheromones, @decay_interval_ms)
  end
end
```

## 3.2 Emergent Behavior for Change Optimization

```elixir
defmodule Indrajaal.Swarm.EmergentBehavior do
  @moduledoc """
  Coordinates emergent behavior across swarm algorithms.

  ## Emergent Properties
  - Self-organization: Agents organize without central control
  - Collective intelligence: Swarm finds better solutions than individuals
  - Adaptability: System adapts to changing conditions
  - Resilience: System maintains function despite failures

  ## Integration Points
  - GWO provides leadership hierarchy
  - PSO tunes parameters continuously
  - ACO finds optimal change sequences
  - BEE allocates agents to tasks
  - FIREFLY attracts agents to quality
  """

  use GenServer

  alias Indrajaal.Swarm.{GreyWolf, ParticleSwarm, AntColony, BeeAlgorithm, Firefly}
  alias Indrajaal.Swarm.PheromoneTrails

  @emergence_cycle_ms 500  # Check for emergence every 500ms

  defstruct [
    :gwo_state,
    :pso_state,
    :aco_state,
    :bee_state,
    :firefly_state,
    :emergent_metrics
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_emergence_check()
    {:ok, initialize_swarm_states()}
  end

  @impl true
  def handle_info(:emergence_check, state) do
    # Run one iteration of each algorithm
    new_state = state
      |> run_gwo_iteration()
      |> run_pso_iteration()
      |> run_aco_iteration()
      |> run_bee_iteration()
      |> run_firefly_iteration()
      |> calculate_emergent_metrics()

    # Publish emergent state
    publish_emergent_state(new_state.emergent_metrics)

    schedule_emergence_check()
    {:noreply, new_state}
  end

  defp run_gwo_iteration(state) do
    # Target is current optimization goal
    target = get_current_target()
    new_pack = GreyWolf.hunt(state.gwo_state, target)

    # Update hierarchy in pheromone trails
    hierarchy = extract_hierarchy(new_pack)
    PheromoneTrails.update_hierarchy(hierarchy)

    %{state | gwo_state: new_pack}
  end

  defp run_pso_iteration(state) do
    {new_particles, new_gbest} = ParticleSwarm.update_swarm(
      state.pso_state.particles,
      state.pso_state.global_best
    )

    %{state | pso_state: %{
      state.pso_state |
      particles: new_particles,
      global_best: new_gbest
    }}
  end

  defp run_aco_iteration(state) do
    # Find optimal path through pending changes
    change_graph = get_change_dependency_graph()
    {path, pheromones} = AntColony.find_optimal_path(
      change_graph,
      :start,
      :end,
      10,  # ants
      1    # single iteration per cycle
    )

    %{state | aco_state: %{
      state.aco_state |
      best_path: path,
      pheromones: pheromones
    }}
  end

  defp run_bee_iteration(state) do
    tasks = get_pending_tasks()
    allocations = BeeAlgorithm.allocate(state.bee_state, tasks)

    # Publish task fitness via waggle dance
    Enum.each(tasks, fn task ->
      PheromoneTrails.publish_resource(task.id, task.fitness)
    end)

    %{state | bee_state: %{
      state.bee_state |
      allocations: allocations
    }}
  end

  defp run_firefly_iteration(state) do
    new_fireflies = Firefly.illuminate(state.firefly_state)

    # Publish quality scores
    Enum.each(new_fireflies, fn ff ->
      PheromoneTrails.publish_quality(ff.id, ff.brightness)
    end)

    %{state | firefly_state: new_fireflies}
  end

  defp calculate_emergent_metrics(state) do
    metrics = %{
      # GWO convergence: How tight is the pack?
      pack_cohesion: calculate_pack_cohesion(state.gwo_state),

      # PSO convergence: How close are particles to gbest?
      pso_convergence: calculate_pso_convergence(state.pso_state),

      # ACO path quality: Best path cost improvement
      path_quality: calculate_path_quality(state.aco_state),

      # BEE allocation efficiency
      allocation_efficiency: calculate_allocation_efficiency(state.bee_state),

      # FIREFLY clustering: Are agents grouping around quality?
      quality_clustering: calculate_quality_clustering(state.firefly_state),

      # Overall emergent intelligence score
      emergent_intelligence: 0.0  # Calculated below
    }

    # Weighted combination of all metrics
    ei = 0.2 * metrics.pack_cohesion +
         0.2 * metrics.pso_convergence +
         0.2 * metrics.path_quality +
         0.2 * metrics.allocation_efficiency +
         0.2 * metrics.quality_clustering

    %{state | emergent_metrics: %{metrics | emergent_intelligence: ei}}
  end

  defp publish_emergent_state(metrics) do
    :telemetry.execute(
      [:swarm, :emergence, :metrics],
      metrics,
      %{timestamp: System.system_time(:millisecond)}
    )
  end

  defp schedule_emergence_check do
    Process.send_after(self(), :emergence_check, @emergence_cycle_ms)
  end

  # Stub implementations
  defp initialize_swarm_states, do: %__MODULE__{}
  defp get_current_target, do: %{}
  defp extract_hierarchy(_), do: %{}
  defp get_change_dependency_graph, do: %{}
  defp get_pending_tasks, do: []
  defp calculate_pack_cohesion(_), do: 0.8
  defp calculate_pso_convergence(_), do: 0.75
  defp calculate_path_quality(_), do: 0.85
  defp calculate_allocation_efficiency(_), do: 0.9
  defp calculate_quality_clustering(_), do: 0.7
end
```

## 3.3 Fitness Functions for Evolution Quality

```elixir
defmodule Indrajaal.Swarm.FitnessFunctions do
  @moduledoc """
  Fitness functions for swarm-based evolution optimization.

  ## Fitness Dimensions
  - Code Quality: Coverage, issues, complexity
  - Change Quality: Impact, reversibility, documentation
  - System Quality: Health, performance, stability
  - Evolution Quality: Success rate, adaptation speed

  ## STAMP Constraints
  - SC-FIT-001: All fitness values normalized [0.0, 1.0]
  - SC-FIT-002: Weights configurable per domain
  - SC-FIT-003: Historical fitness tracked in DuckDB
  """

  @type fitness_result :: %{
    overall: float(),
    code_quality: float(),
    change_quality: float(),
    system_quality: float(),
    evolution_quality: float()
  }

  # Default weights
  @default_weights %{
    code_quality: 0.3,
    change_quality: 0.25,
    system_quality: 0.25,
    evolution_quality: 0.2
  }

  @doc """
  Calculate comprehensive fitness for an agent's solution.
  """
  @spec calculate_fitness(solution :: map(), domain :: atom()) :: fitness_result()
  def calculate_fitness(solution, domain \\ :default) do
    weights = get_domain_weights(domain)

    code_q = code_quality_fitness(solution)
    change_q = change_quality_fitness(solution)
    system_q = system_quality_fitness(solution)
    evolution_q = evolution_quality_fitness(solution)

    overall =
      weights.code_quality * code_q +
      weights.change_quality * change_q +
      weights.system_quality * system_q +
      weights.evolution_quality * evolution_q

    %{
      overall: clamp(overall),
      code_quality: code_q,
      change_quality: change_q,
      system_quality: system_q,
      evolution_quality: evolution_q
    }
  end

  @doc """
  Code quality fitness: coverage, credo issues, complexity.
  """
  @spec code_quality_fitness(solution :: map()) :: float()
  def code_quality_fitness(solution) do
    coverage_score = Map.get(solution, :coverage, 0.0) / 100.0

    # Inverse of credo issues (0 issues = 1.0)
    credo_issues = Map.get(solution, :credo_issues, 10)
    credo_score = 1.0 / (1.0 + credo_issues / 10.0)

    # Inverse of complexity
    complexity = Map.get(solution, :complexity, 20.0)
    complexity_score = 1.0 / (1.0 + complexity / 15.0)

    (coverage_score * 0.4 + credo_score * 0.3 + complexity_score * 0.3)
    |> clamp()
  end

  @doc """
  Change quality fitness: impact, reversibility, documentation.
  """
  @spec change_quality_fitness(solution :: map()) :: float()
  def change_quality_fitness(solution) do
    # Lower impact is better
    impact_score = Map.get(solution, :impact_score, 30)
    impact_fitness = 1.0 - (impact_score / 50.0)

    # Reversibility presence
    reversible = if Map.get(solution, :has_reversal_plan, false), do: 1.0, else: 0.5

    # Documentation presence
    documented = if Map.get(solution, :is_documented, false), do: 1.0, else: 0.6

    (impact_fitness * 0.4 + reversible * 0.3 + documented * 0.3)
    |> clamp()
  end

  @doc """
  System quality fitness: health, performance, stability.
  """
  @spec system_quality_fitness(solution :: map()) :: float()
  def system_quality_fitness(solution) do
    health = Map.get(solution, :system_health, 0.8)

    # OODA cycle adherence (closer to target is better)
    ooda_time = Map.get(solution, :ooda_cycle_ms, 50)
    ooda_target = 50
    ooda_fitness = 1.0 - abs(ooda_time - ooda_target) / ooda_target

    # Error rate (lower is better)
    error_rate = Map.get(solution, :error_rate, 0.05)
    error_fitness = 1.0 - error_rate

    (health * 0.4 + ooda_fitness * 0.3 + error_fitness * 0.3)
    |> clamp()
  end

  @doc """
  Evolution quality fitness: success rate, adaptation speed.
  """
  @spec evolution_quality_fitness(solution :: map()) :: float()
  def evolution_quality_fitness(solution) do
    # Historical success rate
    success_rate = Map.get(solution, :evolution_success_rate, 0.7)

    # Adaptation speed (generations to convergence)
    generations = Map.get(solution, :generations_to_converge, 50)
    speed_fitness = 1.0 - (generations / 100.0)

    # Diversity maintenance
    diversity = Map.get(solution, :population_diversity, 0.3)
    diversity_fitness = diversity / 0.5  # Target diversity is 0.5

    (success_rate * 0.4 + speed_fitness * 0.3 + diversity_fitness * 0.3)
    |> clamp()
  end

  @doc """
  Get domain-specific fitness weights.
  """
  @spec get_domain_weights(domain :: atom()) :: map()
  def get_domain_weights(:safety) do
    %{
      code_quality: 0.35,
      change_quality: 0.35,
      system_quality: 0.20,
      evolution_quality: 0.10
    }
  end

  def get_domain_weights(:performance) do
    %{
      code_quality: 0.25,
      change_quality: 0.20,
      system_quality: 0.35,
      evolution_quality: 0.20
    }
  end

  def get_domain_weights(_default) do
    @default_weights
  end

  defp clamp(value) do
    max(0.0, min(1.0, value))
  end
end
```

---

# 4. 50-AGENT GREY WOLF PACK ARCHITECTURE

## 4.1 Complete Pack Hierarchy

```
+============================================================================+
|                    50-AGENT GREY WOLF PACK HIERARCHY                        |
+============================================================================+
|                                                                             |
|  ╔═══════════════════════════════════════════════════════════════════════╗ |
|  ║  ALPHA WOLF (1) - Executive Agent                                     ║ |
|  ║  ┌─────────────────────────────────────────────────────────────────┐  ║ |
|  ║  │  EXEC-001: Master Orchestrator                                  │  ║ |
|  ║  │  • Model: Claude Opus 4.5 (complex decisions)                   │  ║ |
|  ║  │  • OODA: Strategic (1s cycle)                                   │  ║ |
|  ║  │  • Authority: Absolute veto, /compact trigger                   │  ║ |
|  ║  │  • Layer Scope: L5-L7 change approval                           │  ║ |
|  ║  │  • Swarm Role: Hunt leader, prey selection                      │  ║ |
|  ║  └─────────────────────────────────────────────────────────────────┘  ║ |
|  ╚═══════════════════════════════════════════════════════════════════════╝ |
|                                     │                                       |
|                                     ▼                                       |
|  ╔═══════════════════════════════════════════════════════════════════════╗ |
|  ║  BETA WOLVES (10) - Domain Supervisors                                ║ |
|  ║  ┌─────────────────────────────────────────────────────────────────┐  ║ |
|  ║  │  Model: Claude Sonnet 4 (judgment required)                     │  ║ |
|  ║  │  OODA: Distributed (100ms cycle)                                │  ║ |
|  ║  │  Authority: Domain decisions, escalation to Alpha               │  ║ |
|  ║  │  Swarm Role: Encircle prey, coordinate delta pack               │  ║ |
|  ║  │                                                                 │  ║ |
|  ║  │  SUP-ACCESS    │ SUP-ALARMS    │ SUP-DEVICES   │ SUP-SAFETY    │  ║ |
|  ║  │  SUP-BILLING   │ SUP-CONFIG    │ SUP-INTEGR    │ SUP-ANALYT    │  ║ |
|  ║  │  SUP-COMPLI    │ SUP-INTELLI                                    │  ║ |
|  ║  └─────────────────────────────────────────────────────────────────┘  ║ |
|  ╚═══════════════════════════════════════════════════════════════════════╝ |
|                                     │                                       |
|                                     ▼                                       |
|  ╔═══════════════════════════════════════════════════════════════════════╗ |
|  ║  DELTA WOLVES (15) - Functional Agents                                ║ |
|  ║  ┌─────────────────────────────────────────────────────────────────┐  ║ |
|  ║  │  Model: Claude Sonnet 4 (specialized tasks)                     │  ║ |
|  ║  │  OODA: Fast (50ms cycle)                                        │  ║ |
|  ║  │  Authority: Task execution, omega coordination                  │  ║ |
|  ║  │  Swarm Role: Attack prey, guide omegas                          │  ║ |
|  ║  │                                                                 │  ║ |
|  ║  │  Guardian      │ Sentinel      │ PatternHunter │ TrainingGym   │  ║ |
|  ║  │  GDE           │ MetricsSink   │ TelemetryHub  │ EventRouter   │  ║ |
|  ║  │  StateManager  │ CacheLayer    │ BridgeSvc     │ AuthProvider  │  ║ |
|  ║  │  AuditLogger   │ NotifyEngine  │ HealthCheck                    │  ║ |
|  ║  └─────────────────────────────────────────────────────────────────┘  ║ |
|  ╚═══════════════════════════════════════════════════════════════════════╝ |
|                                     │                                       |
|                                     ▼                                       |
|  ╔═══════════════════════════════════════════════════════════════════════╗ |
|  ║  OMEGA WOLVES (24) - Worker Agents                                    ║ |
|  ║  ┌─────────────────────────────────────────────────────────────────┐  ║ |
|  ║  │  Model: Claude Haiku 3.5 (cost-efficient)                       │  ║ |
|  ║  │  OODA: Micro (<1ms, inline)                                     │  ║ |
|  ║  │  Authority: Atomic operations only                              │  ║ |
|  ║  │  Swarm Role: Chase and capture, follow pack                     │  ║ |
|  ║  │                                                                 │  ║ |
|  ║  │  WRK-COMPILE-{1-3}   │ WRK-TEST-{1-5}      │ WRK-CREDO-{1-2}   │  ║ |
|  ║  │  WRK-FIX-{1-5}       │ WRK-DOC-{1-2}       │ WRK-EXPLORE-{1-3} │  ║ |
|  ║  │  WRK-SWARM-{1-4}                                                │  ║ |
|  ║  └─────────────────────────────────────────────────────────────────┘  ║ |
|  ╚═══════════════════════════════════════════════════════════════════════╝ |
|                                                                             |
+============================================================================+
```

## 4.2 Pack Communication Protocol

```elixir
defmodule Indrajaal.Swarm.PackCommunication do
  @moduledoc """
  Grey Wolf pack communication protocol.

  ## Communication Patterns
  - Alpha → Beta: Strategic directives (Zenoh: indrajaal/pack/alpha/directive)
  - Beta → Delta: Task assignments (Zenoh: indrajaal/pack/beta/{domain}/assign)
  - Delta → Omega: Work orders (Zenoh: indrajaal/pack/delta/{function}/order)
  - Omega → Delta: Status reports (Zenoh: indrajaal/pack/omega/{id}/status)
  - Any → Alpha: Escalations (Zenoh: indrajaal/pack/escalation)

  ## STAMP Constraints
  - SC-PACK-001: Alpha directives MUST be acknowledged within 100ms
  - SC-PACK-002: Escalations to Alpha MUST include full context
  - SC-PACK-003: Status reports every OODA cycle
  """

  use GenServer
  require Logger

  @topics %{
    alpha_directive: "indrajaal/pack/alpha/directive",
    escalation: "indrajaal/pack/escalation",
    pack_status: "indrajaal/pack/status"
  }

  defstruct [
    :wolf_id,
    :rank,
    :domain,
    :superior,
    :subordinates,
    :pending_directives,
    :pending_acks
  ]

  # ============ PUBLIC API ============

  @doc """
  Send directive from Alpha to Beta.
  """
  @spec alpha_directive(directive :: map(), target_betas :: list(atom())) :: :ok
  def alpha_directive(directive, target_betas) do
    GenServer.cast(__MODULE__, {:alpha_directive, directive, target_betas})
  end

  @doc """
  Assign task from Beta to Delta.
  """
  @spec beta_assign(domain :: atom(), task :: map(), target_deltas :: list(atom())) :: :ok
  def beta_assign(domain, task, target_deltas) do
    GenServer.cast(__MODULE__, {:beta_assign, domain, task, target_deltas})
  end

  @doc """
  Issue work order from Delta to Omega.
  """
  @spec delta_order(function :: atom(), work :: map(), target_omegas :: list(String.t())) :: :ok
  def delta_order(function, work, target_omegas) do
    GenServer.cast(__MODULE__, {:delta_order, function, work, target_omegas})
  end

  @doc """
  Report status from any wolf to superior.
  """
  @spec report_status(wolf_id :: String.t(), status :: map()) :: :ok
  def report_status(wolf_id, status) do
    GenServer.cast(__MODULE__, {:report_status, wolf_id, status})
  end

  @doc """
  Escalate issue to Alpha.
  """
  @spec escalate_to_alpha(wolf_id :: String.t(), issue :: map()) :: :ok
  def escalate_to_alpha(wolf_id, issue) do
    GenServer.cast(__MODULE__, {:escalate, wolf_id, issue})
  end

  # ============ MESSAGE STRUCTURES ============

  @type directive :: %{
    id: String.t(),
    type: :hunt | :defend | :rest | :migrate,
    priority: :critical | :high | :normal | :low,
    payload: map(),
    deadline_ms: pos_integer()
  }

  @type status_report :: %{
    wolf_id: String.t(),
    rank: :alpha | :beta | :delta | :omega,
    status: :active | :idle | :blocked | :error,
    current_task: String.t() | nil,
    fitness: float(),
    ooda_metrics: map()
  }

  @type escalation :: %{
    from_wolf: String.t(),
    from_rank: atom(),
    issue_type: :block | :error | :resource | :decision,
    context: map(),
    urgency: :immediate | :high | :normal
  }
end
```

---

# 5. STAMP CONSTRAINTS & AOR RULES

## 5.1 STAMP Constraints (Swarm-OODA)

| ID | Constraint | Severity | Layer | Enforcement |
|----|------------|----------|-------|-------------|
| **Grey Wolf (GWO)** |
| SC-GWO-001 | Alpha has absolute veto authority | CRITICAL | All | Guardian validation |
| SC-GWO-002 | Beta wolves coordinate within domain boundaries | HIGH | L3-L4 | Domain check |
| SC-GWO-003 | Delta wolves cannot override Beta decisions | HIGH | L2-L3 | Rank validation |
| SC-GWO-004 | Omega wolves report to nearest Delta | MEDIUM | L1-L2 | Hierarchy routing |
| SC-GWO-005 | Pack hierarchy updated every 500ms | HIGH | All | Emergence cycle |
| **Particle Swarm (PSO)** |
| SC-PSO-001 | Particles MUST stay within safe parameter bounds | CRITICAL | L3-L5 | Boundary clamp |
| SC-PSO-002 | Best position updates require Guardian validation | HIGH | L4+ | Guardian gate |
| SC-PSO-003 | Inertia weight decays to prevent oscillation | MEDIUM | All | Config |
| **Ant Colony (ACO)** |
| SC-ACO-001 | Pheromone levels bounded [0.1, 10.0] | HIGH | All | Clamp function |
| SC-ACO-002 | Ants MUST respect dependency constraints | CRITICAL | L2-L4 | Graph validation |
| SC-ACO-003 | Evaporation rate tuned per layer | MEDIUM | All | Config |
| **Bee Algorithm** |
| SC-BEE-001 | Scout allocation <= 20% of swarm | HIGH | All | Allocation check |
| SC-BEE-002 | Task abandonment after limit trials | MEDIUM | L2-L3 | Trial counter |
| SC-BEE-003 | Resource reallocation respects OODA timing | HIGH | All | Budget check |
| **Firefly Algorithm** |
| SC-FIREFLY-001 | Brightness bounded [0.0, 1.0] | HIGH | All | Normalize |
| SC-FIREFLY-002 | Random movement bounded by layer | MEDIUM | L1-L3 | Layer config |
| SC-FIREFLY-003 | Attraction coefficient tuned by domain | LOW | All | Domain config |
| **Pheromone Trails** |
| SC-PHER-001 | Pheromone decay rate configurable per algorithm | MEDIUM | All | Config |
| SC-PHER-002 | Pheromone levels bounded to prevent saturation | HIGH | All | Clamp |
| SC-PHER-003 | Pub/sub latency < 10ms | HIGH | All | Zenoh NIF |
| **OODA Hierarchy** |
| SC-MICRO-001 | No blocking operations in micro OODA | CRITICAL | L0-L1 | Code review |
| SC-MICRO-002 | Pattern matching MUST be exhaustive | HIGH | L0-L1 | Dialyzer |
| SC-MICRO-003 | Guard clauses MUST be pure functions | HIGH | L0-L1 | Credo |
| SC-FAST-001 | Cycle MUST complete in <100ms | CRITICAL | L2-L3 | Telemetry alert |
| SC-FAST-002 | OBSERVE phase < 10ms | HIGH | L2-L3 | Phase budget |
| SC-FAST-003 | Hysteresis prevents oscillation | HIGH | L2-L3 | Hold counter |
| SC-FAST-004 | All phases emit telemetry | HIGH | L2-L3 | Audit |
| SC-DIST-001 | Cycle MUST complete in <200ms | HIGH | L4-L5 | Telemetry |
| SC-DIST-002 | Container health via FPPS consensus | CRITICAL | L4 | FPPS module |
| SC-DIST-003 | Scaling decisions require 2oo3 voting | CRITICAL | L4-L5 | Quorum |
| SC-STRAT-001 | Cycle MUST complete in <60s | HIGH | L6-L7 | Telemetry |
| SC-STRAT-002 | Constitutional verification before proposal | CRITICAL | L6-L7 | Oracle |
| SC-STRAT-003 | Federation consensus for L7 changes | CRITICAL | L7 | Protocol |
| SC-STRAT-004 | All proposals via Guardian | CRITICAL | L6-L7 | Gateway |
| **Fitness Functions** |
| SC-FIT-001 | All fitness values normalized [0.0, 1.0] | HIGH | All | Clamp |
| SC-FIT-002 | Weights configurable per domain | MEDIUM | All | Config |
| SC-FIT-003 | Historical fitness tracked in DuckDB | HIGH | L3 | Append-only |
| **Pack Communication** |
| SC-PACK-001 | Alpha directives acked within 100ms | HIGH | All | Timeout |
| SC-PACK-002 | Escalations include full context | MEDIUM | All | Schema |
| SC-PACK-003 | Status reports every OODA cycle | MEDIUM | All | Telemetry |

## 5.2 AOR Rules (Swarm-OODA)

| ID | Rule | Enforcement |
|----|------|-------------|
| **Grey Wolf Pack** |
| AOR-GWO-001 | Alpha MUST review all L4+ changes before approval | Guardian gate |
| AOR-GWO-002 | Beta wolves MUST escalate cross-domain conflicts | Escalation bus |
| AOR-GWO-003 | Delta wolves MUST coordinate omega allocation via BEE | Bee algorithm |
| AOR-GWO-004 | Omega wolves MUST report fitness every cycle | Telemetry |
| AOR-GWO-005 | Pack rebalancing requires Alpha approval | Guardian |
| **Swarm Algorithms** |
| AOR-PSO-001 | Parameters outside bounds trigger emergency | Alert |
| AOR-ACO-001 | Path changes logged to Immutable Register | Audit |
| AOR-BEE-001 | Scout discoveries shared via pheromone | Zenoh |
| AOR-FIREFLY-001 | Quality scores published for swarm visibility | Telemetry |
| **OODA Execution** |
| AOR-OODA-001 | Every agent MUST execute OODA loop | GenServer |
| AOR-OODA-002 | Cycle violations logged and analyzed | Telemetry |
| AOR-OODA-003 | Decisions include 5-order effects analysis | Template |
| AOR-OODA-004 | ACT phase MUST emit telemetry | Telemetry |
| AOR-OODA-005 | Hysteresis applied to prevent oscillation | State |
| **Emergence** |
| AOR-EMERGE-001 | Emergent metrics published every 500ms | Cycle |
| AOR-EMERGE-002 | Low emergence score triggers analysis | Alert |
| AOR-EMERGE-003 | Swarm health below 0.5 triggers rebalance | Strategic OODA |

---

# 6. APPENDIX: QUICK REFERENCE

## 6.1 OODA Timing Quick Reference

| Tier | Cycle | Layers | Executor | Budget |
|------|-------|--------|----------|--------|
| Micro | <1ms | L0-L1 | Inline Elixir | N/A |
| Fast | 50ms | L2-L3 | GenServer | 5+15+15+15 |
| Distributed | 100ms | L4-L5 | Supervisor | 20+30+25+25 |
| Strategic | 1s | L6-L7 | F# Cortex | 200+300+250+250 |

## 6.2 Swarm Algorithm Quick Reference

| Algorithm | Purpose | Update Frequency | Key Metric |
|-----------|---------|------------------|------------|
| GWO | Leadership | 500ms | Pack cohesion |
| PSO | Tuning | 500ms | Convergence |
| ACO | Paths | 500ms | Path quality |
| BEE | Allocation | 500ms | Efficiency |
| FIREFLY | Quality | 500ms | Clustering |

## 6.3 Pack Model Quick Reference

| Role | Count | Model | OODA Tier | Authority |
|------|-------|-------|-----------|-----------|
| Alpha | 1 | Opus | Strategic | Veto |
| Beta | 10 | Sonnet | Distributed | Domain |
| Delta | 15 | Sonnet | Fast | Task |
| Omega | 24 | Haiku | Micro | Atomic |

---

**Document End**

| Field | Value |
|-------|-------|
| Total Lines | 550+ |
| STAMP Coverage | 45+ constraints |
| AOR Coverage | 20+ rules |
| Elixir Modules | 8 |
| F# Modules | 1 |
| Last Updated | 2026-01-10 |
| Next Review | 2026-04-10 |
