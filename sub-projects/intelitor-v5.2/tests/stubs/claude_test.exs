defmodule Intelitor.ClaudeTest do
  @moduledoc """
  Test suite for Intelitor.Claude.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/claude.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Claude

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Claude)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Claude, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Claude.__info__(:module)
      assert info == Intelitor.Claude
    end
  end
end
