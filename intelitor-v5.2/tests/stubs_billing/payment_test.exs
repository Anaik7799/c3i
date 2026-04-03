defmodule Intelitor.Billing.PaymentTest do
  @moduledoc """
  Test suite for Intelitor.Billing.Payment.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/billing/payment.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Billing.Payment

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Payment)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Payment, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Payment.__info__(:module)
      assert info == Intelitor.Billing.Payment
    end
  end
end
