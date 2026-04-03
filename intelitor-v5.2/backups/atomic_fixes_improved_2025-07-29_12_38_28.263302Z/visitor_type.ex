defmodule Intelitor.VisitorManagement.VisitorType do
  @moduledoc """
  Visitor types and categories for classification and policy application.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.VisitorManagement,
    table: "visitor_types"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :type_code, :string do
      allow_nil? false
      constraints max_length: 20
    end

    attribute :category, :atom do
      constraints one_of: [
                    :guest,
                    :contractor,
                    :vendor,
                    :delivery,
                    :service,
                    :vip,
                    :government,
                    :media,
                    :candidate
                  ]

      allow_nil? false
    end

    attribute :security_level, :atom do
      constraints one_of: [:public, :restricted, :confidential, :secret]
      default :public
    end

    attribute :requires_escort, :boolean do
      default false
    end

    attribute :requires_background_check, :boolean do
      default false
    end

    attribute :requires_training, :boolean do
      default false
    end

    attribute :max_visit_duration_hours, :integer do
      default 8
      constraints min: 1, max: 168
    end

    attribute :advance_notice_hours, :integer do
      default 24
      constraints min: 0, max: 720
    end

    attribute :approval_required, :boolean do
      default true
    end

    attribute :allowed_areas, {:array, :uuid} do
      default []
    end

    attribute :restricted_areas, {:array, :uuid} do
      default []
    end

    attribute :required_documents, {:array, :string} do
      default []
    end

    attribute :pass_design_template, :string do
      constraints max_length: 100
    end

    attribute :is_active, :boolean do
      default true
    end

    timestamps()
  end

  relationships do
    has_many :visitors, Intelitor.VisitorManagement.Visitor do
      destination_attribute :visitor_type_id
    end

    has_many :visit_requests, Intelitor.VisitorManagement.VisitRequest do
      destination_attribute :visitor_type_id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :create_type do
      argument :name, :string do
        allow_nil? false
      end

      argument :type_code, :string do
        allow_nil? false
      end

      argument :category, :atom do
        allow_nil? false
      end

      argument :security_level, :atom do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:type_code, arg(:type_code))
      change set_attribute(:category, arg(:category))
      change set_attribute(:security_level, arg(:security_level))
    end

    update :configure_requirements do
      require_atomic? false
      argument :requires_escort, :boolean do
        allow_nil? false
      end

      argument :requires_background_check, :boolean do
        allow_nil? false
      end

      argument :requires_training, :boolean do
        allow_nil? false
      end

      argument :max_duration, :integer do
        allow_nil? false
      end

      change set_attribute(:requires_escort, arg(:requires_escort))
      change set_attribute(:requires_background_check, arg(:requires_background_check))
      change set_attribute(:requires_training, arg(:requires_training))
      change set_attribute(:max_visit_duration_hours, arg(:max_duration))
    end

    update :set_access_areas do
      require_atomic? false
      argument :allowed_areas, {:array, :uuid} do
        allow_nil? false
      end

      argument :restricted_areas, {:array, :uuid}

      change set_attribute(:allowed_areas, arg(:allowed_areas))
      change set_attribute(:restricted_areas, arg(:restricted_areas))
    end

    update :activate do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  code_interface do
    define :create
    define :create_type
    define :configure_requirements
    define :set_access_areas
    define :activate
    define :deactivate
  end

  postgres do
    table "visitor_types"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :type_code], unique: true
      index [:tenant_id, :category]
      index [:tenant_id, :security_level]
      index [:tenant_id, :is_active]
      index [:tenant_id, :requires_escort]
      index [:tenant_id, :requires_background_check]
    end
  end
end
