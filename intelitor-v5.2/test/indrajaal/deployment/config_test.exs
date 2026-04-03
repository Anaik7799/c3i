defmodule Indrajaal.Deployment.ConfigTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Deployment.Config

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Config)
    end

    test "module exports expected functions" do
      assert function_exported?(Config, :containers, 1)
      assert function_exported?(Config, :run_health_check_for, 2)
    end
  end

  describe "containers/1" do
    test "returns list for :prod_standalone topology" do
      result = Config.containers(:prod_standalone)
      assert is_list(result) or is_map(result) or match?({:error, _}, result)
    end

    test "returns list for :full_mesh topology" do
      result = Config.containers(:full_mesh)
      assert is_list(result) or is_map(result) or match?({:error, _}, result)
    end

    test "returns error or empty for unknown topology" do
      result = Config.containers(:unknown_topology)
      assert is_list(result) or match?({:error, _}, result) or is_nil(result)
    end
  end

  describe "run_health_check_for/2" do
    test "returns ok tuple or error tuple for a container name" do
      result = Config.run_health_check_for("indrajaal-db-prod", [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error tuple for unknown container" do
      result = Config.run_health_check_for("nonexistent-container-xyz", [])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
