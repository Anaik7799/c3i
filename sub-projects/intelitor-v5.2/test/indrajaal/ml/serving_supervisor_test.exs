defmodule Indrajaal.ML.ServingSupervisorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.ServingSupervisor

  test "module is loaded" do
    assert Code.ensure_loaded?(ServingSupervisor)
  end

  test "start_link/1 is defined" do
    assert function_exported?(ServingSupervisor, :start_link, 1)
  end

  test "status/0 is defined" do
    assert function_exported?(ServingSupervisor, :status, 0)
  end

  test "restart_serving/1 is defined" do
    assert function_exported?(ServingSupervisor, :restart_serving, 1)
  end

  test "module uses Supervisor behaviour" do
    behaviours = ServingSupervisor.__info__(:attributes)[:behaviour] || []
    assert Supervisor in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(ServingSupervisor, :child_spec, 1)
  end
end
