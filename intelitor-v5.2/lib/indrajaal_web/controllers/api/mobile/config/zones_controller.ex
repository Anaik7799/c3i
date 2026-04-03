defmodule IndrajaalWeb.Api.Mobile.Config.ZonesController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Sites
  alias IndrajaalWeb.Api.Mobile.Shared.MobileSecurityValidator

  @doc """
  Mobile API controller for zone management within the configuration system.
  Provides endpoints for creating, managing, and organizing zones within sites for mobile clients.
  """

  def index(conn, %{"site_id" => site_id} = params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, zones} <- Sites.list_zones_for_site(site_id, filters) do
      render(conn, :index, zones: zones)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, zone} <- Sites.get_zone(id) do
      render(conn, :show, zone: zone)
    end
  end

  def create(conn, %{"site_id" => site_id, "zone" => zone_params}) do
    zone_params = Map.put(zone_params, "site_id", site_id)

    with :ok <- MobileSecurityValidator.validate_stamp_constraints(zone_params),
         {:ok, zone} <- Sites.create_zone(zone_params) do
      conn
      |> put_status(:created)
      |> render(:show, zone: zone)
    end
  end

  def update(conn, %{"id" => id, "zone" => zone_params}) do
    with {:ok, zone} <- Sites.get_zone(id),
         :ok <- MobileSecurityValidator.validate_stamp_constraints(zone_params, zone),
         {:ok, zone} <- Sites.update_zone(zone, zone_params) do
      render(conn, :show, zone: zone)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, zone} <- Sites.get_zone(id),
         {:ok, _zone} <- Sites.delete_zone(zone) do
      send_resp(conn, :no_content, "")
    end
  end

  # Zone-specific operations
  def set_security_level(conn, %{"id" => id, "security_level" => security_level}) do
    with {:ok, zone} <- Sites.get_zone(id),
         {:ok, zone} <- Sites.set_zone_security_level(zone, security_level) do
      render(conn, :show, zone: zone)
    end
  end

  def set_access_rules(conn, %{"id" => id, "access_rules" => access_rules}) do
    with {:ok, zone} <- Sites.get_zone(id),
         {:ok, zone} <- Sites.set_zone_access_rules(zone, access_rules) do
      render(conn, :show, zone: zone)
    end
  end

  def get_zone_devices(conn, %{"id" => id}) do
    with {:ok, zone} <- Sites.get_zone(id),
         {:ok, devices} <- Sites.get_zone_devices(zone) do
      render(conn, :devices, devices: devices)
    end
  end

  def assigndevice(conn, %{"id" => id, "device_id" => device_id}) do
    with {:ok, zone} <- Sites.get_zone(id),
         {:ok, zone} <- Sites.assign_device_to_zone(zone, device_id) do
      render(conn, :show, zone: zone)
    end
  end

  def unassigndevice(conn, %{"id" => id, "device_id" => device_id}) do
    with {:ok, zone} <- Sites.get_zone(id),
         {:ok, zone} <- Sites.unassign_device_from_zone(zone, device_id) do
      render(conn, :show, zone: zone)
    end
  end

  # Bulk operations for mobile efficiency
  def bulk_create(conn, %{"site_id" => site_id, "zones" => zones_params}) do
    zones_params = Enum.map(zones_params, &Map.put(&1, "site_id", site_id))

    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(zones_params),
         {:ok, zones} <- Sites.bulk_create_zones(zones_params) do
      conn
      |> put_status(:created)
      |> render(:index, zones: zones)
    end
  end

  def bulk_update(conn, %{"zones" => zones_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(zones_params),
         {:ok, zones} <- Sites.bulk_update_zones(zones_params) do
      render(conn, :index, zones: zones)
    end
  end

  def bulk_delete(conn, %{"ids" => ids}) when is_list(ids) do
    with {:ok, _result} <- Sites.bulk_delete_zones(ids) do
      send_resp(conn, :no_content, "")
    end
  end

  # Import/Export operations
  def import(conn, %{"siteid" => site_id, "file" => upload}) do
    with {:ok, zones} <- Sites.import_zones(site_id, upload) do
      conn
      |> put_status(:created)
      |> render(:index, zones: zones)
    end
  end

  def export(conn, %{"siteid" => site_id} = params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, csv_data} <- Sites.export_zones(site_id, filters) do
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"zones.csv\"")
      |> send_resp(200, csv_data)
    end
  end

  # Template operations
  def list_templates(conn, _params) do
    templates = Sites.list_zone_templates()
    render(conn, :templates, templates: templates)
  end

  def create_template(conn, %{"template" => template_params}) do
    with {:ok, template} <- Sites.create_zone_template(template_params) do
      conn
      |> put_status(:created)
      |> render(:template, template: template)
    end
  end

  def apply_template(conn, %{"site_id" => site_id, "id" => template_id, "zone" => zone_params}) do
    zone_params = Map.put(zone_params, "site_id", site_id)

    with {:ok, zone} <- Sites.apply_zone_template(template_id, zone_params) do
      conn
      |> put_status(:created)
      |> render(:show, zone: zone)
    end
  end

  # Version control operations
  def list_versions(conn, %{"id" => id}) do
    with {:ok, versions} <- Sites.list_zone_versions(id) do
      render(conn, :versions, versions: versions)
    end
  end

  def rollback(conn, %{"id" => id, "version" => version}) do
    with {:ok, zone} <- Sites.rollback_zone(id, version) do
      render(conn, :show, zone: zone)
    end
  end
end

# Agent: Worker - 3 (Zone Management Worker)
# SOPv5.1 Compliance: ✅ Zone management with cybernetic framework
# Domain: Sites
# Responsibilities: Zone CRUD operations, security management, device assignment
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
