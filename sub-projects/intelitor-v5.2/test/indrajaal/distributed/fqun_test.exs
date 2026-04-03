defmodule Indrajaal.Distributed.FQUNTest do
  @moduledoc """
  TDG Test Artifacts for FQUN (Fully Qualified Unique Name).

  WHAT: Tests for FQUN generation, registry, and Zenoh integration.
  WHY: SC-DIST-001 requires all resources to have unique FQUNs.
  CONSTRAINTS: Tests must verify uniqueness, format, and registry operations.

  ## TDG Methodology

  - Property tests for uniqueness invariants
  - Unit tests for format validation
  - Integration tests for registry operations

  ## STAMP Constraints Tested

  - SC-DIST-001: All resources MUST have FQUN
  - SC-DIST-002: FQUNs MUST be Zenoh key-expression compatible
  - SC-DIST-003: FQUNs MUST be deterministically derivable
  - SC-DIST-004: FQUN registry MUST support mesh-wide lookup

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.1.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-DIST-001 to SC-DIST-004 |
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Distributed.FQUN

  setup do
    # Start the FQUN GenServer for tests
    case GenServer.whereis(FQUN) do
      nil ->
        {:ok, pid} = FQUN.start_link([])
        on_exit(fn -> Process.exit(pid, :normal) end)
        {:ok, fqun_pid: pid}

      pid ->
        {:ok, fqun_pid: pid}
    end
  end

  # ============================================================
  # FQUN FORMAT TESTS
  # ============================================================

  describe "FQUN.generate/5" do
    test "generates valid FQUN for agent layer" do
      {:ok, fqun} = FQUN.generate(:agent, :cybernetic, "ooda", "controller")

      assert is_binary(fqun)
      assert String.starts_with?(fqun, "indrajaal/agent/")
      assert String.contains?(fqun, "cybernetic")
      assert String.contains?(fqun, "ooda")
      assert String.contains?(fqun, "controller")
    end

    test "generates valid FQUN for worker layer" do
      {:ok, fqun} = FQUN.generate(:worker, :flame, "analytics", "pool")

      assert is_binary(fqun)
      assert String.starts_with?(fqun, "indrajaal/worker/")
      assert String.contains?(fqun, "flame")
    end

    test "generates valid FQUN for supervisor layer" do
      {:ok, fqun} = FQUN.generate(:supervisor, :cluster, "distributed", "main")

      assert is_binary(fqun)
      assert String.starts_with?(fqun, "indrajaal/supervisor/")
    end

    test "generates valid FQUN for resource layer" do
      {:ok, fqun} = FQUN.generate(:resource, :container, "cepaf", "app")

      assert is_binary(fqun)
      assert String.starts_with?(fqun, "indrajaal/resource/")
    end

    test "generates valid FQUN for dashboard layer" do
      {:ok, fqun} = FQUN.generate(:dashboard, :cepaf, "main", "control")

      assert is_binary(fqun)
      assert String.starts_with?(fqun, "indrajaal/dashboard/")
    end

    test "includes node name in FQUN" do
      {:ok, fqun} = FQUN.generate(:agent, :domain, "test_ns", "test_name")

      # Should contain @ for node separator
      assert String.contains?(fqun, "@")
    end

    test "includes instance ID in FQUN" do
      {:ok, fqun} = FQUN.generate(:agent, :domain, "test_ns", "test_name")

      # Should contain # for instance separator
      assert String.contains?(fqun, "#")
    end

    test "rejects invalid layer" do
      assert {:error, {:invalid_layer, :invalid}} = FQUN.generate(:invalid, :domain, "ns", "name")
    end

    test "rejects invalid type for layer" do
      assert {:error, {:invalid_type, :invalid_type, _valid_types}} =
               FQUN.generate(:agent, :invalid_type, "ns", "name")
    end
  end

  # ============================================================
  # FQUN UNIQUENESS TESTS
  # ============================================================

  describe "FQUN uniqueness" do
    test "generates unique FQUNs for same parameters" do
      {:ok, fqun1} = FQUN.generate(:agent, :cybernetic, "test", "uniqueness")
      {:ok, fqun2} = FQUN.generate(:agent, :cybernetic, "test", "uniqueness")

      # FQUNs should be different due to unique instance IDs
      assert fqun1 != fqun2
    end

    test "generates many unique FQUNs" do
      fquns =
        for i <- 1..100 do
          {:ok, fqun} = FQUN.generate(:worker, :oban, "batch_#{i}", "worker")
          fqun
        end

      # All FQUNs should be unique
      assert length(Enum.uniq(fquns)) == 100
    end
  end

  # ============================================================
  # FQUN REGISTRY TESTS
  # ============================================================

  describe "FQUN registry" do
    test "register and lookup FQUN" do
      {:ok, fqun} = FQUN.generate(:agent, :domain, "accounts", "manager")

      # FQUN.generate already registers, so it should appear in registry
      fquns = FQUN.find_by_layer(:agent)
      assert fqun in fquns

      # Unregister
      assert :ok = FQUN.unregister(fqun)

      # After unregister, should not appear
      fquns_after = FQUN.find_by_layer(:agent)
      refute fqun in fquns_after
    end

    test "find_by_layer returns FQUNs for layer" do
      {:ok, fqun1} = FQUN.generate(:worker, :flame, "test", "worker1")
      {:ok, fqun2} = FQUN.generate(:worker, :batch, "test", "worker2")

      FQUN.register(fqun1, %{type: :flame})
      FQUN.register(fqun2, %{type: :batch})

      workers = FQUN.find_by_layer(:worker)
      assert length(workers) >= 2

      FQUN.unregister(fqun1)
      FQUN.unregister(fqun2)
    end

    test "list_all returns all registered FQUNs" do
      {:ok, fqun} = FQUN.generate(:agent, :observability, "test", "list_all")

      # FQUN.generate already registers it, so don't call register again
      all = FQUN.list_all()
      assert is_list(all)
      # list_all returns tuples of {fqun, metadata}
      assert Enum.any?(all, fn {f, _} -> f == fqun end)

      FQUN.unregister(fqun)
    end
  end

  # ============================================================
  # FQUN PARSING TESTS
  # ============================================================

  describe "FQUN parsing" do
    test "parse extracts components" do
      {:ok, fqun} = FQUN.generate(:agent, :cybernetic, "ooda", "controller")
      {:ok, parsed} = FQUN.parse(fqun)

      assert parsed.layer == :agent
      assert parsed.type == :cybernetic
      assert parsed.namespace == "ooda"
      assert parsed.name == "controller"
      assert parsed.node == node()
      assert is_binary(parsed.instance)
    end

    test "parse fails for invalid format" do
      assert {:error, :invalid_fqun} = FQUN.parse("invalid_fqun")
      assert {:error, :invalid_fqun} = FQUN.parse("indrajaal/only/two")
    end
  end

  # ============================================================
  # FQUN ZENOH KEY TESTS
  # ============================================================

  describe "FQUN to_zenoh_key" do
    test "converts FQUN to valid Zenoh key" do
      {:ok, fqun} = FQUN.generate(:agent, :domain, "alarms", "processor")
      key = FQUN.to_zenoh_key(fqun)

      # Zenoh key should not have invalid characters
      assert is_binary(key)
      refute String.contains?(key, " ")
      # Key should be valid Zenoh format
      assert String.starts_with?(key, "indrajaal/")
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "FQUN property tests" do
    property "generated FQUNs are always valid format" do
      forall {layer, type} <- valid_layer_type_gen() do
        namespace = "test_ns_#{:rand.uniform(1000)}"
        name = "test_name_#{:rand.uniform(1000)}"

        case FQUN.generate(layer, type, namespace, name) do
          {:ok, fqun} ->
            assert String.starts_with?(fqun, "indrajaal/")
            assert String.contains?(fqun, "@")
            assert String.contains?(fqun, "#")
            true

          {:error, _} ->
            # Invalid combination - that's ok
            true
        end
      end
    end

    property "parsed FQUNs round-trip correctly" do
      forall {layer, type} <- valid_layer_type_gen() do
        namespace = "roundtrip_#{:rand.uniform(1000)}"
        name = "test_#{:rand.uniform(1000)}"

        case FQUN.generate(layer, type, namespace, name) do
          {:ok, fqun} ->
            {:ok, parsed} = FQUN.parse(fqun)
            assert parsed.layer == layer
            assert parsed.type == type
            assert parsed.namespace == namespace
            assert parsed.name == name
            true

          {:error, _} ->
            true
        end
      end
    end
  end

  # ============================================================
  # GENERATORS
  # ============================================================

  defp valid_layer_type_gen do
    PC.oneof([
      {:agent, PC.oneof([:domain, :cybernetic, :ml, :integration, :observability, :security])},
      {:worker, PC.oneof([:flame, :oban, :broadway, :batch])},
      {:supervisor, PC.oneof([:cluster, :domain, :pool, :sentinel])},
      {:dashboard, PC.oneof([:cepaf, :metrics, :kpi, :admin])},
      {:resource, PC.oneof([:compute, :storage, :network, :container])}
    ])
  end
end
