defmodule Indrajaal.Errors.ForbiddenTest do
  @moduledoc """
  Tests for Indrajaal.Errors.Forbidden namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.Forbidden

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Forbidden)
    end
  end

  describe "sub-errors" do
    test "Forbidden.AccessDenied sub-module exists" do
      assert Code.ensure_loaded?(Forbidden.AccessDenied)
    end

    test "Forbidden.InsufficientPermissions sub-module exists" do
      assert Code.ensure_loaded?(Forbidden.InsufficientPermissions)
    end

    test "Forbidden.TenantIsolationViolation sub-module exists" do
      assert Code.ensure_loaded?(Forbidden.TenantIsolationViolation)
    end

    test "Forbidden.PolicyViolation sub-module exists" do
      assert Code.ensure_loaded?(Forbidden.PolicyViolation)
    end
  end

  describe "error creation" do
    test "can create an AccessDenied error struct" do
      error = %Forbidden.AccessDenied{}
      assert is_struct(error)
    end

    test "can create an InsufficientPermissions error struct" do
      error = %Forbidden.InsufficientPermissions{}
      assert is_struct(error)
    end

    test "can create a TenantIsolationViolation error struct" do
      error = %Forbidden.TenantIsolationViolation{}
      assert is_struct(error)
    end

    test "can create a PolicyViolation error struct" do
      error = %Forbidden.PolicyViolation{}
      assert is_struct(error)
    end
  end
end
