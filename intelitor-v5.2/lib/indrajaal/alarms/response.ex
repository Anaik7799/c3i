defmodule Indrajaal.Alarms.Response do
  @moduledoc """
  Tracks responses to alarm events by security personnel.

  Responses document the actions taken by operators, guards, and emergency
  services in response to alarm events, providing an audit trail of all
  response activities.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Alarms

  use Indrajaal.Multitenancy.TenantResource

  alias Ash.Changeset

  attributes do
    uuid_primary_key :id

    # Response identification
    attribute :alarm_event_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :responder_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :response_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :acknowledgment,
                    :verification,
                    :dispatch,
                    :arrival,
                    :investigation,
                    :all_clear,
                    :escalation,
                    :handoff
                  ]
    end

    # Response details
    attribute :action_taken, :string do
      allow_nil? false
      public? true
      constraints max_length: 1000
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :findings, :string do
      public? true
      constraints max_length: 2000
    end

    # Verification
    attribute :verified?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :verification_method, :atom do
      public? true

      constraints one_of: [
                    :video_review,
                    :audio_review,
                    :phone_call,
                    :physical_check,
                    :sensor_data,
                    :multiple_sources
                  ]
    end

    # Location and time
    attribute :response_location, :string do
      public? true
      constraints max_length: 500
    end

    attribute :arrival_time, :utc_datetime_usec do
      public? true
    end

    attribute :departure_time, :utc_datetime_usec do
      public? true
    end

    attribute :response_time_seconds, :integer do
      public? true
      constraints min: 0
    end

    # Dispatch details
    attribute :dispatch_team_id, :uuid do
      public? true
    end

    attribute :dispatch_vehicle_id, :string do
      public? true
      constraints max_length: 50
    end

    attribute :external_reference, :string do
      public? true
      constraints max_length: 100
    end

    # Media attachments
    attribute :photo_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :video_urls, {:array, :string} do
      public? true
      default []
    end

    attribute :audio_urls, {:array, :string} do
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
    belongs_to :alarm_event, Indrajaal.Alarms.AlarmEvent do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :responder, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_public? true
    end

    # Future relationships
    # belongs_to :dispatch_team, Indrajaal.Dispatch.Team
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :alarm_event_id,
        :responder_id,
        :response_type,
        :action_taken,
        :notes,
        :findings,
        :verified?,
        :verification_method,
        :response_location,
        :arrival_time,
        :dispatch_team_id,
        :dispatch_vehicle_id,
        :external_reference,
        :metadata
      ]

      argument :alarm_event_id, :uuid do
        allow_nil? false
      end

      argument :responder_id, :uuid do
        allow_nil? false
      end

      change fn changeset, __context ->
        # Calculate response time if this is an arrival response
        response_type = Changeset.get_attribute(changeset, :response_type)
        arrival_time = Changeset.get_attribute(changeset, :arrival_time)

        if response_type == :arrival && arrival_time do
          calculate_response_time(changeset)
        else
          changeset
        end
      end
    end

    update :verify do
      require_atomic? false
      accept [:verified?, :verification_method, :findings]

      validate attribute_equals(:verified?, false)

      change set_attribute(:verified?, true)
    end

    update :add_media do
      require_atomic? false
      accept []

      argument :media_type, :atom do
        allow_nil? false
        constraints one_of: [:photo, :video, :audio]
      end

      argument :url, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change fn changeset, __context ->
        media_type = changeset.arguments.media_type
        url = changeset.arguments.url

        field =
          case media_type do
            :photo -> :photo_urls
            :video -> :video_urls
            :audio -> :audio_urls
          end

        current_urls =
          Changeset.get_attribute(changeset, field) || []

        if url in current_urls do
          changeset
        else
          changeset
          |> Changeset.force_change_attribute(field, [url | current_urls])
        end
      end
    end

    update :set_departure do
      require_atomic? false
      accept [:departure_time]

      argument :departure_time, :utc_datetime_usec do
        allow_nil? false
      end

      validate fn changeset, __context ->
        arrival = Changeset.get_attribute(changeset, :arrival_time)
        departure = Changeset.get_attribute(changeset, :departure_time)

        if arrival && departure &&
             DateTime.compare(departure, arrival) == :lt do
          {
            :error,
            field: :departure_time, message: "must be after arrival time"
          }
        else
          :ok
        end
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :duration_minutes, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn response ->
            if response.arrival_time && response.departure_time do
              response.departure_time
              |> DateTime.diff(response.arrival_time)
              |> div(60)
            else
              nil
            end
          end)

        {:ok, values}
      end
    end

    calculate :has_media?, :boolean do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn response ->
            length(response.photo_urls || []) > 0 ||
              length(response.video_urls || []) > 0 ||
              length(response.audio_urls || []) > 0
          end)

        {:ok, values}
      end
    end

    calculate :media_count, :integer do
      calculation fn records, __context ->
        values =
          Enum.map(records, fn response ->
            length(response.photo_urls || []) +
              length(response.video_urls || []) +
              length(response.audio_urls || [])
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
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "guard")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "supervisor")
      authorize_if actor_attribute_equals(:role, "guard")
      # Users can read their own responses
      authorize_if expr(responder_id == ^actor(:id))
    end

    policy action([:update, :verify, :add_media, :set_departure]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      # Responders can update their own responses
      authorize_if expr(responder_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :verify
    define :add_media
    define :set_departure
    define :destroy
  end

  postgres do
    table "alarm_responses"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :alarm_event_id]
      index [:responder_id]
      index [:response_type]

      index [:verified?],
        name: "alarm_responses_verified_index",
        where: "verified? = true"

      index [:arrival_time]

      index [:dispatch_team_id],
        where: "dispatch_team_id IS NOT NULL"
    end
  end

  # Helper functions
  @spec calculate_response_time(term()) :: term()
  defp calculate_response_time(changeset) do
    # Future implementation: Calculate actual response time from alarm trigger
    # Will require fetching alarm_event.triggered_at and comparing arrival_time
    changeset
  end
end

# Agent: Worker - 1 (Alarms Domain Agent)
# SOPv5.1 Compliance: ✅ Critical alarm processing and incident response coordin
# Domain: Alarms
# Responsibilities: Alarm processing, incident response, critical system monito
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
