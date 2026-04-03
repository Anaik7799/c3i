defmodule Indrajaal.Accounts.Changes.HashPasswordTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Changes.HashPassword.

  ## STAMP Safety Integration
  - SC-DB-001: Ash Change compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Password stored in plaintext
  - L5 Root Cause: Hash change not applied in changeset
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Changes.HashPassword

  describe "HashPassword change module" do
    test "module exists and uses Ash.Resource.Change" do
      assert Code.ensure_loaded?(HashPassword)
      assert function_exported?(HashPassword, :change, 3)
    end

    test "change/3 is exported with correct arity" do
      assert function_exported?(HashPassword, :change, 3)
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: HashPassword module exists" do
      assert HashPassword.__info__(:module) == HashPassword
    end
  end
end
