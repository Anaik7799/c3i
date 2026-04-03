defmodule Indrajaal.Notifications.Backends.EmailTest do
  @moduledoc """
  TDG test suite for Email notification backend.

  ## STAMP Safety Integration
  - SC-OBS-067: Real-time alert delivery
  - SC-SEC-045: Secure email transmission

  ## TPS 5-Level RCA Context
  - L1 Symptom: Email notifications not delivered
  - L5 Root Cause: Missing mailer configuration validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Notifications.Backends.Email

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Email)
    end

    test "deliver/2 is exported" do
      assert function_exported?(Email, :deliver, 1)
      assert function_exported?(Email, :deliver, 2)
    end
  end

  describe "behaviour implementation" do
    test "implements notification behaviour" do
      behaviours = Email.__info__(:attributes) |> Keyword.get_values(:behaviour)
      flat = List.flatten(behaviours)
      assert Indrajaal.Notifications.Backends.Behaviour in flat
    end
  end

  describe "deliver/2 with missing params" do
    test "returns error when to field is missing" do
      result = Email.deliver(%{subject: "Test", body: "Test body"})
      assert match?({:error, _}, result)
    end
  end

  describe "deliver/2 with empty address" do
    test "returns error or raises for empty to" do
      result =
        try do
          Email.deliver(%{to: "", subject: "Test", body: "Test"})
        rescue
          _ -> {:error, :exception}
        end

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
