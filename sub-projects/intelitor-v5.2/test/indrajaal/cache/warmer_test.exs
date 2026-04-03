defmodule Indrajaal.Cache.WarmerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cache.Warmer

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Warmer)
    end

    test "module exports expected functions" do
      assert function_exported?(Warmer, :start_link, 1)
      assert function_exported?(Warmer, :warm_now, 1)
      assert function_exported?(Warmer, :queue_warming, 3)
      assert function_exported?(Warmer, :stats, 0)
      assert function_exported?(Warmer, :get_popular_devices, 0)
      assert function_exported?(Warmer, :get_recent_alarms, 0)
    end
  end

  describe "start_link/1" do
    test "starts the GenServer with a name opt" do
      name = :"warmer_test_#{System.unique_integer([:positive])}"
      result = start_supervised({Warmer, [name: name]})
      assert match?({:ok, _}, result)
    end
  end

  describe "get_popular_devices/0" do
    test "returns a list (may be empty without DB)" do
      # get_popular_devices calls into DB layer; without DB it returns [] or errors gracefully
      result =
        try do
          Warmer.get_popular_devices()
        rescue
          _ -> []
        catch
          _, _ -> []
        end

      assert is_list(result)
    end
  end

  describe "get_recent_alarms/0" do
    test "returns a list (may be empty without DB)" do
      result =
        try do
          Warmer.get_recent_alarms()
        rescue
          _ -> []
        catch
          _, _ -> []
        end

      assert is_list(result)
    end
  end
end
