defmodule Indrajaal.Cortex.PredictorTest do
  @moduledoc """
  Tests for Indrajaal.Cortex.Predictor.

  Predictor is a GenServer with one public pure-ish function:
    get_forecast/0 — returns %{next_hour_load: :high, confidence: 0.85}
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cortex.Predictor

  describe "get_forecast/0 — return shape" do
    test "returns a map" do
      assert is_map(Predictor.get_forecast())
    end

    test "has :next_hour_load key" do
      assert Map.has_key?(Predictor.get_forecast(), :next_hour_load)
    end

    test "has :confidence key" do
      assert Map.has_key?(Predictor.get_forecast(), :confidence)
    end

    test "has exactly two keys" do
      assert map_size(Predictor.get_forecast()) == 2
    end
  end

  describe "get_forecast/0 — :next_hour_load" do
    test "next_hour_load is an atom" do
      assert is_atom(Predictor.get_forecast().next_hour_load)
    end

    test "next_hour_load is :high for current stub" do
      assert Predictor.get_forecast().next_hour_load == :high
    end
  end

  describe "get_forecast/0 — :confidence" do
    test "confidence is a number" do
      assert is_number(Predictor.get_forecast().confidence)
    end

    test "confidence is between 0.0 and 1.0 inclusive" do
      c = Predictor.get_forecast().confidence
      assert c >= 0.0 and c <= 1.0, "Expected 0.0..1.0, got #{c}"
    end

    test "confidence is 0.85 for current stub" do
      assert Predictor.get_forecast().confidence == 0.85
    end
  end

  describe "get_forecast/0 — idempotency" do
    test "calling twice returns the same result" do
      assert Predictor.get_forecast() == Predictor.get_forecast()
    end
  end

  describe "child_spec/1 — supervisor integration" do
    test "returns a map" do
      assert is_map(Predictor.child_spec([]))
    end

    test "has :id key" do
      assert Map.has_key?(Predictor.child_spec([]), :id)
    end

    test "has :start key" do
      assert Map.has_key?(Predictor.child_spec([]), :start)
    end

    test "id is the module name" do
      assert Predictor.child_spec([]).id == Predictor
    end
  end

  describe "start_link/1 — GenServer lifecycle" do
    # Predictor registers with name: __MODULE__ and may already be running
    # under the application supervision tree. We access it via the registered
    # name rather than trying to start a second instance.

    test "process is registered under the module name" do
      # Either we're in an isolated test env (process not running) or the
      # app supervisor already started it. Either way, we verify the API works.
      pid = GenServer.whereis(Predictor)

      if is_pid(pid) do
        # Already running — verify it is alive
        assert Process.alive?(pid)
      else
        # Not running — start it ourselves and verify it starts cleanly
        {:ok, new_pid} = start_supervised({Predictor, []})
        assert is_pid(new_pid)
        assert Process.alive?(new_pid)
      end
    end

    test "GenServer state has :forecast key" do
      pid = GenServer.whereis(Predictor)

      if is_pid(pid) do
        state = :sys.get_state(pid)
        assert is_map(state)
        assert Map.has_key?(state, :forecast)
      else
        {:ok, new_pid} = start_supervised({Predictor, []})
        state = :sys.get_state(new_pid)
        assert is_map(state)
        assert Map.has_key?(state, :forecast)
      end
    end

    test ":forecast value is a list" do
      pid = GenServer.whereis(Predictor)

      if is_pid(pid) do
        state = :sys.get_state(pid)
        assert is_list(state.forecast)
      else
        {:ok, new_pid} = start_supervised({Predictor, []})
        state = :sys.get_state(new_pid)
        assert state.forecast == []
      end
    end
  end
end
