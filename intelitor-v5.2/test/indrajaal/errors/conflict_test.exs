defmodule Indrajaal.Errors.ConflictTest do
  @moduledoc """
  Tests for Indrajaal.Errors.Conflict namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.Conflict

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Conflict)
    end
  end

  describe "sub-errors" do
    test "Conflict.ResourceConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.ResourceConflict)
    end

    test "Conflict.ConcurrentModification sub-module exists" do
      assert Code.ensure_loaded?(Conflict.ConcurrentModification)
    end

    test "Conflict.StateConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.StateConflict)
    end

    test "Conflict.ScheduleConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.ScheduleConflict)
    end

    test "Conflict.AssignmentConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.AssignmentConflict)
    end

    test "Conflict.LocationOccupied sub-module exists" do
      assert Code.ensure_loaded?(Conflict.LocationOccupied)
    end

    test "Conflict.DeviceConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.DeviceConflict)
    end

    test "Conflict.AlarmStateConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.AlarmStateConflict)
    end

    test "Conflict.AccessLevelConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.AccessLevelConflict)
    end

    test "Conflict.TenantResourceConflict sub-module exists" do
      assert Code.ensure_loaded?(Conflict.TenantResourceConflict)
    end
  end

  describe "error creation" do
    test "can create a ResourceConflict error struct" do
      error = %Conflict.ResourceConflict{}
      assert is_struct(error)
    end

    test "can create a ConcurrentModification error struct" do
      error = %Conflict.ConcurrentModification{}
      assert is_struct(error)
    end

    test "can create a StateConflict error struct" do
      error = %Conflict.StateConflict{}
      assert is_struct(error)
    end

    test "can create a DeviceConflict error struct" do
      error = %Conflict.DeviceConflict{}
      assert is_struct(error)
    end
  end
end
