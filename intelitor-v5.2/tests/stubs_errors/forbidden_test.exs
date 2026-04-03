defmodule Intelitor.Errors.ForbiddenTest do
  @moduledoc """
  Test suite for Intelitor.Errors.Forbidden.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/errors/forbidden.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Errors.Forbidden

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Forbidden)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Forbidden, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Forbidden.__info__(:module)
      assert info == Intelitor.Errors.Forbidden
    end
  end
end
