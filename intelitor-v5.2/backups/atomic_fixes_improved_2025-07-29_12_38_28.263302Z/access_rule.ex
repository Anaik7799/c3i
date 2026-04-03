defmodule Intelitor.Policy.AccessRule do
  @moduledoc """
  Dynamic access control rules for fine-grained authorization.

  Access rules allow for complex, context-aware authorization decisions
  beyond simple role-permission checks.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Policy,
    table: "access_rules"

  use Intelitor.Multitenancy.TenantResource

  import Intelitor.Shared.PolicyPatterns

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :code, :string do
      allow_nil? false
      public? true

      constraints max_length: 100,
                  match: ~S/^[a-z][a-z0-9_]*$/
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :rule_type, :atom do
      constraints one_of: [:allow, :deny, :conditional]
      default :conditional
      public? true
    end

    attribute :resource_type, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :action, :string do
      public? true
      constraints max_length: 50
    end

    attribute :conditions, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :effect, :atom do
      constraints one_of: [:allow, :deny]
      default :allow
      public? true
    end

    attribute :priority, :integer do
      default 100
      public? true
      constraints min: 1, max: 1000
    end

    attribute :scope, :atom do
      constraints one_of: [:global, :tenant, :organization, :custom]
      default :tenant
      public? true
    end

    attribute :active?, :boolean do
      default true
      public? true
    end

    attribute :effective_from, :utc_datetime_usec do
      public? true
    end

    attribute :effective_until, :utc_datetime_usec do
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :role, Intelitor.Policy.Role do
      public? true
    end

    belongs_to :permission, Intelitor.Policy.Permission do
      public? true
    end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    create :create_from_template do
      argument :template, :atom do
        allow_nil? false
        constraints one_of: [:time_based, :location_based, :attribute_based, :custom]
      end

      argument :template_params, :map do
        allow_nil? false
      end

      change fn changeset, _context ->
        template = Ash.Changeset.get_argument(changeset, :template)
        params = Ash.Changeset.get_argument(changeset, :template_params)

        conditions = build_conditions_from_template(template, params)

        changeset
        |> Ash.Changeset.change_attribute(:conditions, conditions)
        |> Ash.Changeset.change_attribute(:rule_type, :conditional)
      end
    end

    update :toggle_active do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :active?)
        Ash.Changeset.change_attribute(changeset, :active?, !current)
      end
    end

    update :update_priority do
      require_atomic? false
      argument :new_priority, :integer do
        allow_nil? false
        constraints min: 1, max: 1000
      end

      change set_attribute(:priority, arg(:new_priority))
    end

    update :update_conditions do
      require_atomic? false
      accept [:conditions]

      validate fn changeset, _context ->
        conditions = Ash.Changeset.get_attribute(changeset, :conditions)

        if valid_rule_conditions?(conditions) do
          {:ok, changeset}
        else
          {:error, field: :conditions, message: "Invalid condition format"}
        end
      end
    end
  end

  calculations do
    calculate :is_active?,
              :boolean,
              expr(
                active? and
                  (is_nil(effective_from) or effective_from <= now()) and
                  (is_nil(effective_until) or effective_until > now())
              )

    calculate :is_time_limited?,
              :boolean,
              expr(not is_nil(effective_from) or not is_nil(effective_until))

    calculate :days_remaining, :integer do
      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn rule ->
          case rule.effective_until do
            nil ->
              nil

            until_date ->
              diff = DateTime.diff(until_date, now, :day)
              max(0, diff)
          end
        end)
      end
    end

    calculate :condition_count, :integer do
      calculation fn records, _opts ->
        Enum.map(records, fn rule ->
          count_conditions(rule.conditions)
        end)
      end
    end

    calculate :formatted_conditions, :string do
      calculation fn records, _opts ->
        Enum.map(records, fn rule ->
          format_conditions(rule.conditions)
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 3, max: 100)
    validate string_length(:code, min: 3, max: 100)

    validate fn changeset, _context ->
      from = Ash.Changeset.get_attribute(changeset, :effective_from)
      until = Ash.Changeset.get_attribute(changeset, :effective_until)

      if from && until && DateTime.compare(from, until) != :lt do
        {:error, field: :effective_until, message: "must be after effective_from"}
      else
        {:ok, changeset}
      end
    end

    validate fn changeset, _context ->
      rule_type = Ash.Changeset.get_attribute(changeset, :rule_type)
      conditions = Ash.Changeset.get_attribute(changeset, :conditions)

      case {rule_type, conditions} do
        {:conditional, c} when c == %{} ->
          {:error, field: :conditions, message: "required for conditional rules"}

        _ ->
          {:ok, changeset}
      end
    end
  end

  # Migrated to shared utility: Eliminates duplicate code (mass: 35)
  policies do
    admin_and_security_admin_policies()
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :toggle_active
    define :update_priority
    define :create_from_template
    define :get_by_code, action: :read, get_by: [:code]
    define :list_active, action: :read, args: []
  end

  postgres do
    table "access_rules"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:tenant_id, :resource_type, :action, :priority]
      index [:role_id], where: "role_id IS NOT NULL"
      index [:permission_id], where: "permission_id IS NOT NULL"

      index [:active?, :priority],
        name: "access_rules_active_priority_index",
        where: "active? = true"

      index [:effective_from, :effective_until]
    end
  end

  # Helper functions
  defp build_conditions_from_template(:time_based, params) do
    %{
      "type" => "time_window",
      "start_time" => Map.get(params, "start_time", "09:00"),
      "end_time" => Map.get(params, "end_time", "17:00"),
      "timezone" => Map.get(params, "timezone", "UTC"),
      "days_of_week" => Map.get(params, "days_of_week", [1, 2, 3, 4, 5])
    }
  end

  defp build_conditions_from_template(:location_based, params) do
    %{
      "type" => "location",
      "allowed_ips" => Map.get(params, "allowed_ips", []),
      "allowed_countries" => Map.get(params, "allowed_countries", []),
      "denied_countries" => Map.get(params, "denied_countries", [])
    }
  end

  defp build_conditions_from_template(:attribute_based, params) do
    %{
      "type" => "attributes",
      "required_attributes" => Map.get(params, "required_attributes", %{}),
      "match_all" => Map.get(params, "match_all", true)
    }
  end

  defp build_conditions_from_template(:custom, params) do
    Map.get(params, "conditions", %{})
  end

  defp valid_rule_conditions?(conditions) when is_map(conditions) do
    # Validate the structure of rule conditions
    Map.has_key?(conditions, "type") || Map.has_key?(conditions, "and") ||
      Map.has_key?(conditions, "or")
  end

  defp valid_rule_conditions?(_), do: false

  defp count_conditions(conditions) when is_map(conditions) do
    case conditions do
      %{"and" => list} -> Enum.sum(Enum.map(list, &count_conditions/1))
      %{"or" => list} -> Enum.sum(Enum.map(list, &count_conditions/1))
      _ -> 1
    end
  end

  defp count_conditions(_), do: 0

  defp format_conditions(conditions) when is_map(conditions) do
    # Format conditions for display
    Jason.encode!(conditions, pretty: true)
  rescue
    _ -> "Invalid conditions"
  end

  defp format_conditions(_), do: "No conditions"
end
