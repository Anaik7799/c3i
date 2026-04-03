defmodule Indrajaal.Notifications.Preferences do
  @moduledoc """
  User notification preferences management.

  Handles per - user settings for notification types, quiet hours,
  and delivery preferences.

  Agent: Helper - 3 manages notification preferences
  SOPv5.1 Compliance: # OK:
  STAMP Safety: User privacy enforced
  """

  alias Indrajaal.Accounts
  alias Indrajaal.Notifications.UserPreferences
  alias Indrajaal.Repo
  alias Indrajaal.Shared.TimeUtilities

  import Ecto.Query

  require Logger

  # Default preferences
  @default_preferences %{
    # Notification types
    alarm_notifications: true,
    critical_alarm_notifications: true,
    device_notifications: true,
    maintenance_notifications: true,
    system_notifications: true,
    security_notifications: true,
    approval_notifications: true,

    # Delivery preferences
    push_enabled: true,
    email_enabled: false,
    sms_enabled: false,

    # Quiet hours
    quiet_hours_enabled: false,
    quiet_hours_start: ~T[22:00:00],
    quiet_hours_end: ~T[07:00:00],

    # Batching preferences
    batch_non_critical: true,
    batch_window_minutes: 30,

    # Sound preferences
    notification_sound: "default",
    critical_sound: "critical_alarm",
    vibration_enabled: true,

    # Language preference
    locale: "en"
  }

  @doc """
  Gets user preferences, creating defaults if none exist.
  """
  @spec get_preferences(any()) :: any()
  def get_preferences(user_id) do
    # Agent Comment: Helper - 3 retrieves preferences
    # STAMP Safety: Ensure user isolation

    case Repo.get_by(UserPreferences, user_id: user_id) do
      nil ->
        # Create default preferences
        create_default_preferences(user_id)

      prefs ->
        {:ok, prefs}
    end
  end

  @doc """
  Updates user preferences.
  """
  @spec update_preferences(any(), any()) :: any()
  def update_preferences(user_id, params) do
    # Agent Comment: Helper - 3 updates preferences
    # STAMP Safety: Validate all preference values

    {:ok, prefs} = get_preferences(user_id)

    prefs
    |> UserPreferences.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        # Clear cache
        clear_preferences_cache(user_id)

        # Log significant changes
        log_preference_changes(user_id, prefs, updated)

        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Resets preferences to defaults.
  """
  @spec reset_preferences(any()) :: any()
  def reset_preferences(user_id) do
    {:ok, prefs} = get_preferences(user_id)

    prefs
    |> UserPreferences.changeset(@default_preferences)
    |> Repo.update()
  end

  @doc """
  Checks if a specific notification type is enabled.
  """
  @spec notification_enabled?(any(), any()) :: any()
  def notification_enabled?(user_id, notification_type) do
    {:ok, prefs} = get_preferences(user_id)

    case notification_type do
      :alarm_triggered -> prefs.alarm_notifications
      :critical_alarm -> prefs.critical_alarm_notifications
      :device_offline -> prefs.device_notifications
      :device_online -> prefs.device_notifications
      :maintenance_reminder -> prefs.maintenance_notifications
      :system_announcement -> prefs.system_notifications
      :security_breach -> prefs.security_notifications
      :access_denied -> prefs.security_notifications
      :approval_required -> prefs.approval_notifications
      # Allow unknown types by default
      _ -> true
    end
  end

  @doc """
  Checks if current time is within quiet hours.
  """
  @spec in_quiet_hours?(any()) :: any()
  def in_quiet_hours?(user_id) do
    {:ok, prefs} = get_preferences(user_id)

    if prefs.quiet_hours_enabled do
      current_time = Time.utc_now()

      time_in_range?(
        current_time,
        prefs.quiet_hours_start,
        prefs.quiet_hours_end
      )
    else
      false
    end
  end

  @doc """
  Gets delivery channels enabled for a user.
  """
  @spec get_delivery_channels(any()) :: any()
  def get_delivery_channels(user_id) do
    {:ok, prefs} = get_preferences(user_id)

    channels = []
    channels = if prefs.push_enabled, do: [:push | channels], else: channels
    channels = if prefs.email_enabled, do: [:email | channels], else: channels
    channels = if prefs.sms_enabled, do: [:sms | channels], else: channels

    channels
  end

  @doc """
  Bulk updates preferences for multiple __users.
  """
  @spec bulk_update_preferences(any(), any()) :: any()
  def bulk_update_preferences(user_ids, params) do
    # Get all preferences
    prefs_query =
      from(up in UserPreferences,
        where: up.user_id in ^user_ids
      )

    all_prefs = prefs_query |> Repo.all()

    existing = Map.new(all_prefs, &{&1.user_id, &1})

    # Update each
    results =
      Enum.map(user_ids, fn user_id ->
        case Map.get(existing, user_id) do
          nil ->
            # Create with __params
            create_preferences(user_id, params)

          prefs ->
            # Update existing
            prefs
            |> UserPreferences.changeset(params)
            |> Repo.update()
        end
      end)

    # Count successes and failures
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    {:ok,
     %{
       updated: length(successes),
       failed: length(failures),
       results: results
     }}
  end

  @doc """
  Gets preference statistics for a tenant.
  """
  @spec get_preference_stats(any()) :: any()
  def get_preference_stats(tenant_id) do
    # Get all __users for tenant
    users = Accounts.list_tenant_users(tenant_id)
    user_ids = Enum.map(users, & &1.id)

    # Query preferences
    stats_query =
      from(up in UserPreferences,
        where: up.user_id in ^user_ids,
        select: %{
          total_users: count(up.id),
          push_enabled: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", up.push_enabled)),
          email_enabled: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", up.email_enabled)),
          sms_enabled: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", up.sms_enabled)),
          quiet_hours_enabled:
            sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", up.quiet_hours_enabled)),
          alarm_notifications:
            sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", up.alarm_notifications)),
          critical_notifications:
            sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", up.critical_alarm_notifications))
        }
      )

    stats = stats_query |> Repo.one()

    # Add percentages
    if stats.total_users > 0 do
      Map.merge(stats, %{
        push_enabled_pct: Float.round(stats.push_enabled / stats.total_users * 100, 1),
        email_enabled_pct: Float.round(stats.email_enabled / stats.total_users * 100, 1),
        sms_enabled_pct: Float.round(stats.sms_enabled / stats.total_users * 100, 1),
        quiet_hours_pct: Float.round(stats.quiet_hours_enabled / stats.total_users * 100, 1)
      })
    else
      stats
    end
  end

  @doc """
  Exports user preferences.
  """
  @spec export_preferences(any()) :: any()
  def export_preferences(user_id) do
    {:ok, prefs} = get_preferences(user_id)

    prefs_map = Map.from_struct(prefs)

    %{
      version: "1.0",
      exported_at: DateTime.utc_now(),
      preferences:
        prefs_map
        |> Map.drop([:id, :user_id, :inserted_at, :updated_at, :__meta__])
    }
  end

  @doc """
  Imports user preferences.
  """
  def import_preferences(user_id, import_data) do
    if import_data["version"] == "1.0" do
      update_preferences(user_id, import_data["preferences"])
    else
      {:error, :unsupported_version}
    end
  end

  # Private functions

  @spec create_default_preferences(term()) :: term()
  defp create_default_preferences(user_id) do
    params = Map.put(@default_preferences, :user_id, user_id)

    # EP999: Using generic map pattern instead of undefined UserPreferences struct
    empty_map = %{}
    pref_attrs = empty_map |> Map.merge(params)

    {1, [created]} = Repo.insert_all("notification_preferences", [pref_attrs], returning: [:id])
    {:ok, struct(%{id: created.id}, pref_attrs)}
  end

  @spec create_preferences(term(), term()) :: term()
  defp create_preferences(user_id, params) do
    full_params =
      @default_preferences
      |> Map.merge(params)
      |> Map.put(:user_id, user_id)

    # Create preference record directly using Repo
    attrs = Map.merge(@default_preferences, full_params)

    {1, [created]} = Repo.insert_all("notification_preferences", [attrs], returning: [:id])
    {:ok, Map.put(attrs, :id, created.id)}
  end

  # time_in_range? function moved to Indrajaal.Shared.TimeUtilities for duplicate elimination
  defp time_in_range?(current, start_time, end_time) do
    TimeUtilities.time_in_range?(current, start_time, end_time)
  end

  @spec clear_preferences_cache(term()) :: term()
  defp clear_preferences_cache(user_id) do
    # Clear any cached preferences
    # In production, this would clear Redis / ETS cache
    Process.delete({:preferences_cache, user_id})
  end

  defp log_preference_changes(user_id, old_prefs, new_prefs) do
    require Logger
    # Log significant changes
    initial_changes = []

    changes_after_push =
      if old_prefs.push_enabled != new_prefs.push_enabled do
        [
          "push_notifications: #{old_prefs.push_enabled} -> #{new_prefs.push_enabled}"
          | initial_changes
        ]
      else
        initial_changes
      end

    final_changes =
      if old_prefs.quiet_hours_enabled != new_prefs.quiet_hours_enabled do
        [
          "quiet_hours: #{old_prefs.quiet_hours_enabled} -> #{new_prefs.quiet_hours_enabled}"
          | changes_after_push
        ]
      else
        changes_after_push
      end

    if final_changes != [] do
      Logger.info("User preferences updated", %{
        user_id: user_id,
        changes: final_changes
      })
    end
  end
end

defmodule Indrajaal.Notifications.UserPreferences do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_preferences" do
    field :user_id, :binary_id

    # Notification types
    field :alarm_notifications, :boolean, default: true
    field :critical_alarm_notifications, :boolean, default: true
    field :device_notifications, :boolean, default: true
    field :maintenance_notifications, :boolean, default: true
    field :system_notifications, :boolean, default: true
    field :security_notifications, :boolean, default: true
    field :approval_notifications, :boolean, default: true

    # Delivery preferences
    field :push_enabled, :boolean, default: true
    field :email_enabled, :boolean, default: false
    field :sms_enabled, :boolean, default: false

    # Quiet hours
    field :quiet_hours_enabled, :boolean, default: false
    field :quiet_hours_start, :time
    field :quiet_hours_end, :time

    # Batching
    field :batch_non_critical, :boolean, default: true
    field :batch_window_minutes, :integer, default: 30

    # Sound preferences
    field :notification_sound, :string, default: "default"
    field :critical_sound, :string, default: "critical_alarm"
    field :vibration_enabled, :boolean, default: true

    # Language
    field :locale, :string, default: "en"

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  def changeset(prefs, attrs) do
    prefs
    |> cast(attrs, [
      :user_id,
      :alarm_notifications,
      :critical_alarm_notifications,
      :device_notifications,
      :maintenance_notifications,
      :system_notifications,
      :security_notifications,
      :approval_notifications,
      :push_enabled,
      :email_enabled,
      :sms_enabled,
      :quiet_hours_enabled,
      :quiet_hours_start,
      :quiet_hours_end,
      :batch_non_critical,
      :batch_window_minutes,
      :notification_sound,
      :critical_sound,
      :vibration_enabled,
      :locale
    ])
    |> validate_required([:user_id])
    |> validate_number(:batch_window_minutes, greater_than: 0, less_than_or_equal_to: 1440)
    |> validate_inclusion(:locale, ["en", "es", "fr"])
    |> unique_constraint(:user_id)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetic feedback
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
