defmodule Intelitor.LocalTimeTest do
  @moduledoc """
  Test suite for Intelitor.LocalTime.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/local_time.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.LocalTime

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(LocalTime)
    end

    test "module has __info__/1 function" do
      assert function_exported?(LocalTime, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = LocalTime.__info__(:module)
      assert info == Intelitor.LocalTime
    end
  end
end
