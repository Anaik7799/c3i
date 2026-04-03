defmodule Indrajaal.Core.TenantTest do
  import Indrajaal.ActorHelpers
  use Indrajaal.DataCase
  alias Indrajaal.Core.Tenant

  describe "tenant creation" do
    test "creates tenant with valid attributes" do
      attrs = %{
        name: "Test Security Corp",
        slug: "test-security"
      }

      assert {:ok, tenant} = Tenant.register(attrs, actor: system_admin_actor())
      assert tenant.name == "Test Security Corp"
      assert tenant.slug == Ash.CiString.new("test-security")
      assert tenant.status == :active
      assert tenant.subscription_tier == :free
      assert tenant.settings != nil
      assert tenant.metadata != nil
    end

    test "requires unique slug" do
      actor = system_admin_actor()
      attrs = %{name: "First Tenant", slug: "unique-tenant"}
      assert {:ok, _tenant1} = Tenant.register(attrs, actor: actor)

      attrs2 = %{name: "Second Tenant", slug: "unique-tenant"}
      assert {:error, error} = Tenant.register(attrs2, actor: actor)
      assert Exception.message(error) =~ "slug: has already been taken"
    end

    test "validates slug format" do
      actor = system_admin_actor()

      invalid_slugs = [
        "UPPERCASE",
        "special!chars",
        "spaces not allowed",
        "underscores_not_allowed",
        ""
      ]

      for slug <- invalid_slugs do
        attrs = %{name: "Test", slug: slug}
        assert {:error, _error} = Tenant.register(attrs, actor: actor)
      end
    end

    test "accepts valid slug formats" do
      actor = system_admin_actor()

      valid_slugs = [
        "lowercase",
        "with-dashes",
        "numbers123",
        "long-slug-with-multiple-parts-123"
      ]

      for slug <- valid_slugs do
        attrs = %{name: "Test #{slug}", slug: slug}
        assert {:ok, tenant} = Tenant.register(attrs, actor: actor)
        assert tenant.slug == Ash.CiString.new("#{slug}")
      end
    end

    test "creates tenant with all optional fields" do
      attrs = %{
        name: "Enterprise Tenant",
        slug: "enterprise",
        status: :trial,
        subscription_tier: :enterprise,
        metadata: %{"custom" => "data"},
        settings: %{
          "timezone" => "America/Chicago",
          "locale" => "es",
          "features" => %{
            "video_enabled" => false,
            "dispatch_enabled" => true
          }
        }
      }

      assert {:ok, tenant} = Tenant.register(attrs, actor: system_admin_actor())
      assert tenant.status == :trial
      assert tenant.subscription_tier == :enterprise
      assert tenant.metadata["custom"] == "data"
      assert tenant.settings["timezone"] == "America/Chicago"
      assert tenant.settings["locale"] == "es"
      assert tenant.settings["features"]["video_enabled"] == false
    end

    test "creates tenant with maximum length name" do
      max_name = String.duplicate("A", 255)
      attrs = %{name: max_name, slug: "max-length"}

      assert {:ok, tenant} = Tenant.register(attrs, actor: system_admin_actor())
      assert String.length(tenant.name) == 255
    end

    test "rejects tenant with name too long" do
      long_name = String.duplicate("A", 256)
      attrs = %{name: long_name, slug: "too-long"}

      assert {:error, error} = Tenant.register(attrs, actor: system_admin_actor())
      assert Exception.message(error) =~ "name:"
    end

    test "creates tenant with unicode characters" do
      attrs = %{
        name: "日本語 Security 公司",
        slug: "unicode-tenant"
      }

      assert {:ok, tenant} = Tenant.register(attrs, actor: system_admin_actor())
      assert tenant.name == "日本語 Security 公司"
    end

    test "validates required fields" do
      assert {:error, error} = Tenant.register(%{}, actor: system_admin_actor())
      error_msg = Exception.message(error)
      assert error_msg =~ "name is required"
      assert error_msg =~ "slug is required"
    end

    test "sets default values correctly" do
      attrs = %{name: "Default Test", slug: "default-test"}

      assert {:ok, tenant} = Tenant.register(attrs, actor: system_admin_actor())
      assert tenant.status == :active
      assert tenant.subscription_tier == :free
      assert is_map(tenant.settings)
      assert is_map(tenant.metadata)
    end
  end

  describe "tenant updates" do
    setup do
      # Use factory with system admin actor to bypass domain restrictions
      tenant = insert(:tenant)
      {:ok, tenant: tenant, actor: system_admin_actor()}
    end

    test "updates tenant attributes", %{tenant: tenant, actor: actor} do
      attrs = %{
        name: "Updated Name",
        status: :archived
      }

      assert {:ok, updated} = Tenant.update(tenant, attrs, actor: actor)
      assert updated.name == "Updated Name"
      assert updated.status == :archived
      assert updated.slug == tenant.slug
    end

    test "updates tenant settings", %{tenant: tenant, actor: actor} do
      attrs = %{
        settings: %{
          "timezone" => "Europe/London",
          "features" => %{
            "ai_enabled" => true
          }
        }
      }

      assert {:ok, updated} = Tenant.update(tenant, attrs, actor: actor)
      assert updated.settings["timezone"] == "Europe/London"
      assert updated.settings["features"]["ai_enabled"] == true
    end

    test "updates tenant metadata", %{tenant: tenant, actor: actor} do
      attrs = %{
        metadata: %{
          "support_level" => "premium",
          "account_manager" => "John Doe"
        }
      }

      assert {:ok, updated} = Tenant.update(tenant, attrs, actor: actor)
      assert updated.metadata["support_level"] == "premium"
      assert updated.metadata["account_manager"] == "John Doe"
    end

    test "validates status values", %{tenant: tenant, actor: actor} do
      valid_statuses = [:active, :suspended, :archived, :trial]

      for status <- valid_statuses do
        attrs = %{status: status}
        assert {:ok, updated} = Tenant.update(tenant, attrs, actor: actor)
        assert updated.status == status
      end
    end

    test "validates subscription tier values", %{tenant: tenant, actor: actor} do
      valid_tiers = [:free, :basic, :professional, :enterprise, :standard]

      for tier <- valid_tiers do
        attrs = %{subscription_tier: tier}
        assert {:ok, updated} = Tenant.update(tenant, attrs, actor: actor)
        assert updated.subscription_tier == tier
      end
    end

    test "tracks update history in metadata", %{tenant: tenant, actor: actor} do
      attrs = %{
        name: "History Test",
        metadata: Map.put(tenant.metadata || %{}, "update_count", 1)
      }

      assert {:ok, updated} = Tenant.update(tenant, attrs, actor: actor)
      assert updated.metadata["update_count"] == 1
    end
  end

  describe "tenant queries" do
    setup do
      actor = system_admin_actor()
      # Create diverse tenant data using factory
      tenants = Enum.map(1..10, fn _ -> insert(:tenant) end)
      {:ok, tenants: tenants, actor: actor}
    end

    test "lists all tenants", %{tenants: tenants, actor: actor} do
      result = Tenant.list!(actor: actor)
      assert length(result) >= length(tenants)
    end

    test "gets tenant by id", %{tenants: tenants, actor: actor} do
      tenant = List.first(tenants)

      assert {:ok, found} = Tenant.get(tenant.id, actor: actor)
      assert found.id == tenant.id
      assert found.name == tenant.name
    end

    test "returns error for non-existent tenant", %{actor: actor} do
      assert {:error, _error} = Tenant.get(Ecto.UUID.generate(), actor: actor)
    end

    test "filters tenants by status", %{actor: actor} do
      active = insert(:tenant, status: :active)
      suspended = insert(:tenant, status: :suspended)

      results = Tenant.list!(filter: [status: :active], actor: actor)
      assert Enum.any?(results, &(&1.id == active.id))
      refute Enum.any?(results, &(&1.id == suspended.id))
    end
  end

  describe "tenant deletion" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant, actor: system_admin_actor()}
    end

    test "destroys tenant", %{tenant: tenant, actor: actor} do
      assert {:ok, _deleted} = Tenant.archive(tenant, actor: actor)
      assert {:error, _} = Tenant.get(tenant.id, actor: actor)
    end
  end
end
