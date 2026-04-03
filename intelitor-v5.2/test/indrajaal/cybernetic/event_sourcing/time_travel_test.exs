defmodule Indrajaal.Cybernetic.EventSourcing.TimeTravelTest do
  @moduledoc """
  TDG tests for Indrajaal.Cybernetic.EventSourcing.TimeTravel pure module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cybernetic.EventSourcing.TimeTravel

  describe "TimeTravel module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TimeTravel)
    end

    test "new/3 is exported" do
      assert function_exported?(TimeTravel, :new, 3)
    end

    test "goto/2 is exported" do
      assert function_exported?(TimeTravel, :goto, 2)
    end

    test "goto_version/2 is exported" do
      assert function_exported?(TimeTravel, :goto_version, 2)
    end

    test "goto_hlc/2 is exported" do
      assert function_exported?(TimeTravel, :goto_hlc, 2)
    end

    test "goto_datetime/2 is exported" do
      assert function_exported?(TimeTravel, :goto_datetime, 2)
    end

    test "peek/2 is exported" do
      assert function_exported?(TimeTravel, :peek, 2)
    end

    test "multi_peek/2 is exported" do
      assert function_exported?(TimeTravel, :multi_peek, 2)
    end

    test "diff/3 is exported" do
      assert function_exported?(TimeTravel, :diff, 3)
    end

    test "follow_causality/2 is exported" do
      assert function_exported?(TimeTravel, :follow_causality, 2)
    end

    test "summary/1 is exported" do
      assert function_exported?(TimeTravel, :summary, 1)
    end
  end

  describe "TimeTravel new/3" do
    test "creates a new time travel context" do
      events = [
        %{version: 1, data: %{value: "a"}, timestamp: DateTime.utc_now()},
        %{version: 2, data: %{value: "b"}, timestamp: DateTime.utc_now()}
      ]

      result = TimeTravel.new("entity-1", events, %{value: "b"})
      assert is_map(result)
    end

    test "accepts empty events list" do
      result = TimeTravel.new("entity-1", [], %{})
      assert is_map(result)
    end
  end

  describe "TimeTravel summary/1" do
    test "returns summary map for time travel context" do
      events = [%{version: 1, data: %{}, timestamp: DateTime.utc_now()}]
      ctx = TimeTravel.new("entity-1", events, %{})
      summary = TimeTravel.summary(ctx)
      assert is_map(summary)
    end
  end
end
