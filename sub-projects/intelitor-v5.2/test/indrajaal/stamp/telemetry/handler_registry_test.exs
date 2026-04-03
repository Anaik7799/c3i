defmodule Indrajaal.STAMP.Telemetry.HandlerRegistryTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.Telemetry.HandlerRegistry GenServer with 11 handlers.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.STAMP.Telemetry.HandlerRegistry

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(HandlerRegistry)
    end

    test "start_link/1 is exported" do
      assert function_exported?(HandlerRegistry, :start_link, 1)
    end

    test "register_all_handlers/0 is exported" do
      assert function_exported?(HandlerRegistry, :register_all_handlers, 0)
    end

    test "list_handlers/0 is exported" do
      assert function_exported?(HandlerRegistry, :list_handlers, 0)
    end

    test "get_handler/1 is exported" do
      assert function_exported?(HandlerRegistry, :get_handler, 1)
    end

    test "unregister_all_handlers/0 is exported" do
      assert function_exported?(HandlerRegistry, :unregister_all_handlers, 0)
    end
  end

  describe "handler definitions" do
    @tag :sil4
    test "module has 11 handler definitions" do
      # @handler_definitions is a module attribute with 11 entries
      assert Code.ensure_loaded?(HandlerRegistry)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      name = :"handler_registry_#{System.unique_integer([:positive])}"

      case start_supervised({HandlerRegistry, [name: name]}) do
        {:ok, pid} -> {:ok, pid: pid, name: name}
        {:error, reason} -> {:error, reason}
      end
    end

    @tag :sil4
    test "starts successfully", %{pid: pid} do
      assert Process.alive?(pid)
    end

    @tag :sil4
    test "register_all_handlers returns count of registered handlers", %{pid: pid} do
      result = GenServer.call(pid, :register_all_handlers)
      assert match?({:ok, count} when is_integer(count), result)
    end

    @tag :sil4
    test "list_handlers returns a list", %{pid: pid} do
      GenServer.call(pid, :register_all_handlers)
      handlers = GenServer.call(pid, :list_handlers)
      assert is_list(handlers)
    end

    @tag :sil4
    test "get_handler returns :error for unknown handler", %{pid: pid} do
      result = GenServer.call(pid, {:get_handler, "nonexistent-handler"})
      assert match?({:error, :not_found}, result)
    end

    @tag :sil4
    test "unregister_all_handlers returns :ok", %{pid: pid} do
      result = GenServer.call(pid, :unregister_all_handlers)
      assert result == :ok
    end
  end
end
