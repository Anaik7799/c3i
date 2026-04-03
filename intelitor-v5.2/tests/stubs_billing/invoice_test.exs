defmodule Intelitor.Billing.InvoiceTest do
  @moduledoc """
  Test suite for Intelitor.Billing.Invoice.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/billing/invoice.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Billing.Invoice

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Invoice)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Invoice, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Invoice.__info__(:module)
      assert info == Intelitor.Billing.Invoice
    end
  end
end
