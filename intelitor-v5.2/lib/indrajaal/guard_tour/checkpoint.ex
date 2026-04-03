defmodule Indrajaal.GuardTour.Checkpoint do
  @moduledoc """
  Physical checkpoints along patrol routes with NFC / QR code scanning.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.GuardTour

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :location_description, :string do
      constraints max_length: 500
    end

    attribute :checkpoint_type, :atom do
      constraints one_of: [:nfc, :qr_code, :biometric, :manual]
      allow_nil? false
    end

    attribute :identifier_code, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :latitude, :decimal do
      constraints precision: 10, scale: 8
    end

    attribute :longitude, :decimal do
      constraints precision: 11, scale: 8
    end

    attribute :is_mandatory, :boolean do
      default true
    end

    attribute :max_scan_time, :integer do
      default 30
      constraints min: 5, max: 300
    end

    attribute :instructions, :string do
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :route, Indrajaal.GuardTour.TourRoute do
      attribute_writable? true
    end

    belongs_to :location, Indrajaal.Sites.Location do
      attribute_writable? true
    end

    has_many :checkpoint_scans, Indrajaal.GuardTour.CheckpointScan do
      destination_attribute :checkpoint_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  code_interface do
    define :create
  end

  postgres do
    table "checkpoints"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :route_id]
      index [:tenant_id, :identifier_code], unique: true
      index [:tenant_id, :checkpoint_type]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
