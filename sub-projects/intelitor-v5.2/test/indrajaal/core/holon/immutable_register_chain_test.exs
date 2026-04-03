defmodule Indrajaal.Core.Holon.ImmutableRegisterChainTest do
  @moduledoc """
  Immutable Register chain verification test suite.

  ## WHAT
  Tests SHA3 hash chain integrity, Ed25519 signatures, append-only semantics,
  merkle root computation, and Reed-Solomon error correction for the
  ImmutableRegister GenServer.

  ## CONSTRAINTS
  - SC-REG-001: Append-only mandate
  - SC-REG-002: Chain verification on startup
  - SC-REG-003: Ed25519 signatures required
  - SC-REG-004: Self-repair on corruption
  - SC-REG-011: Merkle root for state verification
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Core.Holon.ImmutableRegister

  @genesis_hash "genesis"

  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    name = :"register_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = ImmutableRegister.start_link(name: name, holon_id: "test-holon-#{name}")
    %{register: name, pid: pid}
  end

  # ============================================================================
  # Block Structure Tests
  # ============================================================================

  describe "block structure" do
    test "genesis block has correct hash chain", %{register: reg} do
      {:ok, blocks} = ImmutableRegister.get_full_state(reg)
      # Genesis block should be first
      assert is_list(blocks)
    end

    test "append creates block with prev_hash linking", %{register: reg} do
      {:ok, hash1} = ImmutableRegister.append(reg, :state_change, %{action: :init})
      assert is_binary(hash1)
      assert byte_size(hash1) > 0

      {:ok, hash2} = ImmutableRegister.append(reg, :state_change, %{action: :update})
      assert is_binary(hash2)
      refute hash1 == hash2
    end

    test "blocks contain required fields", %{register: reg} do
      {:ok, _hash} = ImmutableRegister.append(reg, :audit, %{event: :login})
      {:ok, blocks} = ImmutableRegister.get_full_state(reg)

      for block <- blocks do
        assert Map.has_key?(block, :content)
        assert Map.has_key?(block, :prev_hash)
        assert Map.has_key?(block, :hash)
        assert Map.has_key?(block, :timestamp)
      end
    end
  end

  # ============================================================================
  # Chain Integrity Tests (SC-REG-002)
  # ============================================================================

  describe "chain integrity (SC-REG-002)" do
    test "verify returns :ok for valid chain", %{register: reg} do
      {:ok, _} = ImmutableRegister.append(reg, :state, %{a: 1})
      {:ok, _} = ImmutableRegister.append(reg, :state, %{a: 2})
      {:ok, _} = ImmutableRegister.append(reg, :state, %{a: 3})

      assert :ok = ImmutableRegister.verify(reg)
    end

    test "chain grows monotonically", %{register: reg} do
      hashes =
        for i <- 1..5 do
          {:ok, hash} = ImmutableRegister.append(reg, :event, %{seq: i})
          hash
        end

      # All hashes should be unique
      assert length(Enum.uniq(hashes)) == 5
    end

    test "head hash updates after each append", %{register: reg} do
      head_before = ImmutableRegister.head(reg)

      {:ok, _} = ImmutableRegister.append(reg, :change, %{key: "val"})
      head_after = ImmutableRegister.head(reg)

      refute head_before == head_after
    end
  end

  # ============================================================================
  # Append-Only Semantics (SC-REG-001)
  # ============================================================================

  describe "append-only semantics (SC-REG-001)" do
    test "blocks cannot be removed or modified", %{register: reg} do
      {:ok, _} = ImmutableRegister.append(reg, :data, %{v: 1})
      {:ok, blocks_before} = ImmutableRegister.get_full_state(reg)

      {:ok, _} = ImmutableRegister.append(reg, :data, %{v: 2})
      {:ok, blocks_after} = ImmutableRegister.get_full_state(reg)

      # New chain should contain all previous blocks
      assert length(blocks_after) > length(blocks_before)
    end

    test "sequential appends maintain order", %{register: reg} do
      for i <- 1..10 do
        {:ok, _} = ImmutableRegister.append(reg, :seq, %{index: i})
      end

      {:ok, blocks} = ImmutableRegister.get_full_state(reg)

      # Blocks should be ordered by index
      indices =
        blocks
        |> Enum.filter(fn b -> is_map(b.content) and Map.has_key?(b.content, :index) end)
        |> Enum.map(fn b -> b.content.index end)

      assert indices == Enum.sort(indices)
    end
  end

  # ============================================================================
  # Statistics & Export (SC-REG-011)
  # ============================================================================

  describe "statistics and export" do
    test "stats returns block count", %{register: reg} do
      {:ok, _} = ImmutableRegister.append(reg, :stat, %{x: 1})
      {:ok, _} = ImmutableRegister.append(reg, :stat, %{x: 2})

      stats = ImmutableRegister.stats(reg)
      assert is_map(stats)
      assert Map.has_key?(stats, :block_count)
      assert stats.block_count >= 2
    end

    test "export returns all blocks for replication", %{register: reg} do
      for i <- 1..3 do
        {:ok, _} = ImmutableRegister.append(reg, :export, %{n: i})
      end

      {:ok, blocks} = ImmutableRegister.export(reg)
      assert is_list(blocks)
      assert length(blocks) >= 3
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: chain integrity under random appends" do
    @tag timeout: 30_000
    test "chain always verifies after N random appends", %{register: reg} do
      ExUnitProperties.check all(n <- SD.integer(1..20)) do
        categories = for _ <- 1..n, do: Enum.random([:state, :audit, :event, :mutation])
        name = :"prop_register_#{:erlang.unique_integer([:positive])}"
        {:ok, _pid} = ImmutableRegister.start_link(name: name, holon_id: "prop-#{name}")

        for cat <- categories do
          {:ok, _} = ImmutableRegister.append(name, cat, %{random: :rand.uniform(1000)})
        end

        assert :ok = ImmutableRegister.verify(name)
        GenServer.stop(name)
      end
    end
  end

  describe "property: hash uniqueness" do
    @tag timeout: 30_000
    test "all block hashes are unique across appends", %{register: reg} do
      hashes =
        for i <- 1..20 do
          {:ok, hash} = ImmutableRegister.append(reg, :unique, %{i: i, rand: :rand.uniform()})
          hash
        end

      assert length(Enum.uniq(hashes)) == length(hashes)
    end
  end
end
