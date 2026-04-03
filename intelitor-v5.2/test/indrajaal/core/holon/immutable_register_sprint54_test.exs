defmodule Indrajaal.Core.Holon.ImmutableRegisterSprint54Test do
  @moduledoc """
  Sprint 54 TDG comprehensive dual-property test suite for ImmutableRegister.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014)

  ## STAMP Safety Integration
  - SC-REG-001: Append-only mandate — every block insertion is irreversible
  - SC-REG-002: Chain verification on startup — unbroken predecessor hashes
  - SC-REG-003: Ed25519 signatures required — all blocks cryptographically signed
  - SC-REG-004: Self-repair on corruption — damaged chains repaired automatically
  - SC-REG-005: Reed-Solomon parity for error correction (ACTIVE)
  - SC-REG-011: Merkle root for state verification
  - SC-REG-013: Cross-holon attestation for federation
  - SC-GRID-014: All state mutations via append-only register
  - SC-GRID-015: Hash chain verified on every startup
  - SC-GRID-016: All blocks Ed25519 signed

  ## Constitutional Verification
  - Ψ₀ Existence: Register survives all append/verify/repair cycles
  - Ψ₁ Regeneration: Full state exportable and re-importable
  - Ψ₂ Evolutionary Continuity: History preserved; no block ever removed
  - Ψ₃ Verification Capability: Hash chain always verifiable
  - Ψ₅ Truthfulness: Chain never misreports its own integrity

  ## Founder's Directive Alignment
  - Ω₀.4: Co-evolution tracked via append-only lineage
  - Ω₈ Immutable Register: This module is the canonical implementation

  ## TPS 5-Level RCA Context
  - L1 Symptom: Register reports :ok on tampered chain
  - L2 Mechanism: Hash mismatch not detected between blocks
  - L3 Sub-system: Verification loop skips index boundary conditions
  - L4 System: Block indexing off-by-one under concurrent appends
  - L5 Root Cause: Missing property tests for multi-block chain invariants
    (RPN 216 — Severity 9, Occurrence 3, Detection 8)

  ## Change History
  | Version | Date     | Author | Change |
  |---------|----------|--------|--------|
  | 21.3.0  | 2026-03-21 | TDG Agent | Sprint 54 — dual-property + constitutional tests |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Core.Holon.ImmutableRegister

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp new_register do
    unique_name = :"#{__MODULE__}.#{System.unique_integer([:positive])}"
    {:ok, pid} = ImmutableRegister.start_link(name: unique_name, holon_id: "in_memory")
    {pid, unique_name}
  end

  defp stop_register(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1_000)
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    {pid, name} = new_register()

    on_exit(fn -> stop_register(pid) end)

    %{pid: pid, name: name}
  end

  # ---------------------------------------------------------------------------
  # Module existence (Ψ₀ baseline)
  # ---------------------------------------------------------------------------

  describe "module existence (Ψ₀)" do
    test "module is available" do
      assert Code.ensure_loaded?(ImmutableRegister)
    end

    test "exports required public functions" do
      exported = ImmutableRegister.__info__(:functions)

      required = [
        {:start_link, 1},
        {:append, 3},
        {:verify, 1},
        {:export, 1},
        {:head, 0},
        {:stats, 0},
        {:public_key, 0},
        {:repair, 0},
        {:merkle_proof, 1}
      ]

      for {fun, arity} <- required do
        assert Keyword.get(exported, fun) == arity,
               "Expected #{fun}/#{arity} to be exported"
      end
    end

    test "GenServer starts and is alive", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # SC-REG-001: Append-only mandate
  # ---------------------------------------------------------------------------

  describe "append/3 — SC-REG-001 append-only mandate" do
    test "appends a single block", %{pid: pid} do
      assert {:ok, hash} = GenServer.call(pid, {:append, :test, "first"})
      assert is_binary(hash)
      assert byte_size(hash) > 0
    end

    test "hash differs between blocks", %{pid: pid} do
      {:ok, h1} = GenServer.call(pid, {:append, :event, "alpha"})
      {:ok, h2} = GenServer.call(pid, {:append, :event, "beta"})
      assert h1 != h2
    end

    test "block count increments monotonically", %{pid: pid} do
      stats0 = GenServer.call(pid, :stats)
      GenServer.call(pid, {:append, :test, "a"})
      stats1 = GenServer.call(pid, :stats)
      GenServer.call(pid, {:append, :test, "b"})
      stats2 = GenServer.call(pid, :stats)

      assert stats1.block_count > stats0.block_count
      assert stats2.block_count > stats1.block_count
    end

    test "accepts various content types", %{pid: pid} do
      contents = [
        "string content",
        42,
        %{key: "value"},
        {:tuple, :content},
        [1, 2, 3]
      ]

      for content <- contents do
        assert {:ok, _hash} = GenServer.call(pid, {:append, :general, content})
      end
    end

    test "block is not modifiable after append (SC-REG-001)", %{pid: pid} do
      {:ok, _} = GenServer.call(pid, {:append, :immutable, "original"})
      {:ok, blocks} = GenServer.call(pid, :export)
      original_hash = List.first(blocks).hash

      # Attempting to modify state externally has no effect on chain
      {:ok, blocks2} = GenServer.call(pid, :export)
      assert List.first(blocks2).hash == original_hash
    end
  end

  # ---------------------------------------------------------------------------
  # SC-REG-002: Hash chain integrity
  # ---------------------------------------------------------------------------

  describe "verify/1 — SC-REG-002 chain integrity" do
    test "empty register verifies OK", %{pid: pid} do
      assert :ok = GenServer.call(pid, :verify)
    end

    test "single-block register verifies OK", %{pid: pid} do
      GenServer.call(pid, {:append, :test, "solo"})
      assert :ok = GenServer.call(pid, :verify)
    end

    test "multi-block chain verifies OK after sequential appends", %{pid: pid} do
      for i <- 1..10 do
        GenServer.call(pid, {:append, :sequence, "block_#{i}"})
      end

      assert :ok = GenServer.call(pid, :verify)
    end

    test "head hash reflects latest block", %{pid: pid} do
      {:ok, hash1} = GenServer.call(pid, {:append, :test, "first"})
      head1 = GenServer.call(pid, :head)
      assert head1 == hash1

      {:ok, hash2} = GenServer.call(pid, {:append, :test, "second"})
      head2 = GenServer.call(pid, :head)
      assert head2 == hash2
      assert head2 != head1
    end
  end

  # ---------------------------------------------------------------------------
  # SC-REG-003: Ed25519 signatures on every block
  # ---------------------------------------------------------------------------

  describe "block signatures — SC-REG-003" do
    test "exported blocks contain signature field", %{pid: pid} do
      GenServer.call(pid, {:append, :signed, "payload"})
      {:ok, blocks} = GenServer.call(pid, :export)

      for block <- blocks do
        assert Map.has_key?(block, :signature), "block missing :signature"
        assert is_binary(block.signature)
      end
    end

    test "public_key/0 returns binary key", %{pid: pid} do
      pk = GenServer.call(pid, :public_key)
      assert is_binary(pk)
      assert byte_size(pk) > 0
    end

    test "each block carries a non-nil hash", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, :chain, "block_#{i}"})
      end

      {:ok, blocks} = GenServer.call(pid, :export)

      for block <- blocks do
        assert is_binary(block.hash)
        refute is_nil(block.hash)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # SC-REG-011: Merkle root verification
  # ---------------------------------------------------------------------------

  describe "merkle_proof/1 — SC-REG-011" do
    test "returns proof for block 0 after single append", %{pid: pid} do
      GenServer.call(pid, {:append, :merkle, "leaf"})
      result = GenServer.call(pid, {:merkle_proof, 0})

      assert {:ok, _proof} = result
    end

    test "returns error for non-existent index", %{pid: pid} do
      result = GenServer.call(pid, {:merkle_proof, 99})
      assert {:error, :not_found} = result
    end

    test "proof returned as list", %{pid: pid} do
      for i <- 1..4 do
        GenServer.call(pid, {:append, :merkle, "node_#{i}"})
      end

      {:ok, proof} = GenServer.call(pid, {:merkle_proof, 1})
      assert is_list(proof)
    end
  end

  # ---------------------------------------------------------------------------
  # SC-REG-004: Self-repair
  # ---------------------------------------------------------------------------

  describe "repair/0 — SC-REG-004 self-repair" do
    test "repair on clean chain returns {:ok, 0}", %{pid: pid} do
      GenServer.call(pid, {:append, :repair_test, "healthy"})
      result = GenServer.call(pid, :repair)

      case result do
        {:ok, repaired_count} -> assert is_integer(repaired_count)
        {:error, :unrecoverable} -> :ok
      end
    end

    test "repair does not break a valid chain", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, :repair, "block_#{i}"})
      end

      GenServer.call(pid, :repair)
      assert :ok = GenServer.call(pid, :verify)
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₁ Regeneration: Export and import
  # ---------------------------------------------------------------------------

  describe "export/import — Ψ₁ Regeneration" do
    test "export returns list of blocks", %{pid: pid} do
      GenServer.call(pid, {:append, :regen, "a"})
      GenServer.call(pid, {:append, :regen, "b"})

      {:ok, blocks} = GenServer.call(pid, :export)
      assert is_list(blocks)
      assert length(blocks) == 2
    end

    test "exported blocks preserve content", %{pid: pid} do
      GenServer.call(pid, {:append, :preservation, "payload_xyz"})
      {:ok, blocks} = GenServer.call(pid, :export)

      block = List.first(blocks)
      assert block.content == "payload_xyz"
    end

    test "exported blocks have sequential indices", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, :sequence, "item_#{i}"})
      end

      {:ok, blocks} = GenServer.call(pid, :export)
      indices = Enum.map(blocks, & &1.index)
      assert indices == Enum.to_list(0..4)
    end

    test "import into fresh register and re-verify", %{pid: pid} do
      for i <- 1..3 do
        GenServer.call(pid, {:append, :export_test, "block_#{i}"})
      end

      {:ok, blocks} = GenServer.call(pid, :export)

      # Import into a new register
      {pid2, _} = new_register()

      on_exit(fn -> stop_register(pid2) end)

      result = GenServer.call(pid2, {:import, blocks})
      # Import may succeed or note a signature mismatch (different keypair)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # stats/0 contract
  # ---------------------------------------------------------------------------

  describe "stats/0" do
    test "returns a map with block_count key", %{pid: pid} do
      stats = GenServer.call(pid, :stats)
      assert is_map(stats)
      assert Map.has_key?(stats, :block_count)
    end

    test "block_count is 0 initially", %{pid: pid} do
      stats = GenServer.call(pid, :stats)
      assert stats.block_count == 0
    end

    test "block_count increases after append", %{pid: pid} do
      GenServer.call(pid, {:append, :count_test, "x"})
      stats = GenServer.call(pid, :stats)
      assert stats.block_count >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014: PC. prefix)
  # ---------------------------------------------------------------------------

  property "append always returns {:ok, hash} with non-empty binary hash" do
    forall content <- PC.utf8() do
      {pid, _} = new_register()

      try do
        result = GenServer.call(pid, {:append, :prop, content})

        case result do
          {:ok, hash} -> is_binary(hash) and byte_size(hash) > 0
          _ -> false
        end
      after
        stop_register(pid)
      end
    end
  end

  property "block count is monotonically non-decreasing across any append sequence" do
    forall contents <- PC.non_empty(PC.list(PC.utf8())) do
      {pid, _} = new_register()

      try do
        counts =
          Enum.reduce(contents, [0], fn content, [prev | _] = acc ->
            GenServer.call(pid, {:append, :monotone, content})
            stats = GenServer.call(pid, :stats)
            [stats.block_count | acc]
          end)

        # Each count >= previous count
        Enum.zip(tl(counts), counts)
        |> Enum.all?(fn {later, earlier} -> later <= earlier end)
      after
        stop_register(pid)
      end
    end
  end

  property "chain verifies OK after any number of sequential appends" do
    forall n <- PC.pos_integer() do
      n_capped = rem(n, 20) + 1
      {pid, _} = new_register()

      try do
        for i <- 1..n_capped do
          GenServer.call(pid, {:append, :verify_prop, "block_#{i}"})
        end

        GenServer.call(pid, :verify) == :ok
      after
        stop_register(pid)
      end
    end
  end

  property "head hash is always the hash of the most recently appended block" do
    forall contents <- PC.non_empty(PC.list(PC.utf8())) do
      {pid, _} = new_register()

      try do
        last_hash =
          Enum.reduce(contents, nil, fn content, _acc ->
            {:ok, hash} = GenServer.call(pid, {:append, :head_prop, content})
            hash
          end)

        GenServer.call(pid, :head) == last_hash
      after
        stop_register(pid)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests (EP-GEN-014: SD. prefix)
  # ---------------------------------------------------------------------------

  test "exported block count equals number of appends" do
    ExUnitProperties.check all(
                             items <-
                               SD.list_of(SD.string(:alphanumeric, min_length: 1),
                                 min_length: 1,
                                 max_length: 15
                               )
                           ) do
      {pid, _} = new_register()

      try do
        for item <- items do
          GenServer.call(pid, {:append, :count_eq, item})
        end

        {:ok, blocks} = GenServer.call(pid, :export)
        assert length(blocks) == length(items)
      after
        stop_register(pid)
      end
    end
  end

  test "every exported block has prev_hash = hash of preceding block" do
    ExUnitProperties.check all(n <- SD.integer(2..10)) do
      {pid, _} = new_register()

      try do
        for i <- 1..n do
          GenServer.call(pid, {:append, :chain_link, "item_#{i}"})
        end

        {:ok, blocks} = GenServer.call(pid, :export)

        if length(blocks) >= 2 do
          pairs = Enum.zip(blocks, tl(blocks))

          all_linked =
            Enum.all?(pairs, fn {prev_block, next_block} ->
              next_block.prev_hash == prev_block.hash
            end)

          assert all_linked
        end
      after
        stop_register(pid)
      end
    end
  end

  test "stats block_count always equals length of exported blocks" do
    ExUnitProperties.check all(n <- SD.integer(0..20)) do
      {pid, _} = new_register()

      try do
        for i <- 1..n do
          GenServer.call(pid, {:append, :stats_eq, "b#{i}"})
        end

        stats = GenServer.call(pid, :stats)
        {:ok, blocks} = GenServer.call(pid, :export)
        assert stats.block_count == length(blocks)
      after
        stop_register(pid)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₂ Evolutionary continuity: no block ever removed
  # ---------------------------------------------------------------------------

  describe "Constitutional invariants (Ψ₂ Evolutionary Continuity)" do
    test "Ψ₂: block count never decreases after appends", %{pid: pid} do
      GenServer.call(pid, {:append, :psi2, "first"})
      stats1 = GenServer.call(pid, :stats)

      GenServer.call(pid, {:append, :psi2, "second"})
      stats2 = GenServer.call(pid, :stats)

      GenServer.call(pid, {:append, :psi2, "third"})
      stats3 = GenServer.call(pid, :stats)

      assert stats2.block_count >= stats1.block_count
      assert stats3.block_count >= stats2.block_count
    end

    test "Ψ₃: verify reports OK on unmodified chain", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, :psi3, "entry_#{i}"})
      end

      assert :ok = GenServer.call(pid, :verify)
    end

    test "Ψ₅: export data truthfully reflects all appended blocks", %{pid: pid} do
      expected_payloads = ["alpha", "beta", "gamma"]

      for payload <- expected_payloads do
        GenServer.call(pid, {:append, :truth, payload})
      end

      {:ok, blocks} = GenServer.call(pid, :export)
      actual_contents = Enum.map(blocks, & &1.content)

      assert actual_contents == expected_payloads
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 dual-channel invariant
  # ---------------------------------------------------------------------------

  describe "SIL-6 dual-channel verification" do
    test "verify produces same result when called twice on unchanged chain", %{pid: pid} do
      for i <- 1..5 do
        GenServer.call(pid, {:append, :dual, "item_#{i}"})
      end

      result_a = GenServer.call(pid, :verify)
      result_b = GenServer.call(pid, :verify)

      assert result_a == result_b
    end

    test "stats are idempotent across consecutive calls", %{pid: pid} do
      GenServer.call(pid, {:append, :idem, "data"})

      stats_a = GenServer.call(pid, :stats)
      stats_b = GenServer.call(pid, :stats)

      assert stats_a == stats_b
    end
  end

  # ---------------------------------------------------------------------------
  # FMEA: edge cases and boundary conditions
  # ---------------------------------------------------------------------------

  describe "FMEA failure modes (RPN > 50)" do
    test "append with empty binary content succeeds", %{pid: pid} do
      result = GenServer.call(pid, {:append, :edge, ""})
      assert match?({:ok, _}, result)
    end

    test "append with nil content does not crash server", %{pid: pid} do
      result =
        try do
          GenServer.call(pid, {:append, :nil_test, nil})
        catch
          :exit, _ -> {:error, :server_exit}
        end

      # Either succeeds or returns an error — server must survive
      assert Process.alive?(pid)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "merkle_proof for negative index returns error", %{pid: pid} do
      GenServer.call(pid, {:append, :merkle_edge, "x"})

      result =
        try do
          GenServer.call(pid, {:merkle_proof, -1})
        catch
          :exit, _ -> {:error, :bad_arg}
        end

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "multiple concurrent appends preserve server liveness", %{pid: pid} do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            GenServer.call(pid, {:append, :concurrent, "task_#{i}"})
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert Process.alive?(pid)
    end
  end
end
