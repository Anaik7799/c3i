defmodule Indrajaal.Types do
  @moduledoc """
  Comprehensive type definitions for the Indrajaal Security Platform.

  This module provides exhaustive type specifications for all __data structures,
  ensuring complete type safety across the entire system.
  """

  # Core Entity Types
  @type tenant_id :: pos_integer() | binary()
  @type user_id :: pos_integer() | binary()
  @type organization_id :: pos_integer() | binary()
  @type site_id :: pos_integer() | binary()
  @type device_id :: pos_integer() | binary()
  @type resource_id :: pos_integer() | binary()

  # Status and State Types
  @type status :: :active | :inactive | :suspended | :pending | :deleted
  @type device_status :: :online | :offline | :maintenance | :error | :unknown
  @type alarm_status :: :active | :acknowledged | :resolved | :false_alarm
  @type incident_status :: :open | :investigating | :resolved | :closed | :cancelled
  @type priority :: :low | :medium | :high | :critical | :emergency

  # Authentication and Authorization Types
  @type role :: :admin | :manager | :operator | :viewer | :guest | :technician
  @type permission :: :read | :write | :delete | :execute | :admin | :view_only
  @type access_level :: :building | :floor | :room | :area | :zone | :global
  @type auth_method :: :password | :oauth | :saml | :mfa | :biometric

  # Temporal Types
  @type timestamp :: DateTime.t()
  @type date_range :: {Date.t(), Date.t()}
  @type time_period :: :hour | :day | :week | :month | :quarter | :year
  @type timezone :: binary()

  # Geographic and Location Types
  # {latitude, longitude}
  @type coordinates :: {float(), float()}
  @type address :: %{
          street: binary(),
          city: binary(),
          state: binary(),
          postal_code: binary(),
          country: binary()
        }
  @type region :: :north | :south | :east | :west | :central

  # Communication Types
  @type email :: binary()
  @type phone :: binary()
  @type url :: binary()
  @type ip_address :: binary()
  @type mac_address :: binary()

  # Device and Equipment Types
  @type device_type :: :camera | :sensor | :panel | :reader | :intercom | :speaker
  @type sensor_type ::
          :motion | :door | :window | :temperature | :humidity | :smoke | :glass_break
  @type camera_type :: :fixed | :ptz | :dome | :bullet | :thermal | :ip
  @type credential_type :: :card | :pin | :biometric | :mobile | :key | :token

  # Data Structure Types
  @type meta_data :: %{optional(atom() | binary()) => any()}
  @type settings :: %{optional(atom() | binary()) => any()}
  @type configuration :: %{optional(atom() | binary()) => any()}
  @type parameters :: %{optional(atom() | binary()) => any()}

  # Result and Response Types
  @type result(success_type) :: {:ok, success_type} | {:error, error_reason()}
  @type result(
          success_type,
          error_type
        ) :: {:ok, success_type} | {:error, error_type}
  @type error_reason :: atom() | binary() | %{message: binary(), code: atom()}
  @type validation_error :: %{field: atom(), message: binary(), code: atom()}
  @type operation_result :: :ok | {:error, error_reason()}

  # Pagination and Filtering Types
  @type page_info :: %{
          page: pos_integer(),
          per_page: pos_integer(),
          total_pages: pos_integer(),
          total_entries: non_neg_integer(),
          has_next: boolean(),
          has_previous: boolean()
        }
  @type sort_order :: :asc | :desc
  @type sort_field :: atom() | binary()
  @type filter_operator :: :eq | :ne | :gt | :gte | :lt | :lte | :in | :not_in | :like | :ilike
  @type filter_condition :: {atom(), filter_operator(), any()}

  # Security Types
  @type security_level :: :public | :internal | :confidential | :restricted | :secret
  @type encryption_algorithm :: :aes256 | :rsa2048 | :rsa4096 | :ed25519
  @type hash_algorithm :: :sha256 | :sha512 | :bcrypt | :argon2
  @type token_type :: :access | :refresh | :session | :api | :webhook

  # Analytics and Metrics Types
  @type metric_type :: :counter | :gauge | :histogram | :timer | :summary
  @type metric_value :: number() | boolean()
  @type aggregation_function :: :sum | :avg | :min | :max | :count | :distinct
  @type time_series_data :: [{timestamp(), metric_value()}]

  # Report and Export Types
  @type report_format :: :pdf | :excel | :csv | :json | :xml
  @type report_type :: :security | :maintenance | :usage | :compliance | :performance | :financial
  @type export_options :: %{
          format: report_format(),
          include_charts: boolean(),
          include_meta_data: boolean(),
          compression: boolean()
        }

  # Event and Notification Types
  @type __event_type :: :alarm | :incident | :maintenance | :__user_action | :system | :security
  @type notification_type :: :email | :sms | :push | :webhook | :dashboard
  @type notification_priority :: :low | :normal | :high | :urgent | :immediate

  # Asset and Equipment Types
  @type asset_category :: :hardware | :software | :vehicle | :facility | :tool
  @type asset_status :: :in_use | :available | :maintenance | :retired | :disposed
  @type maintenance_type :: :pr_eventive | :corrective | :emergency | :upgrade | :calibration
  @type work_order_status :: :scheduled | :in_progress | :completed | :cancelled | :on_hold

  # Compliance and Audit Types
  @type compliance_framework :: :iso27001 | :soc2 | :pci_dss | :gdpr | :hipaa | :custom
  @type audit_action ::
          :create
          | :read
          | :update
          | :delete
          | :login
          | :logout
          | :access_granted
          | :access_denied
  @type compliance_status :: :compliant | :non_compliant | :partially_compliant | :not_assessed

  # Integration Types
  @type integration_type :: :api | :webhook | :ftp | :email | :__database | :file_import
  @type __data_source_type :: :internal | :external | :third_party | :legacy
  @type sync_status :: :pending | :in_progress | :completed | :failed | :paused

  # Video and Media Types
  @type video_format :: :h264 | :h265 | :mjpeg | :mpeg4
  @type video_resolution :: :"720p" | :"1080p" | :"4K" | :"8K" | :custom
  @type recording_mode :: :continuous | :motion | :scheduled | :manual
  @type stream_quality :: :low | :medium | :high | :ultra | :adaptive

  # Advanced Type Compositions
  @type tenant_context :: %{
          tenant_id: tenant_id(),
          user_id: user_id(),
          organization_id: organization_id(),
          permissions: [permission()],
          settings: settings()
        }

  @type audit_context :: %{
          user_id: user_id(),
          tenant_id: tenant_id(),
          ip_address: ip_address(),
          __user_agent: binary(),
          timestamp: timestamp(),
          action: audit_action(),
          resource_type: atom(),
          resource_id: resource_id()
        }

  @type query_options :: %{
          filters: [filter_condition()],
          sort: [{sort_field(), sort_order()}],
          page: pos_integer(),
          per_page: pos_integer(),
          include: [atom()],
          tenant_id: tenant_id()
        }

  @type bulk_operation_result :: %{
          total: non_neg_integer(),
          success: non_neg_integer(),
          failed: non_neg_integer(),
          errors: [validation_error()],
          duration_ms: non_neg_integer()
        }

  @type system_health :: %{
          status: :healthy | :degraded | :critical,
          uptime_seconds: non_neg_integer(),
          memory_usage_percent: float(),
          cpu_usage_percent: float(),
          disk_usage_percent: float(),
          active_connections: non_neg_integer(),
          response_time_ms: non_neg_integer()
        }

  @type performance_metrics :: %{
          __requests_per_second: float(),
          average_response_time_ms: float(),
          error_rate_percent: float(),
          throughput_mbps: float(),
          active_users: non_neg_integer(),
          __database_connections: non_neg_integer()
        }

  # Function Type Specifications for Common Patterns
  @type async_operation(result_type) :: Task.t() | {:ok, result_type} | {:error, error_reason()}
  @type stream_operation(item_type) :: Enumerable.t() | Stream.t() | [item_type]
  @type batch_operation(
          item_type,
          result_type
        ) :: ([item_type] -> result(result_type))

  # GenServer and Process Types
  @type server_name :: atom() | {:global, atom()} | {:via, module(), any()}
  @type server_option :: {:name, server_name()} | {:timeout, timeout()} | {:debug, [atom()]}
  @type process_state :: %{optional(atom()) => any()}

  # Configuration Types
  @type config_key :: atom() | [atom()] | binary()
  @type config_value :: any()
  @type environment :: :dev | :test | :prod | :staging

  # Testing Types
  @type test_factory_options :: %{
          count: pos_integer(),
          tenant: any(),
          attributes: %{optional(atom()) => any()}
        }
  @type mock_options :: %{
          expect: [{atom(), [any()], any()}],
          allow: [pid()],
          verify_on_exit: boolean()
        }

  # Error Type Definitions
  @type domain_error ::
          {:validation_error, [validation_error()]}
          | {:not_found, {atom(), resource_id()}}
          | {:unauthorized, binary()}
          | {:forbidden, binary()}
          | {:conflict, binary()}
          | {:rate_limited, binary()}
          | {:service_unavailable, binary()}
          | {:internal_error, binary()}

  # Utility Types
  @type maybe(type) :: type | nil
  @type list_of(type) :: [type]
  @type map_of(key_type, value_type) :: %{key_type => value_type}
  @type tuple_of(type1, type2) :: {type1, type2}
  @type union(type1, type2) :: type1 | type2

  # Type Validation Functions
  @spec valid_email?(binary()) :: boolean()
  def valid_email?(email) when is_binary(email) do
    email =~ ~r/^[^\s]+@[^\s]+\.[^\s]+$/
  end

  @spec valid_email?(any()) :: any()
  def valid_email?(_), do: false

  @spec valid_phone?(binary()) :: boolean()
  def valid_phone?(phone) when is_binary(phone) do
    phone =~ ~r/^\+?[\d\s\-\(\)]{10,}$/
  end

  @spec valid_phone?(any()) :: any()
  def valid_phone?(_), do: false

  @spec valid_coordinates?(coordinates()) :: boolean()
  def valid_coordinates?({lat, lng}) when is_float(lat) and is_float(lng) do
    lat >= -90.0 and lat <= 90.0 and lng >= -180.0 and lng <= 180.0
  end

  @spec valid_coordinates?(any()) :: any()
  def valid_coordinates?(_), do: false

  @spec valid_priority?(priority()) :: boolean()
  def valid_priority?(priority)
      when priority in [:low, :medium, :high, :critical, :emergency],
      do: true

  @spec valid_priority?(any()) :: any()
  def valid_priority?(_), do: false

  @spec valid_status?(status()) :: boolean()
  def valid_status?(status)
      when status in [:active, :inactive, :suspended, :pending, :deleted],
      do: true

  @spec valid_status?(any()) :: any()
  def valid_status?(_), do: false
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
