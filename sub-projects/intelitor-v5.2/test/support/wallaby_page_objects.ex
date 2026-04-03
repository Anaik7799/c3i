defmodule Indrajaal.WallabyPageObjects do
  @moduledoc """
  Page Object Model for Wallaby E2E tests.

  This module defines reusable page objects and selectors for all domains
  in the Indrajaal Security Monitoring System, following enterprise testing patterns.
  """

  defmacro __using__(_opts) do
    quote do
      alias Indrajaal.WallabyPageObjects.{
        LoginPage,
        DashboardPage,
        TenantsPage,
        OrganizationsPage,
        UsersPage,
        TeamsPage,
        SitesPage,
        BuildingsPage,
        DevicesPage,
        CamerasPage,
        AlarmsPage,
        NotificationsPage,
        AccessControlPage,
        AccessRulesPage,
        RolesPage,
        PermissionsPage,
        AnalyticsPage,
        ReportsPage,
        VideoPage,
        StreamsPage,
        CommunicationPage,
        GuardTourPage,
        VisitorPage,
        BillingPage,
        MaintenancePage,
        CompliancePage,
        AssetManagementPage,
        RiskManagementPage,
        DispatchPage
      }
    end
  end

  # Authentication Page Objects
  defmodule LoginPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec email_field() :: any()
    def email_field, do: css("[data-test='login-email']")
    @spec password_field() :: any()
    def password_field, do: css("[data-test='login-password']")
    @spec submit_button() :: any()
    def submit_button, do: css("[data-test='login-submit']")
    @spec forgot_password_link() :: any()
    def forgot_password_link, do: css("[data-test='forgot-password']")
    @spec registration_link() :: any()
    def registration_link, do: css("[data-test='register-link']")
    @spec error_message() :: any()
    def error_message, do: css("[data-test='login-error']")
    @spec success_message() :: any()
    def success_message, do: css("[data-test='login-success']")
  end

  defmodule DashboardPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec main_container() :: any()
    def main_container, do: css("[data-test='dashboard']")
    @spec tenant_selector() :: any()
    def tenant_selector, do: css("[data-test='tenant-selector']")
    @spec user_menu() :: any()
    def user_menu, do: css("[data-test='user-menu']")
    @spec logout_button() :: any()
    def logout_button, do: css("[data-test='logout']")
    @spec notification_bell() :: any()
    def notification_bell, do: css("[data-test='notifications']")
    @spec quick_stats() :: any()
    def quick_stats, do: css("[data-test='quick-stats']")
    @spec recent_activities() :: any()
    def recent_activities, do: css("[data-test='recent-activities']")
  end

  # Core Domain Page Objects
  defmodule TenantsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='tenants-table']")
    @spec new_tenant_button() :: any()
    def new_tenant_button, do: css("[data-test='new-tenant']")
    @spec tenant_form() :: any()
    def tenant_form, do: css("[data-test='tenant-form']")
    @spec tenant_name_field() :: any()
    def tenant_name_field, do: css("[data-test='tenant-name']")
    @spec tenant_subdomain_field() :: any()
    def tenant_subdomain_field, do: css("[data-test='tenant-subdomain']")
    @spec tenant_status_select() :: any()
    def tenant_status_select, do: css("[data-test='tenant-status']")
    @spec save_button() :: any()
    def save_button, do: css("[data-test='save-tenant']")
    @spec edit_button(any()) :: any()
    def edit_button(tenant_id), do: css("[data-test='edit-tenant-#{tenant_id}']")
    @spec delete_button(any()) :: any()
    def delete_button(tenant_id), do: css("[data-test='delete-tenant-#{tenant_id}']")
  end

  defmodule OrganizationsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='organizations-table']")
    @spec new_organization_button() :: any()
    def new_organization_button, do: css("[data-test='new-organization']")
    @spec organization_form() :: any()
    def organization_form, do: css("[data-test='organization-form']")
    @spec organization_name_field() :: any()
    def organization_name_field, do: css("[data-test='organization-name']")
    @spec organization_type_select() :: any()
    def organization_type_select, do: css("[data-test='organization-type']")
    @spec parent_organization_select() :: any()
    def parent_organization_select, do: css("[data-test='parent-organization']")
  end

  # Accounts Domain Page Objects
  defmodule UsersPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='users-table']")
    @spec new_user_button() :: any()
    def new_user_button, do: css("[data-test='new-user']")
    @spec user_form() :: any()
    def user_form, do: css("[data-test='user-form']")
    @spec email_field() :: any()
    def email_field, do: css("[data-test='user-email']")
    @spec first_name_field() :: any()
    def first_name_field, do: css("[data-test='user-first-name']")
    @spec last_name_field() :: any()
    def last_name_field, do: css("[data-test='user-last-name']")
    @spec role_select() :: any()
    def role_select, do: css("[data-test='user-role']")
    @spec active_checkbox() :: any()
    def active_checkbox, do: css("[data-test='user-active']")
    @spec search_input() :: any()
    def search_input, do: css("[data-test='user-search']")
    @spec filter_role_select() :: any()
    def filter_role_select, do: css("[data-test='filter-role']")
  end

  defmodule TeamsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='teams-table']")
    @spec new_team_button() :: any()
    def new_team_button, do: css("[data-test='new-team']")
    @spec team_form() :: any()
    def team_form, do: css("[data-test='team-form']")
    @spec team_name_field() :: any()
    def team_name_field, do: css("[data-test='team-name']")
    @spec team_description_field() :: any()
    def team_description_field, do: css("[data-test='team-description']")
    @spec team_lead_select() :: any()
    def team_lead_select, do: css("[data-test='team-lead']")
    @spec members_multiselect() :: any()
    def members_multiselect, do: css("[data-test='team-members']")
  end

  # Sites Domain Page Objects
  defmodule SitesPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='sites-table']")
    @spec new_site_button() :: any()
    def new_site_button, do: css("[data-test='new-site']")
    @spec site_form() :: any()
    def site_form, do: css("[data-test='site-form']")
    @spec site_name_field() :: any()
    def site_name_field, do: css("[data-test='site-name']")
    @spec site_address_field() :: any()
    def site_address_field, do: css("[data-test='site-address']")
    @spec site_coordinates_field() :: any()
    def site_coordinates_field, do: css("[data-test='site-coordinates']")
    @spec site_map_view() :: any()
    def site_map_view, do: css("[data-test='site-map']")
    @spec buildings_tab() :: any()
    def buildings_tab, do: css("[data-test='buildings-tab']")
    @spec zones_tab() :: any()
    def zones_tab, do: css("[data-test='zones-tab']")
  end

  defmodule BuildingsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='buildings-table']")
    @spec new_building_button() :: any()
    def new_building_button, do: css("[data-test='new-building']")
    @spec building_form() :: any()
    def building_form, do: css("[data-test='building-form']")
    @spec building_name_field() :: any()
    def building_name_field, do: css("[data-test='building-name']")
    @spec building_floors_field() :: any()
    def building_floors_field, do: css("[data-test='building-floors']")
    @spec building_type_select() :: any()
    def building_type_select, do: css("[data-test='building-type']")
    @spec floor_plan_upload() :: any()
    def floor_plan_upload, do: css("[data-test='floor-plan-upload']")
  end

  # Devices Domain Page Objects
  defmodule DevicesPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_table() :: any()
    def listing_table, do: css("[data-test='devices-table']")
    @spec new_device_button() :: any()
    def new_device_button, do: css("[data-test='new-device']")
    @spec device_form() :: any()
    def device_form, do: css("[data-test='device-form']")
    @spec device_name_field() :: any()
    def device_name_field, do: css("[data-test='device-name']")
    @spec device_type_select() :: any()
    def device_type_select, do: css("[data-test='device-type']")
    @spec device_model_field() :: any()
    def device_model_field, do: css("[data-test='device-model']")
    @spec device_location_select() :: any()
    def device_location_select, do: css("[data-test='device-location']")
    @spec device_status_indicator() :: any()
    def device_status_indicator, do: css("[data-test='device-status']")
    @spec device_map_view() :: any()
    def device_map_view, do: css("[data-test='devices-map']")
    @spec status_filter_select() :: any()
    def status_filter_select, do: css("[data-test='status-filter']")
  end

  defmodule CamerasPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec listing_grid() :: any()
    def listing_grid, do: css("[data-test='cameras-grid']")
    @spec camera_preview(any()) :: any()
    def camera_preview(camera_id), do: css("[data-test='camera-preview-#{camera_id}']")
    @spec live_view_button(any()) :: any()
    def live_view_button(camera_id), do: css("[data-test='live-view-#{camera_id}']")
    @spec recording_button(any()) :: any()
    def recording_button(camera_id), do: css("[data-test='record-#{camera_id}']")
    @spec ptz_controls(any()) :: any()
    def ptz_controls(camera_id), do: css("[data-test='ptz-controls-#{camera_id}']")
    @spec camera_settings_button(any()) :: any()
    def camera_settings_button(camera_id), do: css("[data-test='camera-settings-#{camera_id}']")
  end

  # Alarms Domain Page Objects
  defmodule AlarmsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec alarms_dashboard() :: any()
    def alarms_dashboard, do: css("[data-test='alarms-dashboard']")
    @spec active_alarms_panel() :: any()
    def active_alarms_panel, do: css("[data-test='active-alarms']")
    @spec alarm_history_table() :: any()
    def alarm_history_table, do: css("[data-test='alarm-history']")
    @spec new_incident_button() :: any()
    def new_incident_button, do: css("[data-test='new-incident']")
    @spec incident_form() :: any()
    def incident_form, do: css("[data-test='incident-form']")
    @spec priority_select() :: any()
    def priority_select, do: css("[data-test='incident-priority']")
    @spec category_select() :: any()
    def category_select, do: css("[data-test='incident-category']")
    @spec description_field() :: any()
    def description_field, do: css("[data-test='incident-description']")
    @spec acknowledge_button(any()) :: any()
    def acknowledge_button(alarm_id), do: css("[data-test='acknowledge-#{alarm_id}']")

    @spec resolve_button(any()) :: any()
    def resolve_button(alarm_id), do: css("[data-test='resolve-#{alarm_id}']")
  end

  defmodule NotificationsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]

    @spec notifications_list() :: any()
    def notifications_list, do: css("[data-test='notifications-list']")

    @spec unread_count() :: any()
    def unread_count, do: css("[data-test='unread-count']")

    @spec mark_read_button(any()) :: any()
    def mark_read_button(notification_id), do: css("[data-test='mark-read-#{notification_id}']")

    @spec mark_all_read_button() :: any()
    def mark_all_read_button, do: css("[data-test='mark-all-read']")

    @spec notification_settings_button() :: any()
    def notification_settings_button, do: css("[data-test='notification-settings']")

    @spec email_notifications_checkbox() :: any()
    def email_notifications_checkbox, do: css("[data-test='email-notifications']")

    @spec sms_notifications_checkbox() :: any()
    def sms_notifications_checkbox, do: css("[data-test='sms-notifications']")
  end

  # Access Control Domain Page Objects
  defmodule AccessControlPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec credentials_table() :: any()
    def credentials_table, do: css("[data-test='credentials-table']")
    @spec new_credential_button() :: any()
    def new_credential_button, do: css("[data-test='new-credential']")
    @spec credential_form() :: any()
    def credential_form, do: css("[data-test='credential-form']")
    @spec credential_type_select() :: any()
    def credential_type_select, do: css("[data-test='credential-type']")
    @spec card_number_field() :: any()
    def card_number_field, do: css("[data-test='card-number']")
    @spec access_levels_multiselect() :: any()
    def access_levels_multiselect, do: css("[data-test='access-levels']")
    @spec valid_from_date() :: any()
    def valid_from_date, do: css("[data-test='valid-from']")
    @spec valid_until_date() :: any()
    def valid_until_date, do: css("[data-test='valid-until']")
    @spec access_logs_table() :: any()
    def access_logs_table, do: css("[data-test='access-logs']")
  end

  defmodule AccessRulesPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec rules_table() :: any()
    def rules_table, do: css("[data-test='access-rules-table']")
    @spec new_rule_button() :: any()
    def new_rule_button, do: css("[data-test='new-access-rule']")
    @spec rule_form() :: any()
    def rule_form, do: css("[data-test='access-rule-form']")
    @spec rule_name_field() :: any()
    def rule_name_field, do: css("[data-test='rule-name']")
    @spec resource_select() :: any()
    def resource_select, do: css("[data-test='rule-resource']")
    @spec action_select() :: any()
    def action_select, do: css("[data-test='rule-action']")
    @spec conditions_builder() :: any()
    def conditions_builder, do: css("[data-test='conditions-builder']")
    @spec add_condition_button() :: any()
    def add_condition_button, do: css("[data-test='add-condition']")
  end

  # Policy Domain Page Objects
  defmodule RolesPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec roles_table() :: any()
    def roles_table, do: css("[data-test='roles-table']")
    @spec new_role_button() :: any()
    def new_role_button, do: css("[data-test='new-role']")
    @spec role_form() :: any()
    def role_form, do: css("[data-test='role-form']")
    @spec role_name_field() :: any()
    def role_name_field, do: css("[data-test='role-name']")
    @spec role_description_field() :: any()
    def role_description_field, do: css("[data-test='role-description']")
    @spec permissions_list() :: any()
    def permissions_list, do: css("[data-test='permissions-list']")
    @spec permission_checkbox(any()) :: any()
    def permission_checkbox(permission_id), do: css("[data-test='permission-#{permission_id}']")
  end

  defmodule PermissionsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec permissions_table() :: any()
    def permissions_table, do: css("[data-test='permissions-table']")
    @spec new_permission_button() :: any()
    def new_permission_button, do: css("[data-test='new-permission']")
    @spec permission_form() :: any()
    def permission_form, do: css("[data-test='permission-form']")
    @spec permission_name_field() :: any()
    def permission_name_field, do: css("[data-test='permission-name']")
    @spec resource_type_select() :: any()
    def resource_type_select, do: css("[data-test='resource-type']")
    @spec action_type_select() :: any()
    def action_type_select, do: css("[data-test='action-type']")
    @spec scope_field() :: any()
    def scope_field, do: css("[data-test='permission-scope']")
  end

  # Analytics Domain Page Objects
  defmodule AnalyticsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec analytics_dashboard() :: any()
    def analytics_dashboard, do: css("[data-test='analytics-dashboard']")
    @spec date_range_picker() :: any()
    def date_range_picker, do: css("[data-test='date-range-picker']")
    @spec refresh_button() :: any()
    def refresh_button, do: css("[data-test='refresh-analytics']")
    @spec export_button() :: any()
    def export_button, do: css("[data-test='export-analytics']")
    @spec chart_container(any()) :: any()
    def chart_container(chart_id), do: css("[data-test='chart-#{chart_id}']")
    @spec kpi_widget(any()) :: any()
    def kpi_widget(kpi_name), do: css("[data-test='kpi-#{kpi_name}']")
    @spec filter_panel() :: any()
    def filter_panel, do: css("[data-test='analytics-filters']")
  end

  defmodule ReportsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec reports_list() :: any()
    def reports_list, do: css("[data-test='reports-list']")
    @spec new_report_button() :: any()
    def new_report_button, do: css("[data-test='new-report']")
    @spec report_form() :: any()
    def report_form, do: css("[data-test='report-form']")
    @spec report_name_field() :: any()
    def report_name_field, do: css("[data-test='report-name']")
    @spec report_type_select() :: any()
    def report_type_select, do: css("[data-test='report-type']")
    @spec data_sources_multiselect() :: any()
    def data_sources_multiselect, do: css("[data-test='data-sources']")
    @spec generate_button() :: any()
    def generate_button, do: css("[data-test='generate-report']")
    @spec download_button(any()) :: any()
    def download_button(report_id), do: css("[data-test='download-#{report_id}']")
  end

  # Video Domain Page Objects
  defmodule VideoPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec video_wall() :: any()
    def video_wall, do: css("[data-test='video-wall']")
    @spec camera_grid() :: any()
    def camera_grid, do: css("[data-test='camera-grid']")
    @spec playback_controls() :: any()
    def playback_controls, do: css("[data-test='playback-controls']")
    @spec recording_timeline() :: any()
    def recording_timeline, do: css("[data-test='recording-timeline']")
    @spec export_video_button() :: any()
    def export_video_button, do: css("[data-test='export-video']")
    @spec motion_detection_toggle() :: any()
    def motion_detection_toggle, do: css("[data-test='motion-detection']")
    @spec alert_zones_editor() :: any()
    def alert_zones_editor, do: css("[data-test='alert-zones']")
  end

  defmodule StreamsPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec streams_list() :: any()
    def streams_list, do: css("[data-test='streams-list']")
    @spec stream_player(any()) :: any()
    def stream_player(stream_id), do: css("[data-test='stream-player-#{stream_id}']")
    @spec stream_quality_select() :: any()
    def stream_quality_select, do: css("[data-test='stream-quality']")
    @spec fullscreen_button() :: any()
    def fullscreen_button, do: css("[data-test='fullscreen']")
    @spec stream_info_panel() :: any()
    def stream_info_panel, do: css("[data-test='stream-info']")
  end

  # Communication Domain Page Objects
  defmodule CommunicationPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec messages_list() :: any()
    def messages_list, do: css("[data-test='messages-list']")
    @spec new_message_button() :: any()
    def new_message_button, do: css("[data-test='new-message']")
    @spec message_form() :: any()
    def message_form, do: css("[data-test='message-form']")
    @spec recipients_select() :: any()
    def recipients_select, do: css("[data-test='recipients']")
    @spec subject_field() :: any()
    def subject_field, do: css("[data-test='message-subject']")
    @spec body_field() :: any()
    def body_field, do: css("[data-test='message-body']")
    @spec send_button() :: any()
    def send_button, do: css("[data-test='send-message']")
    @spec priority_select() :: any()
    def priority_select, do: css("[data-test='message-priority']")
  end

  # Guard Tour Domain Page Objects
  defmodule GuardTourPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec tours_list() :: any()
    def tours_list, do: css("[data-test='guard-tours-list']")
    @spec new_tour_button() :: any()
    def new_tour_button, do: css("[data-test='new-guard-tour']")
    @spec tour_form() :: any()
    def tour_form, do: css("[data-test='guard-tour-form']")
    @spec tour_name_field() :: any()
    def tour_name_field, do: css("[data-test='tour-name']")
    @spec checkpoints_list() :: any()
    def checkpoints_list, do: css("[data-test='checkpoints-list']")
    @spec add_checkpoint_button() :: any()
    def add_checkpoint_button, do: css("[data-test='add-checkpoint']")
    @spec start_tour_button(any()) :: any()
    def start_tour_button(tour_id), do: css("[data-test='start-tour-#{tour_id}']")

    @spec complete_checkpoint_button(any()) :: any()
    def complete_checkpoint_button(checkpoint_id),
      do: css("[data-test='complete-checkpoint-#{checkpoint_id}']")
  end

  # Visitor Management Domain Page Objects
  defmodule VisitorPage do
    @moduledoc false
    import Wallaby.Query, only: [css: 1]
    @spec visitors_list() :: any()
    def visitors_list, do: css("[data-test='visitors-list']")
    @spec check_in_button() :: any()
    def check_in_button, do: css("[data-test='visitor-check-in']")
    @spec visitor_form() :: any()
    def visitor_form, do: css("[data-test='visitor-form']")
    @spec visitor_name_field() :: any()
    def visitor_name_field, do: css("[data-test='visitor-name']")
    @spec visitor_company_field() :: any()
    def visitor_company_field, do: css("[data-test='visitor-company']")
    @spec host_select() :: any()
    def host_select, do: css("[data-test='visitor-host']")
    @spec purpose_field() :: any()
    def purpose_field, do: css("[data-test='visit-purpose']")
    @spec badge_print_button() :: any()
    def badge_print_button, do: css("[data-test='print-badge']")
    @spec check_out_button(any()) :: any()
    def check_out_button(visitor_id), do: css("[data-test='check-out-#{visitor_id}']")
  end
end
