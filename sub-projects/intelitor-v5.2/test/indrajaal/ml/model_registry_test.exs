defmodule Indrajaal.ML.ModelRegistryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.ModelRegistry

  test "module is loaded" do
    assert Code.ensure_loaded?(ModelRegistry)
  end

  test "start_link/1 is defined" do
    assert function_exported?(ModelRegistry, :start_link, 1)
  end

  test "register_model/3 is defined" do
    assert function_exported?(ModelRegistry, :register_model, 3)
  end

  test "get_active_model/1 is defined" do
    assert function_exported?(ModelRegistry, :get_active_model, 1)
  end

  test "get_model_versions/1 is defined" do
    assert function_exported?(ModelRegistry, :get_model_versions, 1)
  end

  test "activate_version/2 is defined" do
    assert function_exported?(ModelRegistry, :activate_version, 2)
  end

  test "rollback/1 is defined" do
    assert function_exported?(ModelRegistry, :rollback, 1)
  end

  test "update_metrics/3 is defined" do
    assert function_exported?(ModelRegistry, :update_metrics, 3)
  end

  test "list_models/0 is defined" do
    assert function_exported?(ModelRegistry, :list_models, 0)
  end

  test "module uses GenServer behaviour" do
    behaviours = ModelRegistry.__info__(:attributes)[:behaviour] || []
    assert GenServer in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(ModelRegistry, :child_spec, 1)
  end

  test "can start under a test supervisor" do
    name = :"test_model_registry_#{System.unique_integer([:positive])}"
    assert {:ok, pid} = start_supervised({ModelRegistry, name: name})
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "list_models/0 returns a list when started" do
    name = :"test_model_registry_list_#{System.unique_integer([:positive])}"
    start_supervised!({ModelRegistry, name: name})
    assert is_list(ModelRegistry.list_models())
  end
end
