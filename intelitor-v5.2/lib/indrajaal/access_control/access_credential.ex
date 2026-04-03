defmodule Indrajaal.AccessControl.AccessCredential do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Access credentials including cards, biometrics, PINs, and mobile credentials.
  Links __users to their physical access methods.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControlDomain

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :credential_type, :atom do
      constraints one_of: [:card, :biometric, :pin, :mobile, :fob]
      allow_nil? false
    end

    attribute :credential_number, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :encoded_data, :string do
      # Encrypted credential data
      sensitive? true
    end

    attribute :issue_date, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :expiry_date, :utc_datetime

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :expired, :lost, :destroyed]
      default :active
    end

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
    end

    has_many :access_logs, Indrajaal.AccessControl.AccessLog
    has_many :access_grants, Indrajaal.AccessControl.AccessGrant
  end

  identities do
    identity :unique_credential,
             [:tenant_id, :credential_type, :credential_number]
  end

  actions do
    defaults [:read, :update, :destroy]

    create :issue do
      primary? true
      accept [:credential_type, :credential_number, :user_id, :expiry_date]

      change set_attribute(:issue_date, &DateTime.utc_now/0)
    end

    update :suspend do
      require_atomic? false
      accept []
      change set_attribute(:status, :suspended)
    end

    update :reactivate do
      require_atomic? false
      accept []
      change set_attribute(:status, :active)
    end

    update :report_lost do
      require_atomic? false
      accept []
      change set_attribute(:status, :lost)
    end

    read :get_by_credential do
      argument :credential_type, :atom do
        allow_nil? false
      end

      argument :credential_number, :string do
        allow_nil? false
      end

      filter expr(
               credential_type == ^arg(:credential_type) and
                 credential_number == ^arg(:credential_number)
             )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end
  end

  code_interface do
    define :issue, action: :issue
    define :suspend, action: :suspend
    define :reactivate, action: :reactivate
    define :report_lost, action: :report_lost
    define :get_by_credential, args: [:credential_type, :credential_number]
  end

  postgres do
    table "access_credentials"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
