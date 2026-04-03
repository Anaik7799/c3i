defmodule Intelitor.TPS.ConfigurationAuditorTest do
  @moduledoc """
  Test suite for Intelitor.TPS.ConfigurationAuditor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/tps/configuration_auditor.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.TPS.ConfigurationAuditor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ConfigurationAuditor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ConfigurationAuditor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ConfigurationAuditor.__info__(:module)
      assert info == Intelitor.TPS.ConfigurationAuditor
    end
  end
end
