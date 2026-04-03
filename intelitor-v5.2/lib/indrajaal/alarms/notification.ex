defmodule Indrajaal.Alarms.Notification do
  @moduledoc """
  Manages notifications sent for alarm events.

  Notifications track all communications sent to customers, contacts, and
  authorities regarding alarm events, including delivery status and responses.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Alarms,
    table: "alarm_notifications"

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Notification identification
    attribute :alarm_event_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recipient_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :customer,
                    :contact,
                    :authority,
                    :operator,
                    :guard,
                    :supervisor,
                    :external
                  ]
    end

    attribute :recipient_id, :uuid do
      public? true
    end

    attribute :recipient_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    # Channel and content
    attribute :channel, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:email, :sms, :phone, :push, :webhook, :in_app]
    end

    attribute :recipient_address, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :subject, :string do
      public? true
      constraints max_length: 200
    end

    attribute :message, :string do
      allow_nil? false
      public? true
      constraints max_length: 2000
    end

    attribute :template_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :template_variables, :map do
      public? true
      default %{}
    end

    # Delivery status
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pending,
                    :queued,
                    :sending,
                    :delivered,
                    :failed,
                    :bounced,
                    :rejected,
                    :cancelled
                  ]

      default :pending
    end

    attribute :sent_at, :utc_datetime_usec do
      public? true
    end

    attribute :delivered_at, :utc_datetime_usec do
      public? true
    end

    attribute :failed_at, :utc_datetime_usec do
      public? true
    end

    attribute :failure_reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :retry_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0, max: 10
    end

    attribute :max_retries, :integer do
      allow_nil? false
      public? true
      default 3
      constraints min: 0, max: 10
    end

    # Provider information
    attribute :provider, :string do
      public? true
      constraints max_length: 50
    end

    attribute :provider_message_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :provider_response, :map do
      public? true
      default %{}
    end

    # Response tracking
    attribute :__requires_response?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :response_received?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :response_received_at, :utc_datetime_usec do
      public? true
    end

    attribute :response_text, :string do
      public? true
      constraints max_length: 500
    end

    attribute :response_action, :atom do
      public? true

      constraints one_of: [
                    :acknowledged,
                    :false_alarm,
                    :will_investigate,
                    :dispatch_requested,
                    :cancelled,
                    :other
                  ]
    end

    # Configuration
    attribute :priority, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :normal, :high, :urgent]
      default :normal
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :alarm_event, Indrajaal.Alarms.AlarmEvent do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :recipient_user, Indrajaal.Accounts.User do
      source_attribute :recipient_id
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :alarm_event_id,
        :recipient_type,
        :recipient_id,
        :recipient_name,
        :channel,
        :recipient_address,
        :subject,
        :message,
        :template_id,
        :template_variables,
        :__requires_response?,
        :priority,
        :expires_at,
        :provider,
        :max_retries
      ]

      argument :alarm_event_id, :uuid do
        allow_nil? false
      end

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :pending)
        |> set_expiration_if_missing()
      end
    end

    update :queue do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :pending)

      change set_attribute(:status, :queued)
    end

    update :mark_sending do
      require_atomic? false

      accept [:provider, :provider_message_id]

      validate attribute_in(:status, [:pending, :queued])

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :sending)
        |> Ash.Changeset.force_change_attribute(:sent_at, DateTime.utc_now())
      end
    end

    update :mark_delivered do
      require_atomic? false

      accept [:provider_response]

      validate attribute_equals(:status, :sending)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :delivered)
        |> Ash.Changeset.force_change_attribute(:delivered_at, DateTime.utc_now())
      end
    end

    update :mark_failed do
      require_atomic? false

      accept [:failure_reason, :provider_response]

      argument :failure_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :failed)
        |> Ash.Changeset.force_change_attribute(:failed_at, DateTime.utc_now())
        |> increment_retry_count()
      end
    end

    update :retry do
      require_atomic? false

      accept []

      validate attribute_equals(:status, :failed)

      validate fn changeset, __context ->
        retry_count = Ash.Changeset.get_attribute(changeset, :retry_count)
        max_retries = Ash.Changeset.get_attribute(changeset, :max_retries)

        if retry_count >= max_retries do
          {:error, field: :retry_count, message: "maximum retries exceeded"}
        else
          :ok
        end
      end

      change set_attribute(:status, :queued)
    end

    update :cancel do
      require_atomic? false

      accept []

      validate fn changeset, __context ->
        status = Ash.Changeset.get_attribute(changeset, :status)

        if status in [:delivered, :cancelled] do
          {:error, field: :status, message: "cannot cancel #{status} notification"}
        else
          :ok
        end
      end

      change set_attribute(:status, :cancelled)
    end

    update :record_response do
      require_atomic? false
      accept [:response_text, :response_action]

      argument :response_text, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:__requires_response?, true)
      validate attribute_equals(:response_received?, false)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:response_received?, true)
        |> Ash.Changeset.force_change_attribute(:response_received_at, DateTime.utc_now())
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :delivery_time_seconds, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn notification ->
            if notification.sent_at && notification.delivered_at do
              DateTime.diff(notification.delivered_at, notification.sent_at)
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :is_expired?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn notification ->
            notification.expires_at &&
              DateTime.compare(DateTime.utc_now(), notification.expires_at) == :gt
          end)

        {:ok, values}
      end
    end

    calculate :can_retry?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn notification ->
            notification.status == :failed &&
              notification.retry_count < notification.max_retries
          end)

        {:ok, values}
      end
    end

    calculate :response_pending?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn notification ->
            notification.__requires_response? &&
              !notification.response_received? &&
              notification.status == :delivered
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:create) do
      # System can create notifications
      authorize_if always()
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:update, :queue, :cancel]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:mark_sending, :mark_delivered, :mark_failed, :retry]) do
      # System actions for notification processing
      authorize_if always()
    end

    policy action(:record_response) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      # Recipients can record their own responses
      authorize_if expr(recipient_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :queue
    define :mark_sending
    define :mark_delivered
    define :mark_failed
    define :retry
    define :cancel
    define :record_response
    define :destroy
  end

  postgres do
    table "alarm_notifications"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :alarm_event_id]
      index [:recipient_type, :recipient_id]
      index [:channel]
      index [:status]
      index [:sent_at]

      index [:__requires_response?], name: "idx_alarm_notifications_requires_response"
      index [:response_received?], name: "idx_alarm_notifications_response_received"
      index [:expires_at]
    end
  end

  # Helper functions
  @spec set_expiration_if_missing(term()) :: term()
  defp set_expiration_if_missing(changeset) do
    if is_nil(Ash.Changeset.get_attribute(changeset, :expires_at)) do
      # Default expiration: 24 hours for normal, 1 hour for urgent
      priority = Ash.Changeset.get_attribute(changeset, :priority)

      expires_at =
        case priority do
          :urgent -> DateTime.add(DateTime.utc_now(), 3600, :second)
          _ -> DateTime.add(DateTime.utc_now(), 86_400, :second)
        end

      Ash.Changeset.force_change_attribute(changeset, :expires_at, expires_at)
    else
      changeset
    end
  end

  @spec increment_retry_count(term()) :: term()
  defp increment_retry_count(changeset) do
    current_count = Ash.Changeset.get_attribute(changeset, :retry_count)
    Ash.Changeset.force_change_attribute(changeset, :retry_count, current_count + 1)
  end
end
