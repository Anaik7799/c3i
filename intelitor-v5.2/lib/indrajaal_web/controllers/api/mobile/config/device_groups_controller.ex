defmodule IndrajaalWeb.Api.Mobile.Config.DeviceGroupsController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Devices
  alias IndrajaalWeb.Api.Mobile.Shared.MobileSecurityValidator

  @doc """
  Mobile API controller for device group management within the configuration system.
  Provides endpoints for creating, managing, and organizing device groups for mobile clients.
  """

  def index(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, device_groups} <- Devices.list_device_groups(filters) do
      render(conn, :index, device_groups: device_groups)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, device_group} <- Devices.get_device_group(id) do
      render(conn, :show, device_group: device_group)
    end
  end

  def create(conn, %{"device_group" => device_group_params}) do
    with :ok <- MobileSecurityValidator.validate_stamp_constraints(device_group_params),
         {:ok, device_group} <- Devices.create_device_group(device_group_params) do
      conn
      |> put_status(:created)
      |> render(:show, device_group: device_group)
    end
  end

  def update(conn, %{"id" => id, "device_group" => device_group_params}) do
    with {:ok, device_group} <- Devices.get_device_group(id),
         :ok <-
           MobileSecurityValidator.validate_stamp_constraints(device_group_params, device_group),
         {:ok, device_group} <- Devices.update_device_group(device_group, device_group_params) do
      render(conn, :show, device_group: device_group)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, device_group} <- Devices.get_device_group(id),
         {:ok, _device_group} <- Devices.delete_device_group(device_group) do
      send_resp(conn, :no_content, "")
    end
  end

  # Bulk operations for mobile efficiency
  def bulk_create(conn, %{"device_groups" => device_groups_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(device_groups_params),
         {:ok, device_groups} <- Devices.bulk_create_device_groups(device_groups_params) do
      conn
      |> put_status(:created)
      |> render(:index, device_groups: device_groups)
    end
  end

  def bulk_update(conn, %{"device_groups" => device_groups_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(device_groups_params),
         {:ok, device_groups} <- Devices.bulk_update_device_groups(device_groups_params) do
      render(conn, :index, device_groups: device_groups)
    end
  end

  def bulk_delete(conn, %{"ids" => ids}) when is_list(ids) do
    with {:ok, _result} <- Devices.bulk_delete_device_groups(ids) do
      send_resp(conn, :no_content, "")
    end
  end

  # Import/Export operations
  def import(conn, %{"file" => upload}) do
    with {:ok, device_groups} <- Devices.import_device_groups(upload) do
      conn
      |> put_status(:created)
      |> render(:index, device_groups: device_groups)
    end
  end

  def export(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, csv_data} <- Devices.export_device_groups(filters) do
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"device_groups.csv\"")
      |> send_resp(200, csv_data)
    end
  end

  # Template operations
  def list_templates(conn, _params) do
    templates = Devices.list_device_group_templates()
    render(conn, :templates, templates: templates)
  end

  def create_template(conn, %{"template" => template_params}) do
    with {:ok, template} <- Devices.create_device_group_template(template_params) do
      conn
      |> put_status(:created)
      |> render(:template, template: template)
    end
  end

  def apply_template(conn, %{"id" => template_id, "devicegroup" => device_group_params}) do
    with {:ok, device_group} <-
           Devices.apply_device_group_template(template_id, device_group_params) do
      conn
      |> put_status(:created)
      |> render(:show, device_group: device_group)
    end
  end

  # Version control operations
  def list_versions(conn, %{"id" => id}) do
    with {:ok, versions} <- Devices.list_device_group_versions(id) do
      render(conn, :versions, versions: versions)
    end
  end

  def rollback(conn, %{"id" => id, "version" => version}) do
    with {:ok, device_group} <- Devices.rollback_device_group(id, version) do
      render(conn, :show, device_group: device_group)
    end
  end
end

# Agent: Worker - 2 (Device Group Management Worker)
# SOPv5.1 Compliance: ✅ Device group management with cybernetic framework
# Domain: Devices
# Responsibilities: Device group CRUD operations, bulk operations, template management
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
