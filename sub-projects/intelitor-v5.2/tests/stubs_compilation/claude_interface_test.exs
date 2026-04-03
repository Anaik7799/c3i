defmodule Intelitor.Compilation.ClaudeInterfaceTest do
  @moduledoc """
  Test suite for Intelitor.Compilation.ClaudeInterface.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/compilation/claude_interface.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Compilation.ClaudeInterface

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ClaudeInterface)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ClaudeInterface, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ClaudeInterface.__info__(:module)
      assert info == Intelitor.Compilation.ClaudeInterface
    end
  end
end
