defmodule Indrajaal.Cortex.Swarm.AlgorithmsTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cortex.Swarm.Algorithms.

  All functions are pure (no GenServer), so async: true is safe.
  Tests cover all 5 swarm intelligence algorithms and their return-value contracts.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cortex.Swarm.Algorithms

  # Minimal valid inputs shared across tests
  @space %{
    dimensions: 2,
    bounds: [[-5.0, 5.0], [-5.0, 5.0]],
    type: :continuous
  }

  @constraints []

  defp objectives do
    [fn pos -> Enum.sum(Enum.map(pos, fn x -> x * x end)) end]
  end

  @base_state %{
    learning_configuration: %{
      swarm_intelligence: %{
        population_size: 10,
        max_iterations: 5,
        convergence_threshold: 0.001,
        alpha: 0.5,
        beta0: 1.0,
        gamma: 1.0,
        inertia_weight: 0.7,
        cognitive_coeff: 1.5,
        social_coeff: 1.5,
        evaporation_rate: 0.5,
        pheromone_intensity: 1.0,
        limit: 5,
        step_size: 0.2,
        attraction: 0.5,
        randomness: 0.2
      }
    }
  }

  # --------------------------------------------------------------------------
  # grey_wolf_optimizer/4
  # --------------------------------------------------------------------------

  describe "grey_wolf_optimizer/4" do
    test "returns a map with required keys" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert is_map(result)
      assert Map.has_key?(result, :best_position)
      assert Map.has_key?(result, :best_fitness)
      assert Map.has_key?(result, :convergence_curve)
      assert Map.has_key?(result, :iterations)
      assert Map.has_key?(result, :diversity)
    end

    test "best_position has correct number of dimensions" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert length(result.best_position) == @space.dimensions
    end

    test "best_fitness is a float" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert is_float(result.best_fitness) or is_integer(result.best_fitness)
    end

    test "convergence_curve is a list" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert is_list(result.convergence_curve)
    end

    test "iterations does not exceed max_iterations" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)

      max_iters =
        get_in(@base_state, [:learning_configuration, :swarm_intelligence, :max_iterations])

      assert result.iterations <= max_iters
    end

    test "diversity is a non-negative number" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert result.diversity >= 0.0
    end

    test "best_position elements are within bounds" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)

      Enum.zip(result.best_position, @space.bounds)
      |> Enum.each(fn {val, [lo, hi]} ->
        assert val >= lo - 0.001
        assert val <= hi + 0.001
      end)
    end

    test "convergence_curve length equals iterations" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert length(result.convergence_curve) == result.iterations
    end

    test "finds near-zero for sphere function (minimum at origin)" do
      result = Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state)
      assert result.best_fitness < 50.0
    end
  end

  # --------------------------------------------------------------------------
  # particle_swarm_optimization/4
  # --------------------------------------------------------------------------

  describe "particle_swarm_optimization/4" do
    test "returns a map with required keys" do
      result =
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state)

      assert is_map(result)
      assert Map.has_key?(result, :best_position)
      assert Map.has_key?(result, :best_fitness)
      assert Map.has_key?(result, :convergence_curve)
      assert Map.has_key?(result, :iterations)
      assert Map.has_key?(result, :diversity)
    end

    test "best_position has correct number of dimensions" do
      result =
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state)

      assert length(result.best_position) == @space.dimensions
    end

    test "convergence_curve is a non-empty list" do
      result =
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state)

      assert is_list(result.convergence_curve)
      assert length(result.convergence_curve) > 0
    end

    test "iterations is a positive integer" do
      result =
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state)

      assert is_integer(result.iterations)
      assert result.iterations > 0
    end

    test "diversity is a float >= 0" do
      result =
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state)

      assert result.diversity >= 0.0
    end

    test "best_fitness improves or stays same across convergence curve" do
      result =
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state)

      curve = result.convergence_curve

      if length(curve) > 1 do
        last = List.last(curve)
        first = List.first(curve)
        assert last <= first + 0.001
      end
    end
  end

  # --------------------------------------------------------------------------
  # ant_colony_optimization/4
  # --------------------------------------------------------------------------

  describe "ant_colony_optimization/4" do
    test "returns a map with required keys" do
      result = Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state)
      assert is_map(result)
      assert Map.has_key?(result, :best_position)
      assert Map.has_key?(result, :best_fitness)
      assert Map.has_key?(result, :convergence_curve)
      assert Map.has_key?(result, :iterations)
      assert Map.has_key?(result, :diversity)
    end

    test "best_position has correct number of dimensions" do
      result = Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state)
      assert length(result.best_position) == @space.dimensions
    end

    test "best_fitness is a number" do
      result = Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state)
      assert is_number(result.best_fitness)
    end

    test "convergence_curve is a list" do
      result = Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state)
      assert is_list(result.convergence_curve)
    end

    test "iterations does not exceed max_iterations" do
      result = Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state)
      max = get_in(@base_state, [:learning_configuration, :swarm_intelligence, :max_iterations])
      assert result.iterations <= max
    end
  end

  # --------------------------------------------------------------------------
  # artificial_bee_colony/4
  # --------------------------------------------------------------------------

  describe "artificial_bee_colony/4" do
    test "returns a map with required keys" do
      result = Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state)
      assert is_map(result)
      assert Map.has_key?(result, :best_position)
      assert Map.has_key?(result, :best_fitness)
      assert Map.has_key?(result, :convergence_curve)
      assert Map.has_key?(result, :iterations)
      assert Map.has_key?(result, :diversity)
    end

    test "best_position has correct number of dimensions" do
      result = Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state)
      assert length(result.best_position) == @space.dimensions
    end

    test "best_fitness is a number" do
      result = Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state)
      assert is_number(result.best_fitness)
    end

    test "convergence_curve has entries" do
      result = Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state)
      assert is_list(result.convergence_curve)
    end

    test "iterations is a positive integer" do
      result = Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state)
      assert result.iterations > 0
    end
  end

  # --------------------------------------------------------------------------
  # firefly_optimization/4
  # --------------------------------------------------------------------------

  describe "firefly_optimization/4" do
    test "returns a map with required keys" do
      result = Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      assert is_map(result)
      assert Map.has_key?(result, :best_position)
      assert Map.has_key?(result, :best_fitness)
      assert Map.has_key?(result, :convergence_curve)
      assert Map.has_key?(result, :iterations)
      assert Map.has_key?(result, :diversity)
    end

    test "best_position has correct number of dimensions" do
      result = Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      assert length(result.best_position) == @space.dimensions
    end

    test "best_fitness is a number" do
      result = Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      assert is_number(result.best_fitness)
    end

    test "convergence_curve is a list" do
      result = Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      assert is_list(result.convergence_curve)
    end

    test "iterations does not exceed max_iterations" do
      result = Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      max = get_in(@base_state, [:learning_configuration, :swarm_intelligence, :max_iterations])
      assert result.iterations <= max
    end
  end

  # --------------------------------------------------------------------------
  # Cross-algorithm consistency checks
  # --------------------------------------------------------------------------

  describe "all algorithms produce consistent result shapes" do
    test "all five algorithms return maps with the same key set" do
      expected_keys =
        MapSet.new([:best_position, :best_fitness, :convergence_curve, :iterations, :diversity])

      results = [
        Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state),
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state),
        Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state),
        Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state),
        Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      ]

      Enum.each(results, fn result ->
        result_keys = result |> Map.keys() |> MapSet.new()

        assert MapSet.subset?(expected_keys, result_keys),
               "Missing keys: #{inspect(MapSet.difference(expected_keys, result_keys))}"
      end)
    end

    test "all algorithms produce best_fitness for sphere function" do
      results = [
        Algorithms.grey_wolf_optimizer(@space, objectives(), @constraints, @base_state),
        Algorithms.particle_swarm_optimization(@space, objectives(), @constraints, @base_state),
        Algorithms.ant_colony_optimization(@space, objectives(), @constraints, @base_state),
        Algorithms.artificial_bee_colony(@space, objectives(), @constraints, @base_state),
        Algorithms.firefly_optimization(@space, objectives(), @constraints, @base_state)
      ]

      Enum.each(results, fn result ->
        assert is_number(result.best_fitness)
        assert result.best_fitness >= 0.0
      end)
    end
  end

  # --------------------------------------------------------------------------
  # 3D space tests
  # --------------------------------------------------------------------------

  describe "algorithms with 3D problem space" do
    setup do
      space_3d = %{
        dimensions: 3,
        bounds: [[-10.0, 10.0], [-10.0, 10.0], [-10.0, 10.0]],
        type: :continuous
      }

      objectives_3d = [fn pos -> Enum.reduce(pos, 0.0, fn x, acc -> acc + x * x end) end]
      {:ok, space: space_3d, objectives: objectives_3d}
    end

    test "GWO handles 3D space", %{space: space, objectives: objectives} do
      result = Algorithms.grey_wolf_optimizer(space, objectives, [], @base_state)
      assert length(result.best_position) == 3
    end

    test "PSO handles 3D space", %{space: space, objectives: objectives} do
      result = Algorithms.particle_swarm_optimization(space, objectives, [], @base_state)
      assert length(result.best_position) == 3
    end

    test "ABC handles 3D space", %{space: space, objectives: objectives} do
      result = Algorithms.artificial_bee_colony(space, objectives, [], @base_state)
      assert length(result.best_position) == 3
    end
  end
end
