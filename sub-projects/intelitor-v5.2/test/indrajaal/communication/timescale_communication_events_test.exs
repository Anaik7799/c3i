defmodule Indrajaal.Communication.TimescaleCommunicationEventsTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for Indrajaal.Communication.TimescaleCommunicationEvents GenServer.
  Tests module existence and exported function signatures without starting DB connections.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Communication.TimescaleCommunicationEvents

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TimescaleCommunicationEvents)
    end

    test "module uses GenServer behaviour" do
      behaviours =
        TimescaleCommunicationEvents.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert GenServer in behaviours
    end
  end

  describe "exported functions" do
    test "start_link/1 is exported" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert Keyword.has_key?(fns, :start_link)
    end

    test "setup_hypertables/0 is exported" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert Keyword.has_key?(fns, :setup_hypertables)
    end

    test "log_communication_event/1 is exported" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert Keyword.has_key?(fns, :log_communication_event)
    end

    test "log_compliance_audit_event/1 is exported" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert Keyword.has_key?(fns, :log_compliance_audit_event)
    end

    test "update_communication_analytics/1 is exported" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert Keyword.has_key?(fns, :update_communication_analytics)
    end

    test "start_link accepts opts argument (arity 0 or 1)" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      arities = Keyword.get_values(fns, :start_link)
      assert 0 in arities or 1 in arities
    end

    test "log_communication_event/1 has arity 1" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert 1 in Keyword.get_values(fns, :log_communication_event)
    end

    test "log_compliance_audit_event/1 has arity 1" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert 1 in Keyword.get_values(fns, :log_compliance_audit_event)
    end

    test "update_communication_analytics/1 has arity 1" do
      fns = TimescaleCommunicationEvents.__info__(:functions)
      assert 1 in Keyword.get_values(fns, :update_communication_analytics)
    end
  end
end
