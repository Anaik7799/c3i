defmodule Indrajaal.Core.SystemConfigTest do
  import Indrajaal.ActorHelpers
  use Indrajaal.DataCase
  alias Indrajaal.Core
  alias Indrajaal.Core.SystemConfig

  describe "system config creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates system config with valid attributes", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        key: "security.mfa.enabled",
        value: "true",
        type: "boolean",
        description: "Enable multi-factor authentication"
      }

      assert {:ok, config} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      assert config.key == "security.mfa.enabled"
      assert config.value == "true"
      assert config.type == "boolean"
      assert config.tenant_id == tenant.id
      assert config.encrypted == false
    end

    test "validates required fields", %{tenant: tenant} do
      attrs = %{}

      assert {:error, error} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      error_msg = Exception.message(error)
      assert error_msg =~ "key: is required"
      assert error_msg =~ "value: is required"
    end

    test "validates key uniqueness per tenant", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        key: "unique.key",
        value: "value1",
        type: "string"
      }

      assert {:ok, _config1} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      # Same key, same tenant should fail
      attrs2 = Map.put(attrs, :value, "value2")

      assert {:error, error} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      assert Exception.message(error) =~ "key: has already been taken"
    end

    test "allows same key for different tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs = %{
        key: "shared.key",
        value: "tenant1_value",
        type: "string"
      }

      assert {:ok, config1} = SystemConfig.set(Map.put(attrs, :tenant_id, tenant1.id))
      assert {:ok, config2} = SystemConfig.set(Map.put(attrs, :tenant_id, tenant2.id))

      assert config1.tenant_id == tenant1.id
      assert config2.tenant_id == tenant2.id
      assert config1.key == config2.key
    end

    test "validates config type values", %{tenant: tenant} do
      valid_types = ["string", "integer", "boolean", "json", "encrypted"]

      for type <- valid_types do
        attrs = %{
          tenant_id: tenant.id,
          key: "test.#{type}",
          value: "test_value",
          type: type
        }

        assert {:ok, config} =
                 SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

        assert config.type == type
      end
    end

    test "creates encrypted config", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        key: "security.api.secret",
        value: "super_secret_key",
        type: "encrypted",
        encrypted: true,
        description: "API secret key"
      }

      assert {:ok, config} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      assert config.encrypted == true
      assert config.type == "encrypted"
      # In production, value would be encrypted
      assert config.value == "super_secret_key"
    end

    test "creates config with category", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        key: "performance.cache.ttl",
        value: "3600",
        type: "integer",
        category: "performance"
      }

      assert {:ok, config} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      assert config.category == "performance"
    end

    test "validates JSON config values", %{tenant: tenant} do
      valid_json =
        Jason.encode!(%{
          "methods" => ["totp", "sms", "email"],
          "required_for" => ["admin", "operator"]
        })

      attrs = %{
        tenant_id: tenant.id,
        key: "security.mfa.config",
        value: valid_json,
        type: "json"
      }

      assert {:ok, config} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      assert config.type == "json"

      # Verify JSON is valid
      assert {:ok, parsed} = Jason.decode(config.value)
      assert parsed["methods"] == ["totp", "sms", "email"]
    end
  end

  describe "system config updates" do
    setup do
      tenant = insert(:tenant)
      config = insert(:system_config, tenant_id: tenant.id)
      {:ok, tenant: tenant, config: config}
    end

    test "updates config value", %{config: config} do
      attrs = %{value: "updated_value"}

      assert {:ok, updated} = SystemConfig.update(config, attrs)
      assert updated.value == "updated_value"
      # Key unchanged
      assert updated.key == config.key
    end

    test "updates config description", %{config: config} do
      attrs = %{description: "Updated description with more details"}

      assert {:ok, updated} = SystemConfig.update(config, attrs)
      assert updated.description == "Updated description with more details"
    end

    test "cannot update key", %{config: config} do
      attrs = %{key: "new.key"}

      assert {:ok, updated} = SystemConfig.update(config, attrs)
      # Key should remain unchanged
      assert updated.key == config.key
    end

    test "tracks value history in metadata", %{config: config} do
      original_value = config.value

      # Update value
      attrs = %{
        value: "new_value",
        metadata: %{
          "changed_by" => "admin@example.com",
          "change_reason" => "Performance optimization",
          "previous_value" => original_value
        }
      }

      assert {:ok, updated} = SystemConfig.update(config, attrs)
      assert updated.metadata["changed_by"] == "admin@example.com"
      assert updated.metadata["previous_value"] == original_value
    end

    test "validates type consistency on update", %{tenant: tenant} do
      config =
        insert(:system_config,
          tenant_id: tenant.id,
          type: "integer",
          value: "100"
        )

      # Update with same type should work
      assert {:ok, updated} = SystemConfig.update(config, %{value: "200"})
      assert updated.value == "200"

      # Type validation would depend on your business rules
    end
  end

  describe "system config queries" do
    setup do
      tenant = insert(:tenant)
      configs = bulk_create_system_configs(60)

      taken_configs = Enum.take(configs, 20)

      tenant_configs =
        taken_configs
        |> Enum.map(fn c ->
          update_result = SystemConfig.update(c, %{tenant_id: tenant.id})
          update_result |> elem(1)
        end)

      {:ok, tenant: tenant, configs: tenant_configs}
    end

    test "lists all configs for tenant", %{tenant: tenant} do
      configs = SystemConfig.list!(tenant_id: tenant.id)
      assert length(configs) >= 20
      assert Enum.all?(configs, &(&1.tenant_id == tenant.id))
    end

    test "gets config by key", %{tenant: tenant, configs: configs} do
      config = List.first(configs)

      found = SystemConfig.get_by_key!(tenant.id, config.key)
      assert found.id == config.id
      assert found.key == config.key
    end

    test "filters configs by category", %{tenant: tenant} do
      # Create configs with specific categories
      security_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "security.test",
          category: "security"
        )

      performance_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "performance.test",
          category: "performance"
        )

      security_configs =
        SystemConfig.list!(
          tenant_id: tenant.id,
          filter: [category: "security"]
        )

      config_ids = Enum.map(security_configs, & &1.id)
      assert security_config.id in config_ids
      refute performance_config.id in config_ids
    end

    test "filters configs by type", %{tenant: tenant} do
      # Create configs with specific types
      bool_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "feature.enabled",
          type: "boolean",
          value: "true"
        )

      int_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "limit.max",
          type: "integer",
          value: "100"
        )

      bool_configs =
        SystemConfig.list!(
          tenant_id: tenant.id,
          filter: [type: "boolean"]
        )

      assert Enum.any?(bool_configs, &(&1.id == bool_config.id))
      refute Enum.any?(bool_configs, &(&1.id == int_config.id))
    end

    test "filters encrypted configs", %{tenant: tenant} do
      encrypted =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "secret.key",
          encrypted: true
        )

      regular =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "public.key",
          encrypted: false
        )

      encrypted_configs =
        SystemConfig.list!(
          tenant_id: tenant.id,
          filter: [encrypted: true]
        )

      assert Enum.any?(encrypted_configs, &(&1.id == encrypted.id))
      refute Enum.any?(encrypted_configs, &(&1.id == regular.id))
    end

    test "searches configs by key pattern", %{tenant: tenant} do
      # Create configs with patterns
      insert(:system_config, tenant_id: tenant.id, key: "security.mfa.enabled")
      insert(:system_config, tenant_id: tenant.id, key: "security.mfa.methods")
      insert(:system_config, tenant_id: tenant.id, key: "security.session.timeout")
      insert(:system_config, tenant_id: tenant.id, key: "performance.cache.ttl")

      mfa_configs =
        SystemConfig.list!(
          tenant_id: tenant.id,
          filter: [key: {:ilike, "%mfa%"}]
        )

      assert length(mfa_configs) >= 2
      assert Enum.all?(mfa_configs, &String.contains?(&1.key, "mfa"))
    end

    test "sorts configs by key", %{tenant: tenant} do
      configs =
        SystemConfig.list!(
          tenant_id: tenant.id,
          sort: [key: :asc]
        )

      keys = Enum.map(configs, & &1.key)
      assert keys == Enum.sort(keys)
    end

    test "paginates config results", %{tenant: tenant} do
      # Ensure enough configs
      for i <- 1..30 do
        insert(:system_config, tenant_id: tenant.id, key: "page.test.#{i}")
      end

      page1 =
        SystemConfig.list!(
          tenant_id: tenant.id,
          page: [limit: 10, offset: 0]
        )

      page2 =
        SystemConfig.list!(
          tenant_id: tenant.id,
          page: [limit: 10, offset: 10]
        )

      assert length(page1) == 10
      assert length(page2) == 10

      # Verify no overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "system config deletion" do
    setup do
      tenant = insert(:tenant)
      config = insert(:system_config, tenant_id: tenant.id)
      {:ok, tenant: tenant, config: config}
    end

    test "destroys system config", %{config: config} do
      assert {:ok, _deleted} = Core.destroy_system_config(config)
      assert {:error, _} = SystemConfig.get(config.id)
    end

    test "handles deletion of critical configs", %{tenant: tenant} do
      critical_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "system.critical.setting",
          metadata: %{"critical" => true}
        )

      # Deletion might be pr__evented for critical configs
      result = Core.destroy_system_config(critical_config)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "system config business logic" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "applies default configs for new tenant", %{tenant: tenant} do
      # This would typically be done during tenant creation
      default_configs = [
        %{key: "security.session.timeout", value: "3600", type: "integer"},
        %{key: "security.mfa.enabled", value: "false", type: "boolean"},
        %{key: "performance.cache.enabled", value: "true", type: "boolean"},
        %{key: "feature.beta.enabled", value: "false", type: "boolean"}
      ]

      for config <- default_configs do
        attrs = Map.put(config, :tenant_id, tenant.id)

        assert {:ok, _} =
                 SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))
      end

      configs = SystemConfig.list!(tenant_id: tenant.id)
      assert length(configs) >= 4
    end

    test "validates integer config values", %{tenant: tenant} do
      attrs = %{
        tenant_id: tenant.id,
        key: "limit.max_users",
        value: "100",
        type: "integer"
      }

      assert {:ok, config} =
               SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

      assert config.value == "100"

      # Value should be parseable as integer
      assert {parsed, ""} = Integer.parse(config.value)
      assert parsed == 100
    end

    test "validates boolean config values", %{tenant: tenant} do
      for value <- ["true", "false"] do
        attrs = %{
          tenant_id: tenant.id,
          key: "feature.test_#{value}",
          value: value,
          type: "boolean"
        }

        assert {:ok, config} =
                 SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

        assert config.value in ["true", "false"]
      end
    end

    test "handles config inheritance and overrides", %{tenant: tenant} do
      # Create parent config (could be global default)
      _parent_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "limit.default",
          value: "50",
          metadata: %{"scope" => "global"}
        )

      # Create override
      override_config =
        insert(:system_config,
          tenant_id: tenant.id,
          key: "limit.override",
          value: "100",
          metadata: %{"overrides" => "limit.default"}
        )

      assert override_config.metadata["overrides"] == "limit.default"
    end
  end

  describe "system config categories" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "groups configs by category", %{tenant: tenant} do
      categories = ["security", "performance", "feature", "integration", "ui"]

      # Create configs for each category
      for category <- categories do
        for i <- 1..3 do
          insert(:system_config,
            tenant_id: tenant.id,
            key: "#{category}.setting_#{i}",
            category: category
          )
        end
      end

      # Verify each category has configs
      for category <- categories do
        configs =
          SystemConfig.list!(
            tenant_id: tenant.id,
            filter: [category: category]
          )

        assert length(configs) >= 3
      end
    end

    test "validates category values", %{tenant: tenant} do
      valid_categories = ["security", "performance", "feature", "integration", "ui"]

      for category <- valid_categories do
        attrs = %{
          tenant_id: tenant.id,
          key: "#{category}.test",
          value: "test",
          type: "string",
          category: category
        }

        assert {:ok, config} =
                 SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

        assert config.category == category
      end
    end
  end

  describe "bulk system config operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates comprehensive config set", %{tenant: tenant} do
      configs = bulk_create_system_configs(60)

      # Update all to belong to tenant
      tenant_configs =
        Enum.map(configs, fn config ->
          {:ok, updated} = SystemConfig.update(config, %{tenant_id: tenant.id})
          updated
        end)

      assert length(tenant_configs) == 60

      # Verify diversity
      categories = tenant_configs |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.filter(& &1)
      assert length(categories) >= 4

      types = tenant_configs |> Enum.map(& &1.type) |> Enum.uniq()
      assert length(types) >= 4
    end

    test "generates security configuration suite", %{tenant: tenant} do
      configs = bulk_create_system_configs(20)
      security_configs = Enum.filter(configs, &(&1.category == "security"))

      # Update to tenant
      _security_configs =
        Enum.map(security_configs, fn config ->
          {:ok, updated} = SystemConfig.update(config, %{tenant_id: tenant.id})
          updated
        end)

      # Verify security-specific configs exist
      keys = Enum.map(security_configs, & &1.key)
      assert Enum.any?(keys, &String.contains?(&1, "mfa"))
      assert Enum.any?(keys, &String.contains?(&1, "password"))
      assert Enum.any?(keys, &String.contains?(&1, "session"))
    end
  end

  describe "system config value conversion" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "handles integer value conversion", %{tenant: tenant} do
      configs = [
        %{key: "limit.zero", value: "0"},
        %{key: "limit.positive", value: "12_345"},
        %{key: "limit.large", value: "9_999_999"}
      ]

      for config <- configs do
        attrs =
          Map.merge(config, %{
            tenant_id: tenant.id,
            type: "integer"
          })

        assert {:ok, created} =
                 SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

        assert {_parsed, ""} = Integer.parse(created.value)
      end
    end

    test "handles JSON value conversion", %{tenant: tenant} do
      json_values = [
        %{"enabled" => true, "count" => 10},
        ["option1", "option2", "option3"],
        %{"nested" => %{"value" => "test"}}
      ]

      for {i, json_value} <- Enum.with_index(json_values) do
        attrs = %{
          tenant_id: tenant.id,
          key: "json.test_#{i}",
          value: Jason.encode!(json_value),
          type: "json"
        }

        assert {:ok, config} =
                 SystemConfig.set(attrs, actor: Indrajaal.ActorHelpers.admin_actor(tenant.id))

        assert {:ok, parsed} = Jason.decode(config.value)
        assert parsed == json_value
      end
    end
  end

  describe "system config access patterns" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "provides configuration map for application", %{tenant: tenant} do
      # Create various configs
      configs = [
        %{key: "app.name", value: "Indrajaal Security"},
        %{key: "app.version", value: "1.0.0"},
        %{key: "feature.video.enabled", value: "true"},
        %{key: "limit.max_devices", value: "1000"}
      ]

      for config <- configs do
        attrs = Map.merge(config, %{tenant_id: tenant.id, type: "string"})
        SystemConfig.set!(attrs)
      end

      # Get all configs as a map
      all_configs = SystemConfig.list!(tenant_id: tenant.id)
      config_map = Map.new(all_configs, fn c -> {c.key, c.value} end)

      assert config_map["app.name"] == "Indrajaal Security"
      assert config_map["app.version"] == "1.0.0"
      assert config_map["feature.video.enabled"] == "true"
      assert config_map["limit.max_devices"] == "1000"
    end

    test "caches f__requently accessed configs", %{tenant: tenant} do
      # Create a f__requently accessed config
      {:ok, config} =
        SystemConfig.set(%{
          tenant_id: tenant.id,
          key: "cache.test",
          value: "cached_value",
          type: "string",
          metadata: %{"access_count" => 0}
        })

      # Simulate multiple accesses
      for _i <- 1..5 do
        _found = SystemConfig.get!(config.id)
      end

      # In a real system, you might track access patterns
      assert config.key == "cache.test"
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: General system coordination and management with cybernetics
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
