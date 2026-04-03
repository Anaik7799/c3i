defmodule Indrajaal.Video.Clip do
  @moduledoc """
  Represents short video clips extracted from recordings.

  Clips are segments of video that capture specific __events or moments of
  interest. They can be created manually or automatically based on motion,
  analytics __events,
  or alarm triggers, and can be easily shared or exported.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Video

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Clip identification
    attribute :recording_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :camera_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    # Clip type and source
    attribute :clip_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:manual, :motion, :analytics, :alarm, :bookmark, :export]
      default :manual
    end

    attribute :source_event_id, :uuid do
      public? true
    end

    attribute :source_event_type, :atom do
      public? true
      constraints one_of: [:alarm, :motion, :analytics, :manual]
    end

    # Time range
    attribute :start_time, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :end_time, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :duration_seconds, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 3600
    end

    attribute :offset_seconds, :integer do
      allow_nil? false
      public? true
      constraints min: 0
    end

    # Storage
    attribute :file_path, :string do
      public? true
      constraints max_length: 500
    end

    attribute :file_size_mb, :float do
      public? true
      constraints min: 0
    end

    attribute :storage_location, :atom do
      public? true
      constraints one_of: [:local, :s3, :azure, :gcp]
      default :local
    end

    attribute :storage_url, :string do
      public? true
      constraints max_length: 500
    end

    # Processing
    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:pending, :processing, :ready, :failed, :deleted]
      default :pending
    end

    attribute :processing_progress, :integer do
      public? true
      constraints min: 0, max: 100
      default 0
    end

    attribute :error_message, :string do
      public? true
      constraints max_length: 500
    end

    # Video properties
    attribute :resolution, :string do
      public? true
      constraints max_length: 20
    end

    attribute :framerate, :integer do
      public? true
      constraints min: 1, max: 120
    end

    attribute :codec, :atom do
      public? true
      constraints one_of: [:h264, :h265, :vp8, :vp9, :av1]
      default :h264
    end

    attribute :has_audio?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Thumbnails
    attribute :thumbnail_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :thumbnails, {:array, :map} do
      public? true
      default []
    end

    # Sharing
    attribute :share_token, :string do
      public? true
      constraints max_length: 100
    end

    attribute :share_expires_at, :utc_datetime_usec do
      public? true
    end

    attribute :share_password, :string do
      public? false
      constraints max_length: 200
    end

    attribute :share_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :download_count, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    # Access control
    attribute :access_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:public, :shared, :private, :restricted]
      default :private
    end

    attribute :authorized_users, {:array, :uuid} do
      public? true
      default []
    end

    # Analytics data
    attribute :detected_objects, {:array, :map} do
      public? true
      default []
    end

    attribute :detected_faces, {:array, :map} do
      public? true
      default []
    end

    attribute :detected_activities, {:array, :map} do
      public? true
      default []
    end

    # Metadata
    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :created_by, :uuid do
      public? true
    end

    attribute :starred?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :recording, Indrajaal.Video.Recording do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :camera, Indrajaal.Video.Camera do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :creator, Indrajaal.Accounts.User do
      source_attribute :created_by
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :recording_id,
        :camera_id,
        :title,
        :description,
        :clip_type,
        :source_event_id,
        :source_event_type,
        :start_time,
        :end_time,
        :created_by,
        :metadata
      ]

      argument :recording_id, :uuid do
        allow_nil? false
      end

      validate fn changeset, __context ->
        start_time = Ash.Changeset.get_attribute(changeset, :start_time)
        end_time = Ash.Changeset.get_attribute(changeset, :end_time)

        if start_time && end_time &&
             DateTime.compare(
               end_time,
               start_time
             ) != :gt do
          {:error, field: :end_time, message: "must be after start time"}
        else
          :ok
        end
      end

      change fn changeset, __context ->
        changeset
        |> calculate_duration()
        |> generate_share_token()
      end
    end

    update :process do
      require_atomic? false
      accept [:processing_progress]

      validate attribute_equals(:status, :pending)

      change set_attribute(:status, :processing)
    end

    update :complete_processing do
      require_atomic? false

      accept [
        :file_path,
        :file_size_mb,
        :storage_location,
        :storage_url,
        :resolution,
        :framerate,
        :codec,
        :has_audio?,
        :thumbnail_url,
        :thumbnails
      ]

      validate attribute_equals(:status, :processing)

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :ready)
        |> Ash.Changeset.force_change_attribute(:processing_progress, 100)
      end
    end

    update :fail_processing do
      require_atomic? false
      accept [:error_message]

      argument :error_message, :string do
        allow_nil? false
        constraints max_length: 500
      end

      validate attribute_in(:status, [:pending, :processing])

      change set_attribute(:status, :failed)
    end

    update :share do
      require_atomic? false
      accept [:share_expires_at, :share_password]

      argument :expires_in_hours, :integer do
        # Max 1 week
        constraints min: 1, max: 168
        default 24
      end

      change fn changeset, __context ->
        hours = changeset.arguments.expires_in_hours
        expires_at = DateTime.add(DateTime.utc_now(), hours * 3600, :second)

        changeset
        |> Ash.Changeset.force_change_attribute(:access_level, :shared)
        |> Ash.Changeset.force_change_attribute(:share_expires_at, expires_at)
      end
    end

    update :unshare do
      require_atomic? false
      accept []

      change fn changeset, __context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:access_level, :private)
        |> Ash.Changeset.force_change_attribute(:share_token, nil)
        |> Ash.Changeset.force_change_attribute(:share_expires_at, nil)
        |> Ash.Changeset.force_change_attribute(:share_password, nil)
      end
    end

    update :track_share do
      require_atomic? false
      accept []

      change fn changeset, __context ->
        count = Ash.Changeset.get_attribute(changeset, :share_count)
        Ash.Changeset.force_change_attribute(changeset, :share_count, count + 1)
      end
    end

    update :track_download do
      require_atomic? false
      accept []

      change fn changeset, __context ->
        count = Ash.Changeset.get_attribute(changeset, :download_count)
        Ash.Changeset.force_change_attribute(changeset, :download_count, count + 1)
      end
    end

    update :add_analytics_data do
      require_atomic? false
      accept [:detected_objects, :detected_faces, :detected_activities]
    end

    update :star do
      require_atomic? false
      accept []

      validate attribute_equals(:starred?, false)

      change set_attribute(:starred?, true)
    end

    update :unstar do
      require_atomic? false
      accept []

      validate attribute_equals(:starred?, true)

      change set_attribute(:starred?, false)
    end

    destroy :destroy do
      require_atomic? false
      primary? true
      soft? true

      change set_attribute(:status, :deleted)
    end
  end

  calculations do
    calculate :is_ready?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn clip ->
            clip.status == :ready
          end)

        {:ok, values}
      end
    end

    calculate :is_shared?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn clip ->
            clip.access_level == :shared &&
              clip.share_token != nil &&
              (is_nil(clip.share_expires_at) ||
                 DateTime.compare(
                   clip.share_expires_at,
                   DateTime.utc_now()
                 ) == :gt)
          end)

        {:ok, values}
      end
    end

    calculate :share_active?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn clip ->
            clip.access_level == :shared &&
              !is_nil(clip.share_expires_at) &&
              DateTime.compare(clip.share_expires_at, DateTime.utc_now()) == :gt
          end)

        {:ok, values}
      end
    end

    calculate :has_analytics?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn clip ->
            !Enum.empty?(clip.detected_objects || []) ||
              !Enum.empty?(clip.detected_faces || []) ||
              !Enum.empty?(clip.detected_activities || [])
          end)

        {:ok, values}
      end
    end

    calculate :total_detections, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn clip ->
            objects = length(clip.detected_objects || [])
            faces = length(clip.detected_faces || [])
            activities = length(clip.detected_activities || [])

            objects + faces + activities
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
      # Creator can read their own clips
      authorize_if expr(created_by == ^actor(:id))
      # Authorized __users can read
      authorize_if expr(^actor(:id) in authorized_users)
      # Shared clips with valid token
      authorize_if expr(access_level == :shared)
    end

    policy action(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:update, :star, :unstar]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      # Creator can update their own clips
      authorize_if expr(created_by == ^actor(:id))
    end

    policy action([:share, :unshare]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :process
    define :complete_processing
    define :fail_processing
    define :share
    define :unshare
    define :track_share
    define :track_download
    define :add_analytics_data
    define :star
    define :unstar
    define :destroy
  end

  postgres do
    table "video_clips"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :recording_id]
      index [:camera_id]
      index [:clip_type]
      index [:source_event_id], where: "source_event_id IS NOT NULL"
      index [:status]
      index [:created_by]
      index [:share_token], where: "share_token IS NOT NULL"
      index [:starred?], name: "clips_starred_index", where: "starred? = true"
      index [:created_at]
    end
  end

  # Helper functions
  @spec calculate_duration(term()) :: term()
  defp calculate_duration(changeset) do
    start_time = Ash.Changeset.get_attribute(changeset, :start_time)
    end_time = Ash.Changeset.get_attribute(changeset, :end_time)

    if start_time && end_time do
      duration = DateTime.diff(end_time, start_time)

      changeset
      |> Ash.Changeset.force_change_attribute(:duration_seconds, duration)
      # Will be calculated from recording start
      |> Ash.Changeset.force_change_attribute(:offset_seconds, 0)
    else
      changeset
    end
  end

  @spec generate_share_token(term()) :: term()
  defp generate_share_token(changeset) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    Ash.Changeset.force_change_attribute(changeset, :share_token, token)
  end

  # EP201: Removed unused function regenerate_share_token/1
  # @spec regenerate_share_token(term()) :: term()
  # defp regenerate_share_token(changeset) do
  #   generate_share_token(changeset)
  # end
end

# Agent: Worker - 3 (Video Domain Agent)
# SOPv5.1 Compliance: ✅ Video analytics and stream processing coordination with
# Domain: Video
# Responsibilities: Video analytics, stream processing, recording management
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
