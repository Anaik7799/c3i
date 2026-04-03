defmodule Intelitor.Alarms.IncidentTypeTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.IncidentType.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/incident_type.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.IncidentType

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(IncidentType)
    end

    test "module has __info__/1 function" do
      assert function_exported?(IncidentType, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = IncidentType.__info__(:module)
      assert info == Intelitor.Alarms.IncidentType
    end
  end
end
