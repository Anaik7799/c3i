defmodule Indrajaal.Errors.ExternalTest do
  @moduledoc """
  Tests for Indrajaal.Errors.External namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.External

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(External)
    end
  end

  describe "sub-errors" do
    test "External.ApiConnectionFailed sub-module exists" do
      assert Code.ensure_loaded?(External.ApiConnectionFailed)
    end

    test "External.ApiRateLimitExceeded sub-module exists" do
      assert Code.ensure_loaded?(External.ApiRateLimitExceeded)
    end

    test "External.WebhookDeliveryFailed sub-module exists" do
      assert Code.ensure_loaded?(External.WebhookDeliveryFailed)
    end

    test "External.EmailDeliveryFailed sub-module exists" do
      assert Code.ensure_loaded?(External.EmailDeliveryFailed)
    end

    test "External.SmsDeliveryFailed sub-module exists" do
      assert Code.ensure_loaded?(External.SmsDeliveryFailed)
    end

    test "External.PaymentProcessingFailed sub-module exists" do
      assert Code.ensure_loaded?(External.PaymentProcessingFailed)
    end

    test "External.CloudStorageError sub-module exists" do
      assert Code.ensure_loaded?(External.CloudStorageError)
    end

    test "External.ActiveDirectoryError sub-module exists" do
      assert Code.ensure_loaded?(External.ActiveDirectoryError)
    end

    test "External.VideoStreamError sub-module exists" do
      assert Code.ensure_loaded?(External.VideoStreamError)
    end

    test "External.IntegrationSyncFailed sub-module exists" do
      assert Code.ensure_loaded?(External.IntegrationSyncFailed)
    end
  end

  describe "error creation" do
    test "can create an ApiConnectionFailed error struct" do
      error = %External.ApiConnectionFailed{}
      assert is_struct(error)
    end

    test "can create an EmailDeliveryFailed error struct" do
      error = %External.EmailDeliveryFailed{}
      assert is_struct(error)
    end

    test "can create a WebhookDeliveryFailed error struct" do
      error = %External.WebhookDeliveryFailed{}
      assert is_struct(error)
    end

    test "can create a VideoStreamError error struct" do
      error = %External.VideoStreamError{}
      assert is_struct(error)
    end
  end
end
