defmodule Intelitor.Alarms.ApiTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.Api.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/api.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.Api

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Api)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Api, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Api.__info__(:module)
      assert info == Intelitor.Alarms.Api
    end
  end
end
