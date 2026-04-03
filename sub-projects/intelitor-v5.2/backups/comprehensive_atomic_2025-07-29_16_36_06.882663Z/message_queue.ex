defmodule Intelitor.Communication.MessageQueue do
  @moduledoc """
  Message queue management for batching and rate-limited delivery.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Communication,
    table: "message_queues"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :queue_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :priority, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :queue_status, :atom do
      constraints one_of: [:active, :paused, :disabled, :error]
      default :active
    end

    attribute :processing_rate_per_minute, :integer do
      default 60
      constraints min: 1, max: 1000
    end

    attribute :retry_policy, :map do
      default %{
        "max_retries" => 3,
        "retry_delay_seconds" => 60,
        "backoff_multiplier" => 2
      }
    end

    attribute :dead_letter_enabled, :boolean do
      default true
    end

    attribute :batch_size, :integer do
      default 10
      constraints min: 1, max: 100
    end

    attribute :messages_pending, :integer do
      default 0
    end

    attribute :messages_processing, :integer do
      default 0
    end

    attribute :messages_failed, :integer do
      default 0
    end

    attribute :last_processed_at, :utc_datetime

    timestamps()
  end

  relationships do
    belongs_to :channel, Intelitor.Communication.NotificationChannel do
      allow_nil? false
      attribute_writable? true
    end
  end

  calculations do
    calculate :total_messages, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          (record.messages_pending || 0) +
            (record.messages_processing || 0) +
            (record.messages_failed || 0)
        end)
      end
    end

    calculate :success_rate, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          total =
            (record.messages_pending || 0) +
              (record.messages_processing || 0) +
              (record.messages_failed || 0)

          if total > 0 do
            failed = record.messages_failed || 0
            success_count = total - failed
            Decimal.div(Decimal.mult(success_count, 100), total)
          else
            Decimal.new(100)
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :create_queue do
      argument :queue_name, :string do
        allow_nil? false
      end

      argument :channel_id, :uuid do
        allow_nil? false
      end

      argument :priority, :atom do
        allow_nil? false
      end

      change set_attribute(:queue_name, arg(:queue_name))
      change set_attribute(:channel_id, arg(:channel_id))
      change set_attribute(:priority, arg(:priority))
    end

    update :pause_queue do
      require_atomic? false
      change set_attribute(:queue_status, :paused)
    end

    update :resume_queue do
      require_atomic? false
      change set_attribute(:queue_status, :active)
    end

    update :disable_queue do
      require_atomic? false
      change set_attribute(:queue_status, :disabled)
    end

    update :increment_pending do
      argument :count, :integer, default: 1

      change fn changeset, _ ->
        current = changeset.data.messages_pending || 0
        increment = Ash.Changeset.get_argument(changeset, :count)
        Ash.Changeset.change_attribute(changeset, :messages_pending, current + increment)
      end
    end

    update :increment_processing do
      require_atomic? false
      argument :count, :integer, default: 1

      change fn changeset, _ ->
        current_pending = changeset.data.messages_pending || 0
        current_processing = changeset.data.messages_processing || 0
        increment = Ash.Changeset.get_argument(changeset, :count)

        changeset
        |> Ash.Changeset.change_attribute(:messages_pending, current_pending - increment)
        |> Ash.Changeset.change_attribute(:messages_processing, current_processing + increment)
      end
    end

    update :increment_failed do
      require_atomic? false
      argument :count, :integer, default: 1

      change fn changeset, _ ->
        current_processing = changeset.data.messages_processing || 0
        current_failed = changeset.data.messages_failed || 0
        increment = Ash.Changeset.get_argument(changeset, :count)

        changeset
        |> Ash.Changeset.change_attribute(:messages_processing, current_processing - increment)
        |> Ash.Changeset.change_attribute(:messages_failed, current_failed + increment)
      end
    end

    update :complete_processing do
      require_atomic? false
      argument :count, :integer, default: 1

      change fn changeset, _ ->
        current = changeset.data.messages_processing || 0
        decrement = Ash.Changeset.get_argument(changeset, :count)

        changeset
        |> Ash.Changeset.change_attribute(:messages_processing, current - decrement)
        |> Ash.Changeset.change_attribute(:last_processed_at, DateTime.utc_now())
      end
    end
  end

  code_interface do
    define :create
    define :create_queue
    define :pause_queue
    define :resume_queue
    define :disable_queue
    define :increment_pending
    define :increment_processing
    define :increment_failed
    define :complete_processing
  end

  postgres do
    table "message_queues"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :channel_id]
      index [:tenant_id, :queue_status]
      index [:tenant_id, :priority]
      index [:tenant_id, :last_processed_at]
    end
  end
end
