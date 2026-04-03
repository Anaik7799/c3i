defmodule Indrajaal.AshFactory do
  @moduledoc """
  Ash-compatible factory for creating test resources.
  Provides helper functions for creating Ash resources in tests.
  """

  alias Indrajaal.Accounts.User
  alias Indrajaal.Alarms.AlarmEvent
  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Devices.Device
  alias Indrajaal.Sites.Site

  @spec insert(any(), any()) :: any()
  def insert(factoryname, attrs \\ %{}) do
    factoryname
    |> build(attrs)
    |> create_resource(factoryname)
  end

  @spec build(any(), any()) :: any()
  def build(factoryname, attrs \\ %{}) do
    factoryname
    |> base_attrs()
    |> Map.merge(attrs)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(attrs, :tenant) do
    attrs
    |> Map.put_new(:slug, "test-tenant-#{System.unique_integer([:positive])}")
    |> then(fn attrs ->
      Tenant
      |> Ash.Changeset.for_create(:register, attrs)
      |> Ash.create!(actor: %{is_system: true})
    end)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(attrs, :organization) do
    attrs
    |> then(fn attrs ->
      Organization
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: %{is_system: true})
    end)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(attrs, :user) do
    attrs
    |> then(fn attrs ->
      User
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: %{is_system: true})
    end)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(attrs, :site) do
    attrs
    |> then(fn attrs ->
      Site
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: %{is_system: true})
    end)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(attrs, :device) do
    attrs
    |> then(fn attrs ->
      Device
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: %{is_system: true})
    end)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(attrs, :alarm_event) do
    attrs
    |> then(fn attrs ->
      AlarmEvent
      |> Ash.Changeset.for_create(:create, attrs)
      |> Ash.create!(actor: %{is_system: true})
    end)
  end

  @spec create_resource(term(), term()) :: term()
  defp create_resource(_attrs, factory_name) do
    raise "Factory not implemented for #{factory_name}"
  end

  # Base attribute definitions
  @spec base_attrs(term()) :: term()
  defp base_attrs(:tenant) do
    %{
      name: "Test Tenant #{System.unique_integer([:positive])}",
      slug: "test-tenant-#{System.unique_integer([:positive])}",
      status: :active,
      subscription_tier: :free,
      settings: %{
        timezone: "UTC",
        locale: "en",
        features: %{
          video_enabled: true,
          dispatch_enabled: true,
          billing_enabled: true
        }
      }
    }
  end

  @spec base_attrs(term()) :: term()
  defp base_attrs(:organization) do
    %{
      name: "Test Organization #{System.unique_integer([:positive])}",
      slug: "test-org-#{System.unique_integer([:positive])}",
      organization_type: :enterprise,
      status: :active,
      contact_info: %{
        "email" => "test@example.com",
        "phone" => "+1-555-0123"
      },
      business_info: %{
        "industry" => "Security Services",
        "company_size" => "101-500"
      }
    }
  end

  @spec base_attrs(term()) :: term()
  defp base_attrs(:user) do
    %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      username: "testuser#{System.unique_integer([:positive])}",
      first_name: "Test",
      last_name: "User",
      status: :active,
      email_confirmed_at: DateTime.utc_now()
    }
  end

  @spec base_attrs(term()) :: term()
  defp base_attrs(:site) do
    %{
      name: "Test Site #{System.unique_integer([:positive])}",
      slug: "test-site-#{System.unique_integer([:positive])}",
      site_type: :office,
      status: :active,
      address: %{
        "line1" => "123 Test St",
        "city" => "Test City",
        "state" => "TS",
        "postal_code" => "12_345",
        "country" => "USA"
      }
    }
  end

  @spec base_attrs(term()) :: term()
  defp base_attrs(:device) do
    %{
      name: "Test Device #{System.unique_integer([:positive])}",
      # Will need to be set by caller
      device_type_id: nil,
      serial_number: "TEST#{System.unique_integer([:positive])}",
      status: :active,
      location_data: %{
        "zone" => "test_zone",
        "floor" => "1"
      }
    }
  end

  @spec base_attrs(term()) :: term()
  defp base_attrs(:alarm_event) do
    %{
      event_type: "test_event",
      severity: :medium,
      source_type: :device,
      description: "Test alarm event",
      status: :new,
      priority: :medium,
      event_data: %{
        "test_data" => "test_value"
      }
    }
  end

  @spec base_attrs(term()) :: term()
  defp base_attrs(factory_name) do
    raise "Base attributes not defined for #{factory_name}"
  end
end
