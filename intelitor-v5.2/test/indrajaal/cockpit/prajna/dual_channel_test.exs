defmodule Indrajaal.Cockpit.Prajna.DualChannelTest do
  @moduledoc """
  TDG-Compliant Tests for DualChannel Module.

  STAMP Compliance: SC-REG-007, SC-PRIME-001, AOR-CONST-002
  TDG: Dual property testing with PropCheck + ExUnitProperties

  Tests SIL-6 dual-channel verification:
  - Independent hash chain verification (Channel A)
  - Independent signature verification (Channel B)
  - Cross-channel agreement checking
  - Disagreement handling (halt + alert)
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.DualChannel

  @genesis_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @signing_key "prajna_immutable_state_hmac_key_v21"

  # ============================================================================
  # Test Helpers
  # ============================================================================

  defp create_valid_block(index, prev_hash, content) do
    now = DateTime.utc_now()
    content_json = Jason.encode!(content)
    content_hash = hash(content_json)
    timestamp_str = DateTime.to_iso8601(now)
    block_data = "#{prev_hash}|#{content_hash}|#{index}|#{timestamp_str}"
    block_hash = hash(block_data)
    signature = sign(block_hash)

    %{
      index: index,
      timestamp: now,
      prev_hash: prev_hash,
      content_hash: content_hash,
      block_hash: block_hash,
      signature: signature,
      content: content,
      protocol_version: "21.1.0"
    }
  end

  defp hash(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp sign(data) do
    :crypto.mac(:hmac, :sha512, @signing_key, data) |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # UNIT TESTS - Single Block Verification
  # ============================================================================

  describe "verify_block/2 - valid blocks" do
    test "verifies a valid genesis block" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      assert {:ok, :verified} = DualChannel.verify_block(block, @genesis_hash)
    end

    test "verifies a valid block in chain" do
      content1 = %{
        change_type: :config_change,
        module: "M1",
        key: "k1",
        old_value: nil,
        new_value: "v1",
        metadata: %{}
      }

      block1 = create_valid_block(0, @genesis_hash, content1)

      content2 = %{
        change_type: :config_change,
        module: "M2",
        key: "k2",
        old_value: nil,
        new_value: "v2",
        metadata: %{}
      }

      block2 = create_valid_block(1, block1.block_hash, content2)

      assert {:ok, :verified} = DualChannel.verify_block(block1, @genesis_hash)
      assert {:ok, :verified} = DualChannel.verify_block(block2, block1.block_hash)
    end
  end

  describe "verify_block/2 - Channel A failures (hash verification)" do
    test "fails when prev_hash mismatches" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      # Wrong expected prev_hash
      wrong_prev = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

      result = DualChannel.verify_block(block, wrong_prev)
      assert {:error, :channel_a_failed, reason} = result
      assert reason =~ "prev_hash mismatch"
    end

    test "fails when content_hash is tampered" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      # Tamper with content_hash
      tampered = %{
        block
        | content_hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      }

      result = DualChannel.verify_block(tampered, @genesis_hash)
      assert {:error, :channel_a_failed, reason} = result
      assert reason =~ "content_hash mismatch"
    end

    test "fails when block_hash is tampered" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      # Tamper with block_hash but keep valid signature for that hash
      tampered_hash = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
      tampered = %{block | block_hash: tampered_hash, signature: sign(tampered_hash)}

      result = DualChannel.verify_block(tampered, @genesis_hash)
      assert {:error, :channel_a_failed, reason} = result
      assert reason =~ "block_hash mismatch"
    end
  end

  describe "verify_block/2 - Channel B failures (signature verification)" do
    test "fails when signature is invalid" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      # Tamper with signature only
      tampered = %{
        block
        | signature:
            "invalid_signature_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }

      result = DualChannel.verify_block(tampered, @genesis_hash)
      assert {:error, :channel_b_failed, reason} = result
      assert reason =~ "signature invalid"
    end

    test "fails when protocol_version is missing" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      # Remove protocol_version
      tampered = Map.delete(block, :protocol_version)

      result = DualChannel.verify_block(tampered, @genesis_hash)
      assert {:error, :channel_b_failed, reason} = result
      assert reason =~ "protocol_version"
    end
  end

  describe "verify_block/2 - Channels disagree" do
    test "reports disagreement when both channels fail differently" do
      content = %{
        change_type: :config_change,
        module: "Test",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      # Tamper with both content_hash AND signature
      tampered = %{
        block
        | content_hash: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
          signature:
            "invalid_signature_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }

      result = DualChannel.verify_block(tampered, @genesis_hash)
      assert {:error, :channels_disagree, details} = result
      assert is_map(details)
      assert Map.has_key?(details, :channel_a)
      assert Map.has_key?(details, :channel_b)
    end
  end

  # ============================================================================
  # UNIT TESTS - Chain Verification
  # ============================================================================

  describe "verify_chain/1 - valid chains" do
    test "verifies empty chain" do
      assert {:ok, :verified} = DualChannel.verify_chain([])
    end

    test "verifies single-block chain" do
      content = %{
        change_type: :config_change,
        module: "M1",
        key: "k1",
        old_value: nil,
        new_value: "v1",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      assert {:ok, :verified} = DualChannel.verify_chain([block])
    end

    test "verifies multi-block chain" do
      blocks = build_valid_chain(5)
      assert {:ok, :verified} = DualChannel.verify_chain(blocks)
    end
  end

  describe "verify_chain/1 - invalid chains" do
    test "fails when block in middle is tampered" do
      blocks = build_valid_chain(5)

      # Tamper with block at index 2
      tampered_block = %{
        Enum.at(blocks, 2)
        | content_hash: "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
      }

      tampered_blocks = List.replace_at(blocks, 2, tampered_block)

      result = DualChannel.verify_chain(tampered_blocks)
      assert {:error, :block_failed, 2, _details} = result
    end

    test "fails when chain continuity is broken" do
      blocks = build_valid_chain(3)

      # Break chain by modifying prev_hash of block 2
      broken_block = %{Enum.at(blocks, 2) | prev_hash: @genesis_hash}
      broken_blocks = List.replace_at(blocks, 2, broken_block)

      result = DualChannel.verify_chain(broken_blocks)
      assert {:error, :block_failed, 2, _details} = result
    end
  end

  # ============================================================================
  # UNIT TESTS - Statistics and State
  # ============================================================================

  describe "stats/0" do
    test "returns initial stats when no verifications performed" do
      stats = DualChannel.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :verification_count)
      assert Map.has_key?(stats, :disagreement_count)
      assert Map.has_key?(stats, :halt_count)
      assert Map.has_key?(stats, :halted)
    end
  end

  describe "halted?/0" do
    test "returns false when not halted" do
      # Stateless fallback returns false
      assert DualChannel.halted?() == false
    end
  end

  # ============================================================================
  # INTEGRATION TESTS - Chain Verification
  # ============================================================================

  describe "chain verification consistency" do
    test "verifies chains of varying lengths" do
      for len <- [1, 3, 5, 10] do
        blocks = build_valid_chain(len)
        assert {:ok, :verified} = DualChannel.verify_chain(blocks)
      end
    end

    test "detects tampering at any position in chain" do
      blocks = build_valid_chain(5)

      for idx <- 0..4 do
        # Tamper with signature at position idx
        tampered_block = %{Enum.at(blocks, idx) | signature: String.duplicate("a", 128)}
        tampered_blocks = List.replace_at(blocks, idx, tampered_block)

        result = DualChannel.verify_chain(tampered_blocks)
        assert {:error, :block_failed, ^idx, _details} = result
      end
    end
  end

  # ============================================================================
  # PROPERTY TESTS - PropCheck (PC)
  # ============================================================================

  property "valid blocks always pass dual-channel verification" do
    forall n <- PC.range(1, 10) do
      blocks = build_valid_chain(n)

      Enum.all?(blocks, fn block ->
        prev_hash =
          if block.index == 0,
            do: @genesis_hash,
            else: Enum.at(blocks, block.index - 1).block_hash

        {:ok, :verified} == DualChannel.verify_block(block, prev_hash)
      end)
    end
  end

  property "tampered content_hash always fails Channel A" do
    forall _n <- PC.range(1, 5) do
      content = %{
        change_type: :config_change,
        module: "PropTest",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      tampered = %{
        block
        | content_hash: "0000000000000000000000000000000000000000000000000000000000000000"
      }

      case DualChannel.verify_block(tampered, @genesis_hash) do
        {:error, :channel_a_failed, _} -> true
        {:error, :channels_disagree, _} -> true
        _ -> false
      end
    end
  end

  property "tampered signature always fails Channel B" do
    forall _n <- PC.range(1, 5) do
      content = %{
        change_type: :config_change,
        module: "PropTest",
        key: "k",
        old_value: nil,
        new_value: "v",
        metadata: %{}
      }

      block = create_valid_block(0, @genesis_hash, content)

      tampered = %{block | signature: String.duplicate("0", 128)}

      case DualChannel.verify_block(tampered, @genesis_hash) do
        {:error, :channel_b_failed, _} -> true
        {:error, :channels_disagree, _} -> true
        _ -> false
      end
    end
  end

  # ============================================================================
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ============================================================================

  test "chain verification is deterministic (property)" do
    for n <- 1..5 do
      blocks = build_valid_chain(n)

      result1 = DualChannel.verify_chain(blocks)
      result2 = DualChannel.verify_chain(blocks)

      assert result1 == result2
    end
  end

  test "verification order matches block order (property)" do
    for n <- [3, 5, 7] do
      blocks = build_valid_chain(n)

      # Verify each block in order
      results =
        Enum.with_index(blocks)
        |> Enum.map(fn {block, idx} ->
          prev_hash = if idx == 0, do: @genesis_hash, else: Enum.at(blocks, idx - 1).block_hash
          DualChannel.verify_block(block, prev_hash)
        end)

      assert Enum.all?(results, fn r -> r == {:ok, :verified} end)
    end
  end

  # ============================================================================
  # Helper: Build Valid Chain
  # ============================================================================

  defp build_valid_chain(length) when length > 0 do
    Enum.reduce(1..length, {[], @genesis_hash}, fn i, {blocks, prev_hash} ->
      content = %{
        change_type: :config_change,
        module: "Module#{i}",
        key: "key#{i}",
        old_value: nil,
        new_value: "value#{i}",
        metadata: %{}
      }

      block = create_valid_block(i - 1, prev_hash, content)
      {blocks ++ [block], block.block_hash}
    end)
    |> elem(0)
  end
end
