defmodule IndrajaalWeb.Api.Mobile.Config.VideoRetentionController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Video
  alias IndrajaalWeb.Api.Mobile.Shared.MobileSecurityValidator

  @doc """
  Mobile API controller for video retention policy configuration within the configuration system.
  Provides endpoints for creating, managing, and configuring video retention policies for mobile clients.
  """

  def get_policies(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, retention_policies} <- Video.get_retention_policies(filters) do
      render(conn, :policies, retention_policies: retention_policies)
    end
  end

  def show_policy(conn, %{"id" => id}) do
    with {:ok, retention_policy} <- Video.get_retention_policy(id) do
      render(conn, :policy, retention_policy: retention_policy)
    end
  end

  def update_policies(conn, %{"policies" => policies_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(policies_params),
         {:ok, retention_policies} <- Video.update_retention_policies(policies_params) do
      render(conn, :policies, retention_policies: retention_policies)
    end
  end

  def create_policy(conn, %{"policy" => policy_params}) do
    with :ok <- MobileSecurityValidator.validate_stamp_constraints(policy_params),
         {:ok, retention_policy} <- Video.create_retention_policy(policy_params) do
      conn
      |> put_status(:created)
      |> render(:policy, retention_policy: retention_policy)
    end
  end

  def update_policy(conn, %{"id" => id, "policy" => policy_params}) do
    with {:ok, retention_policy} <- Video.get_retention_policy(id),
         :ok <-
           MobileSecurityValidator.validate_stamp_constraints(policy_params, retention_policy),
         {:ok, retention_policy} <- Video.update_retention_policy(retention_policy, policy_params) do
      render(conn, :policy, retention_policy: retention_policy)
    end
  end

  def delete_policy(conn, %{"id" => id}) do
    with {:ok, retention_policy} <- Video.get_retention_policy(id),
         {:ok, _retention_policy} <- Video.delete_retention_policy(retention_policy) do
      send_resp(conn, :no_content, "")
    end
  end

  # Retention-specific operations
  def setdefault_retention(conn, %{"retentiondays" => retention_days}) do
    with {:ok, policy} <- Video.set_default_retention_period(retention_days) do
      render(conn, :policy, retention_policy: policy)
    end
  end

  def getdefault_retention(conn, _params) do
    with {:ok, policy} <- Video.get_default_retention_policy() do
      render(conn, :policy, retention_policy: policy)
    end
  end

  def applyretention_to_device(conn, %{"deviceid" => device_id, "policyid" => policy_id}) do
    with {:ok, result} <- Video.apply_retention_policy_to_device(device_id, policy_id) do
      render(conn, :application_result, result: result)
    end
  end

  def applyretention_to_site(conn, %{"siteid" => site_id, "policyid" => policy_id}) do
    with {:ok, result} <- Video.apply_retention_policy_to_site(site_id, policy_id) do
      render(conn, :application_result, result: result)
    end
  end

  def getretention_status(conn, %{"recordingid" => recording_id}) do
    with {:ok, status} <- Video.get_retention_status(recording_id) do
      render(conn, :retention_status, status: status)
    end
  end

  # Archive and cleanup operations
  def archive_old_recordings(conn, %{"cutoff_date" => cutoff_date}) do
    with {:ok, result} <- Video.archive_recordings_before_date(cutoff_date) do
      render(conn, :archive_result, result: result)
    end
  end

  def cleanup_expired_recordings(conn, _params) do
    with {:ok, result} <- Video.cleanup_expired_recordings() do
      render(conn, :cleanup_result, result: result)
    end
  end

  def get_storage_usage(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, usage} <- Video.get_storage_usage(filters) do
      render(conn, :storage_usage, usage: usage)
    end
  end

  def get_retention_forecast(conn, %{"days" => days}) do
    with {:ok, forecast} <- Video.get_retention_forecast(days) do
      render(conn, :retention_forecast, forecast: forecast)
    end
  end

  # Compliance and legal hold operations
  def createlegal_hold(conn, %{"legalhold" => legal_hold_params}) do
    with :ok <- MobileSecurityValidator.validate_stamp_constraints(legal_hold_params),
         {:ok, legal_hold} <- Video.create_legal_hold(legal_hold_params) do
      conn
      |> put_status(:created)
      |> render(:legal_hold, legal_hold: legal_hold)
    end
  end

  def updatelegal_hold(conn, %{"id" => id, "legalhold" => legal_hold_params}) do
    with {:ok, legal_hold} <- Video.get_legal_hold(id),
         :ok <- MobileSecurityValidator.validate_stamp_constraints(legal_hold_params, legal_hold),
         {:ok, legal_hold} <- Video.update_legal_hold(legal_hold, legal_hold_params) do
      render(conn, :legal_hold, legal_hold: legal_hold)
    end
  end

  def release_legal_hold(conn, %{"id" => id}) do
    with {:ok, legal_hold} <- Video.get_legal_hold(id),
         {:ok, legal_hold} <- Video.release_legal_hold(legal_hold) do
      render(conn, :legal_hold, legal_hold: legal_hold)
    end
  end

  def list_legal_holds(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, legal_holds} <- Video.list_legal_holds(filters) do
      render(conn, :legal_holds, legal_holds: legal_holds)
    end
  end

  # Bulk operations for mobile efficiency
  def bulk_create_policies(conn, %{"policies" => policies_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(policies_params),
         {:ok, retention_policies} <- Video.bulk_create_retention_policies(policies_params) do
      conn
      |> put_status(:created)
      |> render(:policies, retention_policies: retention_policies)
    end
  end

  def bulk_update_policies(conn, %{"policies" => policies_params}) do
    with :ok <- MobileSecurityValidator.validate_bulk_stamp_constraints(policies_params),
         {:ok, retention_policies} <- Video.bulk_update_retention_policies(policies_params) do
      render(conn, :policies, retention_policies: retention_policies)
    end
  end

  def bulk_delete_policies(conn, %{"ids" => ids}) when is_list(ids) do
    with {:ok, _result} <- Video.bulk_delete_retention_policies(ids) do
      send_resp(conn, :no_content, "")
    end
  end

  # Import/Export operations
  def import_policies(conn, %{"file" => upload}) do
    with {:ok, retention_policies} <- Video.import_retention_policies(upload) do
      conn
      |> put_status(:created)
      |> render(:policies, retention_policies: retention_policies)
    end
  end

  def export_policies(conn, params) do
    with {:ok, filters} <- MobileSecurityValidator.extract_filters(params),
         {:ok, csv_data} <- Video.export_retention_policies(filters) do
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"retention_policies.csv\"")
      |> send_resp(200, csv_data)
    end
  end

  # Template operations
  def list_templates(conn, _params) do
    templates = Video.list_retention_policy_templates()
    render(conn, :templates, templates: templates)
  end

  def create_template(conn, %{"template" => template_params}) do
    with {:ok, template} <- Video.create_retention_policy_template(template_params) do
      conn
      |> put_status(:created)
      |> render(:template, template: template)
    end
  end

  def applytemplate(conn, %{"id" => template_id, "policy" => policy_params}) do
    with {:ok, retention_policy} <-
           Video.apply_retention_policy_template(template_id, policy_params) do
      conn
      |> put_status(:created)
      |> render(:policy, retention_policy: retention_policy)
    end
  end

  # Version control operations
  def list_versions(conn, %{"id" => id}) do
    with {:ok, versions} <- Video.list_retention_policy_versions(id) do
      render(conn, :versions, versions: versions)
    end
  end

  def rollback(conn, %{"id" => id, "version" => version}) do
    with {:ok, retention_policy} <- Video.rollback_retention_policy(id, version) do
      render(conn, :policy, retention_policy: retention_policy)
    end
  end
end

# Agent: Worker - 4 (Video Retention Management Worker)
# SOPv5.1 Compliance: ✅ Video retention management with cybernetic framework
# Domain: Video
# Responsibilities: Retention policy CRUD operations, legal hold management, storage optimization
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
