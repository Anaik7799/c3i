defmodule Indrajaal.KMS.IntegrityMonitorTest do
  @moduledoc """
  Tests for Indrajaal.KMS.IntegrityMonitor.

  Covers:
  - start_link/1 GenServer lifecycle
  - request_proof_token/1 — proof token generation and hash-chain advancement
  - verify_integrity/0 — chain integrity check against SQLite DB
  - initial state structure

  STAMP: SC-REG-001 (append-only), SC-PROM-001 (proof token required),
         SC-SIL6-015 (immutable audit trail), SC-REG-002 (verify on startup)

  NOTE: IntegrityMonitor registers globally as __MODULE__. Tests must run
  async: false to avoid name conflicts when using the public API
  (request_proof_token/1 and verify_integrity/0 call GenServer.call(__MODULE__)).
  The setup/teardown ensures the process is started and stopped around each test.
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.IntegrityMonitor

  @nonexistent_db "/tmp/integrity_monitor_test_nonexistent_#{:os.getpid()}.db"

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IntegrityMonitor)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(IntegrityMonitor, :start_link, 1)
      assert function_exported?(IntegrityMonitor, :init, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Public API surface
  # ---------------------------------------------------------------------------

  describe "public API surface" do
    test "exports request_proof_token/1" do
      assert function_exported?(IntegrityMonitor, :request_proof_token, 1)
    end

    test "exports verify_integrity/0" do
      assert function_exported?(IntegrityMonitor, :verify_integrity, 0)
    end
  end

  # ---------------------------------------------------------------------------
  # child_spec/1
  # ---------------------------------------------------------------------------

  describe "child_spec/1" do
    test "returns valid child spec map" do
      spec = IntegrityMonitor.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end

  # ---------------------------------------------------------------------------
  # start_link/1 — GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1 GenServer contract" do
    setup do
      {:ok, pid} = GenServer.start_link(IntegrityMonitor, db_path: @nonexistent_db)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "starts a living process", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map", %{pid: pid} do
      state = :sys.get_state(pid)
      assert is_map(state)
    end

    test "initial state has :last_hash key", %{pid: pid} do
      state = :sys.get_state(pid)
      assert Map.has_key?(state, :last_hash)
    end

    test "initial state has :tokens key as a map", %{pid: pid} do
      state = :sys.get_state(pid)
      assert is_map(state.tokens)
    end

    test "initial state has :db_path key", %{pid: pid} do
      state = :sys.get_state(pid)
      assert Map.has_key?(state, :db_path)
    end

    test "initial last_hash is GENESIS", %{pid: pid} do
      state = :sys.get_state(pid)
      assert state.last_hash == "GENESIS"
    end

    test "initial tokens map is empty", %{pid: pid} do
      state = :sys.get_state(pid)
      assert state.tokens == %{}
    end

    test "stops cleanly", %{pid: pid} do
      ref = Process.monitor(pid)
      GenServer.stop(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end
  end

  # ---------------------------------------------------------------------------
  # request_proof_token/1 — via global name
  # ---------------------------------------------------------------------------

  describe "request_proof_token/1" do
    setup do
      # Start with global name so the public API can call __MODULE__
      case IntegrityMonitor.start_link(db_path: @nonexistent_db) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          {:ok, pid: pid}

        {:error, {:already_started, pid}} ->
          {:ok, pid: pid}
      end
    end

    test "returns {:ok, token} tuple" do
      assert {:ok, token} = IntegrityMonitor.request_proof_token("test-actuation-001")
      assert is_binary(token)
    end

    test "token is a non-empty string" do
      {:ok, token} = IntegrityMonitor.request_proof_token("actuation-abc")
      assert byte_size(token) > 0
    end

    test "token is a valid hex string (Base16 encoded SHA-256)" do
      {:ok, token} = IntegrityMonitor.request_proof_token("actuation-hex")
      assert Regex.match?(~r/^[0-9A-F]+$/, token)
    end

    test "token length is 64 hex characters (SHA-256 -> 32 bytes -> 64 hex)" do
      {:ok, token} = IntegrityMonitor.request_proof_token("actuation-length")
      assert String.length(token) == 64
    end

    test "two consecutive tokens for same actuation_id are different" do
      {:ok, token1} = IntegrityMonitor.request_proof_token("same-actuation")
      {:ok, token2} = IntegrityMonitor.request_proof_token("same-actuation")
      # Each token uses different system time, so they should differ
      assert token1 != token2
    end

    test "tokens for different actuation_ids are different" do
      {:ok, token_a} = IntegrityMonitor.request_proof_token("actuation-alpha")
      {:ok, token_b} = IntegrityMonitor.request_proof_token("actuation-beta")
      assert token_a != token_b
    end

    test "hash chain advances: last_hash changes after each token" do
      pid = Process.whereis(IntegrityMonitor)
      state_before = :sys.get_state(pid)
      IntegrityMonitor.request_proof_token("advance-chain-test")
      state_after = :sys.get_state(pid)
      assert state_before.last_hash != state_after.last_hash
    end

    test "token is registered in state.tokens after generation" do
      pid = Process.whereis(IntegrityMonitor)
      {:ok, token} = IntegrityMonitor.request_proof_token("register-test")
      state = :sys.get_state(pid)
      assert Map.has_key?(state.tokens, token)
    end

    test "token expiry in state.tokens is a future timestamp" do
      pid = Process.whereis(IntegrityMonitor)
      {:ok, token} = IntegrityMonitor.request_proof_token("expiry-test")
      state = :sys.get_state(pid)
      expiry = Map.get(state.tokens, token)
      now = System.os_time(:second)
      assert expiry > now
    end
  end

  # ---------------------------------------------------------------------------
  # verify_integrity/0 — via global name
  # ---------------------------------------------------------------------------

  describe "verify_integrity/0" do
    setup do
      case IntegrityMonitor.start_link(db_path: @nonexistent_db) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          {:ok, pid: pid}

        {:error, {:already_started, pid}} ->
          {:ok, pid: pid}
      end
    end

    test "returns a boolean" do
      result = IntegrityMonitor.verify_integrity()
      assert is_boolean(result)
    end

    test "returns true when db does not exist (nothing to corrupt)" do
      # With a nonexistent db path, there is nothing to be corrupt
      # verify_db_accessible always returns :ok (even for missing file)
      # verify_db_integrity returns :ok for missing file
      # verify_timestamp_monotonicity returns :ok for missing file
      result = IntegrityMonitor.verify_integrity()
      assert result == true
    end

    test "can be called multiple times returning consistent boolean" do
      r1 = IntegrityMonitor.verify_integrity()
      r2 = IntegrityMonitor.verify_integrity()
      assert is_boolean(r1)
      assert is_boolean(r2)
      # Both calls against same nonexistent DB should agree
      assert r1 == r2
    end
  end
end
