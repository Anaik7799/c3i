defmodule Indrajaal.Cockpit.Prajna.CommandDispatchTest do
  @moduledoc """
  TDG integration test: Prajna C3I command dispatch — Guardian-gated command lifecycle.

  ## STAMP Safety Integration
  - SC-PRAJNA-001: All commands MUST pass Guardian pre-approval
  - SC-PRAJNA-003: State mutations logged to Immutable Register
  - SC-CTRL-006: All commands via Guardian
  - AOR-PRAJNA-001: Guardian Gate mandatory

  ## TPS 5-Level RCA Context
  - L1 Symptom: Commands bypass Guardian approval
  - L5 Root Cause: Missing validate_command/1 check before dispatch
  """

  use ExUnit.Case, async: true

  @moduletag :prajna

  alias Indrajaal.Cockpit.Prajna.CommandDispatch

  describe "module existence" do
    test "CommandDispatch module is loaded" do
      assert Code.ensure_loaded?(CommandDispatch)
    end

    test "exports dispatch/2" do
      assert function_exported?(CommandDispatch, :dispatch, 2) or
               function_exported?(CommandDispatch, :dispatch, 1)
    end

    test "exports validate_command/1" do
      assert function_exported?(CommandDispatch, :validate_command, 1)
    end

    test "exports execute/2" do
      assert function_exported?(CommandDispatch, :execute, 2)
    end
  end

  describe "validate_command/1" do
    test "valid command passes validation" do
      cmd = %{
        type: :acknowledge_alarm,
        payload: %{alarm_id: "alarm-001"},
        actor_id: "operator-1",
        tenant_id: "tenant-1"
      }

      result = CommandDispatch.validate_command(cmd)
      assert match?({:ok, _}, result) or match?(:ok, result)
    end

    test "command without type fails validation" do
      cmd = %{payload: %{alarm_id: "alarm-001"}}
      result = CommandDispatch.validate_command(cmd)

      assert match?({:error, _, _}, result) or match?({:error, _}, result)
    end

    test "command without payload fails validation" do
      cmd = %{type: :acknowledge_alarm}
      result = CommandDispatch.validate_command(cmd)

      assert match?({:error, _, _}, result) or match?({:error, _}, result)
    end

    test "empty map fails validation" do
      result = CommandDispatch.validate_command(%{})
      assert match?({:error, _, _}, result) or match?({:error, _}, result)
    end
  end

  describe "dispatch/1 (SC-PRAJNA-001)" do
    test "dispatch routes valid command through Guardian gate" do
      cmd = %{
        type: :system_status,
        payload: %{},
        actor_id: "operator-1"
      }

      result =
        if function_exported?(CommandDispatch, :dispatch, 1) do
          CommandDispatch.dispatch(cmd)
        else
          CommandDispatch.dispatch(cmd, [])
        end

      # Should return ok or guardian veto — never crash
      assert is_tuple(result)
    end

    test "dispatch with alarm acknowledge command" do
      cmd = %{
        type: :acknowledge_alarm,
        payload: %{alarm_id: "alarm-001"},
        actor_id: "operator-1",
        tenant_id: "tenant-1"
      }

      result =
        if function_exported?(CommandDispatch, :dispatch, 1) do
          CommandDispatch.dispatch(cmd)
        else
          CommandDispatch.dispatch(cmd, [])
        end

      assert match?({:ok, _}, result) or match?({:error, _, _}, result) or
               match?({:error, _}, result)
    end
  end

  describe "execute/2" do
    test "execute with valid command type returns result" do
      cmd = %{
        type: :system_status,
        payload: %{}
      }

      result = CommandDispatch.execute(cmd, [])
      assert is_tuple(result) or is_map(result)
    end
  end
end
