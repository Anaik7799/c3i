defmodule Intelitor.Errors.ServiceUnavailableTest do
  @moduledoc """
  Test suite for Intelitor.Errors.ServiceUnavailable.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/errors/service_unavailable.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Errors.ServiceUnavailable

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ServiceUnavailable)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ServiceUnavailable, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ServiceUnavailable.__info__(:module)
      assert info == Intelitor.Errors.ServiceUnavailable
    end
  end
end
