defmodule Indrajaal.MCP.Cepaf.HandlerTest do
  @moduledoc """
  Tests for Indrajaal.MCP.Cepaf.Handler GenServer.
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Cepaf.Handler

  describe "start_link/1" do
    test "starts and registers under module name" do
      pid = start_supervised!({Handler, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "starts with custom name option", %{test: test} do
      name = :"test_cepaf_handler_#{test}"
      pid = start_supervised!({Handler, [name: name]})
      assert is_pid(pid)
      assert Process.whereis(name) == pid
    end
  end

  describe "module definition" do
    test "exports start_link/1" do
      assert function_exported?(Handler, :start_link, 1)
    end

    test "exports handle_call/3" do
      assert function_exported?(Handler, :handle_call, 3)
    end

    test "exports handle_cast/2" do
      assert function_exported?(Handler, :handle_cast, 2)
    end

    test "exports handle_info/2" do
      assert function_exported?(Handler, :handle_info, 2)
    end

    test "exports init/1" do
      assert function_exported?(Handler, :init, 1)
    end
  end

  describe "GenServer lifecycle" do
    test "process stays alive after start", %{test: test} do
      name = :"test_cepaf_lifecycle_#{test}"
      pid = start_supervised!({Handler, [name: name]})
      Process.sleep(50)
      assert Process.alive?(pid)
    end

    test "process stops gracefully on supervised shutdown", %{test: test} do
      name = :"test_cepaf_stop_#{test}"
      pid = start_supervised!({Handler, [name: name]})
      assert Process.alive?(pid)
      stop_supervised!(Handler)
      refute Process.alive?(pid)
    end
  end
end
