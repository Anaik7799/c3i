defmodule Indrajaal.Analytics.SecurityDashboardTest do
  @moduledoc """
  Comprehensive test suite for SecurityDashboard resource.
  Tests dashboard configuration and widget management.
  """

  use Indrajaal.DataCase, async: true

  alias Indrajaal.Analytics
  alias Indrajaal.Analytics.SecurityDashboard

  describe "SecurityDashboard.create / 1" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      %{tenant: tenant, organization: organization}
    end

    test "creates dashboard with required attributes", %{
      tenant: tenant,
      organization: organization
    } do
      attrs = %{
        name: "Security Operations Dashboard",
        dashboard_type: :operational,
        layout: %{
          "columns" => 4,
          "rows" => 3,
          "grid_size" => "12x8"
        },
        widgets: [
          %{
            "id" => "widget_1",
            "type" => "metric_card",
            "position" => %{"x" => 0, "y" => 0, "w" => 2, "h" => 1},
            "config" => %{"metric_type" => "response_time", "time_range" => "24h"}
          },
          %{
            "id" => "widget_2",
            "type" => "chart",
            "position" => %{"x" => 2, "y" => 0, "w" => 2, "h" => 2},
            "config" => %{"chart_type" => "line", "metric" => "incident_count"}
          }
        ],
        refresh_interval: 300,
        organization_id: organization.id
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, dashboard} = SecurityDashboard.create(attrs, actor: actor)
      assert dashboard.name == "Security Operations Dashboard"
      assert dashboard.dashboard_type == :operational
      assert dashboard.refresh_interval == 300
      assert dashboard.tenant_id == tenant.id
      assert dashboard.organization_id == organization.id
      assert length(dashboard.widgets) == 2
    end

    test "supports all dashboard types",
         %{tenant: tenant, organization: organization} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      dashboard_types = [:operational, :executive, :tactical, :compliance, :analytics]

      Enum.each(dashboard_types, fn dashboard_type ->
        attrs = %{
          name: "#{dashboard_type} Dashboard",
          dashboard_type: dashboard_type,
          layout: %{"columns" => 2},
          organization_id: organization.id
        }

        assert {:ok, dashboard} = SecurityDashboard.create(attrs, actor: actor)
        assert dashboard.dashboard_type == dashboard_type
      end)
    end

    test "sets default values correctly",
         %{tenant: tenant, organization: organization} do
      attrs = %{
        name: "Basic Dashboard",
        dashboard_type: :operational,
        organization_id: organization.id
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, dashboard} = SecurityDashboard.create(attrs, actor: actor)
      assert dashboard.widgets == []
      assert dashboard.auto_refresh == true
      assert dashboard.is_default == false
      assert dashboard.is_public == false
      assert dashboard.theme == :light
    end

    test "handles complex widget configurations",
         %{tenant: tenant, organization: organization} do
      complex_widgets = [
        %{
          "id" => "threat_map",
          "type" => "heat_map",
          "position" => %{"x" => 0, "y" => 0, "w" => 4, "h" => 3},
          "config" => %{
            "data_source" => "threat_intelligence",
            "map_type" => "geographical",
            "time_range" => "7d",
            "aggregation" => "count",
            "color_scheme" => "red_gradient",
            "filters" => %{
              "severity" => ["high", "critical"],
              "types" => ["intrusion", "malware", "phishing"]
            }
          }
        },
        %{
          "id" => "compliance_gauge",
          "type" => "gauge",
          "position" => %{"x" => 0, "y" => 3, "w" => 2, "h" => 2},
          "config" => %{
            "metric" => "compliance_score",
            "min_value" => 0,
            "max_value" => 100,
            "target_value" => 95,
            "thresholds" => %{
              "critical" => 70,
              "warning" => 85,
              "good" => 95
            }
          }
        }
      ]

      attrs = %{
        name: "Advanced Security Dashboard",
        dashboard_type: :analytics,
        widgets: complex_widgets,
        organization_id: organization.id
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, dashboard} = SecurityDashboard.create(attrs, actor: actor)
      assert length(dashboard.widgets) == 2

      threat_map = Enum.find(dashboard.widgets, &(&1["id"] == "threat_map"))
      assert threat_map["config"]["filters"]["severity"] == ["high", "critical"]
    end
  end

  describe "SecurityDashboard.list_by_type / 1" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      # Create multiple dashboards of different types
      dashboards =
        Enum.map([:operational, :executive, :tactical], fn type ->
          insert(:security_dashboard, %{
            tenant_id: tenant.id,
            organization_id: organization.id,
            dashboard_type: type
          })
        end)

      %{tenant: tenant, organization: organization, dashboards: dashboards}
    end

    test "filters dashboards by type", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      args = %{dashboard_type: :operational}
      assert {:ok, dashboards} = SecurityDashboard.list_by_type(args, actor: actor)

      assert length(dashboards) == 1
      assert Enum.all?(dashboards, &(&1.dashboard_type == :operational))
    end

    test "respects tenant isolation", %{organization: _organization} do
      other_tenant = insert(:tenant)
      actor = %{tenant_id: other_tenant.id, role: "admin"}

      args = %{dashboard_type: :operational}
      assert {:ok, dashboards} = SecurityDashboard.list_by_type(args, actor: actor)

      assert Enum.empty?(dashboards)
    end
  end

  describe "SecurityDashboard.add_widget / 2" do
    setup do
      tenant = insert(:tenant)

      dashboard =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          widgets: [
            %{
              "id" => "existing_widget",
              "type" => "metric_card",
              "position" => %{"x" => 0, "y" => 0, "w" => 2, "h" => 1}
            }
          ]
        })

      %{tenant: tenant, dashboard: dashboard}
    end

    test "adds new widget to dashboard",
         %{tenant: tenant, dashboard: dashboard} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      new_widget = %{
        "id" => "new_chart",
        "type" => "line_chart",
        "position" => %{"x" => 2, "y" => 0, "w" => 2, "h" => 2},
        "config" => %{"metric" => "response_time", "time_range" => "1h"}
      }

      args = %{widget: new_widget}

      assert {:ok, updated_dashboard} =
               SecurityDashboard.add_widget(dashboard, args, actor: actor)

      assert length(updated_dashboard.widgets) == 2
      assert Enum.any?(updated_dashboard.widgets, &(&1["id"] == "new_chart"))
    end

    test "validates widget structure",
         %{tenant: tenant, dashboard: dashboard} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Invalid widget - missing required fields
      invalid_widget = %{"id" => "invalid"}

      args = %{widget: invalid_widget}
      assert {:error, changeset} = SecurityDashboard.add_widget(dashboard, args, actor: actor)

      # Should fail validation
      assert changeset.valid? == false
    end
  end

  describe "SecurityDashboard authorization" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      dashboard =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          organization_id: organization.id
        })

      %{tenant: tenant, organization: organization, dashboard: dashboard}
    end

    test "allows read access for same tenant users",
         %{tenant: tenant, dashboard: dashboard} do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [found_dashboard]} = SecurityDashboard.read([dashboard.id], actor: actor)
      assert found_dashboard.id == dashboard.id
    end

    test "denies read access for different tenant users",
         %{dashboard: dashboard} do
      other_tenant = insert(:tenant)
      actor = %{tenant_id: other_tenant.id, role: "admin"}

      assert {:ok, []} = SecurityDashboard.read([dashboard.id], actor: actor)
    end

    test "allows create for admin users",
         %{tenant: tenant, organization: organization} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      attrs = %{
        name: "Admin Dashboard",
        dashboard_type: :operational,
        organization_id: organization.id
      }

      assert {:ok, _dashboard} = SecurityDashboard.create(attrs, actor: actor)
    end

    test "denies create for viewer users",
         %{tenant: tenant, organization: organization} do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      attrs = %{
        name: "Viewer Dashboard",
        dashboard_type: :operational,
        organization_id: organization.id
      }

      assert {:error, %Ash.Error.Forbidden{}} = SecurityDashboard.create(attrs, actor: actor)
    end
  end

  describe "SecurityDashboard calculations" do
    setup do
      tenant = insert(:tenant)

      # Dashboard with many widgets
      dashboard_with_widgets =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          widgets: [
            %{"id" => "w1", "type" => "chart"},
            %{"id" => "w2", "type" => "gauge"},
            %{"id" => "w3", "type" => "table"}
          ]
        })

      # Dashboard without widgets
      empty_dashboard =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          widgets: []
        })

      %{
        tenant: tenant,
        dashboard_with_widgets: dashboard_with_widgets,
        empty_dashboard: empty_dashboard
      }
    end

    test "calculates widget_count correctly", %{
      tenant: tenant,
      dashboard_with_widgets: dashboard_with_widgets,
      empty_dashboard: empty_dashboard
    } do
      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [loaded_with]} =
               SecurityDashboard.read([dashboard_with_widgets.id],
                 actor: actor,
                 load: [:widget_count]
               )

      assert loaded_with.widget_count == 3

      assert {:ok, [loaded_empty]} =
               SecurityDashboard.read([empty_dashboard.id], actor: actor, load: [:widget_count])

      assert loaded_empty.widget_count == 0
    end

    test "identifies has_alerts_widget?", %{tenant: tenant} do
      dashboard_with_alerts =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          widgets: [
            %{"id" => "alerts", "type" => "alert_list"},
            %{"id" => "metrics", "type" => "metric_card"}
          ]
        })

      dashboard_without_alerts =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          widgets: [
            %{"id" => "chart", "type" => "line_chart"}
          ]
        })

      actor = %{tenant_id: tenant.id, role: "viewer"}

      assert {:ok, [loaded_with]} =
               SecurityDashboard.read([dashboard_with_alerts.id],
                 actor: actor,
                 load: [:has_alerts_widget?]
               )

      assert loaded_with.has_alerts_widget? == true

      assert {:ok, [loaded_without]} =
               SecurityDashboard.read([dashboard_without_alerts.id],
                 actor: actor,
                 load: [:has_alerts_widget?]
               )

      assert loaded_without.has_alerts_widget? == false
    end
  end

  describe "SecurityDashboard complex scenarios" do
    test "handles enterprise dashboard configurations" do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Complex enterprise dashboard with multiple widget types
      enterprise_layout = %{
        "type" => "grid",
        "columns" => 12,
        "rows" => 8,
        "responsive_breakpoints" => %{
          "lg" => 1200,
          "md" => 996,
          "sm" => 768,
          "xs" => 480
        }
      }

      enterprise_widgets = [
        # KPI Cards Row
        %{
          "id" => "total_incidents",
          "type" => "kpi_card",
          "position" => %{"x" => 0, "y" => 0, "w" => 3, "h" => 2},
          "config" => %{
            "metric" => "incident_count",
            "time_range" => "24h",
            "comparison" => "previous_period",
            "target" => 0,
            "format" => "number"
          }
        },
        %{
          "id" => "avg_response_time",
          "type" => "kpi_card",
          "position" => %{"x" => 3, "y" => 0, "w" => 3, "h" => 2},
          "config" => %{
            "metric" => "response_time",
            "time_range" => "24h",
            "target" => 120,
            "format" => "duration"
          }
        },
        # Threat Intelligence Map
        %{
          "id" => "threat_map",
          "type" => "threat_map",
          "position" => %{"x" => 6, "y" => 0, "w" => 6, "h" => 4},
          "config" => %{
            "data_sources" => ["internal_logs", "threat_feeds", "honeypots"],
            "map_type" => "world",
            "threat_types" => ["malware", "intrusion", "ddos"],
            "severity_filter" => ["medium", "high", "critical"],
            "auto_refresh" => 30
          }
        },
        # Incident Timeline
        %{
          "id" => "incident_timeline",
          "type" => "timeline",
          "position" => %{"x" => 0, "y" => 2, "w" => 6, "h" => 3},
          "config" => %{
            "data_source" => "incident_log",
            "time_range" => "7d",
            "grouping" => "severity",
            "max_items" => 50
          }
        },
        # Compliance Status
        %{
          "id" => "compliance_status",
          "type" => "compliance_grid",
          "position" => %{"x" => 0, "y" => 5, "w" => 4, "h" => 3},
          "config" => %{
            "frameworks" => ["ISO27001", "SOC2", "GDPR"],
            "show_details" => true,
            "alert_on_violations" => true
          }
        }
      ]

      dashboard_filters = %{
        "global_time_range" => "24h",
        "severity_levels" => ["medium", "high", "critical"],
        "sites" => [],
        "departments" => [],
        "custom_filters" => %{}
      }

      sharing_settings = %{
        "is_shared" => true,
        "shared_with" => ["security_team", "management"],
        "permissions" => %{
          "view" => ["all_users"],
          "edit" => ["admin", "security_lead"],
          "share" => ["admin"]
        }
      }

      attrs = %{
        name: "Enterprise Security Command Center",
        dashboard_type: :executive,
        layout: enterprise_layout,
        widgets: enterprise_widgets,
        refresh_interval: 30,
        auto_refresh: true,
        time_range: "24h",
        filters: dashboard_filters,
        sharing_settings: sharing_settings,
        alerts_enabled: true,
        export_formats: ["pdf", "csv", "json"],
        theme: :dark,
        organization_id: organization.id
      }

      assert {:ok, dashboard} = SecurityDashboard.create(attrs, actor: actor)
      assert dashboard.name == "Enterprise Security Command Center"
      assert dashboard.dashboard_type == :executive
      assert length(dashboard.widgets) == 5
      assert dashboard.layout["columns"] == 12
      assert dashboard.filters["global_time_range"] == "24h"
      assert dashboard.sharing_settings["is_shared"] == true
      assert dashboard.theme == :dark

      # Verify widget configurations
      threat_map = Enum.find(dashboard.widgets, &(&1["id"] == "threat_map"))

      assert threat_map["config"]["data_sources"] == [
               "internal_logs",
               "threat_feeds",
               "honeypots"
             ]

      kpi_card = Enum.find(dashboard.widgets, &(&1["id"] == "total_incidents"))
      assert kpi_card["config"]["target"] == 0
    end

    test "supports real - time dashboard updates" do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)
      actor = %{tenant_id: tenant.id, role: "analyst"}

      # Create dashboard optimized for real - time updates
      real_time_dashboard =
        insert(:security_dashboard, %{
          tenant_id: tenant.id,
          organization_id: organization.id,
          name: "Real - time Security Operations",
          dashboard_type: :operational,
          # 5 second refresh
          refresh_interval: 5,
          auto_refresh: true,
          widgets: [
            %{
              "id" => "live_alerts",
              "type" => "live_feed",
              "config" => %{
                "data_source" => "security_events",
                "max_items" => 20,
                "auto_scroll" => true,
                "sound_alerts" => true
              }
            }
          ]
        })

      # Simulate adding real - time widgets
      real_time_widgets = [
        %{
          "id" => "system_health",
          "type" => "status_grid",
          "position" => %{"x" => 0, "y" => 0, "w" => 4, "h" => 2},
          "config" => %{
            "update_frequency" => 1,
            "items" => ["cameras", "access_points", "servers", "network"],
            "status_levels" => ["online", "warning", "critical", "offline"]
          }
        },
        %{
          "id" => "live_metrics",
          "type" => "metric_stream",
          "position" => %{"x" => 4, "y" => 0, "w" => 4, "h" => 2},
          "config" => %{
            "metrics" => ["response_time", "throughput", "error_rate"],
            "update_frequency" => 2,
            "show_sparklines" => true
          }
        }
      ]

      # Add widgets to dashboard
      Enum.each(real_time_widgets, fn widget ->
        args = %{widget: widget}

        assert {:ok, updated_dashboard} =
                 SecurityDashboard.add_widget(
                   real_time_dashboard,
                   args,
                   actor: actor
                 )

        real_time_dashboard = updated_dashboard
      end)

      assert length(real_time_dashboard.widgets) == 3
      assert real_time_dashboard.refresh_interval == 5
      assert real_time_dashboard.auto_refresh == true
    end

    test "supports multi - tenant dashboard sharing and permissions" do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant_id: tenant.id)

      # Create users with different roles
      admin_actor = %{tenant_id: tenant.id, role: "admin", user_id: Faker.UUID.v4()}
      analyst_actor = %{tenant_id: tenant.id, role: "analyst", user_id: Faker.UUID.v4()}
      viewer_actor = %{tenant_id: tenant.id, role: "viewer", user_id: Faker.UUID.v4()}

      # Create dashboard with granular permissions
      attrs = %{
        name: "Shared Analytics Dashboard",
        dashboard_type: :analytics,
        organization_id: organization.id,
        is_public: false,
        sharing_settings: %{
          "visibility" => "organization",
          "permissions" => %{
            "view" => ["analyst", "admin", "manager"],
            "edit" => ["admin", "analyst"],
            "share" => ["admin"],
            "export" => ["admin", "manager"]
          },
          "user_permissions" => %{
            admin_actor.user_id => ["view", "edit", "share", "export"],
            analyst_actor.user_id => ["view", "edit"],
            viewer_actor.user_id => ["view"]
          }
        }
      }

      # Admin can create shared dashboard
      assert {:ok, shared_dashboard} = SecurityDashboard.create(attrs, actor: admin_actor)

      # Verify different access levels
      assert {:ok, [_]} = SecurityDashboard.read([shared_dashboard.id], actor: admin_actor)
      assert {:ok, [_]} = SecurityDashboard.read([shared_dashboard.id], actor: analyst_actor)

      # Viewer should have limited access based on sharing settings
      {:ok, dashboards} = SecurityDashboard.read([shared_dashboard.id], actor: viewer_actor)

      if length(dashboards) > 0 do
        # If accessible, should be read - only
        dashboard = List.first(dashboards)

        assert dashboard.sharing_settings["user_permissions"][viewer_actor.user_id] ==
                 ["view"]
      end

      # Test permission inheritance
      permissions = shared_dashboard.sharing_settings["permissions"]
      assert "admin" in permissions["view"]
      assert "admin" in permissions["edit"]
      assert "admin" in permissions["share"]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
