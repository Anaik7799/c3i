defmodule Indrajaal.GuardTour.CheckpointScan do
  @moduledoc """
  Individual checkpoint scanning __events during patrol execution.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :scanned_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :scan_method, :atom do
      constraints one_of: [:nfc, :qr_code, :biometric, :manual, :gps]
      allow_nil? false
    end

    attribute :scan_status, :atom do
      constraints one_of: [:successful, :failed, :missed, :late]
      allow_nil? false
    end

    attribute :latitude, :decimal do
      constraints precision: 10, scale: 8
    end

    attribute :longitude, :decimal do
      constraints precision: 11, scale: 8
    end

    attribute :notes, :string do
      constraints max_length: 500
    end

    attribute :scan_duration, :integer
    attribute :device_info, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :execution, Indrajaal.GuardTour.TourExecution do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :checkpoint, Indrajaal.GuardTour.Checkpoint do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :guard, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :record_scan do
      argument :checkpoint_id, :uuid do
        allow_nil? false
      end

      argument :execution_id, :uuid do
        allow_nil? false
      end

      argument :guard_id, :uuid do
        allow_nil? false
      end

      argument :scan_method, :atom do
        allow_nil? false
      end

      argument :latitude, :decimal
      argument :longitude, :decimal

      change set_attribute(:checkpoint_id, arg(:checkpoint_id))
      change set_attribute(:execution_id, arg(:execution_id))
      change set_attribute(:guard_id, arg(:guard_id))
      change set_attribute(:scan_method, arg(:scan_method))
      change set_attribute(:latitude, arg(:latitude))
      change set_attribute(:longitude, arg(:longitude))
      change set_attribute(:scan_status, :successful)
    end
  end

  code_interface do
    define :create
    define :record_scan
  end

  postgres do
    table "checkpoint_scans"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :execution_id]
      index [:tenant_id, :checkpoint_id]
      index [:tenant_id, :guard_id]
      index [:tenant_id, :scanned_at]
      index [:tenant_id, :scan_status]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
