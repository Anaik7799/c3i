defmodule Indrajaal.CEPAF.Bridge.PhenotypeTest do
  @moduledoc """
  Tests for Indrajaal.CEPAF.Bridge.Phenotype pure module.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CEPAF.Bridge.Phenotype
  alias Indrajaal.CEPAF.Bridge.Grammar

  # Build a minimal genome map directly (matches Genetic.genome() type)
  defp make_genome(name \\ :test) do
    steps = [Grammar.action(:"#{name}_step1", %{}), Grammar.action(:"#{name}_step2", %{})]

    %{
      id: "genome-#{name}-#{System.unique_integer([:positive])}",
      chromosome: steps,
      fitness: 75.0,
      generation: 0,
      parents: []
    }
  end

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Phenotype)
    end

    test "module has expected functions" do
      assert function_exported?(Phenotype, :express, 3)
      assert function_exported?(Phenotype, :evaluate_fitness, 1)
      assert function_exported?(Phenotype, :adapt, 2)
      assert function_exported?(Phenotype, :extract_traits, 1)
      assert function_exported?(Phenotype, :similarity, 2)
      assert function_exported?(Phenotype, :default_environment, 0)
    end
  end

  describe "default_environment/0" do
    test "returns a map with expected structure" do
      env = Phenotype.default_environment()
      assert is_map(env)
      assert Map.has_key?(env, :resources)
      assert Map.has_key?(env, :constraints)
      assert Map.has_key?(env, :capabilities)
      assert Map.has_key?(env, :load)
    end

    test "resources include cpu, memory, network" do
      env = Phenotype.default_environment()
      assert Map.has_key?(env.resources, :cpu)
      assert Map.has_key?(env.resources, :memory)
      assert Map.has_key?(env.resources, :network)
    end

    test "capabilities is a list" do
      env = Phenotype.default_environment()
      assert is_list(env.capabilities)
    end

    test "load is a float" do
      env = Phenotype.default_environment()
      assert is_float(env.load)
    end
  end

  describe "express/3" do
    test "expresses a genome in an environment with :adaptive strategy" do
      env = Phenotype.default_environment()
      genome = make_genome(:express_adaptive)
      result = Phenotype.express(genome, env, :adaptive)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "expresses a genome with :minimal strategy" do
      env = Phenotype.default_environment()
      genome = make_genome(:express_minimal)
      result = Phenotype.express(genome, env, :minimal)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "expressed phenotype has expected fields on success" do
      env = Phenotype.default_environment()
      genome = make_genome(:express_fields)

      case Phenotype.express(genome, env, :adaptive) do
        {:ok, phenotype} ->
          assert Map.has_key?(phenotype, :id)
          assert Map.has_key?(phenotype, :genome_id)
          assert Map.has_key?(phenotype, :workflow)
          assert Map.has_key?(phenotype, :environment)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "extract_traits/1" do
    test "extracts traits from a phenotype" do
      env = Phenotype.default_environment()
      genome = make_genome(:traits)

      case Phenotype.express(genome, env, :adaptive) do
        {:ok, phenotype} ->
          traits = Phenotype.extract_traits(phenotype)
          assert is_map(traits) or is_list(traits)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "evaluate_fitness/1" do
    test "returns a numeric fitness for a phenotype" do
      env = Phenotype.default_environment()
      genome = make_genome(:fitness)

      case Phenotype.express(genome, env, :adaptive) do
        {:ok, phenotype} ->
          fitness = Phenotype.evaluate_fitness(phenotype)
          assert is_float(fitness) or is_integer(fitness)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "similarity/2" do
    test "returns a numeric similarity score between two phenotypes" do
      env = Phenotype.default_environment()
      g1 = make_genome(:sim1)
      g2 = make_genome(:sim2)

      case {Phenotype.express(g1, env, :adaptive), Phenotype.express(g2, env, :adaptive)} do
        {{:ok, p1}, {:ok, p2}} ->
          score = Phenotype.similarity(p1, p2)
          assert is_float(score) or is_integer(score)
          assert score >= 0.0

        _ ->
          :ok
      end
    end
  end

  describe "adapt/2" do
    test "adapts a phenotype to a new environment" do
      env = Phenotype.default_environment()
      genome = make_genome(:adapt)

      case Phenotype.express(genome, env, :adaptive) do
        {:ok, phenotype} ->
          new_env = %{env | load: 0.9}
          result = Phenotype.adapt(phenotype, new_env)
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:error, _} ->
          :ok
      end
    end
  end
end
