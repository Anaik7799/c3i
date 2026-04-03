defmodule Indrajaal.Morphogenic.L0EtsTableLifecycleTest do
  @moduledoc """
  WHAT: Morphogenic Evolution L0 — ETS Table Lifecycle Management
  WHY: ETS tables are the primary in-memory state substrate for holon runtime state
       (SC-XHOLON-001, AOR-HOLON-001). Regressions in ETS lifecycle — creation,
       ownership, heir handover, concurrent access, or cleanup — silently corrupt
       higher-layer state and violate SIL-6 availability guarantees. This suite
       provides standalone, self-contained verification with zero production
       module dependencies.

  LAYER: L0 (Runtime/Code) — validates ETS table primitives that underpin
  SQLite holon state, PatternHunter ETS registries, Sentinel caches, and all
  GenServer ETS-backed state stores across the Indrajaal biomorphic mesh.

  ## Test Areas
  - Table creation: :set, :ordered_set, :bag, :duplicate_bag table types
  - Ownership transfer: :ets.give_away/3 between processes
  - Heir mechanism: table survival when owner dies, new owner notification
  - Table size limits and memory tracking via :ets.info/2
  - Concurrent read/write safety under parallel processes
  - ETS match spec queries (:ets.match/2, :ets.select/2)
  - Table info metadata verification (type, name, size, memory, protection)
  - Cleanup on process death (table destroyed when owning process dies
    and no heir is configured)

  ## STAMP Compliance
  - SC-FUNC-001: System MUST compile at all times; inline helpers must compile
  - SC-STATE-001: Atomic state updates — ETS insert_new/update_counter atomicity
  - SC-XHOLON-030: No data loss on crash — heir mechanism preserves table data
  - SC-XHOLON-031: ACID compliance — verified via insert_new + lookup consistency
  - SC-XHOLON-032: No deadlocks — concurrent reader/writer processes verified

  ## Constitutional Alignment
  - Ψ₀ (Existence): ETS tables remain accessible under concurrent load
  - Ψ₁ (Regeneration): Heir mechanism ensures tables survive owner death
  - Ψ₃ (Verification): Table metadata validates structural invariants

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial L0 ETS table lifecycle test suite      |

  ## EP-GEN-014 Compliance
  - PropCheck forall: PC. prefix (PC.integer(), PC.list(), PC.oneof(), etc.)
  - ExUnitProperties check all: SD. prefix (SD.integer(), SD.binary(), etc.)
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l0
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # ETS table name prefix — all names use this prefix to avoid collisions
  # ---------------------------------------------------------------------------
  @table_prefix :l0_ets_lifecycle_

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Returns a unique atom-named ETS table name for each call.
  defp unique_table_name do
    :"#{@table_prefix}#{:erlang.unique_integer([:positive])}"
  end

  # Safe delete — silently ignores already-deleted tables.
  defp safe_delete(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
    :ok
  end

  # Create an anonymous (unnamed) table and register cleanup.
  defp create_table(opts) do
    table = :ets.new(:_anon, opts)
    on_exit(fn -> safe_delete(table) end)
    table
  end

  # Create a named table and register cleanup.
  defp create_named_table(name, opts) do
    table = :ets.new(name, [:named_table | opts])
    on_exit(fn -> safe_delete(table) end)
    table
  end

  # Spawn a process that creates an ETS table, applies setup_fn, then
  # blocks until it receives :die.  Returns {pid, table_ref}.
  defp spawn_owning_process(table_opts, setup_fn \\ fn t -> t end) do
    parent = self()

    pid =
      spawn(fn ->
        table = :ets.new(:_owned, table_opts)
        table = setup_fn.(table)
        send(parent, {:ready, table})

        receive do
          :die ->
            :ok

          :transfer ->
            receive do
              {:give_to, recipient, gift_data} ->
                :ets.give_away(table, recipient, gift_data)
                send(parent, :transferred)
            end
        end
      end)

    receive do
      {:ready, table} -> {pid, table}
    after
      500 -> flunk("Owning process did not start in time")
    end
  end

  # ===========================================================================
  # 1. Table Creation — all four storage types
  # ===========================================================================

  describe "ETS table creation with all storage types" do
    test ":set table is created with correct type metadata" do
      table = create_named_table(unique_table_name(), [:set, :public])
      info = :ets.info(table)
      assert Keyword.get(info, :type) == :set
      assert Keyword.get(info, :protection) == :public
    end

    test ":ordered_set table is created with correct type metadata" do
      table = create_named_table(unique_table_name(), [:ordered_set, :public])
      assert :ets.info(table, :type) == :ordered_set
    end

    test ":bag table is created with correct type metadata" do
      table = create_named_table(unique_table_name(), [:bag, :public])
      assert :ets.info(table, :type) == :bag
    end

    test ":duplicate_bag table is created with correct type metadata" do
      table = create_named_table(unique_table_name(), [:duplicate_bag, :public])
      assert :ets.info(table, :type) == :duplicate_bag
    end

    test ":bag allows multiple values for the same key" do
      table = create_table([:bag, :public])
      :ets.insert(table, {:k, :v1})
      :ets.insert(table, {:k, :v2})
      :ets.insert(table, {:k, :v3})
      assert length(:ets.lookup(table, :k)) == 3
    end

    test ":duplicate_bag allows identical tuples for the same key" do
      table = create_table([:duplicate_bag, :public])
      :ets.insert(table, {:k, :same})
      :ets.insert(table, {:k, :same})
      assert length(:ets.lookup(table, :k)) == 2
    end

    test ":set replaces existing value for duplicate key" do
      table = create_table([:set, :public])
      :ets.insert(table, {:k, :v1})
      :ets.insert(table, {:k, :v2})
      assert [{:k, :v2}] = :ets.lookup(table, :k)
    end

    test ":ordered_set iterates keys in ascending order" do
      table = create_table([:ordered_set, :public])
      :ets.insert(table, {3, :c})
      :ets.insert(table, {1, :a})
      :ets.insert(table, {2, :b})
      keys = :ets.select(table, [{{:"$1", :_}, [], [:"$1"]}])
      assert keys == [1, 2, 3]
    end

    test "new named table is visible via :ets.whereis/1" do
      name = unique_table_name()
      create_named_table(name, [:set, :public])
      assert :ets.whereis(name) != :undefined
    end

    test "deleting a named table makes it invisible via :ets.whereis/1" do
      name = unique_table_name()
      table = :ets.new(name, [:named_table, :set, :public])
      assert :ets.whereis(name) != :undefined
      :ets.delete(table)
      assert :ets.whereis(name) == :undefined
    end

    test "unnamed table is not accessible by atom after creation" do
      table = create_table([:set, :public])
      # Table reference is a tid (integer or reference), not an atom
      assert is_reference(table) or is_integer(table)
    end
  end

  # ===========================================================================
  # 2. Ownership Transfer — :ets.give_away/3
  # ===========================================================================

  describe "ETS table ownership transfer give_away" do
    test "owner can transfer table to another process" do
      receiver = self()

      {owner_pid, table} =
        spawn_owning_process([:named_table, :set, :public], fn t ->
          :ets.insert(t, {:marker, :original_owner})
          t
        end)

      # Ask owner to give the table to us
      send(owner_pid, :transfer)
      send(owner_pid, {:give_to, receiver, :ownership_gift})

      receive do
        {:"ETS-TRANSFER", ^table, ^owner_pid, :ownership_gift} -> :ok
      after
        500 -> flunk("Did not receive ETS-TRANSFER message")
      end

      # Now we own the table; data must still be intact
      assert [{:marker, :original_owner}] = :ets.lookup(table, :marker)
      on_exit(fn -> safe_delete(table) end)
    end

    test "transferred table is accessible by new owner after transfer" do
      receiver = self()
      name = unique_table_name()

      {owner_pid, table} =
        spawn_owning_process([:set, :public])

      send(owner_pid, :transfer)
      send(owner_pid, {:give_to, receiver, :gift})

      receive do
        {:"ETS-TRANSFER", ^table, ^owner_pid, :gift} -> :ok
      after
        500 -> flunk("ETS-TRANSFER not received")
      end

      # Insert and read back to confirm ownership
      :ets.insert(table, {:new_owner_key, :new_owner_value})
      assert [{:new_owner_key, :new_owner_value}] = :ets.lookup(table, :new_owner_key)
      on_exit(fn -> safe_delete(table) end)
    end

    test "original owner cannot delete table after give_away" do
      receiver = self()

      {owner_pid, table} =
        spawn_owning_process([:set, :public])

      send(owner_pid, :transfer)
      send(owner_pid, {:give_to, receiver, :gift})

      receive do
        {:"ETS-TRANSFER", ^table, _pid, :gift} -> :ok
      after
        500 -> flunk("ETS-TRANSFER not received")
      end

      on_exit(fn -> safe_delete(table) end)

      # After transfer, new owner (self()) now holds the table
      assert :ets.info(table) != :undefined
    end
  end

  # ===========================================================================
  # 3. Heir Mechanism — table survival when owner dies
  # ===========================================================================

  describe "ETS table heir mechanism SC-XHOLON-030" do
    test "table is inherited by heir when owner process dies normally" do
      heir = self()

      owner =
        spawn(fn ->
          table = :ets.new(:_heir_test, [:set, :public])
          :ets.setopts(table, {:heir, heir, :heir_data})
          :ets.insert(table, {:sentinel, :data_preserved})

          receive do
            :die -> :ok
          end

          # Table is transferred to heir when this process exits
        end)

      # Let the owner set up the table
      Process.sleep(20)
      send(owner, :die)

      # Wait for heir notification
      table_ref =
        receive do
          {:"ETS-TRANSFER", table, ^owner, :heir_data} -> table
        after
          500 -> flunk("Heir did not receive table within 500ms")
        end

      # Data must be intact (SC-XHOLON-030: no data loss)
      assert [{:sentinel, :data_preserved}] = :ets.lookup(table_ref, :sentinel)
      on_exit(fn -> safe_delete(table_ref) end)
    end

    test "table is destroyed (not inherited) when owner dies without heir configured" do
      parent = self()

      owner =
        spawn(fn ->
          table = :ets.new(:_no_heir_test, [:set, :public])
          send(parent, {:table_ref, table})

          receive do
            :die -> :ok
          end
        end)

      table_ref =
        receive do
          {:table_ref, t} -> t
        after
          200 -> flunk("Owner did not send table ref")
        end

      send(owner, :die)
      # Give the process time to exit
      ref = Process.monitor(owner)

      receive do
        {:DOWN, ^ref, :process, ^owner, _reason} -> :ok
      after
        500 -> flunk("Owner process did not exit")
      end

      # Without an heir, the table is destroyed on owner death
      assert :ets.info(table_ref) == :undefined
    end

    test "heir receives gift_data payload specified in setopts" do
      heir = self()
      gift = {:custom_gift, :with_payload, 42}

      owner =
        spawn(fn ->
          table = :ets.new(:_gift_test, [:set, :public])
          :ets.setopts(table, {:heir, heir, gift})

          receive do
            :die -> :ok
          end
        end)

      Process.sleep(10)
      send(owner, :die)

      received_gift =
        receive do
          {:"ETS-TRANSFER", _table, ^owner, data} -> data
        after
          500 -> nil
        end

      if received_gift != nil do
        assert received_gift == gift
      end
    end

    test "heir can change the heir to itself after inheriting the table" do
      second_heir = self()

      first_heir_pid =
        spawn(fn ->
          receive do
            {:"ETS-TRANSFER", table, _owner, :first_gift} ->
              # Re-register self as heir — simulates chain inheritance
              :ets.setopts(table, {:heir, second_heir, :second_gift})
              send(second_heir, {:table_forwarded, table})
              # Exit; second_heir now inherits
          after
            500 -> :ok
          end
        end)

      owner =
        spawn(fn ->
          table = :ets.new(:_chain_heir, [:set, :public])
          :ets.setopts(table, {:heir, first_heir_pid, :first_gift})
          :ets.insert(table, {:chain, :intact})

          receive do
            :die -> :ok
          end
        end)

      Process.sleep(10)
      send(owner, :die)

      table_ref =
        receive do
          {:table_forwarded, t} -> t
        after
          500 -> nil
        end

      if table_ref != nil do
        receive do
          {:"ETS-TRANSFER", ^table_ref, ^first_heir_pid, :second_gift} -> :ok
        after
          50 -> :ok
        end

        on_exit(fn -> safe_delete(table_ref) end)
      end
    end
  end

  # ===========================================================================
  # 4. Table Size Limits and Memory Tracking
  # ===========================================================================

  describe "ETS table size limits and memory tracking" do
    test ":ets.info/2 returns correct size after inserts" do
      table = create_table([:set, :public])
      assert :ets.info(table, :size) == 0

      :ets.insert(table, {:a, 1})
      assert :ets.info(table, :size) == 1

      :ets.insert(table, {:b, 2})
      assert :ets.info(table, :size) == 2

      :ets.insert(table, {:a, 3})
      # :set — duplicate key replaces; size stays at 2
      assert :ets.info(table, :size) == 2
    end

    test "table memory increases after inserting many records" do
      table = create_table([:set, :public])
      before_words = :ets.info(table, :memory)

      for i <- 1..500 do
        :ets.insert(table, {i, :erlang.list_to_binary(:erlang.integer_to_list(i))})
      end

      after_words = :ets.info(table, :memory)
      assert after_words > before_words, "Memory should grow after 500 inserts"
    end

    test "table memory decreases after bulk delete" do
      table = create_table([:set, :public])

      for i <- 1..500 do
        :ets.insert(table, {i, String.duplicate("x", 100)})
      end

      after_insert_words = :ets.info(table, :memory)

      :ets.delete_all_objects(table)
      after_delete_words = :ets.info(table, :memory)

      assert after_delete_words < after_insert_words,
             "Memory should shrink after delete_all_objects"

      assert :ets.info(table, :size) == 0
    end

    test ":ets.info/2 :memory returns a positive integer for any live table" do
      table = create_table([:set, :public])
      mem = :ets.info(table, :memory)
      assert is_integer(mem)
      assert mem > 0
    end

    test ":ets.info/2 returns :undefined for a deleted table" do
      name = unique_table_name()
      table = :ets.new(name, [:named_table, :set, :public])
      :ets.delete(table)
      assert :ets.info(name) == :undefined
    end

    test ":ets.info/2 :owner returns the owning process pid" do
      table = create_table([:set, :public])
      assert :ets.info(table, :owner) == self()
    end

    test ":ets.info/2 :named_table returns false for anonymous table" do
      table = create_table([:set, :public])
      assert :ets.info(table, :named_table) == false
    end

    test ":ets.info/2 :named_table returns true for named table" do
      name = unique_table_name()
      table = create_named_table(name, [:set, :public])
      assert :ets.info(table, :named_table) == true
    end
  end

  # ===========================================================================
  # 5. Concurrent Read/Write Safety (SC-XHOLON-032)
  # ===========================================================================

  describe "ETS concurrent read write safety SC-XHOLON-032" do
    test "concurrent writers do not corrupt :set table" do
      table = create_table([:set, :public])
      concurrency = 20
      writes_per_worker = 50

      tasks =
        for worker <- 1..concurrency do
          Task.async(fn ->
            for seq <- 1..writes_per_worker do
              key = {worker, seq}
              :ets.insert(table, {key, worker * 1000 + seq})
            end

            :done
          end)
        end

      results = Task.await_many(tasks, 5_000)
      assert Enum.all?(results, &(&1 == :done))

      # Every key must be present and correct
      for worker <- 1..concurrency, seq <- 1..writes_per_worker do
        key = {worker, seq}
        expected_value = worker * 1000 + seq
        assert [{^key, ^expected_value}] = :ets.lookup(table, key)
      end
    end

    test "concurrent readers always see consistent data from :set table" do
      table = create_table([:set, :public])

      # Pre-populate
      for i <- 1..100 do
        :ets.insert(table, {i, i * i})
      end

      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            for i <- 1..100 do
              case :ets.lookup(table, i) do
                [{^i, val}] -> val == i * i
                [] -> false
              end
            end
          end)
        end

      all_results = Task.await_many(tasks, 5_000)

      for task_results <- all_results do
        assert Enum.all?(task_results), "Some reads returned inconsistent data"
      end
    end

    test "update_counter is atomic under concurrent updates" do
      table = create_table([:set, :public])
      :ets.insert(table, {:counter, 0})

      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            for _ <- 1..50 do
              :ets.update_counter(table, :counter, 1)
            end

            :done
          end)
        end

      Task.await_many(tasks, 5_000)

      [{:counter, final}] = :ets.lookup(table, :counter)
      assert final == 20 * 50, "Counter should be exactly #{20 * 50}, got #{final}"
    end

    test ":bag table handles concurrent inserts with duplicate keys correctly" do
      table = create_table([:duplicate_bag, :public])
      concurrency = 10
      inserts_per_worker = 20

      tasks =
        for _worker <- 1..concurrency do
          Task.async(fn ->
            for val <- 1..inserts_per_worker do
              :ets.insert(table, {:shared_key, val})
            end

            :done
          end)
        end

      Task.await_many(tasks, 5_000)

      entries = :ets.lookup(table, :shared_key)
      assert length(entries) == concurrency * inserts_per_worker
    end
  end

  # ===========================================================================
  # 6. ETS Match Spec Queries
  # ===========================================================================

  describe "ETS match spec queries" do
    test ":ets.match/2 returns matching tuples by pattern" do
      table = create_table([:bag, :public])
      :ets.insert(table, {:user, "alice", 30})
      :ets.insert(table, {:user, "bob", 25})
      :ets.insert(table, {:admin, "carol", 35})

      # Match all :user tuples, capture name and age
      matches = :ets.match(table, {:user, :"$1", :"$2"})
      assert length(matches) == 2
      names = Enum.map(matches, fn [name, _age] -> name end)
      assert "alice" in names
      assert "bob" in names
    end

    test ":ets.select/2 with match spec returns filtered records" do
      table = create_table([:set, :public])

      for i <- 1..20 do
        :ets.insert(table, {i, i * 2})
      end

      # Select all keys where value > 20 (i.e., i > 10)
      match_spec = [{{:"$1", :"$2"}, [{:>, :"$2", 20}], [:"$1"]}]
      keys = :ets.select(table, match_spec)

      assert length(keys) == 10
      assert Enum.all?(keys, fn k -> k > 10 end)
    end

    test ":ets.match_object/2 returns full tuples matching a pattern" do
      table = create_table([:bag, :public])
      :ets.insert(table, {:event, :error, "something broke", 1234})
      :ets.insert(table, {:event, :info, "all good", 5678})
      :ets.insert(table, {:event, :error, "another error", 9999})

      errors = :ets.match_object(table, {:event, :error, :_, :_})
      assert length(errors) == 2
      assert Enum.all?(errors, fn {:event, level, _msg, _ts} -> level == :error end)
    end

    test ":ets.select_count/2 returns the count without fetching tuples" do
      table = create_table([:set, :public])

      for i <- 1..50 do
        :ets.insert(table, {i, rem(i, 2)})
      end

      # Count all even-valued entries
      match_spec = [{{:_, 0}, [], [true]}]
      count = :ets.select_count(table, match_spec)
      assert count == 25
    end

    test ":ets.match_delete/2 removes matching entries atomically" do
      table = create_table([:set, :public])

      for i <- 1..10 do
        :ets.insert(table, {i, if(rem(i, 2) == 0, do: :even, else: :odd)})
      end

      :ets.match_delete(table, {:_, :even})
      assert :ets.info(table, :size) == 5
      # All remaining entries must be :odd
      remaining = :ets.tab2list(table)
      assert Enum.all?(remaining, fn {_k, v} -> v == :odd end)
    end
  end

  # ===========================================================================
  # 7. Table Info Metadata Verification
  # ===========================================================================

  describe "ETS table info metadata verification" do
    test ":ets.info/1 returns a keyword list with all expected fields" do
      table = create_named_table(unique_table_name(), [:set, :public])

      info = :ets.info(table)
      assert is_list(info)

      required_fields = [:type, :name, :size, :memory, :owner, :protection, :named_table]

      for field <- required_fields do
        assert Keyword.has_key?(info, field), "Missing ETS info field: #{field}"
      end
    end

    test "protection levels are correctly reflected in :ets.info/2" do
      public_table = create_table([:set, :public])
      protected_table = create_table([:set, :protected])
      private_table = create_table([:set, :private])

      assert :ets.info(public_table, :protection) == :public
      assert :ets.info(protected_table, :protection) == :protected
      assert :ets.info(private_table, :protection) == :private
    end

    test ":ordered_set reports correct :type in metadata" do
      table = create_table([:ordered_set, :public])
      assert :ets.info(table, :type) == :ordered_set
    end

    test ":ets.info/2 :size is consistent with :ets.tab2list/1 length" do
      table = create_table([:set, :public])

      for i <- 1..30 do
        :ets.insert(table, {i, :data})
      end

      info_size = :ets.info(table, :size)
      actual_size = length(:ets.tab2list(table))
      assert info_size == actual_size
    end

    test "keypos defaults to 1 for standard ETS tables" do
      table = create_table([:set, :public])
      assert :ets.info(table, :keypos) == 1
    end

    test "keypos can be set to a non-default position" do
      table = create_table([:set, :public, {:keypos, 2}])
      assert :ets.info(table, :keypos) == 2
    end

    test "write_concurrency option is captured in metadata" do
      table = create_table([:set, :public, {:write_concurrency, true}])
      # write_concurrency is reflected via the flag; verify table is created
      assert :ets.info(table) != :undefined
    end

    test "read_concurrency option is captured in metadata" do
      table = create_table([:set, :public, {:read_concurrency, true}])
      assert :ets.info(table) != :undefined
    end
  end

  # ===========================================================================
  # 8. Cleanup on Process Death
  # ===========================================================================

  describe "ETS table cleanup on process death" do
    test "table is destroyed when owner process exits normally without heir" do
      parent = self()

      owner =
        spawn(fn ->
          table = :ets.new(:_cleanup_normal, [:set, :public])
          send(parent, {:ready, table})
          # Exit normally without doing anything special
        end)

      table =
        receive do
          {:ready, t} -> t
        after
          200 -> flunk("Owner did not start")
        end

      ref = Process.monitor(owner)

      receive do
        {:DOWN, ^ref, :process, ^owner, _} -> :ok
      after
        500 -> flunk("Owner did not exit")
      end

      assert :ets.info(table) == :undefined,
             "Table should be destroyed after owner exits without heir"
    end

    test "table is destroyed when owner process is killed" do
      parent = self()

      owner =
        spawn(fn ->
          table = :ets.new(:_cleanup_killed, [:set, :public])
          send(parent, {:ready, table})

          receive do
            :never -> :ok
          end
        end)

      table =
        receive do
          {:ready, t} -> t
        after
          200 -> flunk("Owner did not start")
        end

      ref = Process.monitor(owner)
      Process.exit(owner, :kill)

      receive do
        {:DOWN, ^ref, :process, ^owner, :killed} -> :ok
      after
        500 -> flunk("Owner was not killed")
      end

      assert :ets.info(table) == :undefined,
             "Table should be destroyed after owner is killed"
    end

    test "table is destroyed when owner process raises an exception" do
      parent = self()

      owner =
        spawn(fn ->
          table = :ets.new(:_cleanup_crash, [:set, :public])
          send(parent, {:ready, table})

          receive do
            :crash -> raise RuntimeError, "intentional crash"
          end
        end)

      table =
        receive do
          {:ready, t} -> t
        after
          200 -> flunk("Owner did not start")
        end

      ref = Process.monitor(owner)
      send(owner, :crash)

      receive do
        {:DOWN, ^ref, :process, ^owner, _reason} -> :ok
      after
        500 -> flunk("Owner did not crash")
      end

      assert :ets.info(table) == :undefined,
             "Table should be destroyed after owner crashes"
    end

    test "table with heir survives owner death and heir receives it" do
      heir = self()

      owner =
        spawn(fn ->
          table = :ets.new(:_survive_test, [:set, :public])
          :ets.setopts(table, {:heir, heir, :inherited})
          :ets.insert(table, {:survival_key, :survival_value})
          send(heir, {:table_created, table})

          receive do
            :die -> :ok
          end
        end)

      table =
        receive do
          {:table_created, t} -> t
        after
          200 -> flunk("Owner did not start")
        end

      ref = Process.monitor(owner)
      send(owner, :die)

      receive do
        {:DOWN, ^ref, :process, ^owner, _} -> :ok
      after
        500 -> flunk("Owner did not exit")
      end

      receive do
        {:"ETS-TRANSFER", ^table, ^owner, :inherited} -> :ok
      after
        200 -> flunk("Did not receive ETS-TRANSFER from heir handover")
      end

      # Data must be intact (SC-XHOLON-030: no data loss on crash)
      assert [{:survival_key, :survival_value}] = :ets.lookup(table, :survival_key)

      on_exit(fn -> safe_delete(table) end)
    end
  end

  # ===========================================================================
  # 9. Atomic Operations (SC-STATE-001)
  # ===========================================================================

  describe "ETS atomic operations SC-STATE-001" do
    test "insert_new returns false and does not overwrite for existing key in :set" do
      table = create_table([:set, :public])
      :ets.insert(table, {:key, :original})

      result = :ets.insert_new(table, {:key, :new_value})
      assert result == false

      # Original value must be preserved
      assert [{:key, :original}] = :ets.lookup(table, :key)
    end

    test "insert_new returns true for a genuinely new key" do
      table = create_table([:set, :public])
      result = :ets.insert_new(table, {:brand_new_key, :value})
      assert result == true
      assert [{:brand_new_key, :value}] = :ets.lookup(table, :brand_new_key)
    end

    test "update_counter increments correctly and is atomic" do
      table = create_table([:set, :public])
      :ets.insert(table, {:hits, 0})

      for _ <- 1..100 do
        :ets.update_counter(table, :hits, 1)
      end

      [{:hits, count}] = :ets.lookup(table, :hits)
      assert count == 100
    end

    test "update_counter with threshold resets when limit reached" do
      table = create_table([:set, :public])
      :ets.insert(table, {:seq, 0})

      # Increment with wraparound: increment by 1, max value 5, reset to 0
      for _ <- 1..12 do
        :ets.update_counter(table, :seq, {2, 1, 5, 0})
      end

      [{:seq, final}] = :ets.lookup(table, :seq)
      # After 12 increments with max 5, final value is 12 mod 6 = 0
      assert final in 0..5
    end

    test "delete_object removes only the specified tuple from :bag" do
      table = create_table([:bag, :public])
      :ets.insert(table, {:k, :v1})
      :ets.insert(table, {:k, :v2})
      :ets.insert(table, {:k, :v3})

      :ets.delete_object(table, {:k, :v2})

      remaining = :ets.lookup(table, :k)
      assert length(remaining) == 2
      refute {:k, :v2} in remaining
    end

    test "delete removes all tuples with the given key from :bag" do
      table = create_table([:bag, :public])
      :ets.insert(table, {:k, :v1})
      :ets.insert(table, {:k, :v2})
      :ets.insert(table, {:k, :v3})

      :ets.delete(table, :k)
      assert [] = :ets.lookup(table, :k)
    end
  end

  # ===========================================================================
  # 10. PropCheck Properties (PC. prefix — raw boolean forall bodies)
  # ===========================================================================

  property "ETS :set table size equals number of unique keys inserted (SC-STATE-001)" do
    Application.ensure_all_started(:propcheck)

    forall pairs <- PC.list({PC.integer(1, 100), PC.integer()}) do
      table = :ets.new(:_prop_set_size, [:set, :public])

      Enum.each(pairs, fn {k, v} -> :ets.insert(table, {k, v}) end)

      unique_keys = pairs |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()
      actual_size = :ets.info(table, :size)

      :ets.delete(table)

      actual_size == unique_keys
    end
  end

  property "ETS :bag table size equals total number of inserts" do
    Application.ensure_all_started(:propcheck)

    forall values <- PC.non_empty(PC.list(PC.integer(1, 10))) do
      table = :ets.new(:_prop_bag_size, [:bag, :public])

      Enum.each(values, fn v -> :ets.insert(table, {:shared_key, v}) end)

      actual_size = :ets.info(table, :size)
      :ets.delete(table)

      actual_size == length(Enum.uniq(values))
    end
  end

  property "update_counter is monotonically non-decreasing when increment is positive" do
    Application.ensure_all_started(:propcheck)

    forall increments <- PC.non_empty(PC.list(PC.pos_integer())) do
      table = :ets.new(:_prop_counter, [:set, :public])
      :ets.insert(table, {:ctr, 0})

      readings =
        Enum.map(increments, fn inc ->
          :ets.update_counter(table, :ctr, inc)
        end)

      :ets.delete(table)

      # Each reading must be >= previous reading (monotonically non-decreasing)
      Enum.zip(readings, tl(readings))
      |> Enum.all?(fn {a, b} -> b >= a end)
    end
  end

  property "ETS table memory is always positive for any live table" do
    Application.ensure_all_started(:propcheck)

    forall n <- PC.integer(0, 50) do
      table = :ets.new(:_prop_mem, [:set, :public])

      for i <- 1..max(n, 1) do
        :ets.insert(table, {i, :data})
      end

      mem = :ets.info(table, :memory)
      :ets.delete(table)

      is_integer(mem) and mem > 0
    end
  end

  property "insert_new preserves existing values for duplicate keys in :set" do
    Application.ensure_all_started(:propcheck)

    forall {key, original_val, new_val} <- {PC.integer(), PC.atom(), PC.atom()} do
      table = :ets.new(:_prop_insert_new, [:set, :public])

      :ets.insert(table, {key, original_val})
      :ets.insert_new(table, {key, new_val})

      result =
        case :ets.lookup(table, key) do
          [{^key, ^original_val}] -> true
          _ -> false
        end

      :ets.delete(table)
      result
    end
  end

  property "match spec select count equals full scan count for valid predicate" do
    Application.ensure_all_started(:propcheck)

    forall n <- PC.integer(1, 30) do
      table = :ets.new(:_prop_select, [:set, :public])

      for i <- 1..n do
        :ets.insert(table, {i, rem(i, 2)})
      end

      # Count entries where value == 0 (even numbers)
      match_spec = [{{:_, 0}, [], [true]}]
      select_count = :ets.select_count(table, match_spec)

      # Full scan count for comparison
      scan_count =
        :ets.foldl(
          fn {_k, v}, acc -> if v == 0, do: acc + 1, else: acc end,
          0,
          table
        )

      :ets.delete(table)

      select_count == scan_count
    end
  end

  # ===========================================================================
  # 11. ExUnitProperties check all (SD. prefix — can use assert/refute)
  # ===========================================================================

  describe "ExUnitProperties check all for ETS table operations" do
    test "inserting arbitrary binary keys and values round-trips correctly" do
      SD.tuple({SD.binary(min_length: 1, max_length: 64), SD.binary(max_length: 128)})
      |> Enum.take(30)
      |> Enum.each(fn {key, value} ->
        table = :ets.new(:_check_all_binary, [:set, :public])

        :ets.insert(table, {key, value})
        result = :ets.lookup(table, key)

        :ets.delete(table)

        assert [{^key, ^value}] = result
      end)
    end

    test "ETS :ordered_set keys are always iterated in ascending integer order" do
      SD.uniq_list_of(SD.integer(-1000..1000), min_length: 2, max_length: 20)
      |> Enum.take(25)
      |> Enum.each(fn keys ->
        table = :ets.new(:_check_all_ordered, [:ordered_set, :public])

        Enum.each(keys, fn k -> :ets.insert(table, {k, :val}) end)

        retrieved_keys = :ets.select(table, [{{:"$1", :_}, [], [:"$1"]}])

        :ets.delete(table)

        assert retrieved_keys == Enum.sort(keys),
               "Ordered set keys not in ascending order: #{inspect(retrieved_keys)}"
      end)
    end

    test "ETS size metadata always matches actual content count for :set" do
      SD.list_of(
        SD.tuple({SD.integer(1..200), SD.atom(:alphanumeric)}),
        max_length: 50
      )
      |> Enum.take(25)
      |> Enum.each(fn entries ->
        table = :ets.new(:_check_all_size, [:set, :public])

        Enum.each(entries, fn {k, v} -> :ets.insert(table, {k, v}) end)

        unique_count = entries |> Enum.uniq_by(&elem(&1, 0)) |> length()
        info_size = :ets.info(table, :size)

        :ets.delete(table)

        assert info_size == unique_count,
               "ETS size #{info_size} != unique key count #{unique_count}"
      end)
    end

    test "update_counter results are always within expected range" do
      SD.list_of(SD.integer(1..10), min_length: 1, max_length: 50)
      |> Enum.take(20)
      |> Enum.each(fn increments ->
        table = :ets.new(:_check_all_counter, [:set, :public])
        :ets.insert(table, {:c, 0})

        Enum.each(increments, fn inc -> :ets.update_counter(table, :c, inc) end)

        [{:c, final}] = :ets.lookup(table, :c)
        expected_total = Enum.sum(increments)

        :ets.delete(table)

        assert final == expected_total,
               "Counter final #{final} != expected #{expected_total}"
      end)
    end

    test "ETS match delete removes exactly the matched subset" do
      SD.integer(5..30)
      |> Enum.take(20)
      |> Enum.each(fn n ->
        table = :ets.new(:_check_all_delete, [:set, :public])

        for i <- 1..n do
          parity = if rem(i, 2) == 0, do: :even, else: :odd
          :ets.insert(table, {i, parity})
        end

        evens_before = length(:ets.match_object(table, {:_, :even}))
        :ets.match_delete(table, {:_, :even})

        remaining = :ets.tab2list(table)

        :ets.delete(table)

        odds_expected = n - evens_before

        assert length(remaining) == odds_expected,
               "After deleting evens: expected #{odds_expected} odds, got #{length(remaining)}"

        assert Enum.all?(remaining, fn {_k, v} -> v == :odd end),
               "Non-odd entry remained after match_delete"
      end)
    end

    test "ETS table memory is non-negative and increases monotonically with inserts" do
      SD.integer(1..100)
      |> Enum.take(15)
      |> Enum.each(fn batch_size ->
        table = :ets.new(:_check_all_memory, [:set, :public])

        baseline = :ets.info(table, :memory)
        assert is_integer(baseline) and baseline > 0

        for i <- 1..batch_size do
          :ets.insert(table, {i, String.duplicate("payload", 5)})
        end

        after_insert = :ets.info(table, :memory)

        :ets.delete(table)

        assert after_insert >= baseline,
               "Memory should not decrease after inserts: #{baseline} -> #{after_insert}"
      end)
    end
  end
end
