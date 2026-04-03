defmodule Intelitor.Billing.Invoice do
  @moduledoc """
  Represents billing invoices and billing documents.

  Invoices track billing charges, line items, taxes, and payment status
  for subscriptions and one-time charges. They support complex billing
  scenarios including prorations, credits, discounts, and multi-currency
  transactions with comprehensive audit trails.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Billing,
    table: "billing_invoices"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Invoice identification
    attribute :invoice_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :subscription_id, :uuid do
      public? true
    end

    attribute :customer_id, :uuid do
      allow_nil? false
      public? true
    end

    # Invoice details
    attribute :invoice_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :subscription,
                    :usage,
                    :one_time,
                    :setup,
                    :overage,
                    :credit,
                    :adjustment,
                    :refund,
                    :late_fee,
                    :cancellation
                  ]

      default :subscription
    end

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :pending,
                    :sent,
                    :viewed,
                    :paid,
                    :partially_paid,
                    :overdue,
                    :cancelled,
                    :void,
                    :refunded,
                    :disputed
                  ]

      default :draft
    end

    # Dates and timeline
    attribute :invoice_date, :date do
      allow_nil? false
      public? true
    end

    attribute :due_date, :date do
      allow_nil? false
      public? true
    end

    attribute :period_start, :date do
      public? true
    end

    attribute :period_end, :date do
      public? true
    end

    attribute :sent_at, :utc_datetime_usec do
      public? true
    end

    attribute :viewed_at, :utc_datetime_usec do
      public? true
    end

    attribute :paid_at, :utc_datetime_usec do
      public? true
    end

    attribute :voided_at, :utc_datetime_usec do
      public? true
    end

    # Financial amounts
    attribute :subtotal, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2

      default 0.00
    end

    attribute :discount_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :tax_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :total_amount, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2
    end

    attribute :amount_paid, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :amount_due, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      constraints max_length: 3
      default "USD"
    end

    # Line items and details
    attribute :line_items, {:array, :map} do
      public? true
      default []
    end

    attribute :tax_breakdown, {:array, :map} do
      public? true
      default []
    end

    attribute :discount_breakdown, {:array, :map} do
      public? true
      default []
    end

    # Payment terms and methods
    attribute :payment_terms, :string do
      public? true
      constraints max_length: 100
      default "Net 30"
    end

    attribute :payment_methods, {:array, :string} do
      public? true
      default []
    end

    attribute :auto_charge?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :payment_attempts, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :last_payment_attempt, :utc_datetime_usec do
      public? true
    end

    attribute :next_payment_attempt, :utc_datetime_usec do
      public? true
    end

    # Customer and billing information
    attribute :billing_address, :map do
      public? true
      default %{}
    end

    attribute :shipping_address, :map do
      public? true
      default %{}
    end

    attribute :customer_email, :string do
      public? true
      constraints max_length: 255
    end

    attribute :customer_phone, :string do
      public? true
      constraints max_length: 20
    end

    # Business information
    attribute :purchase_order_number, :string do
      public? true
      constraints max_length: 50
    end

    attribute :reference_number, :string do
      public? true
      constraints max_length: 50
    end

    attribute :project_code, :string do
      public? true
      constraints max_length: 50
    end

    attribute :cost_center, :string do
      public? true
      constraints max_length: 50
    end

    # Invoice content
    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :footer_text, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :terms_and_conditions, :string do
      public? true
      constraints max_length: 5000
    end

    # Document management
    attribute :pdf_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :pdf_generated?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :pdf_generated_at, :utc_datetime_usec do
      public? true
    end

    attribute :document_template, :string do
      public? true
      constraints max_length: 100
    end

    # Communication and delivery
    attribute :delivery_method, :atom do
      public? true
      constraints one_of: [:email, :postal, :portal, :api, :manual]
      default :email
    end

    attribute :email_sent?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :email_opened?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :download_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :delivery_confirmations, {:array, :map} do
      public? true
      default []
    end

    # Collections and disputes
    attribute :overdue_days, :integer do
      public? true
      constraints min: 0
    end

    attribute :collection_status, :atom do
      public? true

      constraints one_of: [
                    :none,
                    :soft_collection,
                    :hard_collection,
                    :legal,
                    :written_off
                  ]
    end

    attribute :dispute_status, :atom do
      public? true
      constraints one_of: [:none, :disputed, :under_review, :resolved, :lost]
    end

    attribute :dispute_reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :dispute_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    # Dunning and automation
    attribute :dunning_level, :integer do
      public? true
      constraints min: 0, max: 10
      default 0
    end

    attribute :dunning_paused?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :auto_charge_enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :reminder_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :last_reminder_sent, :utc_datetime_usec do
      public? true
    end

    # Credits and adjustments
    attribute :credits_applied, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :credit_notes, {:array, :map} do
      public? true
      default []
    end

    attribute :adjustments, {:array, :map} do
      public? true
      default []
    end

    # External integrations
    attribute :external_invoice_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :payment_provider, :string do
      public? true
      constraints max_length: 50
    end

    attribute :payment_provider_invoice_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :accounting_system_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :sync_status, :atom do
      public? true
      constraints one_of: [:pending, :synced, :failed, :not_applicable]
    end

    attribute :sync_error, :string do
      public? true
      constraints max_length: 1000
    end

    # Compliance and taxation
    attribute :tax_exempt?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :tax_exempt_reason, :string do
      public? true
      constraints max_length: 200
    end

    attribute :tax_jurisdiction, :string do
      public? true
      constraints max_length: 100
    end

    attribute :vat_number, :string do
      public? true
      constraints max_length: 50
    end

    attribute :reverse_charge?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Analytics and reporting
    attribute :aging_bucket, :atom do
      public? true

      constraints one_of: [
                    :current,
                    :days_1_30,
                    :days_31_60,
                    :days_61_90,
                    :days_over_90
                  ]
    end

    attribute :collection_probability, :decimal do
      public? true

      constraints precision: 5,
                  scale: 2,
                  min: 0,
                  max: 100
    end

    attribute :payment_prediction_date, :date do
      public? true
    end

    # Workflow and approval
    attribute :approval_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :approved?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :approved_by, :uuid do
      public? true
    end

    attribute :approved_at, :utc_datetime_usec do
      public? true
    end

    # Metadata
    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :subscription, Intelitor.Billing.Subscription do
      attribute_public? true
    end

    belongs_to :customer, Intelitor.Accounts.User do
      attribute_public? true
    end

    belongs_to :approved_by_user, Intelitor.Accounts.User do
      source_attribute :approved_by
      attribute_public? true
    end

    has_many :payments, Intelitor.Billing.Payment
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :subscription_id,
        :customer_id,
        :invoice_type,
        :period_start,
        :period_end,
        :due_date,
        :line_items,
        :tax_breakdown,
        :discount_breakdown,
        :payment_terms,
        :payment_methods,
        :auto_charge?,
        :billing_address,
        :shipping_address,
        :customer_email,
        :customer_phone,
        :purchase_order_number,
        :reference_number,
        :project_code,
        :cost_center,
        :description,
        :notes,
        :footer_text,
        :terms_and_conditions,
        :document_template,
        :delivery_method,
        :auto_charge_enabled?,
        :tax_exempt?,
        :tax_exempt_reason,
        :tax_jurisdiction,
        :vat_number,
        :reverse_charge?,
        :approval_required?,
        :metadata
      ]

      change fn changeset, _context ->
        changeset
        |> generate_invoice_number()
        |> Ash.Changeset.force_change_attribute(:invoice_date, Date.utc_today())
        |> calculate_totals()
        |> set_due_date()
      end
    end

    update :finalize do
      require_atomic? false
      
      accept [:status]

      validate attribute_equals(:status, :draft)

      change fn changeset, _context ->
        # Final calculation before sending
        changeset
        |> calculate_totals()
        |> Ash.Changeset.force_change_attribute(:status, :pending)
      end
    end

    update :send_invoice do
      require_atomic? false
      
      accept [:status, :sent_at, :email_sent?]

      validate attribute_equals(:status, :pending)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :sent)
        |> Ash.Changeset.force_change_attribute(:sent_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:email_sent?, true)
      end
    end

    update :mark_viewed do
      require_atomic? false
      
      accept [:viewed_at, :email_opened?]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:viewed_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:email_opened?, true)
      end
    end

    update :record_payment do
      require_atomic? false
      
      accept [:amount_paid, :amount_due, :status, :paid_at]

      argument :payment_amount, :decimal do
        allow_nil? false

        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      change fn changeset, _context ->
        payment_amount = changeset.arguments.payment_amount
        current_paid = Ash.Changeset.get_attribute(changeset, :amount_paid)
        total_amount = Ash.Changeset.get_attribute(changeset, :total_amount)

        new_amount_paid = Decimal.add(current_paid, payment_amount)
        new_amount_due = Decimal.sub(total_amount, new_amount_paid)

        new_status =
          cond do
            Decimal.compare(new_amount_due, 0) == :eq -> :paid
            Decimal.compare(new_amount_paid, 0) == :gt -> :partially_paid
            true -> changeset.data.status
          end

        changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:amount_paid, new_amount_paid)
          |> Ash.Changeset.force_change_attribute(:amount_due, new_amount_due)
          |> Ash.Changeset.force_change_attribute(:status, new_status)

        if new_status == :paid do
          Ash.Changeset.force_change_attribute(changeset, :paid_at, DateTime.utc_now())
        else
          changeset
        end
      end
    end

    update :void do
      require_atomic? false
      
      accept [:status, :voided_at]

      validate attribute_in(:status, [:draft, :pending, :sent])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :void)
        |> Ash.Changeset.force_change_attribute(:voided_at, DateTime.utc_now())
      end
    end

    update :mark_overdue do
      require_atomic? false
      accept [:status, :overdue_days, :aging_bucket]

      validate attribute_in(:status, [:sent, :viewed, :partially_paid])

      change fn changeset, _context ->
        due_date = Ash.Changeset.get_attribute(changeset, :due_date)
        today = Date.utc_today()
        overdue_days = Date.diff(today, due_date)

        aging_bucket =
          cond do
            overdue_days <= 0 -> :current
            overdue_days <= 30 -> :days_1_30
            overdue_days <= 60 -> :days_31_60
            overdue_days <= 90 -> :days_61_90
            true -> :days_over_90
          end

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :overdue)
        |> Ash.Changeset.force_change_attribute(:overdue_days, max(0, overdue_days))
        |> Ash.Changeset.force_change_attribute(:aging_bucket, aging_bucket)
      end
    end

    update :apply_credit do
      require_atomic? false
      
      accept [:credits_applied, :amount_due, :credit_notes]

      argument :credit_amount, :decimal do
        allow_nil? false

        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      argument :credit_note, :string do
        constraints max_length: 500
      end

      change fn changeset, _context ->
        credit_amount = changeset.arguments.credit_amount
        credit_note = changeset.arguments.credit_note
        current_credits = Ash.Changeset.get_attribute(changeset, :credits_applied)
        current_due = Ash.Changeset.get_attribute(changeset, :amount_due)
        credit_notes = Ash.Changeset.get_attribute(changeset, :credit_notes) || []

        new_credits = Decimal.add(current_credits, credit_amount)
        new_amount_due = Decimal.sub(current_due, credit_amount)

        credit_entry = %{
          "amount" => credit_amount,
          "note" => credit_note,
          "applied_at" => DateTime.utc_now()
        }

        changeset
        |> Ash.Changeset.force_change_attribute(:credits_applied, new_credits)
        |> Ash.Changeset.force_change_attribute(:amount_due, new_amount_due)
        |> Ash.Changeset.force_change_attribute(
          :credit_notes,
          [credit_entry | credit_notes]
        )
      end
    end

    update :send_reminder do
      require_atomic? false
      
      accept [:reminder_count, :last_reminder_sent]

      change fn changeset, _context ->
        current_count = Ash.Changeset.get_attribute(changeset, :reminder_count)

        changeset
        |> Ash.Changeset.force_change_attribute(:reminder_count, current_count + 1)
        |> Ash.Changeset.force_change_attribute(:last_reminder_sent, DateTime.utc_now())
      end
    end

    update :approve do
      require_atomic? false
      accept [:approved?, :approved_by, :approved_at]

      argument :approved_by, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:approval_required?, true)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:approved?, true)
        |> Ash.Changeset.force_change_attribute(
          :approved_by,
          changeset.arguments.approved_by
        )
        |> Ash.Changeset.force_change_attribute(:approved_at, DateTime.utc_now())
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_overdue?, :boolean do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(records, fn invoice ->
            Date.compare(today, invoice.due_date) == :gt &&
              invoice.status in [:sent, :viewed, :partially_paid]
          end)

        {:ok, values}
      end
    end

    calculate :days_until_due, :integer do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(records, fn invoice ->
            Date.diff(invoice.due_date, today)
          end)

        {:ok, values}
      end
    end

    calculate :is_paid?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn invoice ->
            invoice.status == :paid
          end)

        {:ok, values}
      end
    end

    calculate :payment_percentage, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn invoice ->
              if Decimal.compare(
                   invoice.total_amount,
                   0
                 ) == :gt do
                Decimal.div(invoice.amount_paid, invoice.total_amount)
                |> Decimal.mult(100)
              else
                Decimal.new(0)
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :net_amount, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn invoice ->
              Decimal.sub(
                invoice.subtotal,
                invoice.discount_amount
              )
              |> Decimal.add(invoice.tax_amount)
              |> Decimal.sub(invoice.credits_applied)
            end
          )

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
      authorize_if actor_attribute_equals(:role, "accountant")
      authorize_if actor_attribute_equals(:role, "customer_service")
      # Customers can read their own invoices
      authorize_if expr(customer_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
      authorize_if actor_attribute_equals(:role, "accountant")
    end

    policy action([:finalize, :send_invoice, :void, :approve]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
    end

    policy action([:mark_viewed, :record_payment, :mark_overdue, :apply_credit, :send_reminder]) do
      # System can update status and payments
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :finalize
    define :send_invoice
    define :mark_viewed
    define :record_payment
    define :void
    define :mark_overdue
    define :apply_credit
    define :send_reminder
    define :approve
    define :destroy
  end

  postgres do
    table "billing_invoices"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :invoice_number], unique: true
      index [:subscription_id], where: "subscription_id IS NOT NULL"
      index [:customer_id]
      index [:approved_by], where: "approved_by IS NOT NULL"
      index [:invoice_type]
      index [:status]
      index [:invoice_date]
      index [:due_date]
      index [:period_start], where: "period_start IS NOT NULL"
      index [:period_end], where: "period_end IS NOT NULL"
      index [:sent_at], where: "sent_at IS NOT NULL"
      index [:paid_at], where: "paid_at IS NOT NULL"
      index [:auto_charge?], name: "invoices_auto_charge_index", where: "auto_charge? = true"
      index [:email_sent?], name: "invoices_email_sent_index", where: "email_sent? = true"
      index [:tax_exempt?], name: "invoices_tax_exempt_index", where: "tax_exempt? = true"

      index [:reverse_charge?],
        name: "invoices_reverse_charge_index",
        where: "reverse_charge? = true"

      index [:approval_required?],
        name: "invoices_approval_required_index",
        where: "approval_required? = true"

      index [:approved?], name: "invoices_approved_index", where: "approved? = true"
      index [:total_amount]
      index [:amount_due], where: "amount_due > 0"
      index [:aging_bucket], where: "aging_bucket IS NOT NULL"
      index [:collection_status], where: "collection_status IS NOT NULL"
      index [:currency]
    end
  end

  # Helper functions
  defp generate_invoice_number(changeset) do
    # Generate invoice number like INV-20251206-001
    date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_suffix =
      :rand.uniform(999)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    invoice_number = "INV-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(changeset, :invoice_number, invoice_number)
  end

  defp calculate_totals(changeset) do
    line_items = Ash.Changeset.get_argument_or_attribute(changeset, :line_items) || []

    subtotal =
      Enum.reduce(line_items, Decimal.new(0), fn item, acc ->
        amount = Decimal.new(item["amount"] || 0)
        Decimal.add(acc, amount)
      end)

    discount_amount =
      Ash.Changeset.get_argument_or_attribute(changeset, :discount_amount) || Decimal.new(0)

    tax_amount = Ash.Changeset.get_argument_or_attribute(changeset, :tax_amount) || Decimal.new(0)

    credits_applied =
      Ash.Changeset.get_argument_or_attribute(changeset, :credits_applied) || Decimal.new(0)

    total_amount =
      subtotal
      |> Decimal.sub(discount_amount)
      |> Decimal.add(tax_amount)

    amount_due = Decimal.sub(total_amount, credits_applied)

    changeset
    |> Ash.Changeset.force_change_attribute(:subtotal, subtotal)
    |> Ash.Changeset.force_change_attribute(:total_amount, total_amount)
    |> Ash.Changeset.force_change_attribute(:amount_due, amount_due)
  end

  defp set_due_date(changeset) do
    invoice_date =
      Ash.Changeset.get_argument_or_attribute(changeset, :invoice_date) || Date.utc_today()

    payment_terms = Ash.Changeset.get_argument_or_attribute(changeset, :payment_terms) || "Net 30"

    due_date =
      case payment_terms do
        "Net 30" -> Date.add(invoice_date, 30)
        "Net 15" -> Date.add(invoice_date, 15)
        "Net 7" -> Date.add(invoice_date, 7)
        "Due on Receipt" -> invoice_date
        # Default to 30 days
        _ -> Date.add(invoice_date, 30)
      end

    if Ash.Changeset.get_argument_or_attribute(changeset, :due_date) do
      changeset
    else
      Ash.Changeset.force_change_attribute(changeset, :due_date, due_date)
    end
  end
end
