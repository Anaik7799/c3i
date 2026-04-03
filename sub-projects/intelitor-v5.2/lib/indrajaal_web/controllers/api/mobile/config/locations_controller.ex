defmodule IndrajaalWeb.Api.Mobile.Config.LocationsController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Sites
  alias IndrajaalWeb.Api.Mobile.Shared.MobileSecurityValidator

  @doc """
  Mobile API controller for location management within the configuration system.
  Provides endpoints for creating, managing, and organizing locations within sites for mobile clients.
  """

  def index(conn, %{"siteid" => site_id} = params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, locations} <- Sites.list_locations_for_site(site_id, filters) do
      render(conn, :index, locations: locations)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, location} <- Sites.get_location(id) do
      render(conn, :show, location: location)
    end
  end

  def create(conn, %{"siteid" => site_id, "location" => location_params}) do
    location_params = Map.put(location_params, "site_id", site_id)

    with :ok <- MobileSecurityValidator.validate_stamp_constraints(location_params),
         {:ok, location} <- Sites.create_location(location_params) do
      conn
      |> put_status(:created)
      |> render(:show, location: location)
    end
  end

  def update(conn, %{"id" => id, "location" => location_params}) do
    with {:ok, location} <- Sites.get_location(id),
         :ok <- MobileSecurityValidator.validate_stamp_constraints(location_params, location),
         {:ok, location} <- Sites.update_location(location, location_params) do
      render(conn, :show, location: location)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, location} <- Sites.get_location(id),
         {:ok, _location} <- Sites.delete_location(location) do
      send_resp(conn, :no_content, "")
    end
  end

  # Location-specific operations
  def set_coordinates(conn, %{"id" => id, "coordinates" => coordinates}) do
    with {:ok, location} <- Sites.get_location(id),
         {:ok, location} <- Sites.set_location_coordinates(location, coordinates) do
      render(conn, :show, location: location)
    end
  end

  def set_boundaries(conn, %{"id" => id, "boundaries" => boundaries}) do
    with {:ok, location} <- Sites.get_location(id),
         {:ok, location} <- Sites.set_location_boundaries(location, boundaries) do
      render(conn, :show, location: location)
    end
  end

  def get_nearby_locations(conn, %{"id" => id, "radius" => radius}) do
    with {:ok, location} <- Sites.get_location(id),
         {:ok, nearby_locations} <- Sites.get_nearby_locations(location, radius) do
      render(conn, :index, locations: nearby_locations)
    end
  end

  # Bulk operations for mobile efficiency
  def bulkcreate(conn, %{"siteid" => site_id, "locations" => locations_params}) do
    locations_params = Enum.map(locations_params, &Map.put(&1, "site_id", site_id))

    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(locations_params),
         {:ok, locations} <- Sites.bulk_create_locations(locations_params) do
      conn
      |> put_status(:created)
      |> render(:index, locations: locations)
    end
  end

  def bulk_update(conn, %{"locations" => locations_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(locations_params),
         {:ok, locations} <- Sites.bulk_update_locations(locations_params) do
      render(conn, :index, locations: locations)
    end
  end

  def bulk_delete(conn, %{"ids" => ids}) when is_list(ids) do
    with {:ok, _result} <- Sites.bulk_delete_locations(ids) do
      send_resp(conn, :no_content, "")
    end
  end

  # Import/Export operations
  def import(conn, %{"siteid" => site_id, "file" => upload}) do
    with {:ok, locations} <- Sites.import_locations(site_id, upload) do
      conn
      |> put_status(:created)
      |> render(:index, locations: locations)
    end
  end

  def export(conn, %{"siteid" => site_id} = params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, csv_data} <- Sites.export_locations(site_id, filters) do
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"locations.csv\"")
      |> send_resp(200, csv_data)
    end
  end

  # Template operations
  def list_templates(conn, _params) do
    templates = Sites.list_location_templates()
    render(conn, :templates, templates: templates)
  end

  def create_template(conn, %{"template" => template_params}) do
    with {:ok, template} <- Sites.create_location_template(template_params) do
      conn
      |> put_status(:created)
      |> render(:template, template: template)
    end
  end

  def applytemplate(conn, %{
        "siteid" => site_id,
        "id" => template_id,
        "location" => location_params
      }) do
    location_params = Map.put(location_params, "site_id", site_id)

    with {:ok, location} <- Sites.apply_location_template(template_id, location_params) do
      conn
      |> put_status(:created)
      |> render(:show, location: location)
    end
  end

  # Version control operations
  def list_versions(conn, %{"id" => id}) do
    with {:ok, versions} <- Sites.list_location_versions(id) do
      render(conn, :versions, versions: versions)
    end
  end

  def rollback(conn, %{"id" => id, "version" => version}) do
    with {:ok, location} <- Sites.rollback_location(id, version) do
      render(conn, :show, location: location)
    end
  end
end

# Agent: Worker - 3 (Location Management Worker)
# SOPv5.1 Compliance: ✅ Location management with cybernetic framework
# Domain: Sites
# Responsibilities: Location CRUD operations, geographical operations, site hierarchy management
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
