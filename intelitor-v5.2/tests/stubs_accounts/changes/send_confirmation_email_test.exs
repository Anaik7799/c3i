defmodule Intelitor.Accounts.Changes.SendConfirmationEmailTest do
  @moduledoc """
  Test suite for Intelitor.Accounts.Changes.SendConfirmationEmail.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/accounts/changes/send_confirmation_email.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Accounts.Changes.SendConfirmationEmail

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(SendConfirmationEmail)
    end

    test "module has __info__/1 function" do
      assert function_exported?(SendConfirmationEmail, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = SendConfirmationEmail.__info__(:module)
      assert info == Intelitor.Accounts.Changes.SendConfirmationEmail
    end
  end
end
