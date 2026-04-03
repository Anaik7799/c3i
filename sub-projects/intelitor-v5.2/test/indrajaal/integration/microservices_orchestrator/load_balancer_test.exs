defmodule Indrajaal.Integration.MicroservicesOrchestrator.LoadBalancerTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.LoadBalancer

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(LoadBalancer)
    end

    test "module identifier is correct" do
      assert LoadBalancer.__info__(:module) == LoadBalancer
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = LoadBalancer.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = LoadBalancer.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = LoadBalancer.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :algorithm field" do
      fields = LoadBalancer.__schema__(:fields)
      assert :algorithm in fields
    end

    test "has :health_check_enabled field" do
      fields = LoadBalancer.__schema__(:fields)
      assert :health_check_enabled in fields
    end

    test "has :configuration field" do
      fields = LoadBalancer.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %LoadBalancer{}
      assert is_struct(struct, LoadBalancer)
    end

    test "default algorithm is :round_robin" do
      struct = %LoadBalancer{}
      assert struct.algorithm == :round_robin
    end

    test "default health_check_enabled is true" do
      struct = %LoadBalancer{}
      assert struct.health_check_enabled == true
    end

    test "default configuration is empty map" do
      struct = %LoadBalancer{}
      assert struct.configuration == %{}
    end
  end

  describe "apply_algorithm/2" do
    test "function is exported" do
      assert function_exported?(LoadBalancer, :apply_algorithm, 2)
    end

    test "round_robin returns instances unchanged" do
      instances = [%{id: 1}, %{id: 2}, %{id: 3}]
      result = LoadBalancer.apply_algorithm(instances, :round_robin)
      assert result == instances
    end

    test "round_robin preserves all elements" do
      instances = [%{id: "a"}, %{id: "b"}]
      result = LoadBalancer.apply_algorithm(instances, :round_robin)
      assert length(result) == 2
    end

    test "weighted_round_robin sorts by weight descending" do
      instances = [
        %{id: 1, weight: 1},
        %{id: 2, weight: 10},
        %{id: 3, weight: 5}
      ]

      result = LoadBalancer.apply_algorithm(instances, :weighted_round_robin)
      assert is_list(result)
      assert length(result) == 3
      assert hd(result).weight == 10
    end

    test "weighted_round_robin with equal weights preserves length" do
      instances = [%{weight: 5}, %{weight: 5}, %{weight: 5}]
      result = LoadBalancer.apply_algorithm(instances, :weighted_round_robin)
      assert length(result) == 3
    end

    test "least_connections returns a list" do
      instances = [%{id: 1}, %{id: 2}]
      result = LoadBalancer.apply_algorithm(instances, :least_connections)
      assert is_list(result)
      assert length(result) == 2
    end

    test "least_connections preserves all elements" do
      instances = [%{id: "x"}]
      result = LoadBalancer.apply_algorithm(instances, :least_connections)
      assert length(result) == 1
    end

    test "hash algorithm returns a list with the same count" do
      instances = [%{id: 1}, %{id: 2}, %{id: 3}]
      result = LoadBalancer.apply_algorithm(instances, :hash)
      assert is_list(result)
      assert length(result) == 3
    end

    test "hash algorithm contains all original elements" do
      instances = [%{id: 1}, %{id: 2}]
      result = LoadBalancer.apply_algorithm(instances, :hash)
      assert Enum.sort_by(result, & &1.id) == Enum.sort_by(instances, & &1.id)
    end

    test "unknown algorithm returns instances unchanged" do
      instances = [%{id: 1}]
      result = LoadBalancer.apply_algorithm(instances, :unknown_algo)
      assert result == instances
    end

    test "works with empty list for every algorithm" do
      for algo <- [:round_robin, :weighted_round_robin, :least_connections, :hash, :unknown] do
        result = LoadBalancer.apply_algorithm([], algo)
        assert result == [], "Expected empty list for algo #{algo}"
      end
    end

    test "single-element list is preserved for round_robin" do
      instances = [%{id: 99}]
      result = LoadBalancer.apply_algorithm(instances, :round_robin)
      assert result == instances
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(LoadBalancer, :spark_dsl_config, 0)
    end
  end
end
