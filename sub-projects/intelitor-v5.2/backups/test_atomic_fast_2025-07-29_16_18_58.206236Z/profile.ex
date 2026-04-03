defmodule Intelitor.Accounts.Profile do
  @moduledoc """
  Extended user profile information.

  Stores additional user data beyond authentication needs,
  including personal details, contact info, and preferences.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Accounts,
    table: "user_profiles"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :phone_number, :string do
      constraints max_length: 20
      description "Primary phone number"
    end

    attribute :mobile_number, :string do
      constraints max_length: 20
      description "Mobile phone number"
    end

    attribute :job_title, :string do
      constraints max_length: 100
      description "Current job title"
    end

    attribute :department, :string do
      constraints max_length: 100
      description "Department or division"
    end

    attribute :employee_id, :string do
      constraints max_length: 50
      description "Internal employee identifier"
    end

    attribute :bio, :string do
      constraints max_length: 1000
      description "Short biography"
    end

    attribute :avatar_url, :string do
      constraints max_length: 500
      description "Profile picture URL"
    end

    attribute :timezone, :string do
      constraints max_length: 50
      default "UTC"
      description "User's preferred timezone"
    end

    attribute :locale, :string do
      constraints max_length: 10
      default "en"
      description "Preferred language/locale"
    end

    attribute :date_format, :string do
      constraints max_length: 20
      default "MM/DD/YYYY"
      description "Preferred date format"
    end

    attribute :time_format, :string do
      constraints max_length: 20
      default "12h"
      description "12h or 24h time format"
    end

    attribute :notification_preferences, :map do
      default %{
        email: true,
        sms: false,
        push: true,
        desktop: true
      }

      description "Notification channel preferences"
    end

    attribute :emergency_contact, :map do
      default %{}
      description "Emergency contact information"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional profile data"
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_user, [:user_id]
  end

  actions do
    defaults [:read, :create, :update, :destroy]
update :update_preferences do
      accept [:timezone, :locale, :date_format, :time_format, :notification_preferences]
    end

    update :update_contact do
      accept [:phone_number, :mobile_number, :emergency_contact]
    end

    update :update_work_info do
      accept [:job_title, :department, :employee_id]
    end
  end

  calculations do
    calculate :display_name, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.user.full_name || record.user.username || record.user.email
        end)
      end

      load [:user]
    end

    calculate :has_avatar?, :boolean, expr(not is_nil(avatar_url) and avatar_url != "")

    calculate :notification_channels, {:array, :atom} do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          record.notification_preferences
          |> Enum.filter(fn {_channel, enabled} -> enabled end)
          |> Enum.map(fn {channel, _} -> String.to_atom(channel) end)
        end)
      end
    end
  end

  validations do
    validate match(:phone_number, ~S/^[+\d\s()-]+$/) do
      where present(:phone_number)
    end

    validate match(:mobile_number, ~S/^[+\d\s()-]+$/) do
      where present(:mobile_number)
    end

    validate one_of(:timezone, [
               "UTC",
               "America/New_York",
               "America/Chicago",
               "America/Denver",
               "America/Los_Angeles",
               "Europe/London",
               "Europe/Paris",
               "Asia/Tokyo",
               "Asia/Shanghai",
               "Australia/Sydney"
             ])

    validate one_of(:locale, ["en", "es", "fr", "de", "it", "pt", "ja", "zh"])
    validate one_of(:time_format, ["12h", "24h"])
  end

  policies do
    # Users can read and update their own profile
    policy action_type([:read, :update]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    # Admins can read all profiles
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Profile creation happens automatically with user
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:is_system, true)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :update_preferences
    define :update_contact
    define :update_work_info
  end

  postgres do
    table "user_profiles"
    repo Intelitor.Repo

    custom_indexes do
      index [:user_id], unique: true
      index [:employee_id], where: "employee_id IS NOT NULL"
    end
  end
end
