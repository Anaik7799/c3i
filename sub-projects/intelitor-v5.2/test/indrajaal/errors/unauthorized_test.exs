defmodule Indrajaal.Errors.UnauthorizedTest do
  @moduledoc """
  Tests for Indrajaal.Errors.Unauthorized namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.Unauthorized

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Unauthorized)
    end
  end

  describe "sub-errors" do
    test "Unauthorized.AuthenticationRequired sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.AuthenticationRequired)
    end

    test "Unauthorized.InvalidToken sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.InvalidToken)
    end

    test "Unauthorized.SessionExpired sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.SessionExpired)
    end

    test "Unauthorized.MfaRequired sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.MfaRequired)
    end

    test "Unauthorized.InvalidMfaCode sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.InvalidMfaCode)
    end

    test "Unauthorized.AccountLocked sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.AccountLocked)
    end

    test "Unauthorized.AccountDisabled sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.AccountDisabled)
    end

    test "Unauthorized.InvalidApiKey sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.InvalidApiKey)
    end

    test "Unauthorized.CertificateInvalid sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.CertificateInvalid)
    end

    test "Unauthorized.DeviceNotRegistered sub-module exists" do
      assert Code.ensure_loaded?(Unauthorized.DeviceNotRegistered)
    end
  end

  describe "error creation" do
    test "can create an AuthenticationRequired error struct" do
      error = %Unauthorized.AuthenticationRequired{}
      assert is_struct(error)
    end

    test "can create an InvalidToken error struct" do
      error = %Unauthorized.InvalidToken{}
      assert is_struct(error)
    end

    test "can create a SessionExpired error struct" do
      error = %Unauthorized.SessionExpired{}
      assert is_struct(error)
    end

    test "can create an AccountLocked error struct" do
      error = %Unauthorized.AccountLocked{}
      assert is_struct(error)
    end
  end
end
