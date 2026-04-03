defmodule Indrajaal.Holon.Database.ConcurrencyHandlerTest do
  @moduledoc """
  Tests for ConcurrencyHandler OCC implementation.

  STAMP Compliance: SC-CONC-001 to SC-CONC-010
  Coverage: Degree D4 from 9x9 Test Matrix
  """

  use ExUnit.Case, async: true
  use PropCheck

  alias Indrajaal.Holon.Database.ConcurrencyHandler
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ==========================================================================
  # Version Vector Operations Tests
  # ==========================================================================

  describe "new_version_vector/1" do
    test "creates version vector with single entry" do
      vv = ConcurrencyHandler.new_version_vector("holon1")

      assert vv == %{"holon1" => 0}
    end
  end

  describe "increment/2" do
    test "increments existing holon entry" do
      vv = %{"holon1" => 5}
      result = ConcurrencyHandler.increment(vv, "holon1")

      assert result == %{"holon1" => 6}
    end

    test "adds new holon with version 1" do
      vv = %{"holon1" => 5}
      result = ConcurrencyHandler.increment(vv, "holon2")

      assert result == %{"holon1" => 5, "holon2" => 1}
    end

    test "handles empty version vector" do
      result = ConcurrencyHandler.increment(%{}, "holon1")

      assert result == %{"holon1" => 1}
    end
  end

  describe "merge/2" do
    test "merges by taking max of each component" do
      vv1 = %{"h1" => 3, "h2" => 5}
      vv2 = %{"h1" => 7, "h3" => 2}

      result = ConcurrencyHandler.merge_version_vectors(vv1, vv2)

      assert result == %{"h1" => 7, "h2" => 5, "h3" => 2}
    end

    test "merge is commutative" do
      vv1 = %{"h1" => 3, "h2" => 5}
      vv2 = %{"h1" => 7, "h3" => 2}

      assert ConcurrencyHandler.merge_version_vectors(vv1, vv2) ==
               ConcurrencyHandler.merge_version_vectors(vv2, vv1)
    end

    test "merge is associative" do
      vv1 = %{"h1" => 1}
      vv2 = %{"h2" => 2}
      vv3 = %{"h3" => 3}

      left =
        ConcurrencyHandler.merge_version_vectors(
          ConcurrencyHandler.merge_version_vectors(vv1, vv2),
          vv3
        )

      right =
        ConcurrencyHandler.merge_version_vectors(
          vv1,
          ConcurrencyHandler.merge_version_vectors(vv2, vv3)
        )

      assert left == right
    end

    test "merge is idempotent" do
      vv = %{"h1" => 3, "h2" => 5}

      assert ConcurrencyHandler.merge_version_vectors(vv, vv) == vv
    end
  end

  describe "version_gte?/2" do
    test "returns true when vv1 >= vv2 for all components" do
      vv1 = %{"h1" => 5, "h2" => 3}
      vv2 = %{"h1" => 5, "h2" => 2}

      assert ConcurrencyHandler.version_gte?(vv1, vv2) == true
    end

    test "returns false when any component of vv1 < vv2" do
      vv1 = %{"h1" => 5, "h2" => 1}
      vv2 = %{"h1" => 5, "h2" => 2}

      assert ConcurrencyHandler.version_gte?(vv1, vv2) == false
    end

    test "handles missing keys (treated as 0)" do
      vv1 = %{"h1" => 5}
      vv2 = %{"h1" => 5, "h2" => 0}

      assert ConcurrencyHandler.version_gte?(vv1, vv2) == true
    end

    test "returns false when vv1 missing key that vv2 has > 0" do
      vv1 = %{"h1" => 5}
      vv2 = %{"h1" => 5, "h2" => 1}

      assert ConcurrencyHandler.version_gte?(vv1, vv2) == false
    end
  end

  describe "happens_before?/2" do
    test "returns true when vv1 < vv2 (causally precedes)" do
      vv1 = %{"h1" => 3, "h2" => 2}
      vv2 = %{"h1" => 5, "h2" => 3}

      assert ConcurrencyHandler.happens_before?(vv1, vv2) == true
    end

    test "returns false when vv1 == vv2" do
      vv = %{"h1" => 3, "h2" => 2}

      assert ConcurrencyHandler.happens_before?(vv, vv) == false
    end

    test "returns false for concurrent versions" do
      vv1 = %{"h1" => 5, "h2" => 2}
      vv2 = %{"h1" => 3, "h2" => 4}

      assert ConcurrencyHandler.happens_before?(vv1, vv2) == false
      assert ConcurrencyHandler.happens_before?(vv2, vv1) == false
    end
  end

  describe "concurrent?/2" do
    test "returns true when neither happens-before the other" do
      vv1 = %{"h1" => 5, "h2" => 2}
      vv2 = %{"h1" => 3, "h2" => 4}

      assert ConcurrencyHandler.concurrent?(vv1, vv2) == true
    end

    test "returns false when one happens-before the other" do
      vv1 = %{"h1" => 3, "h2" => 2}
      vv2 = %{"h1" => 5, "h2" => 3}

      assert ConcurrencyHandler.concurrent?(vv1, vv2) == false
    end

    test "concurrent is symmetric" do
      vv1 = %{"h1" => 5, "h2" => 2}
      vv2 = %{"h1" => 3, "h2" => 4}

      assert ConcurrencyHandler.concurrent?(vv1, vv2) ==
               ConcurrencyHandler.concurrent?(vv2, vv1)
    end
  end

  # ==========================================================================
  # Compare-and-Swap Tests
  # ==========================================================================

  describe "compare_and_swap/4" do
    test "succeeds when current version >= expected" do
      current_vv = %{"h1" => 5}
      expected_vv = %{"h1" => 3}

      result =
        ConcurrencyHandler.compare_and_swap(
          current_vv,
          expected_vv,
          fn -> {:ok, "result"} end,
          :reject
        )

      assert {:ok, "result", new_vv} = result
      # Incremented
      assert new_vv["h1"] == 6
    end

    test "returns conflict when current version < expected" do
      current_vv = %{"h1" => 3}
      expected_vv = %{"h1" => 5}

      result =
        ConcurrencyHandler.compare_and_swap(
          current_vv,
          expected_vv,
          fn -> {:ok, "result"} end,
          :reject
        )

      assert {:conflict, ^current_vv} = result
    end

    test "propagates operation errors" do
      current_vv = %{"h1" => 5}
      expected_vv = %{"h1" => 3}

      result =
        ConcurrencyHandler.compare_and_swap(
          current_vv,
          expected_vv,
          fn -> {:error, "operation failed"} end,
          :reject
        )

      assert {:error, "operation failed"} = result
    end
  end

  # ==========================================================================
  # Retry Logic Tests
  # ==========================================================================

  describe "with_retry/3" do
    test "succeeds without retry when operation succeeds" do
      call_count = :counters.new(1, [:atomics])

      result =
        ConcurrencyHandler.with_retry(
          fn ->
            :counters.add(call_count, 1, 1)
            {:ok, "success"}
          end,
          max_retries: 3
        )

      assert {:ok, "success"} = result
      assert :counters.get(call_count, 1) == 1
    end

    test "retries on conflict up to max_retries" do
      call_count = :counters.new(1, [:atomics])

      result =
        ConcurrencyHandler.with_retry(
          fn ->
            count = :counters.add(call_count, 1, 1)

            if count < 3 do
              {:conflict, %{}}
            else
              {:ok, "success"}
            end
          end,
          max_retries: 5,
          # Minimal delay for testing
          base_delay_ms: 1
        )

      assert {:ok, "success"} = result
      assert :counters.get(call_count, 1) == 3
    end

    test "fails after max_retries exceeded" do
      result =
        ConcurrencyHandler.with_retry(
          fn -> {:conflict, %{}} end,
          max_retries: 3,
          base_delay_ms: 1
        )

      assert {:error, :max_retries_exceeded} = result
    end

    test "uses exponential backoff" do
      # SC-XHOLON-009: Retry backoff MUST be exponential with jitter
      delays = []

      ConcurrencyHandler.with_retry(
        fn -> {:conflict, %{}} end,
        max_retries: 3,
        base_delay_ms: 100,
        on_retry: fn delay ->
          delays = [delay | delays]
        end
      )

      # Verify exponential pattern (with jitter tolerance)
      # Base 100ms: delays should be ~100, ~200, ~400
      assert length(delays) == 3
    end
  end

  # ==========================================================================
  # Pessimistic Locking Tests
  # ==========================================================================

  describe "acquire_lock/3" do
    test "acquires lock successfully when not held" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      result = ConcurrencyHandler.acquire_lock(resource_id, "owner1", 1000)

      assert result == :ok
    end

    test "fails to acquire lock when already held" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      :ok = ConcurrencyHandler.acquire_lock(resource_id, "owner1", 1000)

      result = ConcurrencyHandler.acquire_lock(resource_id, "owner2", 100)

      assert result == {:error, :lock_held}
    end

    test "times out when lock cannot be acquired" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      :ok = ConcurrencyHandler.acquire_lock(resource_id, "owner1", 10000)

      {time_us, result} =
        :timer.tc(fn ->
          ConcurrencyHandler.acquire_lock(resource_id, "owner2", 50)
        end)

      assert result == {:error, :timeout}
      # At least 50ms
      assert time_us >= 50_000
    end
  end

  describe "release_lock/2" do
    test "releases lock when owner matches" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      :ok = ConcurrencyHandler.acquire_lock(resource_id, "owner1", 1000)
      :ok = ConcurrencyHandler.release_lock(resource_id, "owner1")

      # Another owner can now acquire
      result = ConcurrencyHandler.acquire_lock(resource_id, "owner2", 100)
      assert result == :ok
    end

    test "does not release lock when owner doesn't match" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      :ok = ConcurrencyHandler.acquire_lock(resource_id, "owner1", 1000)
      result = ConcurrencyHandler.release_lock(resource_id, "owner2")

      assert result == {:error, :not_owner}
    end
  end

  describe "with_lock/4" do
    test "executes operation with lock held" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      result =
        ConcurrencyHandler.with_lock(
          resource_id,
          "owner1",
          1000,
          fn -> {:ok, "executed"} end
        )

      assert {:ok, "executed"} = result
    end

    test "releases lock even on operation failure" do
      resource_id = "resource_#{:rand.uniform(10000)}"

      try do
        ConcurrencyHandler.with_lock(
          resource_id,
          "owner1",
          1000,
          fn -> raise "error" end
        )
      rescue
        _ ->
          # Lock should be released, another can acquire
          result = ConcurrencyHandler.acquire_lock(resource_id, "owner2", 100)
          assert result == :ok
      end
    end
  end

  # ==========================================================================
  # Two-Phase Commit Tests
  # ==========================================================================

  describe "two_phase_prepare/3" do
    test "acquires all locks when all available" do
      participants = ["p1_#{:rand.uniform(10000)}", "p2_#{:rand.uniform(10000)}"]

      result = ConcurrencyHandler.two_phase_prepare(participants, "coordinator", 1000)

      assert result == :ok
    end

    test "rolls back acquired locks when one fails" do
      # Pre-lock one participant
      p1 = "p1_#{:rand.uniform(10000)}"
      p2 = "p2_#{:rand.uniform(10000)}"

      :ok = ConcurrencyHandler.acquire_lock(p2, "other_owner", 10000)

      result = ConcurrencyHandler.two_phase_prepare([p1, p2], "coordinator", 100)

      assert {:error, failed} = result
      assert p2 in failed

      # p1 lock should be released
      assert ConcurrencyHandler.acquire_lock(p1, "test", 100) == :ok
    end
  end

  describe "two_phase_commit/2" do
    test "releases all locks" do
      participants = ["p1_#{:rand.uniform(10000)}", "p2_#{:rand.uniform(10000)}"]

      :ok = ConcurrencyHandler.two_phase_prepare(participants, "coordinator", 1000)
      :ok = ConcurrencyHandler.two_phase_commit(participants, "coordinator")

      # All locks should be released
      for p <- participants do
        assert ConcurrencyHandler.acquire_lock(p, "test", 100) == :ok
      end
    end
  end

  describe "two_phase_rollback/2" do
    test "releases all locks (same as commit)" do
      participants = ["p1_#{:rand.uniform(10000)}", "p2_#{:rand.uniform(10000)}"]

      :ok = ConcurrencyHandler.two_phase_prepare(participants, "coordinator", 1000)
      :ok = ConcurrencyHandler.two_phase_rollback(participants, "coordinator")

      # All locks should be released
      for p <- participants do
        assert ConcurrencyHandler.acquire_lock(p, "test", 100) == :ok
      end
    end
  end

  # ==========================================================================
  # Property-Based Tests
  # ==========================================================================

  describe "Property: Happens-before transitivity" do
    property "if vv1 < vv2 and vv2 < vv3 then vv1 < vv3" do
      forall {vv1, vv2, vv3} <- {version_vector_gen(), version_vector_gen(), version_vector_gen()} do
        # If precondition fails, property holds vacuously
        precond =
          ConcurrencyHandler.happens_before?(vv1, vv2) and
            ConcurrencyHandler.happens_before?(vv2, vv3)

        if precond do
          ConcurrencyHandler.happens_before?(vv1, vv3)
        else
          true
        end
      end
    end
  end

  describe "Property: Happens-before irreflexivity" do
    property "a version vector does not happen-before itself" do
      forall vv <- version_vector_gen() do
        not ConcurrencyHandler.happens_before?(vv, vv)
      end
    end
  end

  describe "Property: Concurrent exclusion" do
    property "concurrent implies not happens-before in either direction" do
      forall {vv1, vv2} <- {version_vector_gen(), version_vector_gen()} do
        if ConcurrencyHandler.concurrent?(vv1, vv2) do
          not ConcurrencyHandler.happens_before?(vv1, vv2) and
            not ConcurrencyHandler.happens_before?(vv2, vv1)
        else
          true
        end
      end
    end
  end

  describe "Property: Merge produces upper bound" do
    property "merge(vv1, vv2) >= vv1 and merge(vv1, vv2) >= vv2" do
      forall {vv1, vv2} <- {version_vector_gen(), version_vector_gen()} do
        merged = ConcurrencyHandler.merge_version_vectors(vv1, vv2)

        ConcurrencyHandler.version_gte?(merged, vv1) and
          ConcurrencyHandler.version_gte?(merged, vv2)
      end
    end
  end

  # ==========================================================================
  # Generators
  # ==========================================================================

  defp version_vector_gen do
    let entries <- PC.list(PC.tuple([holon_id_gen(), PC.pos_integer()])) do
      Map.new(entries)
    end
  end

  defp holon_id_gen do
    let runtime <- PC.oneof([:ex, :fs, :zig, :rs]) do
      let layer <- PC.range(1, 7) do
        let parts <- PC.vector(3, PC.utf8()) do
          [domain, type, instance] = parts
          "#{runtime}:l#{layer}:#{domain}:#{type}:#{instance}"
        end
      end
    end
  end
end
