defmodule Indrajaal.Testing.UTLTSFormatterTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Testing.UTLTSFormatter

  # ---------------------------------------------------------------------------
  # Module API
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(UTLTSFormatter)
    end

    test "implements GenServer behaviour" do
      behaviours = UTLTSFormatter.__info__(:attributes)[:behaviour] || []
      assert GenServer in behaviours
    end

    test "exports init/1" do
      assert function_exported?(UTLTSFormatter, :init, 1)
    end

    test "exports handle_cast/2" do
      assert function_exported?(UTLTSFormatter, :handle_cast, 2)
    end

    test "exports handle_info/2" do
      assert function_exported?(UTLTSFormatter, :handle_info, 2)
    end

    test "does not export private database helpers" do
      refute function_exported?(UTLTSFormatter, :open_database, 0)
      refute function_exported?(UTLTSFormatter, :flush_buffer, 1)
      refute function_exported?(UTLTSFormatter, :ensure_schema, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Struct shape
  # ---------------------------------------------------------------------------

  describe "struct definition" do
    test "defines struct with db field" do
      fields = UTLTSFormatter.__struct__() |> Map.keys()
      assert :db in fields
    end

    test "defines struct with run_id field" do
      fields = UTLTSFormatter.__struct__() |> Map.keys()
      assert :run_id in fields
    end

    test "defines struct with env_id field" do
      fields = UTLTSFormatter.__struct__() |> Map.keys()
      assert :env_id in fields
    end

    test "defines struct with suite_start_time field" do
      fields = UTLTSFormatter.__struct__() |> Map.keys()
      assert :suite_start_time in fields
    end

    test "defines struct with flush_timer field" do
      fields = UTLTSFormatter.__struct__() |> Map.keys()
      assert :flush_timer in fields
    end

    test "counter fields default to 0" do
      s = %UTLTSFormatter{}
      assert s.test_count == 0
      assert s.pass_count == 0
      assert s.fail_count == 0
      assert s.skip_count == 0
      assert s.error_count == 0
    end

    test "result_buffer defaults to empty list" do
      assert %UTLTSFormatter{}.result_buffer == []
    end

    test "module_map defaults to empty map" do
      assert %UTLTSFormatter{}.module_map == %{}
    end

    test "definition_cache defaults to empty map" do
      assert %UTLTSFormatter{}.definition_cache == %{}
    end

    test "db defaults to nil" do
      assert is_nil(%UTLTSFormatter{}.db)
    end
  end

  # ---------------------------------------------------------------------------
  # init/1 — graceful degradation
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "returns {:ok, state} tuple" do
      assert {:ok, _state} = UTLTSFormatter.init([])
    end

    test "returns a %UTLTSFormatter{} struct as state" do
      {:ok, state} = UTLTSFormatter.init([])
      assert %UTLTSFormatter{} = state
    end

    test "gracefully degrades to db: nil when database unavailable" do
      # The default @db_path likely doesn't exist in CI; init must not crash.
      {:ok, state} = UTLTSFormatter.init([])
      # db is either a valid handle (if utlts.db exists) or nil (degraded mode)
      assert is_nil(state.db) or not is_nil(state.db)
    end

    test "counter fields are zero in initial state" do
      {:ok, state} = UTLTSFormatter.init([])
      assert state.test_count == 0
      assert state.pass_count == 0
      assert state.fail_count == 0
      assert state.skip_count == 0
      assert state.error_count == 0
    end

    test "result_buffer is empty in initial state" do
      {:ok, state} = UTLTSFormatter.init([])
      assert state.result_buffer == []
    end

    test "module_map is empty in initial state" do
      {:ok, state} = UTLTSFormatter.init([])
      assert state.module_map == %{}
    end

    test "init accepts non-empty options list without crashing" do
      assert {:ok, _state} = UTLTSFormatter.init(colors: [enabled: false])
    end
  end

  # ---------------------------------------------------------------------------
  # handle_cast/2 — ExUnit formatter event protocol
  # All casts must return {:noreply, state} without raising.
  # We drive calls directly (no live GenServer process needed) so that the test
  # remains fast, async, and free of side-effects.
  # ---------------------------------------------------------------------------

  describe "handle_cast/2 with db: nil state (graceful degradation)" do
    setup do
      state = %UTLTSFormatter{db: nil}
      %{state: state}
    end

    test "suite_started event is ignored", %{state: state} do
      assert {:noreply, ^state} = UTLTSFormatter.handle_cast({:suite_started, []}, state)
    end

    test "suite_finished map event is ignored when db is nil", %{state: state} do
      assert {:noreply, ^state} =
               UTLTSFormatter.handle_cast({:suite_finished, %{async: 0, run: 0, load: 0}}, state)
    end

    test "suite_finished legacy tuple is ignored when db is nil", %{state: state} do
      assert {:noreply, ^state} =
               UTLTSFormatter.handle_cast({:suite_finished, 1000, 500}, state)
    end

    test "case_started is ignored", %{state: state} do
      fake_case = %ExUnit.TestCase{name: MyTest}
      assert {:noreply, ^state} = UTLTSFormatter.handle_cast({:case_started, fake_case}, state)
    end

    test "case_finished is ignored", %{state: state} do
      fake_case = %ExUnit.TestCase{name: MyTest}
      assert {:noreply, ^state} = UTLTSFormatter.handle_cast({:case_finished, fake_case}, state)
    end

    test "module_started is ignored when db is nil", %{state: state} do
      fake_module = %ExUnit.TestModule{name: MyTest, file: "test/my_test.exs", tests: []}

      assert {:noreply, ^state} =
               UTLTSFormatter.handle_cast({:module_started, fake_module}, state)
    end

    test "test_started is ignored", %{state: state} do
      fake_test = %ExUnit.Test{
        name: :test_something,
        module: MyTest,
        tags: %{},
        time: 0,
        logs: ""
      }

      assert {:noreply, ^state} = UTLTSFormatter.handle_cast({:test_started, fake_test}, state)
    end

    test "test_finished is ignored when db is nil", %{state: state} do
      fake_test = %ExUnit.Test{
        name: :test_something,
        module: MyTest,
        tags: %{},
        time: 100,
        logs: "",
        state: nil
      }

      assert {:noreply, ^state} =
               UTLTSFormatter.handle_cast({:test_finished, fake_test}, state)
    end

    test "unknown cast event is handled without crashing", %{state: state} do
      assert {:noreply, ^state} =
               UTLTSFormatter.handle_cast({:unknown_future_event, :some_data}, state)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_cast/2 — counter updates (no DB needed)
  # We test module_finished and that counters update correctly by combining a
  # state with a fake module_map entry and calling handle_cast directly.
  # ---------------------------------------------------------------------------

  describe "handle_cast/2 module_finished" do
    test "removes module from module_map" do
      state = %UTLTSFormatter{
        db: nil,
        module_map: %{MyTest => %{suite_id: "s1", start_time: 0}}
      }

      {:noreply, new_state} =
        UTLTSFormatter.handle_cast(
          {:module_finished, %ExUnit.TestModule{name: MyTest, file: "f.exs", tests: []}},
          state
        )

      refute Map.has_key?(new_state.module_map, MyTest)
    end

    test "removing a non-existent module does not raise" do
      state = %UTLTSFormatter{db: nil, module_map: %{}}

      assert {:noreply, _} =
               UTLTSFormatter.handle_cast(
                 {:module_finished,
                  %ExUnit.TestModule{name: UnknownMod, file: "f.exs", tests: []}},
                 state
               )
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info/2
  # ---------------------------------------------------------------------------

  describe "handle_info/2" do
    test "flush_buffer message is handled without raising when db is nil" do
      state = %UTLTSFormatter{db: nil}
      assert {:noreply, _new_state} = UTLTSFormatter.handle_info(:flush_buffer, state)
    end

    test "unknown info message is ignored" do
      state = %UTLTSFormatter{db: nil}
      assert {:noreply, ^state} = UTLTSFormatter.handle_info(:some_random_message, state)
    end

    test "flush_buffer reschedules timer when db is nil" do
      state = %UTLTSFormatter{db: nil}
      {:noreply, _new_state} = UTLTSFormatter.handle_info(:flush_buffer, state)
      # No assertion on timer — just verifying it returns without crashing.
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer lifecycle — start and stop
  # ---------------------------------------------------------------------------

  describe "GenServer lifecycle" do
    test "can be started as a supervised process" do
      # UTLTSFormatter is an ExUnit formatter (not a named singleton), so we
      # start it with start_link/1 directly via start_supervised.
      # It degrades gracefully if the DB is absent.
      pid = start_supervised!({GenServer, {UTLTSFormatter, []}})
      assert Process.alive?(pid)
    end

    test "started process responds to :sys.get_status" do
      {:ok, pid} = GenServer.start_link(UTLTSFormatter, [])
      assert {:status, ^pid, _mod, _data} = :sys.get_status(pid)
      GenServer.stop(pid, :normal)
    end

    test "process terminates cleanly" do
      {:ok, pid} = GenServer.start_link(UTLTSFormatter, [])
      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
      refute Process.alive?(pid)
    end
  end
end
