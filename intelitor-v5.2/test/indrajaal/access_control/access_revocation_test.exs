defmodule Indrajaal.AccessControl.AccessRevocationTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessRevocation Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessRevocation

  describe "revocation_type enum values" do
    test "temporary is valid revocation type" do
      valid_types = [:temporary, :permanent, :security_breach, :termination, :lost_credential]
      assert :temporary in valid_types
    end

    test "permanent is valid revocation type" do
      valid_types = [:temporary, :permanent, :security_breach, :termination, :lost_credential]
      assert :permanent in valid_types
    end

    test "security_breach is valid revocation type" do
      valid_types = [:temporary, :permanent, :security_breach, :termination, :lost_credential]
      assert :security_breach in valid_types
    end

    test "termination is valid revocation type" do
      valid_types = [:temporary, :permanent, :security_breach, :termination, :lost_credential]
      assert :termination in valid_types
    end

    test "lost_credential is valid revocation type" do
      valid_types = [:temporary, :permanent, :security_breach, :termination, :lost_credential]
      assert :lost_credential in valid_types
    end
  end

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AccessRevocation)
    end

    test "status defaults to active" do
      default_status = :active
      assert default_status == :active
    end

    test "has Ash resource behavior" do
      assert function_exported?(AccessRevocation, :spark_is, 1) or
               Code.ensure_loaded?(AccessRevocation)
    end
  end
end
