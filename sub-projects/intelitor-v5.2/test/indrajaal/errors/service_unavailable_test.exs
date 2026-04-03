defmodule Indrajaal.Errors.ServiceUnavailableTest do
  @moduledoc """
  Tests for Indrajaal.Errors.ServiceUnavailable namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.ServiceUnavailable

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ServiceUnavailable)
    end
  end

  describe "sub-errors" do
    test "ServiceUnavailable.MaintenanceMode sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.MaintenanceMode)
    end

    test "ServiceUnavailable.CircuitBreakerOpen sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.CircuitBreakerOpen)
    end

    test "ServiceUnavailable.RateLimitExceeded sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.RateLimitExceeded)
    end

    test "ServiceUnavailable.CapacityExceeded sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.CapacityExceeded)
    end

    test "ServiceUnavailable.DatabaseUnavailable sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.DatabaseUnavailable)
    end

    test "ServiceUnavailable.ExternalServiceDown sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.ExternalServiceDown)
    end

    test "ServiceUnavailable.FeatureDisabled sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.FeatureDisabled)
    end

    test "ServiceUnavailable.RegionUnavailable sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.RegionUnavailable)
    end

    test "ServiceUnavailable.StorageUnavailable sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.StorageUnavailable)
    end

    test "ServiceUnavailable.NodeDown sub-module exists" do
      assert Code.ensure_loaded?(ServiceUnavailable.NodeDown)
    end
  end

  describe "error creation" do
    test "can create a MaintenanceMode error struct" do
      error = %ServiceUnavailable.MaintenanceMode{}
      assert is_struct(error)
    end

    test "can create a CircuitBreakerOpen error struct" do
      error = %ServiceUnavailable.CircuitBreakerOpen{}
      assert is_struct(error)
    end

    test "can create a RateLimitExceeded error struct" do
      error = %ServiceUnavailable.RateLimitExceeded{}
      assert is_struct(error)
    end

    test "can create a CapacityExceeded error struct" do
      error = %ServiceUnavailable.CapacityExceeded{}
      assert is_struct(error)
    end
  end
end
