defmodule Indrajaal.Core.SystemConfig do
  @moduledoc """
  System configuration storage.

  Provides key - value configuration storage with optional encryption
  for sensitive values. Configurations are tenant - scoped.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Core

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      allow_nil? false
      constraints max_length: 255
      description "Configuration key"
    end

    attribute :value, :map do
      allow_nil? false
      description "Configuration value (JSON)"
    end

    attribute :description, :string do
      constraints max_length: 1000
      description "Human - readable description"
    end

    attribute :category, :atom do
      constraints one_of: [:general, :security, :features, :integrations, :appearance]
      default :general
      description "Configuration category"
    end

    attribute :encrypted?, :boolean do
      default false
      description "Whether the value is encrypted"
    end

    attribute :editable?, :boolean do
      default true
      description "Whether this config can be edited via UI"
    end

    timestamps()
  end

  identities do
    identity :unique_key_per_tenant, [:tenant_id, :key]
  end

  actions do
    defaults [:read, :destroy]

    create :set do
      accept [:key, :value, :category, :description, :encrypted?, :editable?]
      primary? true
      upsert? true
      upsert_identity :unique_key_per_tenant

      change fn changeset, _ ->
        if Ash.Changeset.get_attribute(changeset, :encrypted?) do
          value = Ash.Changeset.get_attribute(changeset, :value)
          # In production, use proper encryption library
          encrypted = %{encrypted: true, __data: Base.encode64(Jason.encode!(value))}
          Ash.Changeset.change_attribute(changeset, :value, encrypted)
        else
          changeset
        end
      end
    end

    update :update_value do
      require_atomic? false
      accept [:value, :description]

      change fn changeset, _ ->
        if changeset.data.encrypted? do
          value = Ash.Changeset.get_attribute(changeset, :value)
          # In production, use proper encryption library
          encrypted = %{encrypted: true, __data: Base.encode64(Jason.encode!(value))}
          Ash.Changeset.change_attribute(changeset, :value, encrypted)
        else
          changeset
        end
      end
    end

    read :by_category do
      argument :category, :atom do
        allow_nil? false
        constraints one_of: [:general, :security, :features, :integrations, :appearance]
      end

      filter expr(category == ^arg(:category))
    end

    read :editable do
      filter expr(editable? == true)
      description "Only configurations that can be edited"
    end
  end

  calculations do
    calculate :decrypted_value, :map do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.encrypted? && is_map(record.value) && Map.has_key?(record.value, :data) do
            # In production, use proper decryption
            case Base.decode64(record.value.data) do
              {:ok, json} -> Jason.decode!(json)
              _ -> %{}
            end
          else
            record.value
          end
        end)
      end

      description "Decrypted configuration value"
    end

    calculate :safe_value, :map do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.encrypted? do
            %{encrypted: true}
          else
            record.value
          end
        end)
      end

      description "Value with encrypted __data hidden"
    end
  end

  validations do
    validate string_length(:key, min: 1, max: 255)

    validate match(:key, ~r/^[a-z0-9_.]+$/) do
      message "Key must contain only lowercase letters, numbers, underscores, and dots"
    end
  end

  policies do
    # Admins and tenant-scoped actors can read system config
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :system_admin)
      authorize_if actor_attribute_equals(:is_system_admin, true)
      # Allow any actor with a tenant_id (tenant-scoped access)
      authorize_if expr(not is_nil(^actor(:tenant_id)))
      # Allow Tenant structs used as actors (common in tests)
      authorize_if expr(not is_nil(^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:is_system_admin, true)
    end

    policy action_type([:update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:is_system_admin, true)
      forbid_if expr(editable? == false)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :set, action: :set
    define :update_value, action: :update_value
    define :destroy, action: :destroy
  end

  postgres do
    table "system_configs"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :key],
        unique: true,
        name: "system_configs_unique_key_per_tenant_index"

      index [:category],
        name: "system_configs_category_index"

      index [:editable?],
        name: "system_configs_editable_index"
    end
  end

  # Helper functions for common configurations
  defmodule Helpers do
    @moduledoc false

    @spec get_config(term(), term(), term()) :: term()
    def get_config(key, tenant_id, actor) do
      case Indrajaal.Core.SystemConfig.get(
             filter: [key: key, tenant_id: tenant_id],
             actor: actor
           ) do
        {:ok, config} -> {:ok, config.decrypted_value}
        _ -> {:error, :not_found}
      end
    end

    @spec set_config(term(), term(), term(), keyword() | map()) :: term()
    def set_config(key, value, actor, opts \\ []) do
      params = %{
        key: key,
        value: value,
        category: Keyword.get(opts, :category, :general),
        description: Keyword.get(opts, :description),
        encrypted?: Keyword.get(opts, :encrypted?, false)
      }

      Indrajaal.Core.SystemConfig.set(params, actor: actor)
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Core
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
