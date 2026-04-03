defmodule Indrajaal.Observability.ObservabilityBehaviourTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ObservabilityBehaviour

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ObservabilityBehaviour)
    end
  end

  describe "behaviour callbacks defined" do
    test "start_monitoring/1 callback is defined" do
      callbacks = ObservabilityBehaviour.behaviour_info(:callbacks)
      assert Enum.any?(callbacks, fn {name, _arity} -> name == :start_monitoring end)
    end

    test "stop_monitoring/1 callback is defined" do
      callbacks = ObservabilityBehaviour.behaviour_info(:callbacks)
      assert Enum.any?(callbacks, fn {name, _arity} -> name == :stop_monitoring end)
    end

    test "get_metrics/0 callback is defined" do
      callbacks = ObservabilityBehaviour.behaviour_info(:callbacks)
      assert Enum.any?(callbacks, fn {name, _arity} -> name == :get_metrics end)
    end

    test "behaviour_info/1 returns list of callbacks" do
      callbacks = ObservabilityBehaviour.behaviour_info(:callbacks)
      assert is_list(callbacks)
      assert length(callbacks) >= 3
    end
  end

  describe "behaviour implementation contract" do
    defmodule TestObservabilityImpl do
      @behaviour Indrajaal.Observability.ObservabilityBehaviour

      @impl true
      def start_monitoring(_opts), do: {:ok, :started}

      @impl true
      def stop_monitoring(_ref), do: :ok

      @impl true
      def get_metrics, do: %{count: 0}
    end

    test "implementation satisfies behaviour" do
      assert Code.ensure_loaded?(TestObservabilityImpl)
      assert {:ok, :started} = TestObservabilityImpl.start_monitoring([])
      assert :ok = TestObservabilityImpl.stop_monitoring(:ref)
      assert is_map(TestObservabilityImpl.get_metrics())
    end
  end
end
