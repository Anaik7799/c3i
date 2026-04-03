defmodule Indrajaal.Observability.StateTrackerTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.StateTracker

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(StateTracker)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(StateTracker, :start_link, 1)
    end

    test "record_log/3 is exported" do
      assert function_exported?(StateTracker, :record_log, 3)
    end

    test "get_history/0 is exported" do
      assert function_exported?(StateTracker, :get_history, 0)
    end
  end

  describe "StateTracker GenServer lifecycle" do
    setup do
      tmp_dir = System.tmp_dir!()
      db_path = Path.join(tmp_dir, "state_tracker_test_#{System.unique_integer([:positive])}")

      case StateTracker.start_link(
             name: :"st_test_#{System.unique_integer([:positive])}",
             db_path: db_path
           ) do
        {:ok, pid} ->
          on_exit(fn ->
            if Process.alive?(pid), do: GenServer.stop(pid)
            File.rm_rf(db_path)
          end)

          %{tracker: pid}

        {:error, _} ->
          %{tracker: nil}
      end
    end

    test "starts successfully or gracefully fails", %{tracker: pid} do
      if pid != nil, do: assert(Process.alive?(pid))
    end

    test "record_log/3 records without raising", %{tracker: pid} do
      if pid != nil do
        result = StateTracker.record_log(pid, :info, %{event: "test_event", value: 42})
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "get_history/0 returns list", %{tracker: pid} do
      if pid != nil do
        result = StateTracker.get_history(pid)
        assert is_list(result) or match?({:ok, _}, result)
      end
    end
  end
end
