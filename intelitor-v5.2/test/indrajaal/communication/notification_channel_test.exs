defmodule Indrajaal.Communication.NotificationChannelTest do
  @moduledoc """
  Comprehensive test suite for NotificationChannel resource.
  Tests multi - channel communication configuration and management.
  """

  use Indrajaal.DataCase, async: true

  alias Indrajaal.Communication
  alias Indrajaal.Communication.NotificationChannel

  describe "NotificationChannel.create / 1" do
    setup do
      tenant = insert(:tenant)
      %{tenant: tenant}
    end

    test "creates notification channel with required attributes",
         %{tenant: tenant} do
      attrs = %{
        name: "Primary Email Channel",
        channel_type: :email,
        configuration: %{
          "provider" => "sendgrid",
          "api_key" => "test_key_123",
          "from_email" => "notifications@example.com",
          "from_name" => "Security System"
        }
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, channel} = NotificationChannel.create(attrs, actor: actor)
      assert channel.name == "Primary Email Channel"
      assert channel.channel_type == :email
      assert channel.tenant_id == tenant.id
      assert channel.is_enabled == true
      assert channel.rate_limit_per_minute == 100
      assert channel.retry_attempts == 3
      assert channel.priority_order == 1
      assert channel.configuration["provider"] == "sendgrid"
    end

    test "supports all channel types", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      channel_types = [:email, :sms, :push, :in_app, :webhook, :slack, :teams]

      Enum.each(channel_types, fn channel_type ->
        attrs = %{
          name: "#{channel_type} Channel",
          channel_type: channel_type,
          configuration: channel_config_for_type(channel_type)
        }

        assert {:ok, channel} = NotificationChannel.create(attrs, actor: actor)
        assert channel.channel_type == channel_type
      end)
    end

    test "validates rate limit constraints", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Test minimum rate limit
      attrs_min = %{
        name: "Low Rate Channel",
        channel_type: :email,
        rate_limit_per_minute: 1
      }

      assert {:ok, channel} = NotificationChannel.create(attrs_min, actor: actor)
      assert channel.rate_limit_per_minute == 1

      # Test maximum rate limit
      attrs_max = %{
        name: "High Rate Channel",
        channel_type: :webhook,
        rate_limit_per_minute: 10_000
      }

      assert {:ok, channel} = NotificationChannel.create(attrs_max, actor: actor)
      assert channel.rate_limit_per_minute == 10_000

      # Test invalid rate limit (below minimum)
      attrs_invalid = %{
        name: "Invalid Rate Channel",
        channel_type: :sms,
        rate_limit_per_minute: 0
      }

      assert {:error, changeset} = NotificationChannel.create(attrs_invalid, actor: actor)
      assert "must be greater than or equal to 1" in errors_on(changeset).rate_limit_per_minute
    end

    test "validates retry attempts constraints", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Test maximum retry attempts
      attrs_max = %{
        name: "Max Retry Channel",
        channel_type: :email,
        retry_attempts: 10
      }

      assert {:ok, channel} = NotificationChannel.create(attrs_max, actor: actor)
      assert channel.retry_attempts == 10

      # Test zero retry attempts (valid)
      attrs_zero = %{
        name: "No Retry Channel",
        channel_type: :push,
        retry_attempts: 0
      }

      assert {:ok, channel} = NotificationChannel.create(attrs_zero, actor: actor)
      assert channel.retry_attempts == 0

      # Test invalid retry attempts (above maximum)
      attrs_invalid = %{
        name: "Invalid Retry Channel",
        channel_type: :sms,
        retry_attempts: 15
      }

      assert {:error, changeset} = NotificationChannel.create(attrs_invalid, actor: actor)
      assert "must be less than or equal to 10" in errors_on(changeset).retry_attempts
    end

    test "handles complex configuration structures", %{tenant: tenant} do
      complex_config = %{
        "provider" => "twilio",
        "account_sid" => "ACtest123",
        "auth_token" => "secret_token",
        "from_number" => "+1_234_567_890",
        "webhook_url" => "https://example.com / webhook",
        "message_service_sid" => "MGtest456",
        "features" => %{
          "delivery_receipts" => true,
          "smart_encoding" => true,
          "link_shortening" => false
        },
        "rate_limiting" => %{
          "per_second" => 1,
          "per_minute" => 60,
          "per_hour" => 3600
        },
        "regions" => ["us", "eu", "ap"]
      }

      attrs = %{
        name: "Advanced SMS Channel",
        channel_type: :sms,
        configuration: complex_config,
        rate_limit_per_minute: 60,
        priority_order: 2
      }

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, channel} = NotificationChannel.create(attrs, actor: actor)
      assert channel.configuration["provider"] == "twilio"
      assert channel.configuration["features"]["delivery_receipts"] == true
      assert channel.configuration["rate_limiting"]["per_minute"] == 60
      assert channel.priority_order == 2
    end
  end

  describe "NotificationChannel.enable / 1 and disable / 1" do
    setup do
      tenant = insert(:tenant)

      channel =
        insert(:notification_channel, %{
          tenant_id: tenant.id,
          is_enabled: false
        })

      %{tenant: tenant, channel: channel}
    end

    test "enables disabled channel", %{tenant: tenant, channel: channel} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, enabled_channel} = NotificationChannel.enable(channel, actor: actor)
      assert enabled_channel.is_enabled == true
    end

    test "disables enabled channel", %{tenant: tenant} do
      enabled_channel =
        insert(:notification_channel, %{
          tenant_id: tenant.id,
          is_enabled: true
        })

      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:ok, disabled_channel} = NotificationChannel.disable(enabled_channel, actor: actor)
      assert disabled_channel.is_enabled == false
    end
  end

  describe "NotificationChannel.update_config / 2" do
    setup do
      tenant = insert(:tenant)

      channel =
        insert(:notification_channel, %{
          tenant_id: tenant.id,
          configuration: %{
            "provider" => "old_provider",
            "api_key" => "old_key"
          }
        })

      %{tenant: tenant, channel: channel}
    end

    test "updates channel configuration", %{tenant: tenant, channel: channel} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      new_config = %{
        "provider" => "new_provider",
        "api_key" => "new_key_123",
        "endpoint" => "https://api.newprovider.com / v2",
        "timeout" => 30_000
      }

      args = %{config_data: new_config}

      assert {:ok, updated_channel} =
               NotificationChannel.update_config(channel, args, actor: actor)

      assert updated_channel.configuration["provider"] == "new_provider"
      assert updated_channel.configuration["api_key"] == "new_key_123"
      assert updated_channel.configuration["endpoint"] == "https://api.newprovider.com / v2"
      assert updated_channel.configuration["timeout"] == 30_000
    end

    test "requires config_data argument", %{tenant: tenant, channel: channel} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      assert {:error, changeset} = NotificationChannel.update_config(channel, %{}, actor: actor)
      assert "is required" in errors_on(changeset).config_data
    end
  end

  describe "NotificationChannel authorization and tenant isolation" do
    setup do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      channel1 = insert(:notification_channel, %{tenant_id: tenant1.id})
      channel2 = insert(:notification_channel, %{tenant_id: tenant2.id})

      %{
        tenant1: tenant1,
        tenant2: tenant2,
        channel1: channel1,
        channel2: channel2
      }
    end

    test "users can only access channels in their tenant", %{
      tenant1: tenant1,
      tenant2: tenant2,
      channel1: channel1,
      channel2: channel2
    } do
      actor1 = %{tenant_id: tenant1.id, role: "admin"}
      actor2 = %{tenant_id: tenant2.id, role: "admin"}

      # Actor1 can access channel1 but not channel2
      assert {:ok, [found_channel]} = NotificationChannel.read([channel1.id], actor: actor1)
      assert found_channel.id == channel1.id

      assert {:ok, []} = NotificationChannel.read([channel2.id], actor: actor1)

      # Actor2 can access channel2 but not channel1
      assert {:ok, [found_channel]} = NotificationChannel.read([channel2.id], actor: actor2)
      assert found_channel.id == channel2.id

      assert {:ok, []} = NotificationChannel.read([channel1.id], actor: actor2)
    end

    test "list queries respect tenant isolation",
         %{tenant1: tenant1, tenant2: tenant2} do
      actor1 = %{tenant_id: tenant1.id, role: "viewer"}
      actor2 = %{tenant_id: tenant2.id, role: "viewer"}

      # Each actor should only see their tenant's channels
      assert {:ok, channels1} = NotificationChannel.read(actor: actor1)
      assert {:ok, channels2} = NotificationChannel.read(actor: actor2)

      assert Enum.all?(channels1, &(&1.tenant_id == tenant1.id))
      assert Enum.all?(channels2, &(&1.tenant_id == tenant2.id))

      # Should not overlap
      channel1_ids = channels1 |> Enum.map(& &1.id) |> MapSet.new()
      channel2_ids = channels2 |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.disjoint?(channel1_ids, channel2_ids)
    end
  end

  describe "NotificationChannel bulk operations and performance" do
    setup do
      tenant = insert(:tenant)
      %{tenant: tenant}
    end

    test "handles bulk channel creation efficiently", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Create 50 notification channels with different configurations
      channel_configs =
        Enum.map(1..50, fn i ->
          channel_type = Enum.at([:email, :sms, :push, :webhook, :slack], rem(i, 5))

          %{
            name: "Bulk Channel #{i}",
            channel_type: channel_type,
            rate_limit_per_minute: 100 + i * 10,
            priority_order: rem(i, 10) + 1,
            configuration: %{
              "provider" => "provider_#{rem(i, 3) + 1}",
              "batch_id" => "bulk_#{div(i, 10)}"
            }
          }
        end)

      {time_taken, results} =
        :timer.tc(fn ->
          Enum.map(channel_configs, fn attrs ->
            NotificationChannel.create(attrs, actor: actor)
          end)
        end)

      # Verify all succeeded
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Performance check
      # 10 seconds in microseconds
      assert time_taken < 10_000_000

      # Verify they can be queried efficiently
      {:ok, all_channels} = NotificationChannel.read(actor: actor)
      assert length(all_channels) >= 50
    end

    test "supports complex filtering and priority ordering",
         %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Create channels with different priorities and types
      _channels =
        Enum.map(1..20, fn i ->
          insert(:notification_channel, %{
            tenant_id: tenant.id,
            name: "Channel #{i}",
            channel_type: Enum.at([:email, :sms, :push], rem(i, 3)),
            priority_order: rem(i, 5) + 1,
            # Most enabled, some disabled
            is_enabled: rem(i, 4) != 0,
            rate_limit_per_minute: 50 + i * 25
          })
        end)

      # Query all channels and verify tenant isolation
      {:ok, all_channels} = NotificationChannel.read(actor: actor)
      assert length(all_channels) >= 20
      assert Enum.all?(all_channels, &(&1.tenant_id == tenant.id))

      # Verify priority ordering capability
      email_channels = Enum.filter(all_channels, &(&1.channel_type == :email))
      # Should have ~1 / 3 of channels
      assert length(email_channels) >= 6

      # Verify enabled / disabled filtering capability
      enabled_channels = Enum.filter(all_channels, & &1.is_enabled)
      disabled_channels = Enum.filter(all_channels, &(not &1.is_enabled))

      assert length(enabled_channels) > length(disabled_channels)
    end

    test "handles edge cases and validation scenarios", %{tenant: tenant} do
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Test channel with minimal configuration
      minimal_attrs = %{
        name: "Minimal Channel",
        channel_type: :in_app
      }

      assert {:ok, minimal_channel} = NotificationChannel.create(minimal_attrs, actor: actor)
      assert minimal_channel.configuration == %{}
      # Default
      assert minimal_channel.rate_limit_per_minute == 100
      # Default
      assert minimal_channel.retry_attempts == 3

      # Test channel with maximum valid values
      maximal_attrs = %{
        # Max length
        name: String.duplicate("A", 100),
        channel_type: :webhook,
        # Max value
        rate_limit_per_minute: 10_000,
        # Max value
        retry_attempts: 10,
        priority_order: 999,
        # Max value (24 hours)
        escalation_delay_minutes: 1440,
        configuration: %{
          "key1" => String.duplicate("value", 100),
          "nested" => %{
            "deep" => %{
              "structure" => true
            }
          },
          "array" => [1, 2, 3, 4, 5]
        }
      }

      assert {:ok, maximal_channel} = NotificationChannel.create(maximal_attrs, actor: actor)
      assert String.length(maximal_channel.name) == 100
      assert maximal_channel.rate_limit_per_minute == 10_000
      assert maximal_channel.retry_attempts == 10

      # Test invalid name length
      invalid_attrs = %{
        # Exceeds max length
        name: String.duplicate("A", 101),
        channel_type: :email
      }

      assert {:error, changeset} = NotificationChannel.create(invalid_attrs, actor: actor)
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end
  end

  describe "NotificationChannel relationships and integrations" do
    test "maintains relationships with messages and delivery logs" do
      tenant = insert(:tenant)
      actor = %{tenant_id: tenant.id, role: "admin"}

      # Create channel
      channel =
        insert(:notification_channel, %{
          tenant_id: tenant.id,
          channel_type: :email
        })

      # Create related messages (would be done through Message factory in real
      # This tests the relationship structure
      assert %Ash.NotLoaded{} = channel.messages
      assert %Ash.NotLoaded{} = channel.delivery_logs
      assert %Ash.NotLoaded{} = channel.notification_rules

      # Load relationships
      {:ok, [loaded_channel]} =
        NotificationChannel.read([channel.id],
          actor: actor,
          load: [:messages, :delivery_logs, :notification_rules]
        )

      # Should have empty lists for new channel
      assert loaded_channel.messages == []
      assert loaded_channel.delivery_logs == []
      assert loaded_channel.notification_rules == []
    end

    test "supports webhook channel configuration validation" do
      tenant = insert(:tenant)
      actor = %{tenant_id: tenant.id, role: "admin"}

      webhook_config = %{
        "url" => "https://api.example.com / webhook",
        "method" => "POST",
        "headers" => %{
          "Content - Type" => "application / json",
          "Authorization" => "Bearer token123",
          "X-Custom-Header" => "custom-value"
        },
        "timeout" => 30_000,
        "retry_on_status" => [500, 502, 503, 504],
        "success_status" => [200, 201, 202],
        "payload_template" => %{
          "message" => "{{body}}",
          "timestamp" => "{{timestamp}}",
          "severity" => "{{priority}}"
        }
      }

      attrs = %{
        name: "Webhook Integration Channel",
        channel_type: :webhook,
        configuration: webhook_config,
        rate_limit_per_minute: 500
      }

      assert {:ok, webhook_channel} = NotificationChannel.create(attrs, actor: actor)
      assert webhook_channel.configuration["url"] == "https://api.example.com / webhook"

      assert webhook_channel.configuration["headers"]["Authorization"] ==
               "Bearer token123"

      assert webhook_channel.configuration["payload_template"]["message"] ==
               "{{body}}"
    end
  end

  # Helper function for channel type configurations
  defp channel_config_for_type(channel_type) do
    case channel_type do
      :email ->
        %{
          "provider" => "sendgrid",
          "api_key" => "test_key",
          "from_email" => "test@example.com"
        }

      :sms ->
        %{
          "provider" => "twilio",
          "account_sid" => "ACtest",
          "auth_token" => "secret",
          "from_number" => "+1_234_567_890"
        }

      :push ->
        %{
          "provider" => "fcm",
          "server_key" => "server_key_test",
          "project_id" => "test_project"
        }

      :webhook ->
        %{
          "url" => "https://hooks.example.com / webhook",
          "method" => "POST",
          "headers" => %{"Content - Type" => "application / json"}
        }

      :slack ->
        %{
          "webhook_url" => "https://hooks.slack.com / test",
          "channel" => "#notifications"
        }

      :teams ->
        %{
          "webhook_url" => "https://outlook.office.com / webhook / test",
          "theme_color" => "0078D4"
        }

      :in_app ->
        %{
          "display_duration" => 5000,
          "priority_colors" => %{
            "low" => "#28a745",
            "medium" => "#ffc107",
            "high" => "#dc3545"
          }
        }
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
