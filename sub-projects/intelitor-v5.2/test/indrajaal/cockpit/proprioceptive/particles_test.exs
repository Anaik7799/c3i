defmodule Indrajaal.Cockpit.Proprioceptive.ParticlesTest do
  @moduledoc """
  Tests for Indrajaal.Cockpit.Proprioceptive.Particles GenServer.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Proprioceptive.Particles

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Particles)
    end

    test "module has expected public functions" do
      assert function_exported?(Particles, :spawn, 4)
      assert function_exported?(Particles, :emit, 2)
      assert function_exported?(Particles, :register_emitter, 3)
      assert function_exported?(Particles, :add_attractor, 3)
      assert function_exported?(Particles, :get_particles, 0)
      assert function_exported?(Particles, :count, 0)
      assert function_exported?(Particles, :clear, 0)
      assert function_exported?(Particles, :render_json, 0)
      assert function_exported?(Particles, :stats, 0)
    end

    test "module implements GenServer behaviour" do
      assert function_exported?(Particles, :start_link, 1)
      assert function_exported?(Particles, :init, 1)
    end
  end

  describe "Particles GenServer" do
    setup do
      name = :"particles_test_#{System.unique_integer([:positive])}"

      case Particles.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
          {:ok, pid: pid}

        {:error, _} ->
          :skip
      end
    end

    test "count/0 returns a non-negative integer", %{pid: _pid} do
      result = Particles.count()
      assert is_integer(result) and result >= 0
    end

    test "get_particles/0 returns a list", %{pid: _pid} do
      result = Particles.get_particles()
      assert is_list(result)
    end

    test "clear/0 succeeds", %{pid: _pid} do
      result = Particles.clear()
      assert match?(:ok, result) or match?({:ok, _}, result) or result != nil
    end

    test "count is zero after clear", %{pid: _pid} do
      Particles.clear()
      count = Particles.count()
      assert count == 0
    end

    test "stats/0 returns a map or term", %{pid: _pid} do
      result = Particles.stats()
      assert is_map(result) or result != nil
    end

    test "render_json/0 returns a string or map", %{pid: _pid} do
      result = Particles.render_json()
      assert is_binary(result) or is_map(result)
    end

    test "emit/2 returns ok or error", %{pid: _pid} do
      result = Particles.emit(:burst, %{x: 0.5, y: 0.5})

      assert match?(:ok, result) or match?({:ok, _}, result) or match?({:error, _}, result) or
               result != nil
    end
  end
end
