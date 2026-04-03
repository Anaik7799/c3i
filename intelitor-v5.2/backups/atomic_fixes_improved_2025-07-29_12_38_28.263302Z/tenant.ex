defmodule Intelitor.Core.Tenant do
  @moduledoc """
  Tenant resource - the foundation of multi-tenancy.

  Each tenant represents a complete isolated customer environment.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Core,
    table: "tenants"

  use Intelitor.Tracing.ResourceHelpers

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 255
      description "Display name of the tenant"
    end

    attribute :slug, :ci_string do
      allow_nil? false

      constraints max_length: 63,
                  match: ~S/^[a-z0-9-]+$/

      description "URL-safe identifier for the tenant"
    end

    attribute :settings, :map do
      default %{}
      description "Tenant-specific configuration"
    end

    attribute :status, :atom do
      constraints one_of: [:active, :suspended, :archived]
      default :active
      description "Current tenant status"
    end

    attribute :subscription_tier, :atom do
      constraints one_of: [:free, :basic, :professional, :enterprise]
      default :free
      description "Subscription level"
    end

    timestamps()
  end

  identities do
    identity :unique_slug, [:slug]
  end

  actions do
    defaults [:read, :update]

    # Test-only create action that doesn't create organization
    create :create do
      accept [:name, :slug, :status, :subscription_tier, :settings]
      
      change {Intelitor.Changes.TraceBusinessCritical,
              operation_name: "tenant.create_test", importance: :low}
      
      description "Test-only create action without organization creation"
    end

    create :register do
      accept [:name, :slug]
      primary? true

      change {Intelitor.Changes.TraceBusinessCritical,
              operation_name: "tenant.register", importance: :critical}

      change {Intelitor.Changes.TraceAndAudit, audit_action: :tenant_register}

      change fn changeset, context ->
        changeset
        |> Ash.Changeset.after_action(fn changeset, tenant ->
          # Trace organization creation
          Intelitor.Tracing.trace_business_operation(
            "organization.create_primary",
            %{tenant_id: tenant.id},
            fn ->
              # Create default organization after tenant creation
              case Intelitor.Core.Organization.create(
                     %{
                       tenant_id: tenant.id,
                       name: tenant.name,
                       is_primary: true
                     },
                     actor: %{tenant_id: tenant.id, is_system: true}
                   ) do
                {:ok, org} ->
                  # Emit tenant registration success telemetry
                  :telemetry.execute(
                    [:intelitor, :tenant, :registered],
                    %{count: 1},
                    %{
                      tenant_id: tenant.id,
                      organization_id: org.id,
                      subscription_tier: tenant.subscription_tier
                    }
                  )

                  {:ok, tenant}

                {:error, error} ->
                  # Log and trace the error
                  Logger.error("Failed to create primary organization for tenant",
                    tenant_id: tenant.id,
                    error: inspect(error)
                  )

                  {:error, error}
              end
            end
          )
        end)
      end

      after_action(trace_completion(:tenant_registered))
    end

    update :suspend do
      require_atomic? false
      accept []
      change set_attribute(:status, :suspended)

      change {Intelitor.Changes.TraceBusinessCritical,
              operation_name: "tenant.suspend", importance: :high}

      change {Intelitor.Changes.TraceAndAudit, audit_action: :tenant_suspend}

      after_action(fn changeset, result, context ->
        :telemetry.execute(
          [:intelitor, :tenant, :suspended],
          %{count: 1},
          %{tenant_id: result.id, reason: context[:reason]}
        )

        {:ok, result}
      end)

      description "Suspend tenant access"
    end

    update :reactivate do
      require_atomic? false
      accept []
      change set_attribute(:status, :active)

      change {Intelitor.Changes.TraceBusinessCritical,
              operation_name: "tenant.reactivate", importance: :high}

      change {Intelitor.Changes.TraceAndAudit, audit_action: :tenant_reactivate}

      after_action(fn changeset, result, context ->
        :telemetry.execute(
          [:intelitor, :tenant, :reactivated],
          %{count: 1},
          %{tenant_id: result.id}
        )

        {:ok, result}
      end)

      description "Reactivate suspended tenant"
    end

    update :archive do
      require_atomic? false
      accept []
      change set_attribute(:status, :archived)

      change {Intelitor.Changes.TraceBusinessCritical,
              operation_name: "tenant.archive", importance: :high}

      change {Intelitor.Changes.TraceAndAudit, audit_action: :tenant_archive}

      after_action(fn changeset, result, context ->
        :telemetry.execute(
          [:intelitor, :tenant, :archived],
          %{count: 1},
          %{tenant_id: result.id, reason: context[:reason]}
        )

        {:ok, result}
      end)

      description "Archive tenant (soft delete)"
    end

    read :active do
      filter expr(status == :active)
      description "List only active tenants"
    end
  end

  policies do
    # Only system admins can read tenants
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:is_system_admin, true)
      authorize_if expr(id == ^actor(:tenant_id))
    end

    # Only system admins can create/update/destroy tenants
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:is_system_admin, true)
    end
  end

  calculations do
    calculate :organization_count, :integer do
      calculation fn records, _ ->
        # This would be optimized with a proper aggregation
        Enum.map(records, fn _record ->
          # Placeholder - would count organizations
          0
        end)
      end

      description "Number of organizations in tenant"
    end

    calculate :user_count, :integer do
      calculation fn records, _ ->
        # This would be optimized with a proper aggregation
        Enum.map(records, fn _record ->
          # Placeholder - would count users
          0
        end)
      end

      description "Number of users in tenant"
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)
    validate string_length(:slug, min: 3, max: 63)

    validate match(:slug, ~S/^[a-z0-9-]+$/) do
      message "Slug must contain only lowercase letters, numbers, and hyphens"
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :register, action: :register
    define :update
    define :suspend, action: :suspend
    define :reactivate, action: :reactivate
    define :archive, action: :archive
  end

  postgres do
    table "tenants"
    repo Intelitor.Repo

    custom_indexes do
      index [:slug], unique: true, name: "tenants_unique_slug_index"
      index [:status], name: "tenants_status_index"
      index [:subscription_tier], name: "tenants_subscription_tier_index"
    end
  end
end
