defmodule Intelitor.Dispatch.Officer do
  @moduledoc """
  Represents a dispatch officer or security personnel.

  Officers are the individual personnel who respond to incidents as part of
  dispatch teams. They have certifications, specializations, availability
  status, and performance tracking.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Dispatch,
    table: "dispatch_officers"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Officer identification
    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :badge_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :call_sign, :string do
      public? true
      constraints max_length: 20
    end

    # Team assignment
    attribute :team_id, :uuid do
      public? true
    end

    attribute :rank, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :officer,
                    :senior_officer,
                    :corporal,
                    :sergeant,
                    :lieutenant,
                    :captain,
                    :inspector,
                    :commander
                  ]

      default :officer
    end

    attribute :role, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :patrol,
                    :response,
                    :supervisor,
                    :specialist,
                    :k9_handler,
                    :medic,
                    :driver,
                    :communications
                  ]

      default :response
    end

    # Status and availability
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :on_duty,
                    :off_duty,
                    :available,
                    :assigned,
                    :responding,
                    :on_scene,
                    :break,
                    :unavailable,
                    :training
                  ]

      default :off_duty
    end

    attribute :availability, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:available, :busy, :unavailable, :emergency_only]
      default :available
    end

    attribute :shift_start, :utc_datetime_usec do
      public? true
    end

    attribute :shift_end, :utc_datetime_usec do
      public? true
    end

    # Location and movement
    attribute :current_location, :map do
      public? true
      default %{}
    end

    attribute :last_location_update, :utc_datetime_usec do
      public? true
    end

    attribute :assigned_vehicle_id, :uuid do
      public? true
    end

    # Certifications and qualifications
    attribute :certifications, {:array, :string} do
      public? true
      default []
    end

    attribute :specializations, {:array, :atom} do
      public? true

      constraints items: [
                    one_of: [
                      :firearms,
                      :defensive_tactics,
                      :first_aid,
                      :cpr,
                      :k9_handling,
                      :crowd_control,
                      :investigation,
                      :surveillance,
                      :technical_rescue,
                      :hazmat,
                      :emergency_medical,
                      :crisis_negotiation
                    ]
                  ]

      default []
    end

    attribute :security_clearance, :atom do
      public? true
      constraints one_of: [:public, :confidential, :secret, :top_secret]
      default :public
    end

    attribute :certification_expiry, :map do
      public? true
      default %{}
    end

    # Equipment and gear
    attribute :issued_equipment, {:array, :string} do
      public? true
      default []
    end

    attribute :radio_id, :string do
      public? true
      constraints max_length: 50
    end

    attribute :body_camera_id, :string do
      public? true
      constraints max_length: 50
    end

    attribute :weapon_serial, :string do
      public? false
      constraints max_length: 50
    end

    # Performance metrics
    attribute :total_assignments, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :completed_assignments, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :average_response_time_minutes, :float do
      public? true
      constraints min: 0
    end

    attribute :performance_rating, :float do
      public? true
      constraints min: 0, max: 5
    end

    attribute :commendations, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :incidents, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    # Communication preferences
    attribute :contact_phone, :string do
      public? true
      constraints max_length: 50
    end

    attribute :emergency_contact, :string do
      public? true
      constraints max_length: 100
    end

    attribute :notification_preferences, :map do
      public? true

      default %{
        "sms" => true,
        "radio" => true,
        "app" => true,
        "email" => false
      }
    end

    # Training and development
    attribute :last_training_date, :date do
      public? true
    end

    attribute :training_hours_ytd, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end

    attribute :required_training_hours, :integer do
      allow_nil? false
      public? true
      default 40
      constraints min: 0
    end

    # Medical and fitness
    attribute :medical_clearance_date, :date do
      public? true
    end

    attribute :fitness_test_date, :date do
      public? true
    end

    attribute :medical_restrictions, {:array, :string} do
      public? true
      default []
    end

    # Metadata
    attribute :notes, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Intelitor.Accounts.User do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :team, Intelitor.Dispatch.Team do
      attribute_public? true
    end

    belongs_to :assigned_vehicle, Intelitor.Dispatch.Vehicle do
      attribute_public? true
    end

    has_many :assignments, Intelitor.Dispatch.Assignment
  end

  actions do
    defaults [:create, :read, :destroy, :update]

    update :update_status do
      require_atomic? false
      accept [:status, :availability]

      argument :status, :atom do
        allow_nil? false

        constraints one_of: [
                      :on_duty,
                      :off_duty,
                      :available,
                      :assigned,
                      :responding,
                      :on_scene,
                      :break,
                      :unavailable,
                      :training
                    ]
      end
    end

    update :start_shift do
      require_atomic? false
      accept [:shift_start]

      validate attribute_in(:status, [:off_duty, :unavailable])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :on_duty)
        |> Ash.Changeset.force_change_attribute(:availability, :available)
        |> Ash.Changeset.force_change_attribute(:shift_start, DateTime.utc_now())
      end
    end

    update :end_shift do
      require_atomic? false
      accept [:shift_end]

      validate attribute_in(:status, [:on_duty, :available, :break])

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :off_duty)
        |> Ash.Changeset.force_change_attribute(:availability, :unavailable)
        |> Ash.Changeset.force_change_attribute(:shift_end, DateTime.utc_now())
      end
    end

    update :assign_to_team do
      require_atomic? false
      accept [:team_id]

      argument :team_id, :uuid do
        allow_nil? false
      end
    end

    update :remove_from_team do
      require_atomic? false
      accept []

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:team_id, nil)
        |> Ash.Changeset.force_change_attribute(:status, :available)
      end
    end

    update :assign_vehicle do
      require_atomic? false
      accept [:assigned_vehicle_id]

      argument :vehicle_id, :uuid do
        allow_nil? false
      end
    end

    update :remove_vehicle do
      require_atomic? false
      accept []

      change set_attribute(:assigned_vehicle_id, nil)
    end

    update :update_location do
      require_atomic? false
      accept [:current_location, :last_location_update]

      argument :latitude, :float do
        allow_nil? false
        constraints min: -90, max: 90
      end

      argument :longitude, :float do
        allow_nil? false
        constraints min: -180, max: 180
      end

      change fn changeset, _context ->
        location = %{
          "latitude" => changeset.arguments.latitude,
          "longitude" => changeset.arguments.longitude,
          "timestamp" => DateTime.utc_now(),
          "accuracy" => 5.0,
          "heading" => 0.0,
          "speed" => 0.0
        }

        changeset
        |> Ash.Changeset.force_change_attribute(:current_location, location)
        |> Ash.Changeset.force_change_attribute(:last_location_update, DateTime.utc_now())
      end
    end

    update :add_certification do
      require_atomic? false
      accept []

      argument :certification, :string do
        allow_nil? false
        constraints max_length: 100
      end

      argument :expiry_date, :date

      change fn changeset, _context ->
        certifications = Ash.Changeset.get_attribute(changeset, :certifications) || []
        certification = changeset.arguments.certification

        if certification in certifications do
          changeset
        else
          updated_certs = [certification | certifications]

          changeset =
            Ash.Changeset.force_change_attribute(changeset, :certifications, updated_certs)

          # Update expiry tracking if date provided
          if expiry_date = changeset.arguments.expiry_date do
            expiry_map = Ash.Changeset.get_attribute(changeset, :certification_expiry) || %{}
            updated_expiry = Map.put(expiry_map, certification, expiry_date)

            Ash.Changeset.force_change_attribute(
              changeset,
              :certification_expiry,
              updated_expiry
            )
          else
            changeset
          end
        end
      end
    end

    update :remove_certification do
      require_atomic? false
      accept []

      argument :certification, :string do
        allow_nil? false
      end

      change fn changeset, _context ->
        certifications = Ash.Changeset.get_attribute(changeset, :certifications) || []
        certification = changeset.arguments.certification

        updated_certs = Enum.reject(certifications, &(&1 == certification))

        changeset =
          Ash.Changeset.force_change_attribute(changeset, :certifications, updated_certs)

        # Remove expiry tracking
        expiry_map = Ash.Changeset.get_attribute(changeset, :certification_expiry) || %{}
        updated_expiry = Map.delete(expiry_map, certification)

        Ash.Changeset.force_change_attribute(
          changeset,
          :certification_expiry,
          updated_expiry
        )
      end
    end

    update :track_assignment do
      require_atomic? false
      accept []

      argument :completed?, :boolean do
        allow_nil? false
      end

      argument :response_time_minutes, :float do
        constraints min: 0
      end

      change fn changeset, _context ->
        total = Ash.Changeset.get_attribute(changeset, :total_assignments)
        completed = Ash.Changeset.get_attribute(changeset, :completed_assignments)
        completed? = changeset.arguments.completed?

        changeset = Ash.Changeset.force_change_attribute(changeset, :total_assignments, total + 1)

        changeset =
          if completed? do
            Ash.Changeset.force_change_attribute(
              changeset,
              :completed_assignments,
              completed + 1
            )
          else
            changeset
          end

        # Update average response time if provided
        if response_time = changeset.arguments.response_time_minutes do
          current_avg = Ash.Changeset.get_attribute(changeset, :average_response_time_minutes)

          new_avg =
            if current_avg do
              (current_avg + response_time) / 2.0
            else
              response_time
            end

          Ash.Changeset.force_change_attribute(
            changeset,
            :average_response_time_minutes,
            new_avg
          )
        else
          changeset
        end
      end
    end

    update :add_training_hours do
      require_atomic? false
      accept [:training_hours_ytd, :last_training_date]

      argument :hours, :integer do
        allow_nil? false
        constraints min: 1, max: 40
      end

      change fn changeset, _context ->
        current_hours = Ash.Changeset.get_attribute(changeset, :training_hours_ytd)
        hours = changeset.arguments.hours

        changeset
        |> Ash.Changeset.force_change_attribute(:training_hours_ytd, current_hours + hours)
        |> Ash.Changeset.force_change_attribute(:last_training_date, Date.utc_today())
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
    calculate :is_on_duty?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn officer ->
              officer.status in [:on_duty, :available, :assigned, :responding, :on_scene, :break]
            end
          )

        {:ok, values}
      end
    end

    calculate :is_available_for_assignment?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn officer ->
              officer.status in [:on_duty, :available] &&
                officer.availability in [:available, :emergency_only] &&
                officer.active?
            end
          )

        {:ok, values}
      end
    end

    calculate :completion_rate, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn officer ->
              if officer.total_assignments > 0 do
                officer.completed_assignments / officer.total_assignments * 100.0
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :training_compliance, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn officer ->
              if officer.required_training_hours > 0 do
                min(
                  officer.training_hours_ytd / officer.required_training_hours,
                  1.0
                ) * 100.0
              else
                100.0
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :certifications_expiring_soon, :integer do
      calculation fn records, _context ->
        thirty_days = Date.add(Date.utc_today(), 30)

        values =
          Enum.map(
            records,
            fn officer ->
              expiry_map = officer.certification_expiry || %{}

              Enum.count(
                expiry_map,
                fn {_cert, expiry_date} ->
                  Date.compare(
                    expiry_date,
                    thirty_days
                  ) in [:lt, :eq]
                end
              )
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

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      authorize_if actor_attribute_equals(:role, "supervisor")
      # Officers can read their own records
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type([:create, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:update, :add_certification, :remove_certification]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "supervisor")
    end

    policy action([:update_status, :update_location, :start_shift, :end_shift]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "operator")
      authorize_if actor_attribute_equals(:role, "dispatcher")
      # Officers can update their own status
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :update_status
    define :start_shift
    define :end_shift
    define :assign_to_team
    define :remove_from_team
    define :assign_vehicle
    define :remove_vehicle
    define :update_location
    define :add_certification
    define :remove_certification
    define :track_assignment
    define :add_training_hours
    define :activate
    define :deactivate
    define :destroy
  end

  postgres do
    table "dispatch_officers"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :badge_number], unique: true
      index [:user_id], unique: true
      index [:team_id], where: "team_id IS NOT NULL"
      index [:status]
      index [:availability]
      index [:rank]
      index [:role]
      index [:assigned_vehicle_id], where: "assigned_vehicle_id IS NOT NULL"
      index [:active?], name: "dispatch_officers_active_index", where: "active? = true"
      index [:last_location_update]
    end
  end
end
