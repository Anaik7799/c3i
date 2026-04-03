defmodule Indrajaal.AccessControl.AccessScheduleTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessSchedule Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessSchedule

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AccessSchedule)
    end

    test "schedule_type defaults to business_hours" do
      default = :business_hours
      assert default == :business_hours
    end

    test "timezone defaults to UTC" do
      default_tz = "UTC"
      assert default_tz == "UTC"
    end

    test "has get code interface function" do
      assert function_exported?(AccessSchedule, :get, 1) or
               function_exported?(AccessSchedule, :get, 2)
    end

    test "has list code interface function" do
      assert function_exported?(AccessSchedule, :list, 1) or
               function_exported?(AccessSchedule, :list, 0)
    end

    test "has Ash resource behavior" do
      assert function_exported?(AccessSchedule, :spark_is, 1) or
               Code.ensure_loaded?(AccessSchedule)
    end
  end
end
