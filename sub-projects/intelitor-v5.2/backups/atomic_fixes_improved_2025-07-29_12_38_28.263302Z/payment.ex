defmodule Intelitor.Billing.Payment do
  @moduledoc """
  Represents payment transactions and payment processing.

  Payments track all financial transactions including successful payments,
  failed attempts, refunds, and chargebacks. They provide comprehensive
  payment processing integration with multiple payment providers and
  detailed transaction audit trails.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Billing,
    table: "billing_payments"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Payment identification
    attribute :payment_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :invoice_id, :uuid do
      public? true
    end

    attribute :subscription_id, :uuid do
      public? true
    end

    attribute :customer_id, :uuid do
      allow_nil? false
      public? true
    end

    # Payment details
    attribute :payment_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :subscription,
                    :invoice,
                    :one_time,
                    :refund,
                    :partial_refund,
                    :chargeback,
                    :adjustment,
                    :credit,
                    :fee,
                    :penalty
                  ]

      default :invoice
    end

    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pending,
                    :processing,
                    :succeeded,
                    :failed,
                    :cancelled,
                    :refunded,
                    :partially_refunded,
                    :disputed,
                    :chargeback
                  ]

      default :pending
    end

    # Financial amounts
    attribute :amount, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    attribute :fee_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :net_amount, :decimal do
      allow_nil? false
      public? true

      constraints precision: 10,
                  scale: 2
    end

    attribute :refunded_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0

      default 0.00
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      constraints max_length: 3
      default "USD"
    end

    # Payment method information
    attribute :payment_method_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :credit_card,
                    :debit_card,
                    :bank_transfer,
                    :ach,
                    :wire_transfer,
                    :paypal,
                    :apple_pay,
                    :google_pay,
                    :cryptocurrency,
                    :check,
                    :cash,
                    :store_credit,
                    :gift_card
                  ]

      default :credit_card
    end

    attribute :payment_method_details, :map do
      public? true
      default %{}
    end

    attribute :card_last_four, :string do
      public? true
      constraints max_length: 4
    end

    attribute :card_brand, :string do
      public? true
      constraints max_length: 20
    end

    attribute :card_exp_month, :integer do
      public? true
      constraints min: 1, max: 12
    end

    attribute :card_exp_year, :integer do
      public? true
      constraints min: 2020, max: 2040
    end

    # Payment provider information
    attribute :payment_provider, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :provider_transaction_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :provider_customer_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :provider_payment_method_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :provider_response, :map do
      public? true
      default %{}
    end

    # Transaction timeline
    attribute :attempted_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :processed_at, :utc_datetime_usec do
      public? true
    end

    attribute :succeeded_at, :utc_datetime_usec do
      public? true
    end

    attribute :failed_at, :utc_datetime_usec do
      public? true
    end

    attribute :refunded_at, :utc_datetime_usec do
      public? true
    end

    # Authorization and capture
    attribute :authorization_code, :string do
      public? true
      constraints max_length: 50
    end

    attribute :authorized_at, :utc_datetime_usec do
      public? true
    end

    attribute :captured?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :captured_at, :utc_datetime_usec do
      public? true
    end

    attribute :capture_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2,
                  min: 0
    end

    # Failure and error handling
    attribute :failure_reason, :string do
      public? true
      constraints max_length: 200
    end

    attribute :failure_code, :string do
      public? true
      constraints max_length: 50
    end

    attribute :decline_reason, :string do
      public? true
      constraints max_length: 200
    end

    attribute :retry_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :last_retry_at, :utc_datetime_usec do
      public? true
    end

    attribute :next_retry_at, :utc_datetime_usec do
      public? true
    end

    # Risk and fraud detection
    attribute :risk_score, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :risk_level, :atom do
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
    end

    attribute :fraud_indicators, {:array, :string} do
      public? true
      default []
    end

    attribute :verification_checks, :map do
      public? true
      default %{}
    end

    attribute :three_d_secure?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :three_d_secure_result, :string do
      public? true
      constraints max_length: 50
    end

    # Customer information
    attribute :billing_address, :map do
      public? true
      default %{}
    end

    attribute :customer_ip, :string do
      public? true
      # IPv6 address
      constraints max_length: 45
    end

    attribute :customer_email, :string do
      public? true
      constraints max_length: 255
    end

    attribute :customer_phone, :string do
      public? true
      constraints max_length: 20
    end

    # Refunds and adjustments
    attribute :refundable?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :refund_reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :refund_reference, :string do
      public? true
      constraints max_length: 100
    end

    attribute :partial_refunds, {:array, :map} do
      public? true
      default []
    end

    # Disputes and chargebacks
    attribute :disputed?, :boolean do
      allow_nil? false
      public? true
      default false
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

    attribute :dispute_status, :atom do
      public? true
      constraints one_of: [:open, :under_review, :won, :lost, :cancelled]
    end

    attribute :dispute_evidence, :map do
      public? true
      default %{}
    end

    # Settlement and reconciliation
    attribute :settled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :settled_at, :utc_datetime_usec do
      public? true
    end

    attribute :settlement_amount, :decimal do
      public? true

      constraints precision: 10,
                  scale: 2
    end

    attribute :settlement_currency, :string do
      public? true
      constraints max_length: 3
    end

    attribute :settlement_rate, :decimal do
      public? true

      constraints precision: 10,
                  scale: 6,
                  min: 0
    end

    # Reporting and analytics
    attribute :merchant_category_code, :string do
      public? true
      constraints max_length: 4
    end

    attribute :industry_type, :string do
      public? true
      constraints max_length: 50
    end

    attribute :payment_source, :atom do
      public? true
      constraints one_of: [:online, :in_person, :phone, :mail, :recurring, :api]
    end

    attribute :channel, :string do
      public? true
      constraints max_length: 50
    end

    # Compliance and regulation
    attribute :pci_compliant?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :gdpr_compliant?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :data_retention_days, :integer do
      public? true
      # 20 years
      constraints min: 1, max: 7300
    end

    # Notifications and communication
    attribute :receipt_sent?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :receipt_email, :string do
      public? true
      constraints max_length: 255
    end

    attribute :notification_sent?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :notification_preferences, :map do
      public? true
      default %{}
    end

    # Webhook and API integration
    attribute :webhook_delivered?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :webhook_attempts, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :api_version, :string do
      public? true
      constraints max_length: 20
    end

    attribute :integration_metadata, :map do
      public? true
      default %{}
    end

    # Business information
    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :reference_number, :string do
      public? true
      constraints max_length: 100
    end

    attribute :order_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :invoice_number, :string do
      public? true
      constraints max_length: 50
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
    belongs_to :invoice, Intelitor.Billing.Invoice do
      attribute_public? true
    end

    belongs_to :subscription, Intelitor.Billing.Subscription do
      attribute_public? true
    end

    belongs_to :customer, Intelitor.Accounts.User do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :invoice_id,
        :subscription_id,
        :customer_id,
        :payment_type,
        :amount,
        :fee_amount,
        :currency,
        :payment_method_type,
        :payment_method_details,
        :card_last_four,
        :card_brand,
        :card_exp_month,
        :card_exp_year,
        :payment_provider,
        :provider_transaction_id,
        :provider_customer_id,
        :provider_payment_method_id,
        :authorization_code,
        :billing_address,
        :customer_ip,
        :customer_email,
        :customer_phone,
        :risk_score,
        :risk_level,
        :fraud_indicators,
        :verification_checks,
        :three_d_secure?,
        :three_d_secure_result,
        :merchant_category_code,
        :industry_type,
        :payment_source,
        :channel,
        :description,
        :reference_number,
        :order_id,
        :invoice_number,
        :metadata
      ]

      change fn changeset, _context ->
        now = DateTime.utc_now()
        amount = Ash.Changeset.get_argument_or_attribute(changeset, :amount)

        fee_amount =
          Ash.Changeset.get_argument_or_attribute(changeset, :fee_amount) || Decimal.new(0)

        changeset
        |> generate_payment_number()
        |> Ash.Changeset.force_change_attribute(:attempted_at, now)
        |> Ash.Changeset.force_change_attribute(:status, :pending)
        |> Ash.Changeset.force_change_attribute(
          :net_amount,
          Decimal.sub(
            amount,
            fee_amount
          )
        )
      end
    end


    update :authorize do
      require_atomic? false
      accept [:status, :authorization_code, :authorized_at, :provider_response]

      argument :authorization_code, :string do
        allow_nil? false
        constraints max_length: 50
      end

      argument :provider_response, :map do
        default %{}
      end

      validate attribute_equals(:status, :pending)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :processing)
        |> Ash.Changeset.force_change_attribute(
          :authorization_code,
          changeset.arguments.authorization_code
        )
        |> Ash.Changeset.force_change_attribute(:authorized_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :provider_response,
          changeset.arguments.provider_response
        )
      end
    end

    update :capture do
      require_atomic? false
      accept [:captured?, :captured_at, :capture_amount, :status, :succeeded_at]

      argument :capture_amount, :decimal do
        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      validate attribute_equals(:status, :processing)

      change fn changeset, _context ->
        now = DateTime.utc_now()

        capture_amount =
          changeset.arguments.capture_amount || Ash.Changeset.get_attribute(changeset, :amount)

        changeset
        |> Ash.Changeset.force_change_attribute(:captured?, true)
        |> Ash.Changeset.force_change_attribute(:captured_at, now)
        |> Ash.Changeset.force_change_attribute(:capture_amount, capture_amount)
        |> Ash.Changeset.force_change_attribute(:status, :succeeded)
        |> Ash.Changeset.force_change_attribute(:succeeded_at, now)
      end
    end

    update :fail do
      require_atomic? false
      
      
      accept [:status, :failed_at, :failure_reason, :failure_code, :decline_reason]

      argument :failure_reason, :string do
        allow_nil? false
        constraints max_length: 200
      end

      argument :failure_code, :string do
        constraints max_length: 50
      end

      argument :decline_reason, :string do
        constraints max_length: 200
      end

      validate attribute_in(:status, [:pending, :processing])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :failed)
        |> Ash.Changeset.force_change_attribute(:failed_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :failure_reason,
          changeset.arguments.failure_reason
        )
        |> (fn cs ->
              if code = changeset.arguments.failure_code do
                Ash.Changeset.force_change_attribute(cs, :failure_code, code)
              else
                cs
              end
            end).()
        |> (fn cs ->
              if reason = changeset.arguments.decline_reason do
                Ash.Changeset.force_change_attribute(cs, :decline_reason, reason)
              else
                cs
              end
            end).()
      end
    end

    update :refund do
      require_atomic? false
      accept [:refunded_amount, :refund_reason, :refund_reference, :partial_refunds]

      argument :refund_amount, :decimal do
        allow_nil? false

        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      argument :reason, :string do
        constraints max_length: 500
      end

      argument :reference, :string do
        constraints max_length: 100
      end

      validate attribute_equals(:status, :succeeded)
      validate attribute_equals(:refundable?, true)

      change fn changeset, _context ->
        refund_amount = changeset.arguments.refund_amount
        reason = changeset.arguments.reason
        reference = changeset.arguments.reference

        current_refunded = Ash.Changeset.get_attribute(changeset, :refunded_amount)
        total_amount = Ash.Changeset.get_attribute(changeset, :amount)

        new_refunded_amount = Decimal.add(current_refunded, refund_amount)
        partial_refunds = Ash.Changeset.get_attribute(changeset, :partial_refunds) || []

        refund_entry = %{
          "amount" => refund_amount,
          "reason" => reason,
          "reference" => reference,
          "refunded_at" => DateTime.utc_now()
        }

        new_status =
          if Decimal.compare(new_refunded_amount, total_amount) == :eq do
            :refunded
          else
            :partially_refunded
          end

        changeset
        |> Ash.Changeset.force_change_attribute(:refunded_amount, new_refunded_amount)
        |> Ash.Changeset.force_change_attribute(:status, new_status)
        |> Ash.Changeset.force_change_attribute(:refunded_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:refund_reason, reason)
        |> Ash.Changeset.force_change_attribute(:refund_reference, reference)
        |> Ash.Changeset.force_change_attribute(
          :partial_refunds,
          [refund_entry | partial_refunds]
        )
      end
    end

    update :dispute do
      require_atomic? false
      accept [:disputed?, :dispute_reason, :dispute_amount, :dispute_status, :status]

      argument :dispute_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      argument :dispute_amount, :decimal do
        constraints precision: 10,
                    scale: 2,
                    min: 0
      end

      validate attribute_equals(:status, :succeeded)

      change fn changeset, _context ->
        dispute_amount =
          changeset.arguments.dispute_amount || Ash.Changeset.get_attribute(changeset, :amount)

        changeset
        |> Ash.Changeset.force_change_attribute(:disputed?, true)
        |> Ash.Changeset.force_change_attribute(
          :dispute_reason,
          changeset.arguments.dispute_reason
        )
        |> Ash.Changeset.force_change_attribute(:dispute_amount, dispute_amount)
        |> Ash.Changeset.force_change_attribute(:dispute_status, :open)
        |> Ash.Changeset.force_change_attribute(:status, :disputed)
      end
    end

    update :settle do
      require_atomic? false
      accept [:settled?, :settled_at, :settlement_amount, :settlement_currency, :settlement_rate]

      argument :settlement_amount, :decimal do
        constraints precision: 10,
                    scale: 2
      end

      argument :settlement_currency, :string do
        constraints max_length: 3
      end

      argument :settlement_rate, :decimal do
        constraints precision: 10,
                    scale: 6,
                    min: 0
      end

      validate attribute_equals(:status, :succeeded)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:settled?, true)
        |> Ash.Changeset.force_change_attribute(:settled_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(
          :settlement_amount,
          changeset.arguments.settlement_amount
        )
        |> Ash.Changeset.force_change_attribute(
          :settlement_currency,
          changeset.arguments.settlement_currency
        )
        |> Ash.Changeset.force_change_attribute(
          :settlement_rate,
          changeset.arguments.settlement_rate
        )
      end
    end

    update :retry do
      require_atomic? false
      accept [:retry_count, :last_retry_at, :next_retry_at, :status]

      validate attribute_equals(:status, :failed)

      change fn changeset, _context ->
        current_retries = Ash.Changeset.get_attribute(changeset, :retry_count)
        now = DateTime.utc_now()

        # Calculate next retry with exponential backoff
        # Hours
        next_retry = DateTime.add(now, (current_retries + 1) * 3600, :second)

        changeset
        |> Ash.Changeset.force_change_attribute(:retry_count, current_retries + 1)
        |> Ash.Changeset.force_change_attribute(:last_retry_at, now)
        |> Ash.Changeset.force_change_attribute(:next_retry_at, next_retry)
        |> Ash.Changeset.force_change_attribute(:status, :pending)
      end
    end

    update :send_receipt do
      require_atomic? false
      accept [:receipt_sent?, :receipt_email, :notification_sent?]

      argument :email, :string do
        constraints max_length: 255
      end

      validate attribute_equals(:status, :succeeded)

      change fn changeset, _context ->
        email =
          changeset.arguments.email || Ash.Changeset.get_attribute(changeset, :customer_email)

        changeset
        |> Ash.Changeset.force_change_attribute(:receipt_sent?, true)
        |> Ash.Changeset.force_change_attribute(:receipt_email, email)
        |> Ash.Changeset.force_change_attribute(:notification_sent?, true)
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_successful?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn payment ->
              payment.status == :succeeded
            end
          )

        {:ok, values}
      end
    end

    calculate :processing_time_seconds, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn payment ->
              if payment.attempted_at && payment.processed_at do
                DateTime.diff(
                  payment.processed_at,
                  payment.attempted_at,
                  :second
                )
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :refund_percentage, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn payment ->
            if Decimal.compare(payment.amount, 0) == :gt do
              Decimal.div(payment.refunded_amount, payment.amount)
              |> Decimal.mult(100)
            else
              Decimal.new(0)
            end
          end)

        {:ok, values}
      end
    end

    calculate :fee_percentage, :decimal do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn payment ->
            if Decimal.compare(payment.amount, 0) == :gt do
              Decimal.div(payment.fee_amount, payment.amount)
              |> Decimal.mult(100)
            else
              Decimal.new(0)
            end
          end)

        {:ok, values}
      end
    end

    calculate :is_fully_refunded?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn payment ->
              Decimal.compare(
                payment.refunded_amount,
                payment.amount
              ) == :eq
            end
          )

        {:ok, values}
      end
    end

    calculate :days_since_payment, :integer do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        values =
          Enum.map(
            records,
            fn payment ->
              if payment.succeeded_at do
                DateTime.diff(
                  now,
                  payment.succeeded_at,
                  :day
                )
              else
                nil
              end
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
      # Customers can read their own payments
      authorize_if expr(customer_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "billing_manager")
    end

    policy action([
             :authorize,
             :capture,
             :fail,
             :refund,
             :dispute,
             :settle,
             :retry,
             :send_receipt
           ]) do
      # Payment system can update payment status
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :authorize
    define :capture
    define :fail
    define :refund
    define :dispute
    define :settle
    define :retry
    define :send_receipt
    define :destroy
  end

  postgres do
    table "billing_payments"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :payment_number], unique: true
      index [:invoice_id], where: "invoice_id IS NOT NULL"
      index [:subscription_id], where: "subscription_id IS NOT NULL"
      index [:customer_id]
      index [:payment_type]
      index [:status]
      index [:payment_method_type]
      index [:payment_provider]
      index [:provider_transaction_id], where: "provider_transaction_id IS NOT NULL"
      index [:attempted_at]
      index [:processed_at], where: "processed_at IS NOT NULL"
      index [:succeeded_at], where: "succeeded_at IS NOT NULL"
      index [:failed_at], where: "failed_at IS NOT NULL"
      index [:captured?], name: "payments_captured_index", where: "captured? = true"
      index [:refundable?], name: "payments_refundable_index", where: "refundable? = true"
      index [:disputed?], name: "payments_disputed_index", where: "disputed? = true"
      index [:settled?], name: "payments_settled_index", where: "settled? = true"
      index [:receipt_sent?], name: "payments_receipt_sent_index", where: "receipt_sent? = true"
      index [:amount]
      index [:currency]
      index [:risk_level], where: "risk_level IS NOT NULL"
      index [:settlement_amount], where: "settlement_amount IS NOT NULL"
      index [:next_retry_at], where: "next_retry_at IS NOT NULL"
    end
  end

  # Helper functions
  defp generate_payment_number(changeset) do
    # Generate payment number like PAY-20251206-001
    date_str = Date.utc_today() |> Date.to_string() |> String.replace("-", "")

    random_suffix =
      :rand.uniform(999)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    payment_number = "PAY-#{date_str}-#{random_suffix}"

    Ash.Changeset.force_change_attribute(changeset, :payment_number, payment_number)
  end
end
