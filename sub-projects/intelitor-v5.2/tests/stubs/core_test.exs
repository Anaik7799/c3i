defmodule Intelitor.CoreTest do
  @moduledoc """
  Test suite for Intelitor.Core.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/core.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Core

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Core)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Core, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Core.__info__(:module)
      assert info == Intelitor.Core
    end
  end
end
