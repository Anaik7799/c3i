defmodule Indrajaal.Core.Holon.HolonRegenerationTest do
  # MUST be false because we are simulating hard crashes and checking shared filesystem state
  use ExUnit.Case, async: false

  alias Indrajaal.Core.Holon.ImmutableRegister

  @moduledoc """
  S54-T108: Biomorphic Holon Regeneration Test (P0)

  Validates SC-HOLON-010 and SC-BIO-EXT-009: 
  Authoritative holon state ≡ SQLite ∪ DuckDB ONLY.
  A Holon MUST be able to fully regenerate its state from its Immutable Register
  without relying on PostgreSQL.
  """

  setup do
    # Start the HolonDatabase Registry if not already running (required by ImmutableRegister)
    registry_name = Indrajaal.Holon.Database.Registry

    case Registry.start_link(keys: :unique, name: registry_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      _other -> :ok
    end

    # 1. Setup a clean holon ID for the test using valid UHI format (SC-DBNAME-001)
    # Format: {runtime}:{layer}:{domain}:{type}:{instance}
    # "tst" = Test Infrastructure domain, "srv" = service type
    instance = "regen#{System.unique_integer([:positive])}"
    holon_id = "ex:l3:tst:srv:#{instance}"

    # Ensure a clean slate — UHI paths resolve to data/holons/ex/l3/tst/{instance}/
    holon_path = "data/holons/ex/l3/tst/#{instance}"
    File.rm_rf!(holon_path)

    on_exit(fn ->
      File.rm_rf!(holon_path)
    end)

    {:ok, %{holon_id: holon_id}}
  end

  test "holon can fully regenerate its state after a hard crash", %{holon_id: holon_id} do
    # Phase 1: Initialize and Mutate

    # Start the Immutable Register for this specific holon
    {:ok, register_pid} = ImmutableRegister.start_link(holon_id: holon_id)

    # Verify it started
    assert Process.alive?(register_pid)

    # Append initial state blocks — append returns {:ok, hash}
    {:ok, _hash1} =
      ImmutableRegister.append(register_pid, "GENESIS", %{event: "holon_born", config: "standard"})

    {:ok, _hash2} =
      ImmutableRegister.append(register_pid, "MUTATION", %{
        event: "learned_pattern",
        pattern_id: 42
      })

    {:ok, _hash3} =
      ImmutableRegister.append(register_pid, "MUTATION", %{
        event: "resource_acquired",
        amount: 100
      })

    # Get the current full state to compare later
    {:ok, original_state} = ImmutableRegister.get_full_state(register_pid)

    # Verify the chain is intact before we kill it
    assert :ok = ImmutableRegister.verify(register_pid)

    # Phase 2: Force-kill (Simulate OOM / Hard Crash)
    Process.exit(register_pid, :kill)

    # Ensure the process is dead
    refute Process.alive?(register_pid)

    # Give the OS a tiny fraction of a second to release file locks if any
    Process.sleep(50)

    # Phase 3: Resurrection

    # Restart the Register. It should automatically detect the existing data/holons/{id} path
    # and reconstruct its state from the WAL.
    {:ok, resurrected_pid} = ImmutableRegister.start_link(holon_id: holon_id)

    assert Process.alive?(resurrected_pid)

    # Phase 4: Assert 100% state reconstruction

    # 1. Chain must still be verifiable
    assert :ok = ImmutableRegister.verify(resurrected_pid)

    # 2. Reconstructed state must match original state exactly
    {:ok, reconstructed_state} = ImmutableRegister.get_full_state(resurrected_pid)

    assert original_state == reconstructed_state

    # Clean shutdown
    GenServer.stop(resurrected_pid)
  end
end
