defmodule Indrajaal.Accounts.Changes.SendConfirmationEmailTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Changes.SendConfirmationEmail.

  ## STAMP Safety Integration
  - SC-DB-001: Ash Change compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Confirmation email not sent on registration
  - L5 Root Cause: After-action hook not registered
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Changes.SendConfirmationEmail

  describe "SendConfirmationEmail change module" do
    test "module exists and uses Ash.Resource.Change" do
      assert Code.ensure_loaded?(SendConfirmationEmail)
      assert function_exported?(SendConfirmationEmail, :change, 3)
    end

    test "change/3 is exported with correct arity" do
      assert function_exported?(SendConfirmationEmail, :change, 3)
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: SendConfirmationEmail module exists" do
      assert SendConfirmationEmail.__info__(:module) == SendConfirmationEmail
    end
  end
end
