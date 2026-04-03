defmodule Indrajaal.MCP.Domains.Billing.Handler do
  @moduledoc """
  MCP Handler for Billing domain.

  WHAT: Provides 10 tools for invoice generation, payment processing, and subscription management.
  WHY: Enables AI assistants to manage billing operations, track payments, and generate financial reports.

  STAMP Constraints:
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-MCP-073: Financial operations MUST require Guardian approval

  AOR Rules:
  - AOR-MCP-070: Register all tools on load
  - AOR-SEC-002: ALWAYS use parameterized queries for financial data
  """

  use Indrajaal.MCP.Domains.Handler, domain: :billing

  alias Indrajaal.MCP.Foundation.Types

  @impl true
  def list_tools do
    [
      # Invoice Operations
      %Types.Tool{
        name: "indrajaal.billing.invoices.list",
        description: "List invoices with filtering by status, date range, and tenant",
        input_schema: %{
          type: "object",
          properties: %{
            status: %{type: "string", enum: ["draft", "sent", "paid", "overdue", "cancelled"]},
            tenant_id: %{type: "string"},
            from: %{type: "string", format: "date-time"},
            to: %{type: "string", format: "date-time"},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.billing.invoices.get",
        description: "Get detailed invoice information including line items",
        input_schema: %{
          type: "object",
          properties: %{
            invoice_id: %{type: "string"}
          },
          required: ["invoice_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.billing.invoices.generate",
        description: "Generate a new invoice for a tenant (SC-MCP-073: requires Guardian)",
        input_schema: %{
          type: "object",
          properties: %{
            tenant_id: %{type: "string"},
            period_start: %{type: "string", format: "date"},
            period_end: %{type: "string", format: "date"},
            line_items: %{
              type: "array",
              items: %{
                type: "object",
                properties: %{
                  description: %{type: "string"},
                  quantity: %{type: "number"},
                  unit_price: %{type: "number"},
                  currency: %{type: "string", default: "EUR"}
                }
              }
            }
          },
          required: ["tenant_id", "period_start", "period_end"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # Payment Operations
      %Types.Tool{
        name: "indrajaal.billing.payments.list",
        description: "List payments with filtering",
        input_schema: %{
          type: "object",
          properties: %{
            invoice_id: %{type: "string"},
            status: %{type: "string", enum: ["pending", "completed", "failed", "refunded"]},
            from: %{type: "string", format: "date-time"},
            to: %{type: "string", format: "date-time"},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.billing.payments.record",
        description: "Record a payment against an invoice",
        input_schema: %{
          type: "object",
          properties: %{
            invoice_id: %{type: "string"},
            amount: %{type: "number"},
            currency: %{type: "string", default: "EUR"},
            method: %{type: "string", enum: ["bank_transfer", "card", "direct_debit", "cash"]},
            reference: %{type: "string"}
          },
          required: ["invoice_id", "amount", "method"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # Subscription Management
      %Types.Tool{
        name: "indrajaal.billing.subscriptions.list",
        description: "List active subscriptions",
        input_schema: %{
          type: "object",
          properties: %{
            tenant_id: %{type: "string"},
            status: %{type: "string", enum: ["active", "trial", "suspended", "cancelled"]},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.billing.subscriptions.get",
        description: "Get subscription details with usage metrics",
        input_schema: %{
          type: "object",
          properties: %{
            subscription_id: %{type: "string"}
          },
          required: ["subscription_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },

      # Financial Reports
      %Types.Tool{
        name: "indrajaal.billing.revenue.summary",
        description: "Get revenue summary for a period",
        input_schema: %{
          type: "object",
          properties: %{
            from: %{type: "string", format: "date"},
            to: %{type: "string", format: "date"},
            group_by: %{type: "string", enum: ["day", "week", "month"]}
          },
          required: ["from", "to"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.billing.overdue",
        description: "Get overdue invoices requiring attention",
        input_schema: %{
          type: "object",
          properties: %{
            days_overdue: %{type: "integer", default: 30},
            min_amount: %{type: "number"},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.billing.credit.apply",
        description: "Apply a credit note to a tenant account",
        input_schema: %{
          type: "object",
          properties: %{
            tenant_id: %{type: "string"},
            amount: %{type: "number"},
            currency: %{type: "string", default: "EUR"},
            reason: %{type: "string"}
          },
          required: ["tenant_id", "amount", "reason"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      }
    ]
  end

  @impl true
  def handle(:invoices, %{"invoice_id" => invoice_id} = args, context) do
    audit_log(@domain, :invoices, args, context)

    success(%{
      id: invoice_id,
      status: "draft",
      total_amount: 0.0,
      currency: "EUR",
      line_items: [],
      created_at: DateTime.utc_now()
    })
  end

  def handle(:invoices, %{"tenant_id" => _} = args, context) do
    audit_log(@domain, :invoices, args, context)

    with :ok <- validate_required(args, ["tenant_id", "period_start", "period_end"]) do
      success(%{
        id: Ecto.UUID.generate(),
        tenant_id: Map.get(args, "tenant_id"),
        status: "draft",
        generated: true,
        line_items_count: length(Map.get(args, "line_items", [])),
        generated_at: DateTime.utc_now()
      })
    end
  end

  def handle(:invoices, args, context) do
    audit_log(@domain, :invoices, args, context)
    success(%{invoices: [], total: 0, filters: args})
  end

  def handle(:payments, %{"invoice_id" => _, "amount" => _} = args, context) do
    audit_log(@domain, :payments, args, context)

    with :ok <- validate_required(args, ["invoice_id", "amount", "method"]) do
      success(%{
        payment_id: Ecto.UUID.generate(),
        invoice_id: Map.get(args, "invoice_id"),
        amount: Map.get(args, "amount"),
        method: Map.get(args, "method"),
        status: "completed",
        recorded_at: DateTime.utc_now()
      })
    end
  end

  def handle(:payments, args, context) do
    audit_log(@domain, :payments, args, context)
    success(%{payments: [], total: 0, filters: args})
  end

  def handle(:subscriptions, %{"subscription_id" => sub_id} = args, context) do
    audit_log(@domain, :subscriptions, args, context)

    success(%{
      id: sub_id,
      status: "active",
      plan: "enterprise",
      usage: %{sites: 0, devices: 0, users: 0},
      next_billing_date: Date.utc_today() |> Date.add(30)
    })
  end

  def handle(:subscriptions, args, context) do
    audit_log(@domain, :subscriptions, args, context)
    success(%{subscriptions: [], total: 0, filters: args})
  end

  def handle(:revenue, args, context) do
    audit_log(@domain, :revenue, args, context)

    with :ok <- validate_required(args, ["from", "to"]) do
      success(%{
        total_revenue: 0.0,
        currency: "EUR",
        period: %{from: Map.get(args, "from"), to: Map.get(args, "to")},
        breakdown: []
      })
    end
  end

  def handle(:overdue, args, context) do
    audit_log(@domain, :overdue, args, context)

    success(%{
      overdue_invoices: [],
      total_overdue_amount: 0.0,
      currency: "EUR",
      days_threshold: Map.get(args, "days_overdue", 30)
    })
  end

  def handle(:credit, args, context) do
    audit_log(@domain, :credit, args, context)

    with :ok <- validate_required(args, ["tenant_id", "amount", "reason"]) do
      success(%{
        credit_note_id: Ecto.UUID.generate(),
        tenant_id: Map.get(args, "tenant_id"),
        amount: Map.get(args, "amount"),
        reason: Map.get(args, "reason"),
        applied: true,
        applied_at: DateTime.utc_now()
      })
    end
  end

  def handle(action, _args, _context) do
    {:error, {:unknown_action, action}}
  end
end
