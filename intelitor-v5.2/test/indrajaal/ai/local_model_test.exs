defmodule Indrajaal.AI.LocalModelTest do
  @moduledoc """
  Tests for the LocalModel GenServer.

  ## STAMP Constraints Verified
  - SC-NEURO-001: Simplex principle - Guardian gates all AI output
  """

  use ExUnit.Case, async: false

  alias Indrajaal.AI.LocalModel

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(LocalModel)
    end

    test "exports start_link/1" do
      assert function_exported?(LocalModel, :start_link, 1)
    end

    test "exports ask/2" do
      assert function_exported?(LocalModel, :ask, 2)
    end

    test "exports ask/1" do
      assert function_exported?(LocalModel, :ask, 1)
    end
  end

  describe "GenServer initialization" do
    test "can start the GenServer" do
      # Start the GenServer
      {:ok, pid} = LocalModel.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "initializes with default state" do
      {:ok, pid} = LocalModel.start_link([])

      # GenServer should be alive and responding
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "ask/2 with Guardian integration" do
    setup do
      # Start LocalModel for tests
      {:ok, pid} = LocalModel.start_link([])

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      %{pid: pid}
    end

    test "returns result with status" do
      result = LocalModel.ask("What is the system status?")

      assert {:ok, response} = result
      assert Map.has_key?(response, :status)
      assert response.status in [:approved, :vetoed]
    end

    test "includes response text" do
      {:ok, response} = LocalModel.ask("Test prompt")

      assert Map.has_key?(response, :response)
      assert is_binary(response.response)
    end

    test "includes action proposal" do
      {:ok, response} = LocalModel.ask("Test prompt")

      assert Map.has_key?(response, :action)
    end

    test "accepts context parameter" do
      context = %{system_state: :nominal}
      {:ok, response} = LocalModel.ask("Test prompt", context)

      assert response.status in [:approved, :vetoed]
    end
  end
end
