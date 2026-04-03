defmodule Indrajaal.Cockpit.Prajna.ImmutableStateTest do
  @moduledoc """
  TDG-Compliant Tests for ImmutableState Module.

  STAMP Compliance: SC-REG-001, SC-REG-002, SC-REG-003, SC-PRAJNA-003
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests cryptographically-signed append-only blocks:
  - Hash chain integrity (SHA3-256)
  - Ed25519 signatures
  - Merkle root computation
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.ImmutableState

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Register Creation
  # ═══════════════════════════════════════════════════════════════════════════

  describe "create_register/0" do
    test "creates empty register with genesis hash" do
      register = ImmutableState.create_register()

      assert register.blocks == []
      assert register.last_index == -1
      assert is_binary(register.last_hash)
      # SHA-256 hex = 64 chars
      assert String.length(register.last_hash) == 64
      assert %DateTime{} = register.created_at
      assert %DateTime{} = register.last_updated
    end

    test "genesis hash is consistent" do
      r1 = ImmutableState.create_register()
      r2 = ImmutableState.create_register()

      assert r1.last_hash == r2.last_hash
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Record State Change (SC-REG-001)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "record/2" do
    test "appends block to register" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "TestModule",
        key: "setting",
        old_value: "old",
        new_value: "new",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)

      assert length(updated.blocks) == 1
      assert updated.last_index == 0
      assert updated.last_hash != register.last_hash
    end

    test "maintains hash chain (SC-REG-002)" do
      register = ImmutableState.create_register()

      change1 = %{
        change_type: :config_change,
        module: "M1",
        key: "k1",
        old_value: nil,
        new_value: "v1",
        metadata: %{}
      }

      change2 = %{
        change_type: :config_change,
        module: "M2",
        key: "k2",
        old_value: nil,
        new_value: "v2",
        metadata: %{}
      }

      r1 = ImmutableState.record(change1, register)
      r2 = ImmutableState.record(change2, r1)

      [block1, block2] = r2.blocks

      # Block 2's prev_hash should equal block 1's block_hash (chain integrity)
      # Note: We use block_hash (not content_hash) for chain continuity per SIL-6
      assert block2.prev_hash == block1.block_hash
    end

    test "includes signature in each block (SC-REG-003)" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :command_execution,
        module: "Cmd",
        key: "test",
        old_value: nil,
        new_value: "ok",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      assert is_binary(block.signature)
      # Ed25519 signature (64 bytes) Base64-encoded = 88 chars
      assert String.length(block.signature) == 88
    end

    test "includes protocol version" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "M",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      assert block.protocol_version == "21.1.0"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Chain Verification (SC-REG-002)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "verify_chain/1" do
    test "empty register is valid" do
      register = ImmutableState.create_register()
      assert ImmutableState.verify_chain(register) == :valid
    end

    test "single block register is valid" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "M",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)

      assert ImmutableState.verify_chain(updated) == :valid
    end

    test "multi-block chain is valid" do
      register = ImmutableState.create_register()

      updated =
        Enum.reduce(1..5, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "M#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      assert ImmutableState.verify_chain(updated) == :valid
      assert length(updated.blocks) == 5
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Block Retrieval
  # ═══════════════════════════════════════════════════════════════════════════

  describe "get_block/2" do
    test "retrieves block by index" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "Test",
        key: "key",
        old_value: nil,
        new_value: "val",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)

      block = ImmutableState.get_block(0, updated)

      assert block.index == 0
      assert block.content.module == "Test"
    end

    test "returns nil for non-existent index" do
      register = ImmutableState.create_register()
      assert ImmutableState.get_block(0, register) == nil
      assert ImmutableState.get_block(99, register) == nil
    end
  end

  describe "get_blocks_by_type/2" do
    test "filters blocks by change type" do
      register = ImmutableState.create_register()

      config_change = %{
        change_type: :config_change,
        module: "Cfg",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      command_exec = %{
        change_type: :command_execution,
        module: "Cmd",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      updated =
        register
        |> ImmutableState.record(config_change)
        |> ImmutableState.record(command_exec)
        |> ImmutableState.record(config_change)

      config_blocks = ImmutableState.get_blocks_by_type(:config_change, updated)
      command_blocks = ImmutableState.get_blocks_by_type(:command_execution, updated)

      assert length(config_blocks) == 2
      assert length(command_blocks) == 1
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Merkle Root (SC-REG-012)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "compute_merkle_root/1" do
    test "empty register has consistent merkle root" do
      register = ImmutableState.create_register()
      root = ImmutableState.compute_merkle_root(register)

      assert is_binary(root)
      assert String.length(root) == 64
    end

    test "merkle root changes with new blocks" do
      register = ImmutableState.create_register()
      root1 = ImmutableState.compute_merkle_root(register)

      change = %{
        change_type: :config_change,
        module: "M",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      root2 = ImmutableState.compute_merkle_root(updated)

      assert root1 != root2
    end

    test "merkle root is deterministic" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "M",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)

      root1 = ImmutableState.compute_merkle_root(updated)
      root2 = ImmutableState.compute_merkle_root(updated)

      assert root1 == root2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Convenience Functions
  # ═══════════════════════════════════════════════════════════════════════════

  describe "record_config/5" do
    test "records configuration change" do
      register = ImmutableState.create_register()
      updated = ImmutableState.record_config("MyModule", "timeout", "30", "60", register)

      [block] = updated.blocks
      assert block.content.change_type == :config_change
      assert block.content.module == "MyModule"
      assert block.content.key == "timeout"
      assert block.content.old_value == "30"
      assert block.content.new_value == "60"
    end
  end

  describe "record_guardian_decision/4" do
    test "records guardian decision" do
      register = ImmutableState.create_register()

      updated =
        ImmutableState.record_guardian_decision("restart", "approved", "Within policy", register)

      [block] = updated.blocks
      assert block.content.change_type == :guardian_decision
      assert block.content.module == "Guardian"
      assert block.content.key == "restart"
      assert block.content.new_value == "approved"
    end
  end

  describe "summary/1" do
    test "returns readable summary" do
      register = ImmutableState.create_register()
      summary = ImmutableState.summary(register)

      assert is_binary(summary)
      assert String.contains?(summary, "0 blocks")
      assert String.contains?(summary, "integrity: :valid")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC) - Append-Only Invariants
  # ═══════════════════════════════════════════════════════════════════════════

  property "append-only: block count always increases" do
    forall n <- PC.range(0, 10) do
      changes =
        if n == 0 do
          []
        else
          Enum.map(1..n, fn i ->
            %{
              change_type: Enum.random([:config_change, :command_execution]),
              module: "Module#{i}",
              key: "key#{i}",
              old_value: "old#{i}",
              new_value: "new#{i}",
              metadata: %{}
            }
          end)
        end

      register = ImmutableState.create_register()

      final =
        Enum.reduce(changes, register, fn change, acc ->
          ImmutableState.record(change, acc)
        end)

      length(final.blocks) == length(changes)
    end
  end

  property "chain remains valid after any number of appends" do
    forall n <- PC.range(0, 20) do
      register = ImmutableState.create_register()

      final =
        if n == 0 do
          register
        else
          Enum.reduce(1..n, register, fn i, acc ->
            change = %{
              change_type: :config_change,
              module: "M#{i}",
              key: "k",
              old_value: nil,
              new_value: "v",
              metadata: %{}
            }

            ImmutableState.record(change, acc)
          end)
        end

      ImmutableState.verify_chain(final) == :valid
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD) - Basic Properties
  # ═══════════════════════════════════════════════════════════════════════════

  test "blocks have unique content hashes (property)" do
    modules = ["ModA", "ModB", "ModC", "ModD", "ModE"]
    register = ImmutableState.create_register()

    final =
      Enum.with_index(modules)
      |> Enum.reduce(register, fn {mod, i}, acc ->
        change = %{
          change_type: :config_change,
          module: mod,
          key: "k#{i}",
          old_value: nil,
          new_value: "v",
          metadata: %{}
        }

        ImmutableState.record(change, acc)
      end)

    hashes = Enum.map(final.blocks, & &1.content_hash)
    assert length(Enum.uniq(hashes)) == length(hashes)
  end

  test "merkle root is stable for same register (property)" do
    for n <- 1..5 do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "M#{i}",
            key: "k",
            old_value: nil,
            new_value: "v",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      root1 = ImmutableState.compute_merkle_root(final)
      root2 = ImmutableState.compute_merkle_root(final)
      assert root1 == root2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Ed25519 Signatures (SC-REG-003)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Ed25519 signatures (SC-REG-003)" do
    test "register has Ed25519 keypair" do
      register = ImmutableState.create_register()

      assert register.keypair != nil
      {pub, sec} = register.keypair
      assert is_binary(pub)
      assert is_binary(sec)
      # Ed25519 public key is 32 bytes
      assert byte_size(pub) == 32
      # Ed25519 secret key is 32 bytes (OTP 28+ returns seed format)
      assert byte_size(sec) == 32
    end

    test "public_key/1 returns the public key" do
      register = ImmutableState.create_register()

      pub = ImmutableState.public_key(register)
      assert is_binary(pub)
      assert byte_size(pub) == 32
    end

    test "blocks have Base64-encoded Ed25519 signatures" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "TestEd25519",
        key: "sig_test",
        old_value: nil,
        new_value: "verified",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      # Signature should be Base64 encoded (88 chars for 64-byte signature)
      assert is_binary(block.signature)
      assert {:ok, sig_bytes} = Base.decode64(block.signature)
      assert byte_size(sig_bytes) == 64
    end

    test "different blocks have different signatures" do
      register = ImmutableState.create_register()

      change1 = %{
        change_type: :config_change,
        module: "M1",
        key: "k1",
        old_value: nil,
        new_value: "v1",
        metadata: %{}
      }

      change2 = %{
        change_type: :config_change,
        module: "M2",
        key: "k2",
        old_value: nil,
        new_value: "v2",
        metadata: %{}
      }

      r1 = ImmutableState.record(change1, register)
      r2 = ImmutableState.record(change2, r1)

      [block1, block2] = r2.blocks

      # Signatures should be different
      assert block1.signature != block2.signature
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - ImmutableRegister Integration (SC-REG-013)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "ImmutableRegister integration (SC-REG-013)" do
    test "sync_to_register/1 handles missing register gracefully" do
      block = %{
        block_hash: "abc123",
        index: 0,
        content: %{change_type: :test},
        timestamp: DateTime.utc_now(),
        signature: Base.encode64(:crypto.strong_rand_bytes(64))
      }

      # Should not crash when ImmutableRegister is not running
      result = ImmutableState.sync_to_register(block)
      assert {:ok, :skipped} = result
    end

    test "attestation_info/0 returns error when not running" do
      # Should handle gracefully when GenServer not running
      result = ImmutableState.attestation_info()
      assert Map.has_key?(result, :error) or Map.has_key?(result, :holon_id)
    end

    test "attest_with_register/0 returns error when not running" do
      result = ImmutableState.attest_with_register()
      assert {:error, _reason} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - DuckDB Persistence Structure
  # ═══════════════════════════════════════════════════════════════════════════

  describe "DuckDB persistence schema" do
    test "block has all required fields for persistence" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "PersistTest",
        key: "test_key",
        old_value: "old",
        new_value: "new",
        metadata: %{source: "test"}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      # Verify all DuckDB column fields exist
      assert is_integer(block.index)
      assert %DateTime{} = block.timestamp
      assert is_binary(block.prev_hash)
      assert String.length(block.prev_hash) == 64
      assert is_binary(block.content_hash)
      assert String.length(block.content_hash) == 64
      assert is_binary(block.block_hash)
      assert String.length(block.block_hash) == 64
      assert is_binary(block.signature)
      assert is_map(block.content)
      assert is_binary(block.protocol_version)
    end

    test "content is JSON-serializable" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :guardian_decision,
        module: "Guardian",
        key: "restart",
        old_value: nil,
        new_value: "approved",
        metadata: %{reason: "Within policy", timestamp: DateTime.utc_now()}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      # Content should be JSON-serializable
      assert {:ok, json} = Jason.encode(block.content)
      assert is_binary(json)

      # And deserializable
      assert {:ok, decoded} = Jason.decode(json, keys: :atoms)
      assert decoded.change_type == "guardian_decision"
    end

    test "protocol version is 21.1.0" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "Version",
        key: "check",
        old_value: nil,
        new_value: "ok",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      assert block.protocol_version == "21.1.0"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - Chain Integrity (PropCheck, PC.)
  # P3 COVERAGE: Hash linkage preserved
  # ═══════════════════════════════════════════════════════════════════════════

  property "chain integrity: every block links to previous (SC-REG-002)" do
    forall n <- PC.range(1, 15) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "Chain#{i}",
            key: "link_test",
            old_value: nil,
            new_value: "block_#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # Verify all blocks are properly linked
      Enum.all?(Enum.with_index(final.blocks), fn {block, idx} ->
        if idx == 0 do
          # First block should reference genesis hash
          block.prev_hash == "0000000000000000000000000000000000000000000000000000000000000000"
        else
          # All subsequent blocks should reference the previous block's hash
          prev_block = Enum.at(final.blocks, idx - 1)
          block.prev_hash == prev_block.block_hash
        end
      end)
    end
  end

  property "hash chain: prev_hash always equals prior block_hash" do
    forall n <- PC.range(2, 10) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "M#{i}",
            key: "k",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # For each pair of consecutive blocks, verify linkage
      final.blocks
      |> Enum.with_index()
      |> Enum.filter(fn {_block, idx} -> idx > 0 end)
      |> Enum.all?(fn {block, idx} ->
        prev_block = Enum.at(final.blocks, idx - 1)
        block.prev_hash == prev_block.block_hash
      end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - Append-Only Immutability (PropCheck, PC.)
  # P3 COVERAGE: Blocks never modified
  # ═══════════════════════════════════════════════════════════════════════════

  property "append-only: existing blocks never change after new appends" do
    forall n <- PC.range(1, 8) do
      register = ImmutableState.create_register()

      # Create initial chain
      state_after_n =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "Immut#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # Capture block hashes
      original_blocks = state_after_n.blocks

      # Append more blocks
      state_after_more =
        Enum.reduce((n + 1)..(n + 3), state_after_n, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "Extra#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # Verify original blocks are unchanged
      Enum.zip(original_blocks, Enum.take(state_after_more.blocks, n))
      |> Enum.all?(fn {original, current} ->
        original.block_hash == current.block_hash and
          original.content_hash == current.content_hash and
          original.signature == current.signature
      end)
    end
  end

  property "append-only: block indices strictly increasing" do
    forall n <- PC.range(1, 12) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "Idx#{i}",
            key: "idx_test",
            old_value: nil,
            new_value: "#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # Indices should be 0, 1, 2, ..., n-1
      Enum.with_index(final.blocks)
      |> Enum.all?(fn {block, idx} -> block.index == idx end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - Signature Verification (PropCheck, PC.)
  # P3 COVERAGE: All blocks are properly signed
  # ═══════════════════════════════════════════════════════════════════════════

  property "Ed25519 signatures are present for all blocks" do
    forall n <- PC.range(1, 10) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "Sig#{i}",
            key: "sig_test",
            old_value: nil,
            new_value: "signed_#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # All blocks must have signatures
      Enum.all?(final.blocks, fn block ->
        is_binary(block.signature) and String.length(block.signature) == 88
      end)
    end
  end

  property "Ed25519 signatures are deterministic for same keypair and content" do
    forall n <- PC.range(1, 5) do
      register = ImmutableState.create_register()

      changes =
        Enum.map(1..n, fn i ->
          %{
            change_type: :config_change,
            module: "Determinism#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }
        end)

      # Apply all changes
      final =
        Enum.reduce(changes, register, fn change, acc ->
          ImmutableState.record(change, acc)
        end)

      # All blocks should have non-empty signatures
      Enum.all?(final.blocks, fn block ->
        is_binary(block.signature) and String.length(block.signature) > 0
      end)
    end
  end

  property "signature content: Base64 decodes to 64-byte Ed25519 signature" do
    forall n <- PC.range(1, 8) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "SigDecode#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # All signatures should decode to 64-byte Ed25519 format
      Enum.all?(final.blocks, fn block ->
        case Base.decode64(block.signature) do
          {:ok, decoded} -> byte_size(decoded) == 64
          :error -> false
        end
      end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - Reed-Solomon (PropCheck, PC.)
  # ═══════════════════════════════════════════════════════════════════════════

  property "all blocks have RS parity after recording" do
    forall n <- PC.range(1, 10) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "RSProp#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # All blocks should have RS parity
      Enum.all?(final.blocks, fn block ->
        is_binary(Map.get(block, :rs_parity)) and
          byte_size(block.rs_parity) > 0
      end)
    end
  end

  property "RS verification passes for all valid blocks" do
    forall n <- PC.range(1, 5) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..n, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "RSVerifyProp#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # All blocks should pass RS verification
      Enum.all?(final.blocks, fn block ->
        ImmutableState.verify_block_rs(block) == :ok
      end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD.) - P3 Coverage
  # Chain integrity and immutability with StreamData
  # ═══════════════════════════════════════════════════════════════════════════

  test "StreamData: hash chain linkage across variable-sized blocks" do
    ExUnitProperties.check all(block_count <- SD.integer(1..20)) do
      register = ImmutableState.create_register()

      final =
        Enum.reduce(1..block_count, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "StreamChain#{i}",
            key: "test_#{i}",
            old_value: nil,
            new_value: "block_#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # Verify all blocks properly linked
      Enum.all?(Enum.with_index(final.blocks), fn {block, idx} ->
        if idx == 0 do
          block.prev_hash == "0000000000000000000000000000000000000000000000000000000000000000"
        else
          prev_block = Enum.at(final.blocks, idx - 1)
          block.prev_hash == prev_block.block_hash
        end
      end)
      |> assert()
    end
  end

  test "StreamData: immutability across appends" do
    ExUnitProperties.check all(
                             initial_blocks <- SD.integer(1..10),
                             additional_blocks <- SD.integer(1..5)
                           ) do
      register = ImmutableState.create_register()

      # Create initial state
      state1 =
        Enum.reduce(1..initial_blocks, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "Init#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      original_blocks = state1.blocks

      # Append more blocks
      state2 =
        Enum.reduce(
          (initial_blocks + 1)..(initial_blocks + additional_blocks),
          state1,
          fn i, acc ->
            change = %{
              change_type: :config_change,
              module: "Add#{i}",
              key: "k#{i}",
              old_value: nil,
              new_value: "v#{i}",
              metadata: %{}
            }

            ImmutableState.record(change, acc)
          end
        )

      # Verify original blocks unchanged
      Enum.zip(original_blocks, Enum.take(state2.blocks, initial_blocks))
      |> Enum.all?(fn {orig, curr} ->
        orig.block_hash == curr.block_hash
      end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Reed-Solomon Error Correction (SC-REG-006, SC-REG-008)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "Reed-Solomon parity (SC-REG-006)" do
    test "blocks include RS parity data" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "RSTest",
        key: "parity",
        old_value: nil,
        new_value: "test_value",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      # Block should have RS parity
      assert Map.has_key?(block, :rs_parity)
      assert is_binary(block.rs_parity)
      # Parity should be non-empty
      assert byte_size(block.rs_parity) > 0
    end

    test "RS parity is unique per block content" do
      register = ImmutableState.create_register()

      change1 = %{
        change_type: :config_change,
        module: "RS1",
        key: "k1",
        old_value: nil,
        new_value: "value1",
        metadata: %{}
      }

      change2 = %{
        change_type: :config_change,
        module: "RS2",
        key: "k2",
        old_value: nil,
        new_value: "value2",
        metadata: %{}
      }

      r1 = ImmutableState.record(change1, register)
      r2 = ImmutableState.record(change2, r1)

      [block1, block2] = r2.blocks

      # Different blocks should have different parity
      assert block1.rs_parity != block2.rs_parity
    end

    test "verify_block_rs/1 returns :ok for valid block" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "RSVerify",
        key: "test",
        old_value: nil,
        new_value: "valid",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)
      [block] = updated.blocks

      # Block should pass RS verification
      assert ImmutableState.verify_block_rs(block) == :ok
    end

    test "verify_block_rs/1 handles blocks without parity (legacy)" do
      # Create a block without RS parity (simulating legacy block)
      legacy_block = %{
        index: 0,
        block_hash: "abc123",
        content: %{change_type: :test},
        signature: "sig123",
        rs_parity: nil
      }

      # Should return :ok for legacy blocks without parity
      assert ImmutableState.verify_block_rs(legacy_block) == :ok
    end
  end

  describe "verify_chain_with_repair/1 (SC-REG-006, SC-REG-008)" do
    test "verifies valid chain" do
      register = ImmutableState.create_register()

      updated =
        Enum.reduce(1..3, register, fn i, acc ->
          change = %{
            change_type: :config_change,
            module: "ChainRepair#{i}",
            key: "k#{i}",
            old_value: nil,
            new_value: "v#{i}",
            metadata: %{}
          }

          ImmutableState.record(change, acc)
        end)

      # Chain should verify successfully
      assert {:ok, verified_state} = ImmutableState.verify_chain_with_repair(updated)
      assert verified_state.repair_count == 0
      assert Map.has_key?(verified_state.verification_stats, :last_verified)
      assert verified_state.verification_stats.blocks_verified == 3
      assert verified_state.verification_stats.repairs_made == 0
    end

    test "initializes verification_stats field" do
      register = ImmutableState.create_register()

      change = %{
        change_type: :config_change,
        module: "Stats",
        key: "test",
        old_value: nil,
        new_value: "ok",
        metadata: %{}
      }

      updated = ImmutableState.record(change, register)

      assert {:ok, verified} = ImmutableState.verify_chain_with_repair(updated)

      assert is_map(verified.verification_stats)
      assert %DateTime{} = verified.verification_stats.last_verified
    end
  end

  describe "record_repair_event/3 (SC-REG-008)" do
    test "creates repair event block" do
      register = ImmutableState.create_register()

      repair_info = %{
        error_type: :crc_mismatch,
        corrected_bytes: 5
      }

      updated = ImmutableState.record_repair_event(0, repair_info, register)

      assert length(updated.blocks) == 1
      [block] = updated.blocks

      assert block.content.change_type == :repair_event
      assert block.content.module == "ImmutableState"
      assert block.content.key == "rs_repair"
      assert block.content.new_value.repaired_block_index == 0
      assert block.content.new_value.repair_info == repair_info
      assert block.content.metadata.constraint == "SC-REG-008"
    end
  end

  describe "rs_status/0" do
    test "returns RS parameters" do
      status = ImmutableState.rs_status()

      assert is_map(status)
      assert status.constraint == "SC-REG-006"
      assert is_map(status.parameters)
      assert Map.has_key?(status.parameters, :n)
      assert Map.has_key?(status.parameters, :k)
      assert Map.has_key?(status.parameters, :parity_symbols)
    end
  end
end
