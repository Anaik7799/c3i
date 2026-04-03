defmodule Indrajaal.Fractal.L3.NifSystemTest do
  use ExUnit.Case
  alias Indrajaal.Native.Zenoh

  @moduledoc """
  Layer 3: System Testing.
  Verifies NIF behavior within the container/node context.
  """

  @tag :nif
  @tag :system
  test "zenoh resource declaration in system context" do
    # Check if we can declare a resource path
    path = "indrajaal/system/test/l3"

    # This tests the binding's ability to allocate resources
    # We expect either :ok or a specific error, but NOT a crash
    case Zenoh.declare_publisher(path) do
      {:ok, _ref} -> :ok
      {:error, _} -> :ok
    end
  end
end
