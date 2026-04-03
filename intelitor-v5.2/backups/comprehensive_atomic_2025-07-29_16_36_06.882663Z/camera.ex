defmodule Intelitor.Video.Camera do
  @moduledoc """
  Represents a video camera in the surveillance system.

  Cameras are the primary video capture devices, supporting various protocols
  like RTSP, ONVIF, and proprietary formats. They can be configured for
  continuous recording, motion detection, and AI-powered analytics.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Video,
    table: "cameras"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Camera identification
    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :model, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :manufacturer, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :serial_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    # Connection details
    attribute :protocol, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:rtsp, :onvif, :http, :proprietary]
      default :rtsp
    end

    attribute :connection_url, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :username, :string do
      public? true
      constraints max_length: 100
    end

    attribute :password_encrypted, :string do
      public? false
      constraints max_length: 500
    end

    attribute :port, :integer do
      public? true
      constraints min: 1, max: 65535
      default 554
    end

    # Location
    attribute :site_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :zone_id, :uuid do
      public? true
    end

    attribute :location_name, :string do
      public? true
      constraints max_length: 200
    end

    attribute :mounting_position, :atom do
      public? true
      constraints one_of: [:ceiling, :wall, :pole, :corner, :outdoor]
    end

    attribute :coverage_area, :string do
      public? true
      constraints max_length: 500
    end

    # Capabilities
    attribute :resolution, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1920x1080"
    end

    attribute :max_resolution, :string do
      public? true
      constraints max_length: 20
    end

    attribute :framerate, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 120
      default 30
    end

    attribute :has_ptz?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :has_audio?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :has_infrared?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :has_analytics?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # PTZ settings
    attribute :ptz_presets, {:array, :map} do
      public? true
      default []
    end

    attribute :default_preset, :string do
      public? true
      constraints max_length: 50
    end

    # Recording settings
    attribute :recording_enabled?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :recording_mode, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:continuous, :motion, :scheduled, :event]
      default :continuous
    end

    attribute :retention_days, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 365
      default 30
    end

    attribute :motion_sensitivity, :integer do
      public? true
      constraints min: 0, max: 100
      default 50
    end

    attribute :motion_zones, {:array, :map} do
      public? true
      default []
    end

    # Stream settings
    attribute :primary_stream_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :secondary_stream_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :stream_key, :string do
      public? true
      constraints max_length: 100
    end

    # Status
    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:online, :offline, :error, :maintenance]
      default :offline
    end

    attribute :last_seen, :utc_datetime_usec do
      public? true
    end

    attribute :health_status, :atom do
      public? true
      constraints one_of: [:good, :warning, :critical]
      default :good
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 500
    end

    # Analytics settings
    attribute :analytics_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :analytics_types, {:array, :atom} do
      public? true

      constraints items: [
                    one_of: [
                      :motion,
                      :person,
                      :vehicle,
                      :face,
                      :license_plate,
                      :loitering,
                      :intrusion,
                      :abandoned_object,
                      :crowd
                    ]
                  ]

      default []
    end

    attribute :analytics_config, :map do
      public? true
      default %{}
    end

    # Metadata
    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    timestamps()
  end

  relationships do
    belongs_to :site, Intelitor.Sites.Site do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :zone, Intelitor.Sites.Zone do
      attribute_public? true
    end

    has_many :streams, Intelitor.Video.Stream
    has_many :recordings, Intelitor.Video.Recording
    has_many :clips, Intelitor.Video.Clip
    has_many :analytics, Intelitor.Video.Analytics
  end

  actions do
    defaults [:create, :read, :destroy, :update]

    update :update_connection do
      require_atomic? false
      accept [:connection_url, :username, :password_encrypted, :port]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :offline)
        |> Ash.Changeset.force_change_attribute(:last_seen, nil)
      end
    end

    update :update_stream_settings do
      require_atomic? false
      accept [:primary_stream_url, :secondary_stream_url, :stream_key]
    end

    update :enable_recording do
      require_atomic? false
      accept [:recording_mode, :retention_days]

      change set_attribute(:recording_enabled?, true)
    end

    update :disable_recording do
      require_atomic? false
      accept []

      change set_attribute(:recording_enabled?, false)
    end

    update :enable_analytics do
      require_atomic? false
      accept [:analytics_types, :analytics_config]

      validate fn changeset, _context ->
        types = Ash.Changeset.get_attribute(changeset, :analytics_types) || []

        if Enum.empty?(types) do
          {:error, field: :analytics_types, message: "must select at least one analytics type"}
        else
          :ok
        end
      end

      change set_attribute(:analytics_enabled?, true)
    end

    update :disable_analytics do
      require_atomic? false
      accept []

      change set_attribute(:analytics_enabled?, false)
    end

    update :update_status do
      require_atomic? false
      accept [:status, :health_status, :error_message]

      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:online, :offline, :error, :maintenance]
      end

      change fn changeset, _context ->
        status = Ash.Changeset.get_argument(changeset, :status)

        changeset =
          if status == :online do
            Ash.Changeset.force_change_attribute(changeset, :last_seen, DateTime.utc_now())
          else
            changeset
          end

        changeset
      end
    end

    update :heartbeat do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :online)
        |> Ash.Changeset.force_change_attribute(:last_seen, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:health_status, :good)
      end
    end

    update :add_preset do
      require_atomic? false
      accept []

      argument :preset_name, :string do
        allow_nil? false
        constraints max_length: 50
      end

      argument :preset_data, :map do
        allow_nil? false
      end

      validate attribute_equals(:has_ptz?, true)

      change fn changeset, _context ->
        presets = Ash.Changeset.get_attribute(changeset, :ptz_presets) || []

        new_preset = %{
          "name" => changeset.arguments.preset_name,
          "data" => changeset.arguments.preset_data,
          "created_at" => DateTime.utc_now()
        }

        # Check if preset name already exists
        if Enum.any?(presets, fn p -> p["name"] == changeset.arguments.preset_name end) do
          Ash.Changeset.add_error(changeset,
            field: :preset_name,
            message: "preset name already exists"
          )
        else
          Ash.Changeset.force_change_attribute(changeset, :ptz_presets, [new_preset | presets])
        end
      end
    end

    update :activate do
      require_atomic? false
      accept []

      validate attribute_equals(:active?, false)

      change set_attribute(:active?, true)
    end

    update :deactivate do
      require_atomic? false
      accept []

      validate attribute_equals(:active?, true)

      change set_attribute(:active?, false)
    end
  end

  calculations do
    calculate :is_online?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn camera ->
            camera.status == :online
          end)

        {:ok, values}
      end
    end

    calculate :is_recording?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn camera ->
            camera.recording_enabled? && camera.status == :online
          end)

        {:ok, values}
      end
    end

    calculate :has_recent_activity?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn camera ->
            camera.last_seen &&
              DateTime.diff(DateTime.utc_now(), camera.last_seen, :minute) < 5
          end)

        {:ok, values}
      end
    end

    calculate :storage_estimate_gb_per_day, :float do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn camera ->
            # Rough estimate based on resolution and framerate
            # Assuming H.264 compression
            case camera.resolution do
              # 4K
              "3840x2160" -> camera.framerate * 0.375
              # 2K
              "2560x1440" -> camera.framerate * 0.225
              # 1080p
              "1920x1080" -> camera.framerate * 0.125
              # 720p
              "1280x720" -> camera.framerate * 0.075
              # Default
              _ -> camera.framerate * 0.1
            end
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "viewer")
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action([:enable_recording, :disable_recording]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:enable_analytics, :disable_analytics]) do
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_connection
    define :update_stream_settings
    define :enable_recording
    define :disable_recording
    define :enable_analytics
    define :disable_analytics
    define :update_status
    define :heartbeat
    define :add_preset
    define :activate
    define :deactivate
    define :destroy
  end

  postgres do
    table "cameras"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :serial_number], unique: true
      index [:site_id]
      index [:zone_id], where: "zone_id IS NOT NULL"
      index [:status]

      index [:recording_enabled?],
        name: "cameras_recording_enabled_index",
        where: "recording_enabled? = true"

      index [:analytics_enabled?],
        name: "cameras_analytics_enabled_index",
        where: "analytics_enabled? = true"

      index [:active?], name: "cameras_active_index", where: "active? = true"
      index [:last_seen]
    end
  end
end
