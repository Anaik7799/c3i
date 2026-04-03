defmodule Intelitor.AccessControl.AccessScheduleTest do
  @moduledoc """
  Test suite for Intelitor.AccessControl.AccessSchedule.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/access_control/access_schedule.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AccessControl.AccessSchedule

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AccessSchedule)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AccessSchedule, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AccessSchedule.__info__(:module)
      assert info == Intelitor.AccessControl.AccessSchedule
    end
  end
end
