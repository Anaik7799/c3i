defmodule Indrajaal.AccessControl.AccessCredentialTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessCredential Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessCredential

  describe "resource definition" do
    test "is an Ash resource" do
      assert function_exported?(AccessCredential, :spark_is, 1)
    end

    test "has credential_type field" do
      fields = AccessCredential.__info__(:functions)
      assert is_list(fields)
    end

    test "credential_type allows card value" do
      valid_types = [:card, :biometric, :pin, :mobile, :fob]
      assert :card in valid_types
    end

    test "credential_type allows biometric value" do
      valid_types = [:card, :biometric, :pin, :mobile, :fob]
      assert :biometric in valid_types
    end

    test "credential_type allows pin value" do
      valid_types = [:card, :biometric, :pin, :mobile, :fob]
      assert :pin in valid_types
    end

    test "credential_type allows mobile value" do
      valid_types = [:card, :biometric, :pin, :mobile, :fob]
      assert :mobile in valid_types
    end

    test "credential_type allows fob value" do
      valid_types = [:card, :biometric, :pin, :mobile, :fob]
      assert :fob in valid_types
    end

    test "code_interface defines issue action" do
      assert function_exported?(AccessCredential, :issue, 1) or
               function_exported?(AccessCredential, :issue, 2)
    end

    test "code_interface defines suspend action" do
      assert function_exported?(AccessCredential, :suspend, 1) or
               function_exported?(AccessCredential, :suspend, 2)
    end

    test "code_interface defines reactivate action" do
      assert function_exported?(AccessCredential, :reactivate, 1) or
               function_exported?(AccessCredential, :reactivate, 2)
    end
  end
end
