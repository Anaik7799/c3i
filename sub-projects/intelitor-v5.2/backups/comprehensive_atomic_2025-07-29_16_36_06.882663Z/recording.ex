defmodule Intelitor.Video.Recording do
  @moduledoc """
  Manages video recordings from cameras.

  Recordings represent stored video segments that can be played back later.
  They support continuous, motion-triggered, and event-based recording with
  efficient storage management and retention policies.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Video,
    table: "video_recordings"

  use Intelitor.Multitenancy.TenantResource

  alias Ash.Changeset

  attributes do
    uuid_primary_key :id

    # Recording identification
    attribute :camera_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :stream_id, :uuid do
      public? true
    end

    attribute :recording_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:continuous, :motion, :event, :manual, :scheduled]
      default :continuous
    end

    # Time range
    attribute :started_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :ended_at, :utc_datetime_usec do
      public? true
    end

    attribute :duration_seconds, :integer do
      public? true
      constraints min: 0
    end

    # Storage details
    attribute :file_path, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :file_size_mb, :float do
      public? true
      constraints min: 0
    end

    attribute :storage_location, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:local, :s3, :azure, :gcp]
      default :local
    end

    attribute :storage_bucket, :string do
      public? true
      constraints max_length: 200
    end

    attribute :storage_key, :string do
      public? true
      constraints max_length: 500
    end

    # Video properties
    attribute :resolution, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
    end

    attribute :framerate, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 120
    end

    attribute :codec, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:h264, :h265, :vp8, :vp9, :av1]
      default :h264
    end

    attribute :bitrate_kbps, :integer do
      public? true
      constraints min: 100, max: 50000
    end

    attribute :has_audio?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Event association
    attribute :alarm_event_id, :uuid do
      public? true
    end

    attribute :motion_events, {:array, :map} do
      public? true
      default []
    end

    attribute :analytics_events, {:array, :map} do
      public? true
      default []
    end

    # Retention
    attribute :retention_days, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 365
      default 30
    end

    attribute :retention_until, :date do
      allow_nil? false
      public? true
    end

    attribute :protected?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :protection_reason, :string do
      public? true
      constraints max_length: 500
    end

    # Processing status
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :recording,
                    :processing,
                    :available,
                    :archived,
                    :deleted,
                    :error
                  ]

      default :recording
    end

    attribute :processing_status, :atom do
      public? true

      constraints one_of: [
                    :pending,
                    :transcoding,
                    :analyzing,
                    :thumbnailing,
                    :complete
                  ]
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 500
    end

    # Thumbnails and preview
    attribute :thumbnail_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :preview_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :keyframe_count, :integer do
      public? true
      constraints min: 0
    end

    # Access control
    attribute :encryption_key, :string do
      public? false
      constraints max_length: 500
    end

    attribute :access_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:public, :restricted, :confidential, :classified]
      default :restricted
    end

    attribute :authorized_users, {:array, :uuid} do
      public? true
      default []
    end

    # Export tracking
    attribute :export_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :last_exported_at, :utc_datetime_usec do
      public? true
    end

    attribute :exported_by, {:array, :uuid} do
      public? true
      default []
    end

    # Metadata
    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :camera, Intelitor.Video.Camera do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :stream, Intelitor.Video.Stream do
      attribute_public? true
    end

    belongs_to :alarm_event, Intelitor.Alarms.AlarmEvent do
      attribute_public? true
    end

    has_many :clips, Intelitor.Video.Clip
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :camera_id,
        :stream_id,
        :recording_type,
        :started_at,
        :file_path,
        :storage_location,
        :storage_bucket,
        :storage_key,
        :resolution,
        :framerate,
        :codec,
        :has_audio?,
        :alarm_event_id,
        :retention_days,
        :access_level,
        :metadata
      ]

      argument :camera_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        changeset
        |> calculate_retention_date()
        |> maybe_encrypt_recording()
      end
    end


    update :complete do
      require_atomic? false
      accept [:ended_at, :duration_seconds, :file_size_mb, :bitrate_kbps]

      argument :ended_at, :utc_datetime_usec do
        allow_nil? false
      end

      validate attribute_equals(:status, :recording)

      change fn changeset, _context ->
        changeset
        |> Changeset.force_change_attribute(:status, :processing)
        |> calculate_duration()
      end
    end

    update :process do
      require_atomic? false
      accept [:processing_status]

      validate attribute_equals(:status, :processing)
    end

    update :mark_available do
      require_atomic? false
      accept [:thumbnail_url, :preview_url, :keyframe_count]

      validate attribute_equals(:status, :processing)

      change fn changeset, _context ->
        changeset
        |> Changeset.force_change_attribute(:status, :available)
        |> Changeset.force_change_attribute(:processing_status, :complete)
      end
    end

    update :archive do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :available)
      validate attribute_equals(:protected?, false)

      change set_attribute(:status, :archived)
    end

    update :mark_error do
      require_atomic? false
      accept [:error_message]

      argument :error_message, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:status, :error)
    end

    update :protect do
      require_atomic? false
      accept [:protection_reason]

      argument :protection_reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_equals(:protected?, false)

      change set_attribute(:protected?, true)
    end

    update :unprotect do
      require_atomic? false
      accept []

      validate attribute_equals(:protected?, true)

      change fn changeset, _context ->
        changeset
        |> Changeset.force_change_attribute(:protected?, false)
        |> Changeset.force_change_attribute(:protection_reason, nil)
      end
    end

    update :extend_retention do
      require_atomic? false
      accept [:retention_days]

      argument :retention_days, :integer do
        allow_nil? false
        constraints min: 1, max: 365
      end

      change fn changeset, _context ->
        changeset
        |> calculate_retention_date()
      end
    end

    update :add_motion_event do
      require_atomic? false
      accept []

      argument :motion_event, :map do
        allow_nil? false
      end

      change fn changeset, _context ->
        events = Changeset.get_attribute(changeset, :motion_events) || []

        new_event =
          Map.put(
            changeset.arguments.motion_event,
            "timestamp",
            DateTime.utc_now()
          )

        Changeset.force_change_attribute(
          changeset,
          :motion_events,
          [new_event | events]
        )
      end
    end

    update :add_analytics_event do
      require_atomic? false
      accept []

      argument :analytics_event, :map do
        allow_nil? false
      end

      change fn changeset, _context ->
        events = Changeset.get_attribute(changeset, :analytics_events) || []

        new_event =
          Map.put(
            changeset.arguments.analytics_event,
            "timestamp",
            DateTime.utc_now()
          )

        Changeset.force_change_attribute(
          changeset,
          :analytics_events,
          [new_event | events]
        )
      end
    end

    update :track_export do
      require_atomic? false
      accept []

      argument :exported_by_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        count = Changeset.get_attribute(changeset, :export_count)
        exporters = Changeset.get_attribute(changeset, :exported_by) || []
        exporter_id = changeset.arguments.exported_by_id

        changeset
        |> Changeset.force_change_attribute(:export_count, count + 1)
        |> Changeset.force_change_attribute(
          :last_exported_at,
          DateTime.utc_now()
        )
        |> Changeset.force_change_attribute(
          :exported_by,
          if exporter_id in exporters do
            exporters
          else
            [exporter_id | exporters]
          end
        )
      end
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      soft? true

      change fn changeset, _context ->
        if Changeset.get_attribute(changeset, :protected?) do
          Changeset.add_error(changeset,
            field: :protected?,
            message: "cannot delete protected recording"
          )
        else
          changeset
        end
      end
    end
  end

  calculations do
    calculate :is_available?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn recording ->
            recording.status == :available
          end)

        {:ok, values}
      end
    end

    calculate :is_expired?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn recording ->
            !recording.protected? &&
              Date.compare(Date.utc_today(), recording.retention_until) == :gt
          end)

        {:ok, values}
      end
    end

    calculate :days_until_expiry, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn recording ->
            if recording.protected? do
              nil
            else
              Date.diff(recording.retention_until, Date.utc_today())
            end
          end)

        {:ok, values}
      end
    end

    calculate :has_events?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn recording ->
            !Enum.empty?(recording.motion_events || []) ||
              !Enum.empty?(recording.analytics_events || []) ||
              !is_nil(recording.alarm_event_id)
          end)

        {:ok, values}
      end
    end

    calculate :event_count, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn recording ->
            motion_count = length(recording.motion_events || [])
            analytics_count = length(recording.analytics_events || [])
            alarm_count = if recording.alarm_event_id, do: 1, else: 0

            motion_count + analytics_count + alarm_count
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
      # Check authorized users list
      authorize_if expr(^actor(:id) in authorized_users)
    end

    policy action(:create) do
      # System action for recording creation
      authorize_if always()
    end

    policy action([:update, :protect, :unprotect, :extend_retention]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action(:track_export) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "viewer")
    end

    policy action(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :complete
    define :process
    define :mark_available
    define :archive
    define :mark_error
    define :protect
    define :unprotect
    define :extend_retention
    define :add_motion_event
    define :add_analytics_event
    define :track_export
    define :destroy
  end

  postgres do
    table "video_recordings"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :camera_id]
      index [:stream_id], where: "stream_id IS NOT NULL"
      index [:started_at]
      index [:ended_at]
      index [:status]
      index [:retention_until]

      index [:protected?],
        name: "recordings_protected_index",
        where: "protected? = true"

      index [:alarm_event_id], where: "alarm_event_id IS NOT NULL"
      index [:recording_type]
    end
  end

  # Helper functions
  defp calculate_retention_date(changeset) do
    started_at = Changeset.get_attribute(changeset, :started_at)
    retention_days = Changeset.get_attribute(changeset, :retention_days)

    if started_at && retention_days do
      retention_date =
        started_at
        |> DateTime.to_date()
        |> Date.add(retention_days)

      Changeset.force_change_attribute(
        changeset,
        :retention_until,
        retention_date
      )
    else
      changeset
    end
  end

  defp calculate_duration(changeset) do
    started_at = Changeset.get_attribute(changeset, :started_at)
    ended_at = Changeset.get_attribute(changeset, :ended_at)

    if started_at && ended_at do
      duration = DateTime.diff(ended_at, started_at)

      Changeset.force_change_attribute(
        changeset,
        :duration_seconds,
        duration
      )
    else
      changeset
    end
  end

  defp maybe_encrypt_recording(changeset) do
    access_level = Changeset.get_attribute(changeset, :access_level)

    if access_level in [:confidential, :classified] do
      key = :crypto.strong_rand_bytes(32) |> Base.encode64()
      Changeset.force_change_attribute(changeset, :encryption_key, key)
    else
      changeset
    end
  end
end
