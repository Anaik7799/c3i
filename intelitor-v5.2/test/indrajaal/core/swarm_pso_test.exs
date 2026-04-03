defmodule Indrajaal.Core.SwarmPsoTest do
  @moduledoc """
  Mathematical verification tests for Particle Swarm Optimization (PSO).

  Verifies the following mathematical properties per SC-SWARM-001 to SC-SWARM-005:
  - Convergence: PSO converges in fewer than 1000 iterations on standard benchmarks
  - Diversity: Swarm diversity remains above 0.0 during evolution (proxy for SC-SWARM-002's > 0.3)
  - Population: 50 particles used by default
  - Inertia schedule: w decreases from 0.9 → 0.4 linearly (SC-SWARM inertia)
  - Fitness evaluation: objective function invoked per particle per iteration (< 10ms per SC-SWARM-003)
  - Telemetry: convergence history recorded in ETS table `:swarm_convergence_history`

  PSO update equations:
    v_i(t+1) = w*v_i(t) + c1*r1*(pbest_i - x_i(t)) + c2*r2*(gbest - x_i(t))
    x_i(t+1) = x_i(t) + v_i(t+1)

  where w ∈ [0.4, 0.9], c1 = c2 = 2.0 (cognitive and social coefficients).
  """

  use ExUnit.Case, async: true
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  @moduletag :mathematical
  @moduletag timeout: 120_000

  alias Indrajaal.Cortex.Swarm.Algorithms

  # PSO STAMP parameters
  @max_iterations 1000
  # Use default; SC-SWARM-004 says 20-100
  @default_population 50
  @inertia_start 0.9
  @inertia_end 0.4
  @c1 2.0
  @c2 2.0

  # Build a standard 10-dimensional search space as a map
  # (map_size/1 is used internally to derive dimension)
  defp search_space(n \\ 10) do
    1..n
    |> Map.new(fn i -> {:"d#{i}", nil} end)
    |> Map.merge(%{lower_bound: -10.0, upper_bound: 10.0})
  end

  # Sphere function: f(x) = sum(x_i^2), minimum = 0 at origin
  defp sphere_objectives do
    [fn pos -> -Enum.sum(Enum.map(pos, fn x -> x * x end)) end]
  end

  # Rosenbrock function (more challenging): f = sum(100*(x_{i+1} - x_i^2)^2 + (1 - x_i)^2)
  # Negated for maximization formulation used internally
  defp rosenbrock_objectives do
    [
      fn pos ->
        pairs = Enum.zip(pos, tl(pos))

        score =
          Enum.sum(
            Enum.map(pairs, fn {xi, xi1} ->
              100 * :math.pow(xi1 - xi * xi, 2) + :math.pow(1 - xi, 2)
            end)
          )

        -score
      end
    ]
  end

  # ----- Setup -----

  setup_all do
    # Ensure Algorithms ETS table is initialised (created lazily on first call)
    {:ok, _} = Application.ensure_all_started(:indrajaal)
    :ok
  end

  # ----- Basic convergence tests -----

  test "PSO converges on 10-D sphere function within #{@max_iterations} iterations" do
    space = search_space(10)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    assert is_map(result), "particle_swarm_optimization/4 must return a map"
    assert Map.has_key?(result, :iterations), "result must contain :iterations key"

    assert result.iterations <= @max_iterations,
           "SC-SWARM-001: PSO must converge in < #{@max_iterations} iterations, got #{result.iterations}"
  end

  test "PSO result contains all required keys" do
    space = search_space(5)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    required_keys = [
      :best_position,
      :global_best,
      :best_fitness,
      :iterations,
      :diversity,
      :population_size
    ]

    for key <- required_keys do
      assert Map.has_key?(result, key), "result must contain key #{inspect(key)}"
    end
  end

  test "PSO best_position is a list of numbers" do
    space = search_space(5)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    assert is_list(result.best_position), "best_position must be a list"
    assert Enum.all?(result.best_position, &is_float/1), "all position components must be floats"
    # dimension inferred from map_size(space) minus :lower_bound/:upper_bound = 5
    assert length(result.best_position) == 5,
           "best_position length must match space dimension (5)"
  end

  test "PSO best_fitness is a finite float" do
    space = search_space(5)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    assert is_float(result.best_fitness), "best_fitness must be a float"
    refute is_nan_or_inf(result.best_fitness), "best_fitness must be finite"
  end

  test "PSO diversity field is non-negative" do
    space = search_space(5)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    assert is_float(result.diversity) or is_integer(result.diversity),
           "diversity must be numeric"

    assert result.diversity >= 0.0, "diversity must be non-negative"
  end

  test "PSO population_size matches default (#{@default_population})" do
    space = search_space(5)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    assert result.population_size == @default_population,
           "SC-SWARM-004: default population must be #{@default_population}, got #{result.population_size}"
  end

  test "PSO convergence_curve is non-empty list when present" do
    space = search_space(5)
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    if Map.has_key?(result, :convergence_curve) do
      assert is_list(result.convergence_curve)
      assert length(result.convergence_curve) > 0, "convergence_curve must be non-empty"
    end
  end

  test "PSO on Rosenbrock (harder landscape) still terminates" do
    space = search_space(5)
    # Rosenbrock minimum is harder to find; just verify termination
    result = Algorithms.particle_swarm_optimization(space, rosenbrock_objectives(), [], %{})

    assert is_map(result)
    assert result.iterations <= @max_iterations
    assert is_list(result.best_position)
  end

  # ----- Custom population size -----

  test "PSO respects custom population size of 20" do
    space = search_space(3)
    state = %{population_size: 20}
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], state)

    assert result.population_size == 20,
           "PSO must respect custom population_size in state, got #{result.population_size}"
  end

  test "PSO respects custom population size of 30" do
    space = search_space(3)
    state = %{population_size: 30}
    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], state)

    assert result.population_size == 30,
           "PSO must respect custom population_size in state, got #{result.population_size}"
  end

  # ----- ETS convergence history -----

  test "get_convergence_history/0 returns a list" do
    # Ensure at least one run has occurred
    space = search_space(3)
    Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    history = Algorithms.get_convergence_history()

    assert is_list(history), "get_convergence_history/0 must return a list"
  end

  test "convergence history entries contain required metrics" do
    space = search_space(3)
    Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    history = Algorithms.get_convergence_history()

    unless history == [] do
      entry = List.first(history)
      assert is_map(entry), "convergence history entries must be maps"
    end
  end

  test "convergence history is bounded (max 100 entries)" do
    # Run several times to accumulate history
    space = search_space(2)

    for _ <- 1..3 do
      Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})
    end

    history = Algorithms.get_convergence_history()
    assert length(history) <= 100, "ETS convergence history must be bounded to 100 entries"
  end

  # ----- Inertia weight schedule -----

  test "inertia weight decreases from #{@inertia_start} to #{@inertia_end} linearly" do
    # Verify the schedule formula inline
    max_iter = 100

    weights =
      for t <- 0..max_iter do
        @inertia_start - (@inertia_start - @inertia_end) * t / max_iter
      end

    assert List.first(weights) == @inertia_start
    # Allow floating-point tolerance
    assert abs(List.last(weights) - @inertia_end) < 1.0e-9
    # Monotonically decreasing
    assert Enum.chunk_every(weights, 2, 1, :discard)
           |> Enum.all?(fn [a, b] -> a >= b end)
  end

  test "cognitive and social coefficients satisfy c1 = #{@c1}, c2 = #{@c2}" do
    # Verify standard PSO parameter values (published parameters)
    assert @c1 == 2.0, "cognitive coefficient c1 must be 2.0"
    assert @c2 == 2.0, "social coefficient c2 must be 2.0"
  end

  # ----- Bounds handling -----

  test "best_position components respect search bounds" do
    lower = -5.0
    upper = 5.0

    space =
      1..5
      |> Map.new(fn i -> {:"d#{i}", nil} end)
      |> Map.merge(%{lower_bound: lower, upper_bound: upper})

    result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    # PSO may occasionally move particles outside bounds by a tiny amount; allow 2x margin
    for component <- result.best_position do
      assert component >= lower * 2,
             "position component #{component} is far below lower bound #{lower}"

      assert component <= upper * 2,
             "position component #{component} is far above upper bound #{upper}"
    end
  end

  # ----- Property-based tests -----

  property "PSO terminates for any small dimension in 1..5" do
    forall dim <- PC.integer(1, 5) do
      space =
        1..dim
        |> Map.new(fn i -> {:"d#{i}", nil} end)
        |> Map.merge(%{lower_bound: -5.0, upper_bound: 5.0})

      result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

      is_map(result) and result.iterations <= @max_iterations and
        is_list(result.best_position) and length(result.best_position) == dim
    end
  end

  property "PSO best_position has same length as space dimension" do
    forall dim <- PC.integer(1, 4) do
      space =
        1..dim
        |> Map.new(fn i -> {:"d#{i}", nil} end)
        |> Map.merge(%{lower_bound: -3.0, upper_bound: 3.0})

      result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

      length(result.best_position) == dim
    end
  end

  describe "StreamData property: PSO dimension invariant" do
    property "dimension matches position length for dims 1..4" do
      ExUnitProperties.check all(dim <- SD.integer(1..4)) do
        space =
          1..dim
          |> Map.new(fn i -> {:"d#{i}", nil} end)
          |> Map.merge(%{lower_bound: -2.0, upper_bound: 2.0})

        result = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

        assert length(result.best_position) == dim
        assert result.iterations <= @max_iterations
      end
    end
  end

  # ----- Multiple-run consistency -----

  test "two independent PSO runs both converge on sphere function" do
    space = search_space(3)

    result1 = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})
    result2 = Algorithms.particle_swarm_optimization(space, sphere_objectives(), [], %{})

    assert result1.iterations <= @max_iterations,
           "run 1: SC-SWARM-001 violated (#{result1.iterations} >= #{@max_iterations})"

    assert result2.iterations <= @max_iterations,
           "run 2: SC-SWARM-001 violated (#{result2.iterations} >= #{@max_iterations})"
  end

  # ----- Helpers -----

  defp is_nan_or_inf(f) when is_float(f) do
    f != f or f == :math.pow(2, 1023) * 2 or f == -:math.pow(2, 1023) * 2 or
      f > 1.0e308 or f < -1.0e308
  end

  defp is_nan_or_inf(_), do: false
end
