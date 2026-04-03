defmodule IndrajaalWeb.Api.Mobile.Config.VideoRecordingController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Video
  alias IndrajaalWeb.Api.Mobile.Shared.MobileSecurityValidator

  @doc """
  Mobile API controller for video recording configuration within the configuration system.
  Provides endpoints for creating, managing, and configuring video recording policies for mobile clients.
  """

  # Recording policy management
  def list_policies(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, policies} <- Video.list_recording_policies(filters) do
      render(conn, :policies, policies: policies)
    end
  end

  def show_policy(conn, %{"id" => id}) do
    with {:ok, policy} <- Video.get_recording_policy(id) do
      render(conn, :policy, policy: policy)
    end
  end

  def create_policy(conn, %{"policy" => policy_params}) do
    with :ok <- MobileSecurityValidator.validate_stamp_constraints(policy_params),
         {:ok, policy} <- Video.create_recording_policy(policy_params) do
      conn
      |> put_status(:created)
      |> render(:policy, policy: policy)
    end
  end

  def update_policy(conn, %{"id" => id, "policy" => policy_params}) do
    with {:ok, policy} <- Video.get_recording_policy(id),
         :ok <- MobileSecurityValidator.validate_stamp_constraints(policy_params, policy),
         {:ok, policy} <- Video.update_recording_policy(policy, policy_params) do
      render(conn, :policy, policy: policy)
    end
  end

  def delete_policy(conn, %{"id" => id}) do
    with {:ok, policy} <- Video.get_recording_policy(id),
         {:ok, _policy} <- Video.delete_recording_policy(policy) do
      send_resp(conn, :no_content, "")
    end
  end

  # Recording management operations
  def startrecording(conn, %{"deviceid" => device_id, "policyid" => policy_id}) do
    with {:ok, recording} <- Video.start_recording(device_id, policy_id) do
      conn
      |> put_status(:created)
      |> render(:recording, recording: recording)
    end
  end

  def stoprecording(conn, %{"recordingid" => recording_id}) do
    with {:ok, recording} <- Video.stop_recording(recording_id) do
      render(conn, :recording, recording: recording)
    end
  end

  def pa_userecording(conn, %{"recordingid" => recording_id}) do
    with {:ok, recording} <- Video.pause_recording(recording_id) do
      render(conn, :recording, recording: recording)
    end
  end

  def resumerecording(conn, %{"recordingid" => recording_id}) do
    with {:ok, recording} <- Video.resume_recording(recording_id) do
      render(conn, :recording, recording: recording)
    end
  end

  def getrecording_status(conn, %{"recordingid" => recording_id}) do
    with {:ok, status} <- Video.get_recording_status(recording_id) do
      render(conn, :status, status: status)
    end
  end

  # Recording retrieval and playback
  def list_recordings(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, recordings} <- Video.list_recordings(filters) do
      render(conn, :recordings, recordings: recordings)
    end
  end

  def getrecording(conn, %{"recordingid" => recording_id}) do
    with {:ok, recording} <- Video.get_recording(recording_id) do
      render(conn, :recording, recording: recording)
    end
  end

  def downloadrecording(conn, %{"recordingid" => recording_id}) do
    with {:ok, recording_data} <- Video.get_recording_data(recording_id) do
      conn
      |> put_resp_content_type("video/mp4")
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"recording_#{recording_id}.mp4\""
      )
      |> send_resp(200, recording_data)
    end
  end

  def getrecording_thumbnail(conn, %{"recordingid" => recording_id}) do
    with {:ok, thumbnail_data} <- Video.get_recording_thumbnail(recording_id) do
      conn
      |> put_resp_content_type("image/jpeg")
      |> send_resp(200, thumbnail_data)
    end
  end

  # Schedule-based recording operations
  def create_schedule(conn, %{"schedule" => schedule_params}) do
    with :ok <- MobileSecurityValidator.validate_stamp_constraints(schedule_params),
         {:ok, schedule} <- Video.create_recording_schedule(schedule_params) do
      conn
      |> put_status(:created)
      |> render(:schedule, schedule: schedule)
    end
  end

  def update_schedule(conn, %{"id" => id, "schedule" => schedule_params}) do
    with {:ok, schedule} <- Video.get_recording_schedule(id),
         :ok <- MobileSecurityValidator.validate_stamp_constraints(schedule_params, schedule),
         {:ok, schedule} <- Video.update_recording_schedule(schedule, schedule_params) do
      render(conn, :schedule, schedule: schedule)
    end
  end

  def delete_schedule(conn, %{"id" => id}) do
    with {:ok, schedule} <- Video.get_recording_schedule(id),
         {:ok, _schedule} <- Video.delete_recording_schedule(schedule) do
      send_resp(conn, :no_content, "")
    end
  end

  def enable_schedule(conn, %{"id" => id}) do
    with {:ok, schedule} <- Video.get_recording_schedule(id),
         {:ok, schedule} <- Video.enable_recording_schedule(schedule) do
      render(conn, :schedule, schedule: schedule)
    end
  end

  def disable_schedule(conn, %{"id" => id}) do
    with {:ok, schedule} <- Video.get_recording_schedule(id),
         {:ok, schedule} <- Video.disable_recording_schedule(schedule) do
      render(conn, :schedule, schedule: schedule)
    end
  end

  # Bulk operations for mobile efficiency
  def bulk_create_policies(conn, %{"policies" => policies_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(policies_params),
         {:ok, policies} <- Video.bulk_create_recording_policies(policies_params) do
      conn
      |> put_status(:created)
      |> render(:policies, policies: policies)
    end
  end

  def bulk_update_policies(conn, %{"policies" => policies_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(policies_params),
         {:ok, policies} <- Video.bulk_update_recording_policies(policies_params) do
      render(conn, :policies, policies: policies)
    end
  end

  def bulk_delete_policies(conn, %{"ids" => ids}) when is_list(ids) do
    with {:ok, _result} <- Video.bulk_delete_recording_policies(ids) do
      send_resp(conn, :no_content, "")
    end
  end

  # Import/Export operations
  def import_policies(conn, %{"file" => upload}) do
    with {:ok, policies} <- Video.import_recording_policies(upload) do
      conn
      |> put_status(:created)
      |> render(:policies, policies: policies)
    end
  end

  def export_policies(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, csv_data} <- Video.export_recording_policies(filters) do
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"recording_policies.csv\"")
      |> send_resp(200, csv_data)
    end
  end

  # Template operations
  def list_templates(conn, _params) do
    templates = Video.list_recording_policy_templates()
    render(conn, :templates, templates: templates)
  end

  def create_template(conn, %{"template" => template_params}) do
    with {:ok, template} <- Video.create_recording_policy_template(template_params) do
      conn
      |> put_status(:created)
      |> render(:template, template: template)
    end
  end

  def applytemplate(conn, %{"id" => template_id, "policy" => policy_params}) do
    with {:ok, policy} <- Video.apply_recording_policy_template(template_id, policy_params) do
      conn
      |> put_status(:created)
      |> render(:policy, policy: policy)
    end
  end

  # Version control operations
  def list_versions(conn, %{"id" => id}) do
    with {:ok, versions} <- Video.list_recording_policy_versions(id) do
      render(conn, :versions, versions: versions)
    end
  end

  def rollback(conn, %{"id" => id, "version" => version}) do
    with {:ok, policy} <- Video.rollback_recording_policy(id, version) do
      render(conn, :policy, policy: policy)
    end
  end
end

# Agent: Worker - 4 (Video Recording Management Worker)
# SOPv5.1 Compliance: ✅ Video recording management with cybernetic framework
# Domain: Video
# Responsibilities: Recording policy CRUD operations, recording control, schedule management
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
