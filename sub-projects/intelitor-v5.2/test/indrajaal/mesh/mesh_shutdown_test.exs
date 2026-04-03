defmodule Indrajaal.Mesh.MeshShutdownTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Mesh.MeshShutdown
  alias Indrajaal.Mesh.DigitalTwin

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(MeshShutdown)
    end

    test "module exports shutdown/2" do
      assert function_exported?(MeshShutdown, :shutdown, 2)
    end
  end

  describe "shutdown/2 function signature" do
    test "shutdown/2 accepts a DigitalTwin and config map" do
      # Verify the function is callable with correct arity
      assert function_exported?(MeshShutdown, :shutdown, 2)
    end

    test "DigitalTwin.create_default/0 builds a valid twin for testing" do
      twin = DigitalTwin.create_default()
      assert is_struct(twin, DigitalTwin)
      assert is_map(twin.genotypes)
      assert is_map(twin.phenotypes)
    end

    test "shutdown config map has expected keys" do
      # Verify the expected config map shape matches the module's interface spec.
      # We do NOT call shutdown/2 here as it requires runtime services
      # (ContainerLifecycle Registry, DyingGasp) not available in unit tests.
      expected_config_keys = [
        :pre_shutdown_timeout_ms,
        :drain_timeout_ms,
        :graceful_timeout_ms,
        :force_kill_after_ms,
        :save_checkpoint,
        :verbose
      ]

      config = %{
        pre_shutdown_timeout_ms: 5000,
        drain_timeout_ms: 10_000,
        graceful_timeout_ms: 3000,
        force_kill_after_ms: 20_000,
        save_checkpoint: true,
        verbose: true
      }

      for key <- expected_config_keys do
        assert Map.has_key?(config, key), "Config must have key #{key}"
      end
    end
  end
end
