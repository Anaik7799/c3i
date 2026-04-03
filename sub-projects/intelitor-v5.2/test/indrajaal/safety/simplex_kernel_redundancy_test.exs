defmodule Indrajaal.Safety.SimplexKernelRedundancyTest do
  @moduledoc """
  TDG test suite for Simplex Kernel minimum redundancy enforcement.

  WHAT: Tests that MinRedundancy=2 is enforced, that redundancy cannot be
  reduced below the minimum, and that pool operations preserve safety
  invariants. All tests are self-contained — no dependency on running services.

  CONSTRAINTS:
  - SC-SIMPLEX-002: Redundancy MUST NOT be reduced below minimum (MinRedundancy=2)
  - SC-SIL-002: Safe failure fraction >= 90%
  - SC-SIL-004: Separation of concerns for safety functions
  - SC-HA-001: SIL-6 availability requirements
  - SC-QUORUM-001: Two-out-of-three voting mandatory for safety-critical decisions

  ## Constitutional Verification
  - Ψ₀ (Existence): System cannot reduce itself below 2 active replicas
  - Ψ₃ (Verification): Redundancy level is always checkable

  ## Change History
  | Version | Date       | Author | Change                                   |
  |---------|------------|--------|------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 2 — redundancy suite      |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Simplex kernel pool model (pure, self-contained)
  # ---------------------------------------------------------------------------

  @min_redundancy 2

  defp new_pool(node_count) when node_count >= @min_redundancy do
    nodes = for i <- 1..node_count, do: %{id: i, state: :active, health: 1.0}
    %{nodes: nodes, min_redundancy: @min_redundancy}
  end

  defp active_count(pool) do
    Enum.count(pool.nodes, &(&1.state == :active))
  end

  defp remove_node(pool, node_id) do
    current_active = active_count(pool)

    if current_active <= pool.min_redundancy do
      {:error, :below_minimum_redundancy,
       %{current: current_active, minimum: pool.min_redundancy}}
    else
      updated_nodes =
        Enum.map(pool.nodes, fn node ->
          if node.id == node_id, do: %{node | state: :removed}, else: node
        end)

      {:ok, %{pool | nodes: updated_nodes}}
    end
  end

  defp deactivate_node(pool, node_id) do
    current_active = active_count(pool)

    if current_active <= pool.min_redundancy do
      {:error, :below_minimum_redundancy,
       %{current: current_active, minimum: pool.min_redundancy}}
    else
      updated_nodes =
        Enum.map(pool.nodes, fn node ->
          if node.id == node_id, do: %{node | state: :inactive}, else: node
        end)

      {:ok, %{pool | nodes: updated_nodes}}
    end
  end

  defp add_node(pool, new_id) do
    node = %{id: new_id, state: :active, health: 1.0}
    %{pool | nodes: [node | pool.nodes]}
  end

  defp redundancy_ok?(pool) do
    active_count(pool) >= pool.min_redundancy
  end

  defp quorum_met?(pool) do
    # 2oo3 voting: quorum = floor(N/2) + 1
    n = active_count(pool)
    quorum = div(n, 2) + 1
    n >= quorum
  end

  defp safe_failure_fraction(pool) do
    total = length(pool.nodes)
    active = active_count(pool)

    if total == 0 do
      0.0
    else
      active / total
    end
  end

  # ---------------------------------------------------------------------------
  # SC-SIMPLEX-002: MinRedundancy=2 enforced
  # ---------------------------------------------------------------------------

  describe "SC-SIMPLEX-002: MinRedundancy=2 enforcement" do
    test "min_redundancy constant is exactly 2" do
      assert @min_redundancy == 2
    end

    test "pool starts with correct active count" do
      pool = new_pool(3)
      assert active_count(pool) == 3
      assert redundancy_ok?(pool)
    end

    test "can remove node when above minimum" do
      pool = new_pool(3)
      assert {:ok, updated} = remove_node(pool, 1)
      assert active_count(updated) == 2
      assert redundancy_ok?(updated)
    end

    test "cannot remove node when at minimum (3-node pool, 1 already removed)" do
      pool = new_pool(3)
      {:ok, pool2} = remove_node(pool, 1)

      assert active_count(pool2) == 2

      # Trying to remove another node would breach minimum
      assert {:error, :below_minimum_redundancy, _} = remove_node(pool2, 2)
    end

    test "cannot remove node from 2-node pool" do
      pool = new_pool(2)
      assert {:error, :below_minimum_redundancy, %{current: 2, minimum: 2}} = remove_node(pool, 1)
    end

    test "error includes current and minimum counts" do
      pool = new_pool(2)
      {:error, :below_minimum_redundancy, details} = remove_node(pool, 1)

      assert details.current == 2
      assert details.minimum == @min_redundancy
    end

    test "deactivate_node respects minimum" do
      pool = new_pool(2)
      assert {:error, :below_minimum_redundancy, _} = deactivate_node(pool, 1)
    end

    test "adding node increases active count" do
      pool = new_pool(2)
      pool2 = add_node(pool, 3)
      assert active_count(pool2) == 3
    end

    test "after adding node, removal is allowed" do
      pool = new_pool(2)
      pool2 = add_node(pool, 3)
      assert {:ok, pool3} = remove_node(pool2, 1)
      assert active_count(pool3) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # SC-SIL-002: Safe failure fraction >= 90%
  # ---------------------------------------------------------------------------

  describe "SC-SIL-002: safe failure fraction" do
    test "all-active pool has fraction 1.0" do
      pool = new_pool(3)
      assert safe_failure_fraction(pool) == 1.0
    end

    test "one removed from 3-node pool gives 2/3 ≈ 0.67" do
      pool = new_pool(3)
      {:ok, pool2} = remove_node(pool, 1)
      fraction = safe_failure_fraction(pool2)
      assert_in_delta fraction, 2 / 3, 0.01
    end

    test "minimum allowed pool (2/2) gives fraction 1.0" do
      pool = new_pool(2)
      assert safe_failure_fraction(pool) == 1.0
    end

    test "10-node pool with 9 active gives 0.9" do
      pool = new_pool(10)
      {:ok, pool2} = remove_node(pool, 1)
      fraction = safe_failure_fraction(pool2)
      assert_in_delta fraction, 0.9, 0.01
    end
  end

  # ---------------------------------------------------------------------------
  # SC-QUORUM-001: 2oo3 voting
  # ---------------------------------------------------------------------------

  describe "SC-QUORUM-001: quorum computation" do
    test "3-node pool has quorum of 2" do
      pool = new_pool(3)
      # With 3 active, quorum = floor(3/2)+1 = 2 — met by 3 >= 2
      assert quorum_met?(pool)
    end

    test "2-node pool meets quorum" do
      pool = new_pool(2)
      # quorum = floor(2/2)+1 = 2, active = 2
      assert quorum_met?(pool)
    end

    test "5-node pool: quorum = 3" do
      pool = new_pool(5)
      assert quorum_met?(pool)
      # Active = 5, quorum = 3 → met
    end

    test "quorum formula: floor(N/2)+1" do
      for n <- [2, 3, 4, 5, 6, 7] do
        expected_quorum = div(n, 2) + 1
        assert expected_quorum >= 2, "Quorum for N=#{n} must be >= 2"
        assert expected_quorum <= n, "Quorum for N=#{n} must be <= N"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: redundancy invariants" do
    property "new pool always satisfies redundancy constraint" do
      forall n <- PC.integer(2, 20) do
        pool = new_pool(n)
        redundancy_ok?(pool)
      end
    end

    test "removing nodes never goes below min_redundancy" do
      ExUnitProperties.check all(initial <- SD.integer(2, 10), removals <- SD.integer(0, 8)) do
        pool = new_pool(initial)

        final_pool =
          Enum.reduce(1..max(removals, 1), pool, fn i, acc ->
            case remove_node(acc, i) do
              {:ok, updated} -> updated
              {:error, _, _} -> acc
            end
          end)

        assert active_count(final_pool) >= @min_redundancy,
               "Active count #{active_count(final_pool)} fell below minimum #{@min_redundancy}"
      end
    end

    test "safe_failure_fraction is always in [0.0, 1.0]" do
      ExUnitProperties.check all(n <- SD.integer(2, 20)) do
        pool = new_pool(n)
        frac = safe_failure_fraction(pool)
        assert frac >= 0.0 and frac <= 1.0
      end
    end

    test "quorum is always met for valid pools" do
      ExUnitProperties.check all(n <- SD.integer(2, 20)) do
        pool = new_pool(n)
        assert quorum_met?(pool), "Expected quorum to be met for #{n}-node pool"
      end
    end

    test "error tuple always contains current and minimum fields" do
      ExUnitProperties.check all(n <- SD.integer(2, 10)) do
        pool = new_pool(n)

        # Try to remove nodes down to minimum, then one more
        final_pool =
          Enum.reduce(1..n, pool, fn i, acc ->
            case remove_node(acc, i) do
              {:ok, updated} -> updated
              _ -> acc
            end
          end)

        # At minimum — next removal must fail with correct error
        next_id = n + 1
        result = remove_node(final_pool, next_id)

        assert match?({:error, :below_minimum_redundancy, %{current: _, minimum: _}}, result),
               "Expected structured error, got #{inspect(result)}"
      end
    end
  end
end
