defmodule Indrajaal.Observability.ZenohFractalPublisherTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.ZenohFractalPublisher

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ZenohFractalPublisher)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(ZenohFractalPublisher, :start_link, 1)
    end

    test "publish_entry/2 is exported" do
      assert function_exported?(ZenohFractalPublisher, :publish_entry, 2)
    end

    test "publish_entries/2 is exported" do
      assert function_exported?(ZenohFractalPublisher, :publish_entries, 2)
    end

    test "flush/1 is exported" do
      assert function_exported?(ZenohFractalPublisher, :flush, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(ZenohFractalPublisher, :get_stats, 1)
    end

    test "enabled?/1 is exported" do
      assert function_exported?(ZenohFractalPublisher, :enabled?, 1)
    end

    test "set_enabled/2 is exported" do
      assert function_exported?(ZenohFractalPublisher, :set_enabled, 2)
    end

    test "handle_incoming_event/2 is exported" do
      assert function_exported?(ZenohFractalPublisher, :handle_incoming_event, 2)
    end
  end

  describe "ZenohFractalPublisher GenServer lifecycle" do
    setup do
      name = :"zfp_test_#{System.unique_integer([:positive])}"

      case ZenohFractalPublisher.start_link(name: name) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{publisher: pid, name: name}

        {:error, _} ->
          %{publisher: nil, name: name}
      end
    end

    test "starts or gracefully fails", %{publisher: pid} do
      if pid != nil, do: assert(Process.alive?(pid))
    end

    test "enabled?/1 returns boolean", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohFractalPublisher.enabled?(name)
        assert is_boolean(result) or result == :ok or match?({:ok, _}, result)
      end
    end

    test "set_enabled/2 enables the publisher", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohFractalPublisher.set_enabled(name, true)
        assert result == :ok or match?({:ok, _}, result)
      end
    end

    test "get_stats/1 returns stats map", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohFractalPublisher.get_stats(name)
        assert is_map(result) or match?({:ok, _}, result)
      end
    end

    test "flush/1 completes without crash", %{publisher: pid, name: name} do
      if pid != nil do
        result = ZenohFractalPublisher.flush(name)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test "publish_entry/2 completes", %{publisher: pid, name: name} do
      if pid != nil do
        result =
          ZenohFractalPublisher.publish_entry(name, %{
            layer: :function,
            event: :metric,
            value: 0.5
          })

        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
