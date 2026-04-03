defmodule Indrajaal.AssetManagement.AssetTransfer do
  @moduledoc """
  Asset transfers between locations, __users, and departments.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :transfer_type, :atom do
      constraints one_of: [
                    :location_change,
                    :__user_reassignment,
                    :department_transfer,
                    :temporary_loan,
                    :permanent_transfer
                  ]

      allow_nil? false
    end

    attribute :transfer_status, :atom do
      constraints one_of: [
                    :__requested,
                    :approved,
                    :in_transit,
                    :completed,
                    :rejected,
                    :cancelled
                  ]

      default :__requested
    end

    attribute :__requested_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :approved_at, :utc_datetime
    attribute :completed_at, :utc_datetime

    attribute :transfer_reason, :string do
      allow_nil? false
      constraints max_length: 500
    end

    attribute :expected_completion_date, :date

    attribute :shipping_method, :string do
      constraints max_length: 100
    end

    attribute :tracking_number, :string do
      constraints max_length: 100
    end

    attribute :transfer_cost, :decimal do
      constraints precision: 10, scale: 2
    end

    attribute :insurance_value, :decimal do
      constraints precision: 15, scale: 2
    end

    attribute :special_handling_required, :boolean do
      default false
    end

    attribute :handling_instructions, :string do
      constraints max_length: 1000
    end

    attribute :transfer_notes, :string do
      constraints max_length: 2000
    end

    attribute :condition_at_transfer, :atom do
      constraints one_of: [:excellent, :good, :fair, :poor, :damaged]
    end

    timestamps()
  end

  relationships do
    belongs_to :asset, Indrajaal.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :from_user, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :to_user, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :from_location, Indrajaal.AssetManagement.AssetLocation do
      attribute_writable? true
    end

    belongs_to :to_location, Indrajaal.AssetManagement.AssetLocation do
      attribute_writable? true
    end

    belongs_to :__requested_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :completed_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        today = Date.utc_today()

        Enum.map(records, fn record ->
          case record.expected_completion_date do
            nil ->
              false

            expected_date ->
              record.transfer_status not in [:completed, :cancelled, :rejected] &&
                Date.compare(today, expected_date) == :gt
          end
        end)
      end
    end

    calculate :days_in_transit, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case {record.transfer_status, record.approved_at} do
            {:in_transit, approved_at} when not is_nil(approved_at) ->
              DateTime.diff(DateTime.utc_now(), approved_at, :day)

            _ ->
              nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :__request_transfer do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :transfer_type, :atom do
        allow_nil? false
      end

      argument :transfer_reason, :string do
        allow_nil? false
      end

      argument :__requested_by_id, :uuid do
        allow_nil? false
      end

      argument :to_user_id, :uuid
      argument :to_location_id, :uuid

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:transfer_type, arg(:transfer_type))
      change set_attribute(:transfer_reason, arg(:transfer_reason))
      change set_attribute(:__requested_by_id, arg(:__requested_by_id))
      change set_attribute(:to_user_id, arg(:to_user_id))
      change set_attribute(:to_location_id, arg(:to_location_id))
    end

    update :approve_transfer do
      require_atomic? false

      argument :approved_by_id, :uuid do
        allow_nil? false
      end

      argument :expected_completion_date, :date

      change set_attribute(:transfer_status, :approved)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
      change set_attribute(:approved_by_id, arg(:approved_by_id))

      change set_attribute(
               :expected_completion_date,
               arg(:expected_completion_date)
             )
    end

    update :reject_transfer do
      require_atomic? false

      argument :rejected_by_id, :uuid do
        allow_nil? false
      end

      argument :rejection_reason, :string do
        allow_nil? false
      end

      change set_attribute(:transfer_status, :rejected)
      change set_attribute(:approved_by_id, arg(:rejected_by_id))
      change set_attribute(:transfer_notes, arg(:rejection_reason))
    end

    update :start_transfer do
      require_atomic? false
      argument :shipping_method, :string
      argument :tracking_number, :string

      change set_attribute(:transfer_status, :in_transit)
      change set_attribute(:shipping_method, arg(:shipping_method))
      change set_attribute(:tracking_number, arg(:tracking_number))
    end

    update :complete_transfer do
      require_atomic? false

      argument :completed_by_id, :uuid do
        allow_nil? false
      end

      argument :condition_at_transfer, :atom do
        allow_nil? false
      end

      argument :completion_notes, :string

      change set_attribute(:transfer_status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change set_attribute(:completed_by_id, arg(:completed_by_id))
      change set_attribute(:condition_at_transfer, arg(:condition_at_transfer))
      change set_attribute(:transfer_notes, arg(:completion_notes))
    end

    update :cancel_transfer do
      require_atomic? false

      argument :cancellation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:transfer_status, :cancelled)
      change set_attribute(:transfer_notes, arg(:cancellation_reason))
    end
  end

  validations do
    validate present([:to_user_id, :to_location_id], exactly: 1),
      message: "Transfer must specify either a destination user or location,
        but not both"
  end

  code_interface do
    define :create
    define :__request_transfer
    define :approve_transfer
    define :reject_transfer
    define :start_transfer
    define :complete_transfer
    define :cancel_transfer
  end

  postgres do
    table "asset_transfers"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :transfer_status]
      index [:tenant_id, :transfer_type]
      index [:tenant_id, :__requested_by_id]
      index [:tenant_id, :to_user_id]
      index [:tenant_id, :to_location_id]

      index [:tenant_id, :expected_completion_date],
        where: "expected_completion_date IS NOT NULL"

      index [:tenant_id, :tracking_number], where: "tracking_number IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
