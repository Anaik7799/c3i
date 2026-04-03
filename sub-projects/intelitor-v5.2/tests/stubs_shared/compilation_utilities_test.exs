defmodule Intelitor.Shared.CompilationUtilitiesTest do
  @moduledoc """
  Test suite for Intelitor.Shared.CompilationUtilities.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/shared/compilation_utilities.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Shared.CompilationUtilities

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(CompilationUtilities)
    end

    test "module has __info__/1 function" do
      assert function_exported?(CompilationUtilities, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = CompilationUtilities.__info__(:module)
      assert info == Intelitor.Shared.CompilationUtilities
    end
  end
end
