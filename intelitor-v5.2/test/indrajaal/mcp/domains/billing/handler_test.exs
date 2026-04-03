defmodule Indrajaal.MCP.Domains.Billing.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Billing Handler.

  Tests 10 tools for invoice generation, payment processing,
  and subscription management.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-073: Financial operations MUST require Guardian approval
  - AOR-SEC-002: ALWAYS use parameterized queries for financial data

  ## TPS 5-Level RCA Context
  - L1 Symptom: Billing tool returns unexpected error
  - L5 Root Cause: Missing required fields or invalid currency format
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Billing.Handler
  alias StreamData, as: SD

  @moduletag :mcp_billing
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns 10 tools" do
      tools = Handler.list_tools()
      assert length(tools) == 10
    end

    test "invoice generation requires guardian" do
      tools = Handler.list_tools()
      gen = Enum.find(tools, &(&1.name == "indrajaal.billing.invoices.generate"))
      assert gen.requires_guardian == true
    end

    test "payment recording requires guardian" do
      tools = Handler.list_tools()
      rec = Enum.find(tools, &(&1.name == "indrajaal.billing.payments.record"))
      assert rec.requires_guardian == true
    end

    test "credit apply requires guardian" do
      tools = Handler.list_tools()
      credit = Enum.find(tools, &(&1.name == "indrajaal.billing.credit.apply"))
      assert credit.requires_guardian == true
    end

    test "listing operations do NOT require guardian" do
      tools = Handler.list_tools()
      list_tools = Enum.filter(tools, &String.contains?(&1.name, ".list"))

      Enum.each(list_tools, fn tool ->
        assert tool.requires_guardian == false,
               "#{tool.name} should not require guardian"
      end)
    end

    test "all tools are in indrajaal namespace" do
      tools = Handler.list_tools()
      Enum.each(tools, fn tool -> assert tool.namespace == :indrajaal end)
    end
  end

  # ── handle :invoices ───────────────────────────────────────────

  describe "handle/3 - :invoices" do
    test "list invoices returns empty list" do
      assert {:ok, data} = Handler.handle(:invoices, %{}, @context)
      assert data.invoices == []
      assert data.total == 0
    end

    test "get invoice by ID" do
      assert {:ok, data} =
               Handler.handle(:invoices, %{"invoice_id" => "inv-001"}, @context)

      assert data.id == "inv-001"
      assert data.status == "draft"
      assert data.currency == "EUR"
    end

    test "generate invoice for tenant" do
      args = %{
        "tenant_id" => "tenant-001",
        "period_start" => "2026-01-01",
        "period_end" => "2026-01-31"
      }

      assert {:ok, data} = Handler.handle(:invoices, args, @context)
      assert data.tenant_id == "tenant-001"
      assert data.generated == true
      assert Map.has_key?(data, :id)
    end

    test "generate invoice with line items" do
      args = %{
        "tenant_id" => "tenant-001",
        "period_start" => "2026-01-01",
        "period_end" => "2026-01-31",
        "line_items" => [
          %{"description" => "Service A", "quantity" => 1, "unit_price" => 100.0}
        ]
      }

      assert {:ok, data} = Handler.handle(:invoices, args, @context)
      assert data.line_items_count == 1
    end
  end

  # ── handle :payments ───────────────────────────────────────────

  describe "handle/3 - :payments" do
    test "list payments returns empty" do
      assert {:ok, data} = Handler.handle(:payments, %{}, @context)
      assert data.payments == []
    end

    test "record payment" do
      args = %{
        "invoice_id" => "inv-001",
        "amount" => 500.0,
        "method" => "bank_transfer"
      }

      assert {:ok, data} = Handler.handle(:payments, args, @context)
      assert data.invoice_id == "inv-001"
      assert data.amount == 500.0
      assert data.status == "completed"
      assert Map.has_key?(data, :payment_id)
    end

    test "record payment requires invoice_id, amount, method" do
      args = %{"invoice_id" => "inv-001", "amount" => 100.0}
      result = Handler.handle(:payments, args, @context)
      assert {:error, _} = result
    end
  end

  # ── handle :subscriptions ──────────────────────────────────────

  describe "handle/3 - :subscriptions" do
    test "list subscriptions" do
      assert {:ok, data} = Handler.handle(:subscriptions, %{}, @context)
      assert data.subscriptions == []
    end

    test "get subscription by ID" do
      assert {:ok, data} =
               Handler.handle(
                 :subscriptions,
                 %{"subscription_id" => "sub-001"},
                 @context
               )

      assert data.id == "sub-001"
      assert data.status == "active"
      assert data.plan == "enterprise"
      assert is_map(data.usage)
    end
  end

  # ── handle :revenue ────────────────────────────────────────────

  describe "handle/3 - :revenue" do
    test "get revenue summary" do
      args = %{"from" => "2026-01-01", "to" => "2026-01-31"}

      assert {:ok, data} = Handler.handle(:revenue, args, @context)
      assert data.currency == "EUR"
      assert is_number(data.total_revenue)
    end

    test "revenue requires from and to" do
      result = Handler.handle(:revenue, %{"from" => "2026-01-01"}, @context)
      assert {:error, _} = result
    end
  end

  # ── handle :overdue ────────────────────────────────────────────

  describe "handle/3 - :overdue" do
    test "get overdue invoices" do
      assert {:ok, data} = Handler.handle(:overdue, %{}, @context)
      assert data.overdue_invoices == []
      assert data.days_threshold == 30
    end

    test "overdue with custom threshold" do
      assert {:ok, data} =
               Handler.handle(:overdue, %{"days_overdue" => 60}, @context)

      assert data.days_threshold == 60
    end
  end

  # ── handle :credit ─────────────────────────────────────────────

  describe "handle/3 - :credit" do
    test "apply credit note" do
      args = %{
        "tenant_id" => "tenant-001",
        "amount" => 50.0,
        "reason" => "Service outage compensation"
      }

      assert {:ok, data} = Handler.handle(:credit, args, @context)
      assert data.tenant_id == "tenant-001"
      assert data.amount == 50.0
      assert data.applied == true
      assert Map.has_key?(data, :credit_note_id)
    end

    test "credit requires tenant_id, amount, reason" do
      args = %{"tenant_id" => "t1", "amount" => 10.0}
      result = Handler.handle(:credit, args, @context)
      assert {:error, _} = result
    end
  end

  # ── Unknown action ─────────────────────────────────────────────

  describe "handle/3 - unknown action" do
    test "returns error for unknown action" do
      assert {:error, {:unknown_action, :unknown}} =
               Handler.handle(:unknown, %{}, @context)
    end
  end

  # ── Property Tests ─────────────────────────────────────────────

  describe "property tests" do
    test "property: invoice get always returns valid data for any ID" do
      check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)) do
        {:ok, data} = Handler.handle(:invoices, %{"invoice_id" => id}, @context)
        assert data.id == id
        assert data.currency == "EUR"
      end
    end

    test "property: subscription get always returns active for any ID" do
      check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)) do
        {:ok, data} =
          Handler.handle(:subscriptions, %{"subscription_id" => id}, @context)

        assert data.status == "active"
      end
    end

    test "property: overdue threshold defaults correctly" do
      check all(days <- SD.integer(1..365)) do
        {:ok, data} =
          Handler.handle(:overdue, %{"days_overdue" => days}, @context)

        assert data.days_threshold == days
      end
    end
  end
end
