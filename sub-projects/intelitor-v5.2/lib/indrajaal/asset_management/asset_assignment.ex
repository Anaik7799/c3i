defmodule Indrajaal.AssetManagement.AssetAssignment do
  @moduledoc """
  Asset assignment history and current assignments to __users and locations.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :assignment_type, :atom do
      constraints one_of: [:user, :location, :department, :project]
      allow_nil? false
    end

    attribute :assigned_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :unassigned_at, :utc_datetime

    attribute :is_current, :boolean do
      default true
    end

    attribute :assignment_reason, :string do
      constraints max_length: 500
    end

    attribute :conditions, :string do
      constraints max_length: 1000
    end

    attribute :expected_return_date, :date

    attribute :assignment_notes, :string do
      constraints max_length: 1000
    end

    attribute :responsibility_level, :atom do
      constraints one_of: [:full, :shared, :temporary, :custodial]
      default :full
    end

    timestamps()
  end

  relationships do
    belongs_to :asset, Indrajaal.AssetManagement.Asset do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :assigned_to_user, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :assigned_to_location, Indrajaal.AssetManagement.AssetLocation do
      attribute_writable? true
    end

    belongs_to :assigned_by, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :unassigned_by, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :assign_to_user do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :assigned_by_id, :uuid do
        allow_nil? false
      end

      argument :assignment_reason, :string

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:assigned_to_user_id, arg(:user_id))
      change set_attribute(:assigned_by_id, arg(:assigned_by_id))
      change set_attribute(:assignment_type, :user)
      change set_attribute(:assignment_reason, arg(:assignment_reason))
    end

    create :assign_to_location do
      argument :asset_id, :uuid do
        allow_nil? false
      end

      argument :location_id, :uuid do
        allow_nil? false
      end

      argument :assigned_by_id, :uuid do
        allow_nil? false
      end

      argument :assignment_reason, :string

      change set_attribute(:asset_id, arg(:asset_id))
      change set_attribute(:assigned_to_location_id, arg(:location_id))
      change set_attribute(:assigned_by_id, arg(:assigned_by_id))
      change set_attribute(:assignment_type, :location)
      change set_attribute(:assignment_reason, arg(:assignment_reason))
    end

    update :unassign do
      require_atomic? false

      argument :unassigned_by_id, :uuid do
        allow_nil? false
      end

      argument :unassignment_reason, :string

      change set_attribute(:is_current, false)
      change set_attribute(:unassigned_at, &DateTime.utc_now/0)
      change set_attribute(:unassigned_by_id, arg(:unassigned_by_id))
      change set_attribute(:assignment_notes, arg(:unassignment_reason))
    end

    update :extend_assignment do
      require_atomic? false

      argument :new_return_date, :date do
        allow_nil? false
      end

      change set_attribute(:expected_return_date, arg(:new_return_date))
    end
  end

  validations do
    validate present([:assigned_to_user_id, :assigned_to_location_id],
               count: 1
             ),
             message: "Asset must be assigned to either a user or location,
        but not both"

    validate compare(:expected_return_date, greater_than: :assigned_at),
      message: "Expected return date must be after assignment date",
      where: [present(:expected_return_date)]
  end

  code_interface do
    define :create
    define :assign_to_user
    define :assign_to_location
    define :unassign
    define :extend_assignment
  end

  postgres do
    table "asset_assignments"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :asset_id]
      index [:tenant_id, :assigned_to_user_id]
      index [:tenant_id, :assigned_to_location_id]
      index [:tenant_id, :is_current]
      index [:tenant_id, :assignment_type]
      index [:tenant_id, :assigned_at]

      index [:tenant_id, :expected_return_date],
        where: "expected_return_date IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
