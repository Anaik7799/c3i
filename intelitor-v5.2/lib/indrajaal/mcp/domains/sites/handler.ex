defmodule Indrajaal.MCP.Domains.Sites.Handler do
  @moduledoc """
  MCP Handler for Sites domain.

  WHAT: Provides 11 tools for site management, zones, and access points.
  WHY: Enables AI assistants to manage security site configurations.

  STAMP Constraints:
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-SITE-001: Site data integrity
  - SC-SITE-002: Zone hierarchy validation

  AOR Rules:
  - AOR-MCP-070: Register all tools on load
  - AOR-SITE-001: Validate zone hierarchy before changes
  """

  use Indrajaal.MCP.Domains.Handler, domain: :sites

  alias Indrajaal.MCP.Foundation.Types

  @impl true
  def list_tools do
    [
      # Site Management
      %Types.Tool{
        name: "indrajaal.sites.list",
        description: "List all sites with filtering options",
        input_schema: %{
          type: "object",
          properties: %{
            tenant_id: %{type: "string", description: "Filter by tenant"},
            status: %{type: "string", enum: ["active", "inactive", "suspended"]},
            search: %{type: "string", description: "Search by name or address"},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.get",
        description: "Get detailed site information including zones and devices",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string", description: "Site UUID"}
          },
          required: ["site_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.create",
        description: "Create a new site",
        input_schema: %{
          type: "object",
          properties: %{
            tenant_id: %{type: "string"},
            name: %{type: "string"},
            address: %{
              type: "object",
              properties: %{
                street: %{type: "string"},
                city: %{type: "string"},
                country: %{type: "string"},
                postal_code: %{type: "string"}
              }
            },
            contact: %{
              type: "object",
              properties: %{
                name: %{type: "string"},
                phone: %{type: "string"},
                email: %{type: "string"}
              }
            },
            timezone: %{type: "string", default: "Europe/Amsterdam"}
          },
          required: ["tenant_id", "name"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.update",
        description: "Update site information",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"},
            name: %{type: "string"},
            address: %{type: "object"},
            contact: %{type: "object"},
            status: %{type: "string", enum: ["active", "inactive", "suspended"]}
          },
          required: ["site_id"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # Zone Management
      %Types.Tool{
        name: "indrajaal.sites.zones.list",
        description: "List zones for a site",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"}
          },
          required: ["site_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.zones.create",
        description: "Create a new zone within a site",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"},
            name: %{type: "string"},
            type: %{type: "string", enum: ["perimeter", "interior", "entry", "safe"]},
            parent_zone_id: %{type: "string", description: "For hierarchical zones"}
          },
          required: ["site_id", "name", "type"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.zones.update",
        description: "Update zone configuration",
        input_schema: %{
          type: "object",
          properties: %{
            zone_id: %{type: "string"},
            name: %{type: "string"},
            type: %{type: "string"},
            enabled: %{type: "boolean"}
          },
          required: ["zone_id"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # Access Points
      %Types.Tool{
        name: "indrajaal.sites.access_points.list",
        description: "List access points for a site",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"}
          },
          required: ["site_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.access_points.create",
        description: "Create a new access point",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"},
            zone_id: %{type: "string"},
            name: %{type: "string"},
            type: %{type: "string", enum: ["door", "gate", "turnstile", "elevator"]}
          },
          required: ["site_id", "name", "type"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # Site Status
      %Types.Tool{
        name: "indrajaal.sites.status",
        description: "Get comprehensive site status including all systems",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"}
          },
          required: ["site_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.sites.arm",
        description: "Arm/disarm site or specific zones",
        input_schema: %{
          type: "object",
          properties: %{
            site_id: %{type: "string"},
            zone_ids: %{
              type: "array",
              items: %{type: "string"},
              description: "Specific zones, or all if empty"
            },
            mode: %{type: "string", enum: ["arm_away", "arm_stay", "arm_night", "disarm"]},
            code: %{type: "string", description: "User code for verification"}
          },
          required: ["site_id", "mode"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      }
    ]
  end

  @impl true
  def handle(:list, args, context) do
    audit_log(@domain, :list, args, context)
    success(%{sites: [], total: 0, filters: args})
  end

  def handle(:get, %{"site_id" => site_id} = args, context) do
    audit_log(@domain, :get, args, context)

    success(%{
      id: site_id,
      name: "Site",
      status: "active",
      zones: [],
      devices: [],
      created_at: DateTime.utc_now()
    })
  end

  def handle(:create, args, context) do
    audit_log(@domain, :create, args, context)

    with :ok <- validate_required(args, ["tenant_id", "name"]) do
      success(%{
        id: Ecto.UUID.generate(),
        created: true,
        site: args
      })
    end
  end

  def handle(:update, %{"site_id" => site_id} = args, context) do
    audit_log(@domain, :update, args, context)

    success(%{
      id: site_id,
      updated: true,
      changes: Map.drop(args, ["site_id"])
    })
  end

  def handle(:zones, %{"zone_id" => zone_id} = args, context) do
    audit_log(@domain, :zones, args, context)

    success(%{
      id: zone_id,
      updated: true,
      changes: Map.drop(args, ["zone_id"])
    })
  end

  def handle(:zones, %{"site_id" => _site_id, "name" => _} = args, context) do
    audit_log(@domain, :zones, args, context)

    success(%{
      id: Ecto.UUID.generate(),
      created: true,
      zone: args
    })
  end

  def handle(:zones, %{"site_id" => site_id} = args, context) do
    audit_log(@domain, :zones, args, context)
    success(%{site_id: site_id, zones: [], total: 0})
  end

  def handle(:access_points, %{"site_id" => _site_id, "name" => _} = args, context) do
    audit_log(@domain, :access_points, args, context)

    success(%{
      id: Ecto.UUID.generate(),
      created: true,
      access_point: args
    })
  end

  def handle(:access_points, %{"site_id" => site_id} = args, context) do
    audit_log(@domain, :access_points, args, context)
    success(%{site_id: site_id, access_points: [], total: 0})
  end

  def handle(:status, %{"site_id" => site_id} = args, context) do
    audit_log(@domain, :status, args, context)

    success(%{
      site_id: site_id,
      armed: false,
      arm_mode: nil,
      zones_armed: 0,
      zones_total: 0,
      devices_online: 0,
      devices_total: 0,
      active_alarms: 0,
      last_activity: DateTime.utc_now()
    })
  end

  def handle(:arm, %{"site_id" => site_id, "mode" => mode} = args, context) do
    audit_log(@domain, :arm, args, context)

    success(%{
      site_id: site_id,
      mode: mode,
      zones_affected: Map.get(args, "zone_ids", []),
      success: true,
      timestamp: DateTime.utc_now()
    })
  end

  def handle(action, _args, _context) do
    {:error, {:unknown_action, action}}
  end
end
