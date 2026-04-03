defmodule Intelitor.Sites.Site do
  @moduledoc """
  Represents a physical site or facility in the security monitoring system.

  Sites are the top-level physical locations that contain buildings, zones, and devices.
  They define the geographic boundaries and operational parameters for security monitoring.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Sites,
    table: "sites",
    extensions: [AshAdmin.Resource, AshJsonApi.Resource]

  use Intelitor.Multitenancy.TenantResource

  alias Intelitor.Shared.ValidationUtilities

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :code, :string do
      allow_nil? false
      public? true

      constraints max_length: 50,
                  match: ~S/^[A-Z][A-Z0-9_-]*$/
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :address, :map do
      public? true
      default %{}
    end

    attribute :coordinates, :map do
      public? true
      default %{}
    end

    attribute :timezone, :string do
      public? true
      default "UTC"
      constraints max_length: 50
    end

    attribute :business_hours, :map do
      public? true

      default %{
        "monday" => %{"open" => "09:00", "close" => "17:00"},
        "tuesday" => %{"open" => "09:00", "close" => "17:00"},
        "wednesday" => %{"open" => "09:00", "close" => "17:00"},
        "thursday" => %{"open" => "09:00", "close" => "17:00"},
        "friday" => %{"open" => "09:00", "close" => "17:00"},
        "saturday" => %{"closed" => true},
        "sunday" => %{"closed" => true}
      }
    end

    attribute :contact_info, :map do
      public? true
      default %{}
    end

    attribute :emergency_contacts, {:array, :map} do
      public? true
      default []
    end

    attribute :site_type, :atom do
      public? true

      constraints one_of: [
                    :office,
                    :warehouse,
                    :retail,
                    :industrial,
                    :residential,
                    :mixed,
                    :other
                  ]

      default :office
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:active, :inactive, :construction, :decommissioned]
      default :active
    end

    attribute :security_level, :atom do
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :max_occupancy, :integer do
      public? true
      constraints min: 0
    end

    attribute :current_occupancy, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :features, {:array, :string} do
      public? true
      default []
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :organization, Intelitor.Core.Organization do
      allow_nil? false
      public? true
    end

    has_many :buildings, Intelitor.Sites.Building do
      public? true
    end

    has_many :zones, Intelitor.Sites.Zone do
      public? true
    end

    # TODO: Uncomment when Devices domain is implemented
    # has_many :devices, Intelitor.Devices.Device do
    #   public? true
    # end

    # TODO: Uncomment when Alarms domain is implemented
    # has_many :incidents, Intelitor.Alarms.Incident do
    #   public? true
    # end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :update]

    create :create do
      primary? true

      accept [
        :name,
        :code,
        :description,
        :address,
        :coordinates,
        :timezone,
        :business_hours,
        :contact_info,
        :emergency_contacts,
        :site_type,
        :security_level,
        :max_occupancy,
        :features,
        :organization_id
      ]

      change fn changeset, _context ->
        # Validate coordinates if provided
        case Ash.Changeset.get_attribute(changeset, :coordinates) do
          %{"lat" => lat, "lng" => lng} when is_number(lat) and is_number(lng) ->
            if lat >= -90 and lat <= 90 and lng >= -180 and lng <= 180 do
              {:ok, changeset}
            else
              {:error, field: :coordinates, message: "Invalid latitude or longitude values"}
            end

          nil ->
            {:ok, changeset}

          _ ->
            {:error, field: :coordinates, message: "Coordinates must have lat and lng as numbers"}
        end
      end
    end


    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:status, :active)
    end

    update :deactivate do
      require_atomic? false
      accept []
      change set_attribute(:status, :inactive)
    end

    update :update_occupancy do
      require_atomic? false
      argument :occupancy, :integer do
        allow_nil? false
        constraints min: 0
      end

      change set_attribute(:current_occupancy, arg(:occupancy))

      validate fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_occupancy)
        max = Ash.Changeset.get_attribute(changeset, :max_occupancy)

        if max && current > max do
          {:error,
           field: :current_occupancy, message: "Cannot exceed maximum occupancy of #{max}"}
        else
          {:ok, changeset}
        end
      end
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:status, :decommissioned)
    end
  end

  calculations do
    calculate :is_active?, :boolean, expr(status == :active)

    calculate :is_open?, :boolean do
      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn site ->
          check_if_open(site, now)
        end)
      end
    end

    calculate :occupancy_percentage, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn site ->
          if site.max_occupancy && site.max_occupancy > 0 do
            Float.round(site.current_occupancy / site.max_occupancy * 100, 2)
          else
            0.0
          end
        end)
      end
    end

    calculate :building_count, :integer, expr(count(buildings))

    calculate :zone_count, :integer, expr(count(zones))

    # TODO: Uncomment when Devices domain is implemented
    # calculate :device_count, :integer, expr(count(devices))

    calculate :full_address, :string do
      calculation fn records, _opts ->
        Enum.map(records, fn site ->
          format_address(site.address)
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 3, max: 255)
    validate string_length(:code, min: 2, max: 50)

    validate match(:code, ~S/^[A-Z][A-Z0-9_-]*$/) do
      message "must start with uppercase letter and contain only uppercase letters, numbers, underscores, and hyphens"
    end

    validate &ValidationUtilities.validate_occupancy_limits/2
    validate &ValidationUtilities.validate_timezone/2
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "site_manager")
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if expr(^actor(:role) == "site_manager" and ^actor(:site_id) == id)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :deactivate
    define :update_occupancy
    define :get_by_code, action: :read, get_by: [:code]
  end

  json_api do
    type "site"

    routes do
      base("/sites")

      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  postgres do
    table "sites"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:tenant_id, :organization_id]
      index [:status], where: "status = 'active'"
      index [:site_type]
      index [:security_level]
    end
  end

  # Helper functions
  defp check_if_open(site, now) do
    with tz when tz != nil <- site.timezone,
         {:ok, local_time} <- DateTime.shift_zone(now, tz),
         day <- local_time |> DateTime.to_date() |> Date.day_of_week() |> day_name(),
         hours <- Map.get(site.business_hours || %{}, day, %{}) do
      if Map.get(hours, "closed", false) do
        false
      else
        open_time = Map.get(hours, "open")
        close_time = Map.get(hours, "close")

        if open_time && close_time do
          current_time = Calendar.strftime(local_time, "%H:%M")
          current_time >= open_time && current_time <= close_time
        else
          # Default to open if hours not specified
          true
        end
      end
    else
      # Default to open if can't determine
      _ -> true
    end
  end

  defp day_name(1), do: "monday"
  defp day_name(2), do: "tuesday"
  defp day_name(3), do: "wednesday"
  defp day_name(4), do: "thursday"
  defp day_name(5), do: "friday"
  defp day_name(6), do: "saturday"
  defp day_name(7), do: "sunday"

  defp format_address(nil), do: ""

  defp format_address(address) when is_map(address) do
    parts = [
      Map.get(address, "line1"),
      Map.get(address, "line2"),
      Map.get(address, "city"),
      Map.get(address, "state"),
      Map.get(address, "postal_code"),
      Map.get(address, "country")
    ]

    parts
    |> Enum.filter(&(&1 && &1 != ""))
    |> Enum.join(", ")
  end

  defp format_address(_), do: ""
end
