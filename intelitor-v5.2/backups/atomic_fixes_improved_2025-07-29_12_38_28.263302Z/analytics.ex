defmodule Intelitor.Video.Analytics do
  @moduledoc """
  Manages AI-powered video analytics and detection results.

  Analytics processes video feeds in real-time or on recordings to detect
  objects, people, vehicles, faces, behaviors, and anomalies. It provides
  actionable insights and can trigger alerts based on configurable rules.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Video,
    table: "video_analytics"

  use Intelitor.Multitenancy.TenantResource

  # Aliases for cleaner code
  alias Ash.Changeset

  attributes do
    uuid_primary_key :id

    # Analytics identification
    attribute :camera_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :recording_id, :uuid do
      public? true
    end

    attribute :stream_id, :uuid do
      public? true
    end

    attribute :analytics_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :object_detection,
                    :person_detection,
                    :vehicle_detection,
                    :face_detection,
                    :face_recognition,
                    :license_plate,
                    :motion_detection,
                    :loitering,
                    :intrusion,
                    :line_crossing,
                    :crowd_detection,
                    :abandoned_object,
                    :removed_object,
                    :behavior_analysis,
                    :anomaly_detection
                  ]
    end

    # Detection details
    attribute :timestamp, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :confidence, :float do
      allow_nil? false
      public? true
      constraints min: 0.0, max: 1.0
    end

    attribute :object_class, :string do
      public? true
      constraints max_length: 100
    end

    attribute :object_id, :string do
      public? true
      constraints max_length: 100
    end

    attribute :tracking_id, :string do
      public? true
      constraints max_length: 100
    end

    # Bounding box and position
    attribute :bounding_box, :map do
      public? true
      default %{}
      # Expected format: %{"x" => 0, "y" => 0, "width" => 100, "height" => 100}
    end

    attribute :center_point, :map do
      public? true
      default %{}
      # Expected format: %{"x" => 50, "y" => 50}
    end

    attribute :zone_id, :uuid do
      public? true
    end

    attribute :zone_name, :string do
      public? true
      constraints max_length: 100
    end

    # Object attributes
    attribute :attributes, :map do
      public? true
      default %{}
      # Can contain: color, size, direction, speed, etc.
    end

    attribute :face_attributes, :map do
      public? true
      default %{}
      # Can contain: age, gender, emotion, mask, glasses, etc.
    end

    attribute :vehicle_attributes, :map do
      public? true
      default %{}
      # Can contain: type, make, model, color, license_plate
    end

    # Recognition results
    attribute :person_id, :uuid do
      public? true
    end

    attribute :person_name, :string do
      public? true
      constraints max_length: 200
    end

    attribute :license_plate_text, :string do
      public? true
      constraints max_length: 50
    end

    attribute :license_plate_region, :string do
      public? true
      constraints max_length: 50
    end

    # Behavior and movement
    attribute :direction, :atom do
      public? true

      constraints one_of: [
                    :north,
                    :south,
                    :east,
                    :west,
                    :northeast,
                    :northwest,
                    :southeast,
                    :southwest
                  ]
    end

    attribute :speed_kmph, :float do
      public? true
      constraints min: 0
    end

    attribute :dwell_time_seconds, :integer do
      public? true
      constraints min: 0
    end

    attribute :trajectory, {:array, :map} do
      public? true
      default []
    end

    # Event details
    attribute :event_type, :atom do
      public? true

      constraints one_of: [
                    :entered,
                    :exited,
                    :appeared,
                    :disappeared,
                    :crossed_line,
                    :loitering,
                    :running,
                    :falling,
                    :fighting,
                    :crowding,
                    :abandoned,
                    :removed
                  ]
    end

    attribute :event_description, :string do
      public? true
      constraints max_length: 500
    end

    # Alert status
    attribute :alert_triggered?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :alert_level, :atom do
      public? true
      constraints one_of: [:info, :warning, :alert, :critical]
    end

    attribute :alert_sent_at, :utc_datetime_usec do
      public? true
    end

    attribute :alarm_event_id, :uuid do
      public? true
    end

    # Rules evaluation
    attribute :matched_rules, {:array, :string} do
      public? true
      default []
    end

    attribute :rule_conditions, :map do
      public? true
      default %{}
    end

    # Processing details
    attribute :processing_time_ms, :integer do
      public? true
      constraints min: 0
    end

    attribute :model_name, :string do
      public? true
      constraints max_length: 100
    end

    attribute :model_version, :string do
      public? true
      constraints max_length: 50
    end

    # Review status
    attribute :reviewed?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :reviewed_by, :uuid do
      public? true
    end

    attribute :reviewed_at, :utc_datetime_usec do
      public? true
    end

    attribute :review_notes, :string do
      public? true
      constraints max_length: 500
    end

    attribute :false_positive?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Snapshot
    attribute :snapshot_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :snapshot_timestamp, :utc_datetime_usec do
      public? true
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

    belongs_to :stream, Intelitor.Video.Stream do
      attribute_public? true
    end

    belongs_to :zone, Intelitor.Sites.Zone do
      attribute_public? true
    end

    belongs_to :person, Intelitor.Accounts.User do
      source_attribute :person_id
      attribute_public? true
    end

    belongs_to :alarm_event, Intelitor.Alarms.AlarmEvent do
      attribute_public? true
    end

    belongs_to :reviewer, Intelitor.Accounts.User do
      source_attribute :reviewed_by
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :camera_id,
        :recording_id,
        :stream_id,
        :analytics_type,
        :timestamp,
        :confidence,
        :object_class,
        :object_id,
        :tracking_id,
        :bounding_box,
        :center_point,
        :zone_id,
        :zone_name,
        :attributes,
        :face_attributes,
        :vehicle_attributes,
        :person_id,
        :person_name,
        :license_plate_text,
        :license_plate_region,
        :direction,
        :speed_kmph,
        :dwell_time_seconds,
        :trajectory,
        :event_type,
        :event_description,
        :matched_rules,
        :rule_conditions,
        :processing_time_ms,
        :model_name,
        :model_version,
        :snapshot_url,
        :snapshot_timestamp,
        :metadata
      ]

      argument :camera_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        evaluate_alert_conditions(changeset)
      end
    end


    update :trigger_alert do
      require_atomic? false
      accept [:alert_level, :alarm_event_id]

      argument :alert_level, :atom do
        allow_nil? false
        constraints one_of: [:info, :warning, :alert, :critical]
      end

      validate attribute_equals(:alert_triggered?, false)

      change fn changeset, _context ->
        changeset
        |> Changeset.force_change_attribute(
          :alert_triggered?,
          true
        )
        |> Changeset.force_change_attribute(
          :alert_sent_at,
          DateTime.utc_now()
        )
      end
    end

    update :link_to_alarm do
      require_atomic? false
      accept [:alarm_event_id]

      argument :alarm_event_id, :uuid do
        allow_nil? false
      end
    end

    update :review do
      require_atomic? false
      accept [:review_notes, :false_positive?]

      argument :reviewed_by, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:reviewed?, false)

      change fn changeset, _context ->
        changeset
        |> Changeset.force_change_attribute(:reviewed?, true)
        |> Changeset.force_change_attribute(
          :reviewed_by,
          changeset.arguments.reviewed_by
        )
        |> Changeset.force_change_attribute(
          :reviewed_at,
          DateTime.utc_now()
        )
      end
    end

    update :mark_false_positive do
      require_atomic? false
      accept []

      validate attribute_equals(:reviewed?, true)

      change set_attribute(:false_positive?, true)
    end

    update :update_tracking do
      require_atomic? false
      accept [:tracking_id, :trajectory, :speed_kmph, :direction]

      change fn changeset, _context ->
        trajectory = Changeset.get_attribute(changeset, :trajectory) || []
        center_point = Changeset.get_attribute(changeset, :center_point)

        if center_point && map_size(center_point) > 0 do
          new_point = Map.put(center_point, "timestamp", DateTime.utc_now())

          Changeset.force_change_attribute(
            changeset,
            :trajectory,
            trajectory ++ [new_point]
          )
        else
          changeset
        end
      end
    end

    update :update_dwell_time do
      require_atomic? false
      accept [:dwell_time_seconds]

      argument :dwell_time_seconds, :integer do
        allow_nil? false
        constraints min: 0
      end
    end

    update :add_rule_match do
      require_atomic? false
      accept []

      argument :rule_name, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :conditions, :map do
        allow_nil? false
      end

      change fn changeset, _context ->
        matched_rules =
          Changeset.get_attribute(changeset, :matched_rules) || []

        rule_conditions =
          Changeset.get_attribute(changeset, :rule_conditions) || %{}

        rule_name = changeset.arguments.rule_name
        conditions = changeset.arguments.conditions

        updated_rules =
          if rule_name in matched_rules do
            matched_rules
          else
            [rule_name | matched_rules]
          end

        changeset
        |> Changeset.force_change_attribute(:matched_rules, updated_rules)
        |> Changeset.force_change_attribute(
          :rule_conditions,
          Map.put(rule_conditions, rule_name, conditions)
        )
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_person?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn analytics ->
            analytics.analytics_type in [
              :person_detection,
              :face_detection,
              :face_recognition
            ]
          end)

        {:ok, values}
      end
    end

    calculate :is_vehicle?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn analytics ->
            analytics.analytics_type in [:vehicle_detection, :license_plate]
          end)

        {:ok, values}
      end
    end

    calculate :is_behavior?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn analytics ->
            analytics.analytics_type in [
              :loitering,
              :intrusion,
              :line_crossing,
              :crowd_detection,
              :behavior_analysis
            ]
          end)

        {:ok, values}
      end
    end

    calculate :requires_review?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn analytics ->
            !analytics.reviewed? &&
              (analytics.alert_triggered? || analytics.confidence < 0.7)
          end)

        {:ok, values}
      end
    end

    calculate :age_seconds, :integer do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn analytics ->
            DateTime.diff(DateTime.utc_now(), analytics.timestamp)
          end)

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:create) do
      # System action for analytics engines
      authorize_if always()
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "viewer")
    end

    policy action([:update, :review, :mark_false_positive]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
    end

    policy action([:trigger_alert, :link_to_alarm]) do
      # System actions
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :trigger_alert
    define :link_to_alarm
    define :review
    define :mark_false_positive
    define :update_tracking
    define :update_dwell_time
    define :add_rule_match
    define :destroy
  end

  postgres do
    table "video_analytics"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :camera_id]
      index [:recording_id], where: "recording_id IS NOT NULL"
      index [:stream_id], where: "stream_id IS NOT NULL"
      index [:analytics_type]
      index [:timestamp]
      index [:object_class]
      index [:person_id], where: "person_id IS NOT NULL"
      index [:zone_id], where: "zone_id IS NOT NULL"

      index [:alert_triggered?],
        name: "analytics_alert_triggered_index",
        where: "alert_triggered? = true"

      index [:reviewed?],
        name: "analytics_reviewed_index",
        where: "reviewed? = false"

      index [:false_positive?],
        name: "analytics_false_positive_index",
        where: "false_positive? = true"

      index [:confidence]
    end
  end

  # Helper functions
  defp evaluate_alert_conditions(changeset) do
    analytics_type = Changeset.get_attribute(changeset, :analytics_type)
    confidence = Changeset.get_attribute(changeset, :confidence)
    event_type = Changeset.get_attribute(changeset, :event_type)

    should_alert = should_trigger_alert?(analytics_type, event_type, confidence)
    alert_level = determine_alert_level(analytics_type, event_type, confidence)

    if should_alert do
      apply_alert_attributes(changeset, alert_level)
    else
      changeset
    end
  end

  defp should_trigger_alert?(analytics_type, event_type, confidence) do
    case {analytics_type, event_type} do
      {:intrusion, _} -> confidence >= 0.8
      {:face_recognition, _} -> confidence >= 0.9
      {:abandoned_object, _} -> confidence >= 0.7
      {_, :fighting} -> true
      {_, :falling} -> true
      {_, :running} -> confidence >= 0.85
      _ -> false
    end
  end

  defp determine_alert_level(analytics_type, event_type, confidence) do
    cond do
      event_type in [:fighting, :falling] -> :critical
      analytics_type == :intrusion && confidence >= 0.9 -> :alert
      analytics_type == :abandoned_object -> :warning
      true -> :info
    end
  end

  defp apply_alert_attributes(changeset, alert_level) do
    changeset
    |> Changeset.force_change_attribute(:alert_triggered?, true)
    |> Changeset.force_change_attribute(:alert_level, alert_level)
    |> Changeset.force_change_attribute(:alert_sent_at, DateTime.utc_now())
  end
end
