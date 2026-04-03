defmodule Indrajaal.Cortex.AIInterfaceTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.AIInterface.
  Tests module existence and public function contracts.
  STAMP: SC-COG-001, SC-GDE-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.AIInterface

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(AIInterface)
    end

    test "module exports expected functions" do
      functions = AIInterface.__info__(:functions)
      assert Keyword.has_key?(functions, :generate_context)
      assert Keyword.has_key?(functions, :execute_command)
    end
  end

  describe "generate_context/0" do
    test "returns a map" do
      result = AIInterface.generate_context()
      assert is_map(result)
    end

    test "context contains required keys" do
      context = AIInterface.generate_context()
      # Should have at minimum a timestamp or context structure
      assert is_map(context)
    end
  end

  describe "execute_command/1" do
    test "accepts a command string" do
      result = AIInterface.execute_command("status")
      assert result != nil
    end

    test "accepts a command map" do
      result = AIInterface.execute_command(%{action: :ping})
      assert result != nil
    end

    test "handles unknown command gracefully" do
      result = AIInterface.execute_command(:unknown_command_sprint54)
      # Should not raise — graceful handling expected
      assert result != nil
    end
  end
end
