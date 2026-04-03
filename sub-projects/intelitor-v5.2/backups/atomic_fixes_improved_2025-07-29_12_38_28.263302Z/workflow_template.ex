defmodule Intelitor.Alarms.WorkflowTemplate do
  @moduledoc """
  Defines automated workflows for alarm response procedures.

  WorkflowTemplates enable automated response orchestration, defining steps,
  conditions, and actions to be taken when specific types of alarms are triggered.
  This ensures consistent and timely response to security incidents.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Alarms,
    table: "workflow_templates"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Template identification
    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :category, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :standard,
                    :emergency,
                    :verification,
                    :escalation,
                    :dispatch,
                    :notification,
                    :custom
                  ]

      default :standard
    end

    # Applicability
    attribute :incident_type_id, :uuid do
      public? true
    end

    attribute :site_specific?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :site_ids, {:array, :uuid} do
      public? true
      default []
    end

    attribute :severity_levels, {:array, :atom} do
      public? true
      constraints items: [one_of: [:low, :medium, :high, :critical]]
      default [:high, :critical]
    end

    # Workflow definition
    attribute :steps, {:array, :map} do
      allow_nil? false
      public? true
      default []
    end

    attribute :conditions, :map do
      public? true
      default %{}
    end

    attribute :variables, :map do
      public? true
      default %{}
    end

    # Timing
    attribute :initial_delay_seconds, :integer do
      public? true
      constraints min: 0, max: 3600
      default 0
    end

    attribute :timeout_minutes, :integer do
      public? true
      constraints min: 1, max: 1440
      default 60
    end

    attribute :business_hours_only?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Notification settings
    attribute :notification_channels, {:array, :atom} do
      public? true
      constraints items: [one_of: [:email, :sms, :phone, :push, :webhook]]
      default [:email, :sms]
    end

    attribute :escalation_levels, {:array, :map} do
      public? true
      default []
    end

    # Configuration
    attribute :require_acknowledgment?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :auto_resolve?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :parallel_execution?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :priority, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 10
      default 5
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :version, :integer do
      allow_nil? false
      public? true
      default 1
    end

    timestamps()
  end

  relationships do
    belongs_to :incident_type, Intelitor.Alarms.IncidentType do
      attribute_public? true
    end

    has_many :alarm_events, Intelitor.Alarms.AlarmEvent do
      destination_attribute :workflow_template_id
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :name,
        :description,
        :category,
        :incident_type_id,
        :site_specific?,
        :site_ids,
        :severity_levels,
        :steps,
        :conditions,
        :variables,
        :initial_delay_seconds,
        :timeout_minutes,
        :business_hours_only?,
        :notification_channels,
        :escalation_levels,
        :require_acknowledgment?,
        :auto_resolve?,
        :parallel_execution?,
        :priority
      ]

      validate fn changeset, _context ->
        steps = Ash.Changeset.get_attribute(changeset, :steps) || []

        if Enum.empty?(steps) do
          {:error, field: :steps, message: "must have at least one step"}
        else
          validate_workflow_steps(steps)
        end
      end
    end


    update :update_workflow do
      require_atomic? false
      accept [:steps, :conditions, :variables, :escalation_levels]

      validate fn changeset, _context ->
        steps = Ash.Changeset.get_attribute(changeset, :steps) || []
        validate_workflow_steps(steps)
      end

      change fn changeset, _context ->
        current_version = Ash.Changeset.get_attribute(changeset, :version)
        Ash.Changeset.force_change_attribute(changeset, :version, current_version + 1)
      end
    end

    update :activate do
      require_atomic? false
      
      accept []

      validate attribute_equals(:active?, false)

      change set_attribute(:active?, true)
    end

    update :deactivate do
      require_atomic? false
      
      accept []

      validate attribute_equals(:active?, true)

      change set_attribute(:active?, false)
    end

    update :add_site do
      require_atomic? false
      accept []

      argument :site_id, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:site_specific?, true)

      change fn changeset, _context ->
        current_sites = Ash.Changeset.get_attribute(changeset, :site_ids) || []
        new_site = changeset.arguments.site_id

        if new_site in current_sites do
          changeset
        else
          Ash.Changeset.force_change_attribute(changeset, :site_ids, [new_site | current_sites])
        end
      end
    end

    update :remove_site do
      require_atomic? false
      
      accept []

      argument :site_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        current_sites = Ash.Changeset.get_attribute(changeset, :site_ids) || []
        site_to_remove = changeset.arguments.site_id

        updated_sites = Enum.reject(current_sites, &(&1 == site_to_remove))
        Ash.Changeset.force_change_attribute(changeset, :site_ids, updated_sites)
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :step_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn template ->
            length(template.steps || [])
          end)

        {:ok, values}
      end
    end

    calculate :escalation_level_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn template ->
            length(template.escalation_levels || [])
          end)

        {:ok, values}
      end
    end

    calculate :estimated_duration_minutes, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn template ->
            # Calculate estimated duration based on steps, delays, and timeout
            step_duration = calculate_steps_duration(template.steps || [])
            initial_delay = template.initial_delay_seconds || 0

            # Convert to minutes and add buffer for execution time
            base_duration = div(step_duration + initial_delay, 60)
            timeout_minutes = template.timeout_minutes || 60

            # Use the minimum of calculated duration and timeout, with 10% buffer
            estimated = min(base_duration, timeout_minutes)
            # Minimum 5 minutes for any workflow
            max(estimated, 5)
          end)

        {:ok, values}
      end
    end

    calculate :applies_to_all_sites?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn template ->
            !template.site_specific? || Enum.empty?(template.site_ids || [])
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:activate, :deactivate]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_workflow
    define :activate
    define :deactivate
    define :add_site
    define :remove_site
    define :destroy
  end

  postgres do
    table "workflow_templates"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :name], unique: true
      index [:category]
      index [:incident_type_id], where: "incident_type_id IS NOT NULL"
      index [:active?], name: "workflow_templates_active_index", where: "active? = true"

      index [:site_specific?],
        name: "workflow_templates_site_specific_index",
        where: "site_specific? = true"

      index [:priority]
    end
  end

  # Helper functions
  defp validate_workflow_steps(steps) do
    # Basic validation of workflow steps structure
    valid_step_types = [:notification, :wait, :escalate, :dispatch, :verify, :condition, :action]

    invalid_steps =
      Enum.reject(steps, fn step ->
        Map.has_key?(step, "type") &&
          Map.has_key?(step, "name") &&
          String.to_atom(step["type"]) in valid_step_types
      end)

    if Enum.empty?(invalid_steps) do
      :ok
    else
      {:error, field: :steps, message: "contains invalid step definitions"}
    end
  end

  defp calculate_steps_duration(steps) do
    # Calculate estimated duration for workflow steps in seconds
    Enum.reduce(steps, 0, fn step, acc ->
      step_duration =
        case Map.get(step, "type") do
          "wait" ->
            # Wait steps have explicit duration
            Map.get(step, "duration_seconds", 60)

          "notification" ->
            # Notification steps are quick
            5

          "escalate" ->
            # Escalation includes wait time
            Map.get(step, "escalation_timeout", 300)

          "dispatch" ->
            # Dispatch coordination time
            30

          "verify" ->
            # Verification can take time
            120

          "condition" ->
            # Condition evaluation is fast
            2

          "action" ->
            # Actions vary, default to medium time
            Map.get(step, "estimated_duration", 60)

          _ ->
            # Default duration for unknown step types
            30
        end

      acc + step_duration
    end)
  end
end
