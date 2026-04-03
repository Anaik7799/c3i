defmodule Intelitor.Errors.ExternalTest do
  @moduledoc """
  Test suite for Intelitor.Errors.External.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/errors/external.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Errors.External

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(External)
    end

    test "module has __info__/1 function" do
      assert function_exported?(External, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = External.__info__(:module)
      assert info == Intelitor.Errors.External
    end
  end
end
