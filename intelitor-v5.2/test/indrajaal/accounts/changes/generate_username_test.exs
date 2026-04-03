defmodule Indrajaal.Accounts.Changes.GenerateUsernameTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Changes.GenerateUsername.

  ## STAMP Safety Integration
  - SC-DB-001: Ash Change compliance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Username not generated from email
  - L5 Root Cause: Email parsing logic missing
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Changes.GenerateUsername

  describe "GenerateUsername change module" do
    test "module exists and uses Ash.Resource.Change" do
      assert Code.ensure_loaded?(GenerateUsername)
      assert function_exported?(GenerateUsername, :change, 3)
    end

    test "change/3 is exported with correct arity" do
      assert function_exported?(GenerateUsername, :change, 3)
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: GenerateUsername module exists" do
      assert GenerateUsername.__info__(:module) == GenerateUsername
    end
  end
end
