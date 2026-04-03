defmodule Intelitor.Integrations.DataMapping do
  @moduledoc """
  Defines data transformation mappings for external system integration.

  Data mappings specify how data should be transformed when synchronizing
  between the Intelitor system and external systems.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Integrations,
    table: "integration_data_mappings"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :source_system, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :target_system, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :entity_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :user,
                    :device,
                    :site,
                    :alarm,
                    :event,
                    :video_clip,
                    :access_log,
                    :maintenance_record,
                    :custom
                  ]
    end

    attribute :direction, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:inbound, :outbound, :bidirectional]
      default :inbound
    end

    attribute :field_mappings, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :transformation_rules, :map do
      public? true
      default %{}
    end

    attribute :filter_conditions, :map do
      public? true
      default %{}
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :priority, :integer do
      allow_nil? false
      public? true
      default 100
      constraints min: 1, max: 1000
    end

    attribute :created_by, :uuid do
      allow_nil? false
      public? true
    end

    attribute :last_used_at, :utc_datetime_usec do
      public? true
    end

    attribute :usage_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :api_connection, Intelitor.Integrations.ApiConnection do
      allow_nil? false
      public? true
    end

    belongs_to :creator, Intelitor.Accounts.User do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:active?, true)
    end

    update :deactivate do
      require_atomic? false
      accept []
      change set_attribute(:active?, false)
    end

    update :record_usage do
      require_atomic? false
      accept []
      change set_attribute(:last_used_at, DateTime.utc_now())

      change fn changeset, _context ->
        count = Ash.Changeset.get_attribute(changeset, :usage_count)
        Ash.Changeset.change_attribute(changeset, :usage_count, count + 1)
      end
    end
  end

  calculations do
    calculate :is_used_recently?, :boolean do
      calculation fn records, _opts ->
        one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

        Enum.map(records, fn mapping ->
          mapping.last_used_at &&
            DateTime.compare(mapping.last_used_at, one_week_ago) == :gt
        end)
      end
    end

    calculate :source_fields, {:array, :string} do
      calculation fn records, _opts ->
        Enum.map(records, fn mapping ->
          Map.keys(mapping.field_mappings)
        end)
      end
    end

    calculate :target_fields, {:array, :string} do
      calculation fn records, _opts ->
        Enum.map(records, fn mapping ->
          Map.values(mapping.field_mappings)
        end)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
      field_mappings = Ash.Changeset.get_attribute(changeset, :field_mappings)

      if is_map(field_mappings) && map_size(field_mappings) > 0 do
        {:ok, changeset}
      else
        {:error, field: :field_mappings, message: "must contain at least one field mapping"}
      end
    end

    validate fn changeset, _context ->
      entity_type = Ash.Changeset.get_attribute(changeset, :entity_type)
      field_mappings = Ash.Changeset.get_attribute(changeset, :field_mappings)

      required_fields =
        case entity_type do
          :user -> ["id", "name", "email"]
          :device -> ["id", "name", "type"]
          :site -> ["id", "name"]
          :alarm -> ["id", "type", "timestamp"]
          _ -> ["id"]
        end

      missing_fields = Enum.reject(required_fields, &Map.has_key?(field_mappings, &1))

      if Enum.empty?(missing_fields) do
        {:ok, changeset}
      else
        {:error,
         field: :field_mappings,
         message: "missing required fields: #{Enum.join(missing_fields, ", ")}"}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "integration_admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :activate
    define :deactivate
    define :record_usage
  end

  postgres do
    table "integration_data_mappings"
    repo Intelitor.Repo

    custom_indexes do
      index [:api_connection_id]
      index [:entity_type]
      index [:direction]
      index [:active?], name: "data_mappings_active_index", where: "active? = true"
      index [:priority], where: "active? = true"
    end
  end
end
