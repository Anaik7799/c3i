defmodule Indrajaal.Lifecycle.ContainerLifecycleTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Lifecycle.ContainerLifecycle

  test "module exists" do
    assert Code.ensure_loaded?(ContainerLifecycle)
  end

  test "start_link/1 is exported" do
    assert function_exported?(ContainerLifecycle, :start_link, 1)
  end
end
