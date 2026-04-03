defmodule Indrajaal.Lifecycle.HealthCoordinatorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Lifecycle.HealthCoordinator

  test "module exists" do
    assert Code.ensure_loaded?(HealthCoordinator)
  end

  test "start_link/1 is exported" do
    assert function_exported?(HealthCoordinator, :start_link, 1)
  end
end
