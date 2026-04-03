defmodule Indrajaal.Analytics.SecurityDashboard do
  # PHASE M: Analytics patterns consolidated with Unified
  @moduledoc """
  Configurable dashboards for security monitoring and analytics.
  Real - time visualization of metrics and trends.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  alias Ash.Changeset

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string

    attribute :dashboard_type, :atom do
      constraints one_of: [
                    :executive,
                    :operational,
                    :tactical,
                    :custom,
                    :compliance,
                    :performance
                  ]

      default :operational
    end

    attribute :layout, :map do
      default %{
        grid: %{columns: 12, rows: 8},
        theme: "light",
        auto_refresh: true
      }
    end

    attribute :widgets, {:array, :map} do
      default []
      # Structure: [%{
      #   id: "widget - 1",
      #   type: "metric_chart",
      #   title: "Response Time",
      #   position: %{x: 0, y: 0, w: 4, h: 2},
      #   config: %{
      #     metric_type: "response_time",
      #     chart_type: "line",
      #     time_range: "24h"
      #   }
      # }, ...]
    end

    attribute :refresh_interval, :integer do
      # Seconds
      default 300
      constraints min: 30, max: 3600
    end

    attribute :filters, :map do
      default %{}
      # Global filters: %{site_id: "...", date_range: "7d", ...}
    end

    attribute :sharing, :atom do
      constraints one_of: [:private, :team, :organization, :public]
      default :private
    end

    attribute :is_default, :boolean, default: false
    attribute :is_favorite, :boolean, default: false

    attribute :last_viewed_at, :utc_datetime
    attribute :view_count, :integer, default: 0

    attribute :alert_thresholds, :map do
      default %{}
      # Widget - specific alert configurations
    end

    timestamps()
  end

  relationships do
    belongs_to :owner, Indrajaal.Accounts.User do
      allow_nil? false
    end

    belongs_to :team, Indrajaal.Accounts.Team
    belongs_to :organization, Indrajaal.Core.Organization
  end

  identities do
    identity :unique_name_per_owner, [:tenant_id, :owner_id, :name]
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :description,
        :dashboard_type,
        :layout,
        :widgets,
        :refresh_interval,
        :filters,
        :sharing,
        :team_id,
        :organization_id,
        :alert_thresholds
      ]

      change set_attribute(:owner_id, actor(:id))
    end

    update :add_widget do
      require_atomic? false
      accept []

      argument :widget_config, :map do
        allow_nil? false
      end

      change fn changeset, __context ->
        widget = Changeset.get_argument(changeset, :widget_config)
        current_widgets = Changeset.get_attribute(changeset, :widgets) || []

        # Add unique ID if not present
        widget_with_id =
          if Map.has_key?(widget, "id") do
            widget
          else
            Map.put(widget, "id", Ecto.UUID.generate())
          end

        new_widgets = [widget_with_id | current_widgets]
        Changeset.change_attribute(changeset, :widgets, new_widgets)
      end
    end

    update :remove_widget do
      require_atomic? false
      accept []

      argument :widget_id, :string do
        allow_nil? false
      end

      change fn changeset, __context ->
        widget_id = Changeset.get_argument(changeset, :widget_id)
        current_widgets = Changeset.get_attribute(changeset, :widgets) || []

        new_widgets =
          Enum.reject(current_widgets, fn widget ->
            Map.get(widget, "id") == widget_id
          end)

        Changeset.change_attribute(changeset, :widgets, new_widgets)
      end
    end

    update :update_widget do
      require_atomic? false
      accept []

      argument :widget_id, :string do
        allow_nil? false
      end

      argument :widget_config, :map do
        allow_nil? false
      end

      change fn changeset, __context ->
        widget_id = Changeset.get_argument(changeset, :widget_id)
        widget_config = Changeset.get_argument(changeset, :widget_config)
        current_widgets = Changeset.get_attribute(changeset, :widgets) || []

        new_widgets =
          Enum.map(current_widgets, fn widget ->
            if Map.get(widget, "id") == widget_id do
              Map.merge(widget, widget_config)
            else
              widget
            end
          end)

        Changeset.change_attribute(changeset, :widgets, new_widgets)
      end
    end

    update :duplicate do
      require_atomic? false
      accept []

      argument :new_name, :string do
        allow_nil? false
      end

      change fn changeset, __context ->
        new_name = Changeset.get_argument(changeset, :new_name)

        changeset
        |> Changeset.change_attribute(:name, new_name)
        |> Changeset.change_attribute(:is_default, false)
        |> Changeset.change_attribute(:is_favorite, false)
        |> Changeset.change_attribute(:view_count, 0)
        |> Changeset.change_attribute(:last_viewed_at, nil)
      end
    end

    update :mark_as_viewed do
      require_atomic? false
      accept []

      change fn changeset, __context ->
        current_count = Changeset.get_attribute(changeset, :view_count) || 0

        changeset
        |> Changeset.change_attribute(:last_viewed_at, DateTime.utc_now())
        |> Changeset.change_attribute(:view_count, current_count + 1)
      end
    end

    update :toggle_favorite do
      require_atomic? false
      accept []

      change fn changeset, __context ->
        current_favorite =
          Changeset.get_attribute(changeset, :is_favorite) || false

        Changeset.change_attribute(
          changeset,
          :is_favorite,
          !current_favorite
        )
      end
    end

    read :list_accessible do
      # Returns dashboards the current actor can access
      filter expr(
               owner_id == ^actor(:id) or
                 (sharing == :team and team_id in ^actor(:team_ids)) or
                 (sharing == :organization and
                    organization_id == ^actor(:organization_id)) or
                 sharing == :public
             )
    end

    read :list_by_type do
      argument :dashboard_type, :atom do
        allow_nil? false
      end

      filter expr(dashboard_type == ^arg(:dashboard_type))
    end
  end

  calculations do
    calculate :widget_count, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          length(record.widgets || [])
        end)
      end
    end

    calculate :last_updated, :utc_datetime do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.updated_at
        end)
      end
    end

    calculate :sharing_label, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          case record.sharing do
            :private -> "Private"
            :team -> "Team"
            :organization -> "Organization"
            :public -> "Public"
          end
        end)
      end
    end

    calculate :is_accessible_by_actor?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          # This would check actor permissions
          # Placeholder
          true
        end)
      end
    end
  end

  validations do
    validate attribute_in(:refresh_interval, 30..3600)

    validate fn changeset, __context ->
      if changeset.attributes[:widgets] do
        widgets = changeset.attributes[:widgets]

        # Validate widget structure
        valid_widgets =
          Enum.all?(widgets, fn widget ->
            is_map(widget) &&
              Map.has_key?(widget, "type") &&
              Map.has_key?(widget, "position")
          end)

        if valid_widgets do
          changeset
        else
          Changeset.add_error(
            changeset,
            :widgets,
            "contains invalid widget configuration"
          )
        end
      else
        changeset
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type(:create) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(owner_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  code_interface do
    define :create, action: :create
    define :add_widget, action: :add_widget
    define :remove_widget, action: :remove_widget
    define :update_widget, action: :update_widget
    define :duplicate, action: :duplicate
    define :mark_as_viewed, action: :mark_as_viewed
    define :toggle_favorite, action: :toggle_favorite
    define :list_accessible, action: :list_accessible
    define :list_by_type, action: :list_by_type
  end

  postgres do
    table "security_dashboards"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :owner_id, :name],
        unique: true,
        name: "dashboards_tenant_owner_name_index"

      index [:tenant_id, :dashboard_type],
        name: "dashboards_tenant_type_index"

      index [:tenant_id, :sharing, :team_id],
        where: "sharing = 'team'",
        name: "dashboards_tenant_team_sharing_index"

      index [:tenant_id, :sharing, :organization_id],
        where: "sharing = 'organization'",
        name: "dashboards_tenant_org_sharing_index"

      index [:tenant_id, :is_default],
        where: "is_default = true",
        name: "dashboards_tenant_default_index"

      index [:tenant_id, :last_viewed_at],
        name: "dashboards_tenant_last_viewed_index"
    end
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.1 Compliance: ✅ Data analytics and business intelligence coordination w
# Domain: Analytics
# Responsibilities: Data analytics, business intelligence, performance metrics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
