defmodule Indrajaal.Devices.Camera do
  @moduledoc """
  Represents surveillance cameras in the security system.

  Cameras provide video surveillance capabilities including live streaming,
  recording, motion detection, and analytics features.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Devices

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :camera_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:bullet, :dome, :ptz, :fisheye, :thermal, :multisensor, :covert]
    end

    attribute :resolution, :string do
      public? true
      constraints max_length: 20
      default "1920x1080"
    end

    attribute :megapixels, :float do
      public? true
      constraints min: 0.0
    end

    attribute :sensor_size, :string do
      public? true
      constraints max_length: 20
    end

    attribute :lens_type, :atom do
      public? true
      constraints one_of: [:fixed, :varifocal, :zoom, :fisheye]
      default :fixed
    end

    attribute :focal_length_mm, :string do
      public? true
      constraints max_length: 20
    end

    attribute :field_of_view_deg, :integer do
      public? true
      constraints min: 0, max: 360
    end

    attribute :has_infrared?, :boolean do
      public? true
      default true
    end

    attribute :ir_range_m, :float do
      public? true
      constraints min: 0.0
    end

    attribute :has_wdr?, :boolean do
      public? true
      default false
    end

    attribute :has_audio?, :boolean do
      public? true
      default false
    end

    attribute :audio_type, :atom do
      public? true
      constraints one_of: [:none, :one_way, :two_way]
      default :none
    end

    attribute :compression_formats, {:array, :atom} do
      public? true
      default [:h264]
      constraints items: [one_of: [:h264, :h265, :mjpeg, :mpeg4]]
    end

    attribute :streaming_protocols, {:array, :atom} do
      public? true
      default [:rtsp]
      constraints items: [one_of: [:rtsp, :onvif, :http, :https, :webrtc]]
    end

    attribute :max_framerate, :integer do
      public? true
      default 30
      constraints min: 1, max: 120
    end

    attribute :current_framerate, :integer do
      public? true
      default 15
      constraints min: 1, max: 120
    end

    attribute :bitrate_kbps, :integer do
      public? true
      default 2048
      constraints min: 128
    end

    attribute :recording_enabled?, :boolean do
      public? true
      default true
    end

    attribute :recording_mode, :atom do
      public? true
      constraints one_of: [:continuous, :motion, :schedule, :event]
      default :motion
    end

    attribute :retention_days, :integer do
      public? true
      default 30
      constraints min: 1, max: 365
    end

    attribute :motion_detection_enabled?, :boolean do
      public? true
      default true
    end

    attribute :motion_sensitivity, :integer do
      public? true
      default 50
      constraints min: 0, max: 100
    end

    attribute :motion_zones, {:array, :map} do
      public? true
      default []
    end

    attribute :analytics_enabled?, :boolean do
      public? true
      default false
    end

    attribute :analytics_features, {:array, :atom} do
      public? true
      default []

      constraints items: [
                    one_of: [
                      :face_detection,
                      :people_counting,
                      :line_crossing,
                      :intrusion,
                      :object_left,
                      :object_removed,
                      :loitering,
                      :lpr
                    ]
                  ]
    end

    attribute :ptz_capabilities, :map do
      public? true
      default %{}
    end

    attribute :current_position, :map do
      public? true
      default %{}
    end

    attribute :presets, {:array, :map} do
      public? true
      default []
    end

    attribute :privacy_masks, {:array, :map} do
      public? true
      default []
    end

    attribute :stream_urls, :map do
      public? true
      default %{}
    end

    attribute :snapshot_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :is_recording?, :boolean do
      public? true
      default false
    end

    attribute :last_motion_at, :utc_datetime do
      public? true
    end

    attribute :storage_used_gb, :float do
      public? true
      default 0.0
      constraints min: 0.0
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    belongs_to :device, Indrajaal.Devices.Device do
      allow_nil? false
      public? true
    end

    # Domain implementation reference - ready for integration
    # has_many :recordings, Indrajaal.Video.Recording do
    #   public? true
    # end

    # has_many :snapshots, Indrajaal.Video.Snapshot do
    #   public? true
    # end
  end

  identities do
    identity :unique_device_per_tenant, [:tenant_id, :device_id]
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :camera_type,
        :resolution,
        :megapixels,
        :sensor_size,
        :lens_type,
        :focal_length_mm,
        :field_of_view_deg,
        :has_infrared?,
        :ir_range_m,
        :has_wdr?,
        :has_audio?,
        :audio_type,
        :compression_formats,
        :streaming_protocols,
        :max_framerate,
        :device_id,
        :analytics_features,
        :ptz_capabilities,
        :stream_urls,
        :snapshot_url
      ]
    end

    update :start_recording do
      require_atomic? false
      accept []
      change set_attribute(:is_recording?, true)
      change set_attribute(:recording_enabled?, true)
      change fn changeset, __context -> log_recording_event(changeset, __context, "start") end
    end

    update :stop_recording do
      require_atomic? false
      accept []
      change set_attribute(:is_recording?, false)
      change fn changeset, __context -> log_recording_event(changeset, __context, "stop") end
    end

    update :detect_motion do
      require_atomic? false

      argument :zones, {:array, :integer} do
        default []
      end

      change set_attribute(:last_motion_at, DateTime.utc_now())

      change fn changeset, __context ->
        zones = Ash.Changeset.get_argument(changeset, :zones)
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        motion_events = Map.get(metadata, "motion_events", [])

        entry = %{
          "zones" => zones,
          "timestamp" => DateTime.utc_now()
        }

        # Keep only last 100 __events
        updated_events = [entry | motion_events] |> Enum.take(100)
        updated_metadata = Map.put(metadata, "motion_events", updated_events)
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :move_ptz do
      require_atomic? false

      argument :pan, :float do
        constraints min: -180.0, max: 180.0
      end

      argument :tilt, :float do
        constraints min: -90.0, max: 90.0
      end

      argument :zoom, :float do
        constraints min: 1.0, max: 100.0
      end

      change fn changeset, __context ->
        position = %{
          "pan" => Ash.Changeset.get_argument(changeset, :pan),
          "tilt" => Ash.Changeset.get_argument(changeset, :tilt),
          "zoom" => Ash.Changeset.get_argument(changeset, :zoom),
          "updated_at" => DateTime.utc_now()
        }

        Ash.Changeset.change_attribute(changeset, :current_position, position)
      end

      validate fn changeset, __context ->
        camera_type = Ash.Changeset.get_attribute(changeset, :camera_type)

        if camera_type != :ptz do
          {:error, message: "PTZ control only available for PTZ cameras"}
        else
          {:ok, changeset}
        end
      end
    end

    update :goto_preset do
      require_atomic? false

      argument :preset_number, :integer do
        allow_nil? false
        constraints min: 1, max: 255
      end

      change fn changeset, __context ->
        preset_num = Ash.Changeset.get_argument(changeset, :preset_number)
        presets = Ash.Changeset.get_attribute(changeset, :presets) || []

        case Enum.find(presets, &(&1["number"] == preset_num)) do
          nil ->
            Ash.Changeset.add_error(changeset, field: :preset_number, message: "preset not found")

          preset ->
            position =
              preset
              |> Map.take(["pan", "tilt", "zoom"])
              |> Map.put("updated_at", DateTime.utc_now())

            Ash.Changeset.change_attribute(changeset, :current_position, position)
        end
      end
    end

    update :save_preset do
      require_atomic? false

      argument :preset_number, :integer do
        allow_nil? false
        constraints min: 1, max: 255
      end

      argument :name, :string do
        allow_nil? false
        constraints max_length: 100
      end

      change fn changeset, __context ->
        preset_num = Ash.Changeset.get_argument(changeset, :preset_number)
        name = Ash.Changeset.get_argument(changeset, :name)

        current_pos =
          Ash.Changeset.get_attribute(
            changeset,
            :current_position
          ) || %{}

        presets = Ash.Changeset.get_attribute(changeset, :presets) || []

        new_preset = %{
          "number" => preset_num,
          "name" => name,
          "pan" => Map.get(current_pos, "pan", 0),
          "tilt" => Map.get(current_pos, "tilt", 0),
          "zoom" => Map.get(current_pos, "zoom", 1),
          "saved_at" => DateTime.utc_now()
        }

        # Replace if exists, otherwise add
        updated_presets =
          presets
          |> Enum.reject(&(&1["number"] == preset_num))
          |> Enum.concat([new_preset])
          |> Enum.sort_by(& &1["number"])

        Ash.Changeset.change_attribute(changeset, :presets, updated_presets)
      end
    end

    update :update_storage do
      require_atomic? false

      argument :used_gb, :float do
        allow_nil? false
        constraints min: 0.0
      end

      change set_attribute(:storage_used_gb, arg(:used_gb))
    end
  end

  calculations do
    calculate :is_online?, :boolean do
      calculation fn records, opts ->
        # Would check device status
        records |> Enum.map(fn _ -> true end)
      end
    end

    calculate :supports_analytics?, :boolean, expr(length(analytics_features) > 0)

    calculate :is_ptz?, :boolean, expr(camera_type == :ptz)

    calculate :storage_days_remaining, :integer do
      calculation fn records, opts ->
        records
        |> Enum.map(fn camera ->
          if camera.storage_used_gb && camera.storage_used_gb > 0 do
            # Rough estimate based on current usage
            daily_usage = camera.storage_used_gb / 30.0
            # Placeholder
            available_storage = 1000.0
            Float.round((available_storage - camera.storage_used_gb) / daily_usage)
          else
            camera.retention_days
          end
        end)
      end
    end

    calculate :motion_events_today, :integer do
      calculation fn records, opts ->
        records
        |> Enum.map(fn camera ->
          metadata = camera.metadata || %{}
          __events = Map.get(metadata, "motion_events", [])
          today = Date.utc_today()

          Enum.count(__events, fn __event ->
            case DateTime.from_iso8601(__event["timestamp"] || "") do
              {:ok, datetime, _} -> DateTime.to_date(datetime) == today
              _ -> false
            end
          end)
        end)
      end
    end
  end

  validations do
    validate fn changeset, __context ->
      has_audio = Ash.Changeset.get_attribute(changeset, :has_audio?)
      audio_type = Ash.Changeset.get_attribute(changeset, :audio_type)

      cond do
        !has_audio && audio_type != :none ->
          {:error, field: :audio_type, message: "must be :none when audio is disabled"}

        has_audio && audio_type == :none ->
          {:error, field: :audio_type, message: "must specify audio type when audio is enabled"}

        true ->
          {:ok, changeset}
      end
    end

    validate fn changeset, __context ->
      camera_type = Ash.Changeset.get_attribute(changeset, :camera_type)

      ptz_capabilities =
        Ash.Changeset.get_attribute(
          changeset,
          :ptz_capabilities
        )

      if camera_type == :ptz &&
           (is_nil(ptz_capabilities) ||
              ptz_capabilities ==
                %{}) do
        {:error, field: :ptz_capabilities, message: "PTZ cameras must have capabilities defined"}
      else
        {:ok, changeset}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "device_manager")
      authorize_if actor_attribute_equals(:role, "technician")
    end

    policy action([:start_recording, :stop_recording]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_operator")
      authorize_if actor_attribute_equals(:role, "site_manager")
    end

    policy action([:move_ptz, :goto_preset]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_operator")
      authorize_if actor_attribute_equals(:role, "monitoring_agent")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :start_recording
    define :stop_recording
    define :detect_motion
    define :move_ptz
    define :goto_preset
    define :save_preset
    define :update_storage
  end

  postgres do
    table "cameras"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :device_id], unique: true
      index [:camera_type]

      index [:recording_enabled?],
        name: "cameras_recording_enabled_index",
        where: "recording_enabled? = true"

      index [:motion_detection_enabled?],
        name: "cameras_motion_detection_index",
        where: "motion_detection_enabled? = true"

      index [:analytics_enabled?],
        name: "cameras_analytics_enabled_index",
        where: "analytics_enabled? = true"

      index [:last_motion_at]
    end
  end

  @spec log_recording_event(Ash.Changeset.t(), map(), String.t()) :: Ash.Changeset.t()
  defp log_recording_event(changeset, context, action) do
    metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
    recording_log = Map.get(metadata, "recording_log", [])

    entry = %{
      "action" => action,
      "timestamp" => DateTime.utc_now(),
      "initiated_by" => context[:actor][:id]
    }

    updated_metadata = Map.put(metadata, "recording_log", [entry | recording_log])
    Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
  end
end

# Agent: Worker - 2 (Devices Domain Agent)
# SOPv5.1 Compliance: ✅ Device management and hardware integration coordination
# Domain: Devices
# Responsibilities: Device management, hardware integration, IoT coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
