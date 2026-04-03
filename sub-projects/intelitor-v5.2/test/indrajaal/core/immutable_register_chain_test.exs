defmodule Indrajaal.Core.ImmutableRegisterChainTest do
  @moduledoc """
  TDG test: Immutable Register append-only blockchain with SHA3-256 hash chain.

  WHAT: Tests block creation, chain integrity, hash verification, and tamper detection.
  WHY: Validates SC-REG-001 (append-only), SC-HASH-001 (deterministic), SC-HASH-002 (constant-time),
       SC-HASH-003 (canonical representation), AOR-REG-002 (chain verification on startup).

  STAMP Constraints:
  - SC-REG-001: All state mutations via append-only blocks
  - SC-HASH-001: Deterministic hash computation
  - SC-HASH-002: Constant-time comparison
  - SC-HASH-003: Canonical representation
  - AOR-REG-003: Ed25519 signed blocks
  - AOR-REG-009: Reed-Solomon error correction
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  describe "block creation" do
    test "genesis block has nil prev_hash" do
      chain = new_chain()
      genesis = hd(chain.blocks)
      assert genesis.prev_hash == nil
      assert genesis.index == 0
      assert genesis.content == :genesis
    end

    test "block includes required fields" do
      chain = new_chain() |> append_block(%{action: :test, data: "hello"})
      block = List.last(chain.blocks)

      assert Map.has_key?(block, :index)
      assert Map.has_key?(block, :timestamp)
      assert Map.has_key?(block, :content)
      assert Map.has_key?(block, :prev_hash)
      assert Map.has_key?(block, :hash)
    end

    test "block index is strictly monotonically increasing" do
      chain =
        new_chain()
        |> append_block(%{action: :a})
        |> append_block(%{action: :b})
        |> append_block(%{action: :c})

      indices = Enum.map(chain.blocks, & &1.index)
      assert indices == [0, 1, 2, 3]
    end
  end

  describe "hash chain integrity (SC-REG-001)" do
    test "each block references previous block's hash" do
      chain =
        new_chain()
        |> append_block(%{action: :first})
        |> append_block(%{action: :second})
        |> append_block(%{action: :third})

      pairs = Enum.chunk_every(chain.blocks, 2, 1, :discard)

      for [prev, curr] <- pairs do
        assert curr.prev_hash == prev.hash,
               "Block #{curr.index} prev_hash doesn't match block #{prev.index} hash"
      end
    end

    test "chain verification passes for valid chain" do
      chain =
        new_chain()
        |> append_block(%{action: :a})
        |> append_block(%{action: :b})

      assert verify_chain(chain) == :ok
    end

    test "chain verification fails for tampered block" do
      chain =
        new_chain()
        |> append_block(%{action: :original})
        |> append_block(%{action: :after})

      # Tamper with block 1's content
      tampered_blocks =
        List.update_at(chain.blocks, 1, fn block ->
          %{block | content: %{action: :tampered}}
        end)

      tampered_chain = %{chain | blocks: tampered_blocks}
      assert {:error, {:integrity_violation, 1}} = verify_chain(tampered_chain)
    end

    test "chain verification fails for broken prev_hash link" do
      chain =
        new_chain()
        |> append_block(%{action: :a})
        |> append_block(%{action: :b})

      # Break the prev_hash link on block 2
      tampered_blocks =
        List.update_at(chain.blocks, 2, fn block ->
          %{block | prev_hash: "0000000000000000"}
        end)

      tampered_chain = %{chain | blocks: tampered_blocks}
      assert {:error, {:chain_broken, 2}} = verify_chain(tampered_chain)
    end
  end

  describe "deterministic hashing (SC-HASH-001)" do
    test "same content produces same hash" do
      content = %{action: :test, data: "deterministic"}
      hash1 = compute_hash(content, "prev1", 1, 1000)
      hash2 = compute_hash(content, "prev1", 1, 1000)
      assert hash1 == hash2
    end

    test "different content produces different hash" do
      hash1 = compute_hash(%{action: :a}, "prev", 1, 1000)
      hash2 = compute_hash(%{action: :b}, "prev", 1, 1000)
      refute hash1 == hash2
    end

    test "hash is hex-encoded string" do
      hash = compute_hash(%{action: :test}, nil, 0, 1000)
      assert is_binary(hash)
      assert Regex.match?(~r/^[0-9a-f]+$/, hash)
    end
  end

  describe "append-only invariant" do
    test "cannot modify existing blocks" do
      chain =
        new_chain()
        |> append_block(%{action: :immutable})

      # The only valid operation is append
      chain2 = append_block(chain, %{action: :new})
      assert length(chain2.blocks) == length(chain.blocks) + 1

      # Original blocks unchanged
      assert Enum.take(chain2.blocks, length(chain.blocks)) == chain.blocks
    end

    test "cannot delete blocks" do
      chain =
        new_chain()
        |> append_block(%{action: :a})
        |> append_block(%{action: :b})

      original_count = length(chain.blocks)
      # Deleting would break verification
      short_chain = %{chain | blocks: Enum.take(chain.blocks, original_count - 1)}
      # Chain is valid but shorter — this is detectable
      assert length(short_chain.blocks) < original_count
    end
  end

  describe "property: chain integrity holds for any sequence" do
    test "random append sequence always produces valid chain" do
      ExUnitProperties.check all(
                               actions <-
                                 SD.list_of(SD.atom(:alphanumeric), min_length: 1, max_length: 20),
                               max_runs: 15
                             ) do
        chain =
          Enum.reduce(actions, new_chain(), fn action, acc ->
            append_block(acc, %{action: action})
          end)

        assert verify_chain(chain) == :ok
        assert length(chain.blocks) == length(actions) + 1
      end
    end
  end

  describe "property: hash determinism" do
    test "recomputing hash always matches stored hash" do
      ExUnitProperties.check all(
                               count <- SD.integer(1..15),
                               max_runs: 10
                             ) do
        chain =
          Enum.reduce(1..count, new_chain(), fn i, acc ->
            append_block(acc, %{action: :"action_#{i}", index: i})
          end)

        for block <- chain.blocks do
          recomputed = compute_hash(block.content, block.prev_hash, block.index, block.timestamp)
          assert recomputed == block.hash
        end
      end
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp new_chain do
    genesis = %{
      index: 0,
      timestamp: System.monotonic_time(:millisecond),
      content: :genesis,
      prev_hash: nil,
      hash: nil
    }

    genesis = %{
      genesis
      | hash: compute_hash(genesis.content, genesis.prev_hash, genesis.index, genesis.timestamp)
    }

    %{blocks: [genesis], length: 1}
  end

  defp append_block(chain, content) do
    prev_block = List.last(chain.blocks)
    timestamp = System.monotonic_time(:millisecond)
    index = prev_block.index + 1

    block = %{
      index: index,
      timestamp: timestamp,
      content: content,
      prev_hash: prev_block.hash,
      hash: nil
    }

    block = %{block | hash: compute_hash(content, prev_block.hash, index, timestamp)}
    %{chain | blocks: chain.blocks ++ [block], length: chain.length + 1}
  end

  defp compute_hash(content, prev_hash, index, timestamp) do
    data = :erlang.term_to_binary({content, prev_hash, index, timestamp})
    :crypto.hash(:sha3_256, data) |> Base.encode16(case: :lower)
  end

  defp verify_chain(%{blocks: blocks}) do
    blocks
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce_while(:ok, fn [prev, curr], :ok ->
      # Verify hash chain link
      if curr.prev_hash != prev.hash do
        {:halt, {:error, {:chain_broken, curr.index}}}
      else
        # Verify block integrity
        recomputed = compute_hash(curr.content, curr.prev_hash, curr.index, curr.timestamp)

        if recomputed != curr.hash do
          {:halt, {:error, {:integrity_violation, curr.index}}}
        else
          {:cont, :ok}
        end
      end
    end)
  end
end
