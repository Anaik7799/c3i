defmodule Intelitor.Video.Stream do
  @moduledoc """
  Manages live video streams from cameras.

  Streams represent active video feeds that can be viewed in real-time.
  They support multiple protocols including WebRTC, HLS, and RTMP, with
  adaptive bitrate streaming and transcoding capabilities.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Video,
    table: "video_streams"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Stream identification
    attribute :camera_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :stream_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:primary, :secondary, :substream, :analytics]
      default :primary
    end

    attribute :stream_id, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    # Stream configuration
    attribute :protocol, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:webrtc, :hls, :rtmp, :rtsp, :dash]
      default :webrtc
    end

    attribute :source_url, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :output_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :stream_key, :string do
      public? true
      constraints max_length: 100
    end

    # Video settings
    attribute :resolution, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1920x1080"
    end

    attribute :framerate, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 120
      default 30
    end

    attribute :bitrate_kbps, :integer do
      allow_nil? false
      public? true
      constraints min: 100, max: 50000
      default 2000
    end

    attribute :codec, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:h264, :h265, :vp8, :vp9, :av1]
      default :h264
    end

    attribute :profile, :string do
      public? true
      constraints max_length: 50
      default "baseline"
    end

    # Audio settings
    attribute :audio_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :audio_codec, :atom do
      public? true
      constraints one_of: [:aac, :opus, :pcm, :g711]
      default :aac
    end

    attribute :audio_bitrate_kbps, :integer do
      public? true
      constraints min: 32, max: 320
      default 128
    end

    # Stream state
    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:initializing, :active, :paused, :stopped, :error]
      default :initializing
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :stopped_at, :utc_datetime_usec do
      public? true
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 500
    end

    attribute :reconnect_attempts, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    # Viewers
    attribute :viewer_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :max_viewers, :integer do
      public? true
      constraints min: 1, max: 10000
      default 100
    end

    attribute :viewer_sessions, {:array, :map} do
      public? true
      default []
    end

    # Recording
    attribute :recording_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :recording_id, :uuid do
      public? true
    end

    # Transcoding
    attribute :transcoding_enabled?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :transcoding_profiles, {:array, :map} do
      public? true
      default []
    end

    # Performance metrics
    attribute :metrics, :map do
      public? true

      default %{
        "dropped_frames" => 0,
        "latency_ms" => 0,
        "bandwidth_usage_mbps" => 0,
        "cpu_usage_percent" => 0,
        "memory_usage_mb" => 0
      }
    end

    attribute :quality_score, :integer do
      public? true
      constraints min: 0, max: 100
    end

    # Access control
    attribute :public_access?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :access_token, :string do
      public? true
      constraints max_length: 200
    end

    attribute :allowed_ips, {:array, :string} do
      public? true
      default []
    end

    # Metadata
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

    belongs_to :recording, Intelitor.Video.Recording do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :camera_id,
        :stream_type,
        :stream_id,
        :protocol,
        :source_url,
        :resolution,
        :framerate,
        :bitrate_kbps,
        :codec,
        :profile,
        :audio_enabled?,
        :audio_codec,
        :audio_bitrate_kbps,
        :max_viewers,
        :public_access?,
        :transcoding_enabled?,
        :transcoding_profiles,
        :metadata
      ]

      argument :camera_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        changeset
        |> generate_stream_key()
        |> generate_access_token()
      end
    end


    update :start do
      require_atomic? false
      accept []

      validate attribute_in(:status, [:initializing, :stopped, :error])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :active)
        |> Ash.Changeset.force_change_attribute(:started_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:stopped_at, nil)
        |> Ash.Changeset.force_change_attribute(:reconnect_attempts, 0)
      end
    end

    update :pause do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :active)

      change set_attribute(:status, :paused)
    end

    update :resume do
      require_atomic? false
      accept []

      validate attribute_equals(:status, :paused)

      change set_attribute(:status, :active)
    end

    update :stop do
      require_atomic? false
      accept []

      validate attribute_in(:status, [:active, :paused])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :stopped)
        |> Ash.Changeset.force_change_attribute(:stopped_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:viewer_count, 0)
        |> Ash.Changeset.force_change_attribute(:viewer_sessions, [])
      end
    end

    update :error do
      require_atomic? false
      accept [:error_message]

      argument :error_message, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :error)
        |> increment_reconnect_attempts()
      end
    end

    update :add_viewer do
      require_atomic? false
      accept []

      argument :session_id, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :viewer_info, :map do
        allow_nil? false
      end

      validate fn changeset, _context ->
        viewer_count = Ash.Changeset.get_attribute(changeset, :viewer_count)
        max_viewers = Ash.Changeset.get_attribute(changeset, :max_viewers)

        if viewer_count >= max_viewers do
          {:error, field: :viewer_count, message: "maximum viewers reached"}
        else
          :ok
        end
      end

      change fn changeset, _context ->
        sessions = Ash.Changeset.get_attribute(changeset, :viewer_sessions) || []
        session_id = changeset.arguments.session_id

        # Check if session already exists
        if Enum.any?(sessions, fn s -> s["session_id"] == session_id end) do
          changeset
        else
          new_session =
            Map.merge(
              changeset.arguments.viewer_info,
              %{
                "session_id" => session_id,
                "joined_at" => DateTime.utc_now()
              }
            )

          changeset
          |> Ash.Changeset.force_change_attribute(:viewer_sessions, [new_session | sessions])
          |> Ash.Changeset.force_change_attribute(:viewer_count, length(sessions) + 1)
        end
      end
    end

    update :remove_viewer do
      require_atomic? false
      accept []

      argument :session_id, :string do
        allow_nil? false
      end

      change fn changeset, _context ->
        sessions = Ash.Changeset.get_attribute(changeset, :viewer_sessions) || []
        session_id = changeset.arguments.session_id

        updated_sessions = Enum.reject(sessions, &(&1["session_id"] == session_id))

        changeset
        |> Ash.Changeset.force_change_attribute(:viewer_sessions, updated_sessions)
        |> Ash.Changeset.force_change_attribute(:viewer_count, length(updated_sessions))
      end
    end

    update :update_metrics do
      require_atomic? false
      accept [:metrics, :quality_score]

      argument :metrics, :map do
        allow_nil? false
      end
    end

    update :enable_recording do
      require_atomic? false
      accept [:recording_id]

      argument :recording_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:recording_enabled?, true)
    end

    update :disable_recording do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:recording_enabled?, false)
        |> Ash.Changeset.force_change_attribute(:recording_id, nil)
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :duration_seconds, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn stream ->
              if stream.started_at do
                end_time = stream.stopped_at || DateTime.utc_now()
                DateTime.diff(end_time, stream.started_at)
              else
                0
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :is_live?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn stream ->
            stream.status == :active
          end)

        {:ok, values}
      end
    end

    calculate :bandwidth_usage_mbps, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn stream ->
              if stream.status == :active do
                video_mbps = stream.bitrate_kbps / 1000.0

                audio_mbps =
                  if stream.audio_enabled?,
                    do: stream.audio_bitrate_kbps / 1000.0,
                    else: 0

                (video_mbps + audio_mbps) * stream.viewer_count
              else
                0.0
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :requires_transcoding?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn stream ->
              stream.viewer_count > 10 || stream.protocol in [:hls, :dash]
            end
          )

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "viewer")
      # Public streams can be read by anyone
      authorize_if expr(public_access? == true)
    end

    policy action([:update, :start, :pause, :resume, :stop]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:enable_recording, :disable_recording]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :start
    define :pause
    define :resume
    define :stop
    define :error
    define :add_viewer
    define :remove_viewer
    define :update_metrics
    define :enable_recording
    define :disable_recording
    define :destroy
  end

  postgres do
    table "video_streams"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :camera_id]
      index [:stream_id], unique: true
      index [:status]
      index [:started_at]
      index [:recording_id], where: "recording_id IS NOT NULL"
      index [:public_access?], name: "streams_public_access_index", where: "public_access? = true"
    end
  end

  # Helper functions
  defp generate_stream_key(changeset) do
    key =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    Ash.Changeset.force_change_attribute(changeset, :stream_key, key)
  end

  defp generate_access_token(changeset) do
    if Ash.Changeset.get_attribute(changeset, :public_access?) == false do
      token =
        :crypto.strong_rand_bytes(32)
        |> Base.url_encode64(padding: false)

      Ash.Changeset.force_change_attribute(changeset, :access_token, token)
    else
      changeset
    end
  end

  defp increment_reconnect_attempts(changeset) do
    current = Ash.Changeset.get_attribute(changeset, :reconnect_attempts)

    Ash.Changeset.force_change_attribute(
      changeset,
      :reconnect_attempts,
      current + 1
    )
  end
end
