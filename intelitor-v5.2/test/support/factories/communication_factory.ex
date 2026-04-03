defmodule Indrajaal.CommunicationFactory do
  @moduledoc """
  Comprehensive factory definitions for Communication domain with 50+ items
    per resource.
  Implements enterprise testing standards for multi-channel messaging system.
  """

  defmacro __using__(_) do
    quote do
      alias Faker
      alias Indrajaal.Shared.TestSupport

      import Indrajaal.Test.SharedFactoryUtilities,
        only: [normalize_attrs: 1, handle_tenant_association: 2]

      # Note: sequence/2 and merge_attributes/2 are provided by ExMachina
      # Do not redefine them here to avoid conflicts

      # ===== NOTIFICATION CHANNEL FACTORY =====
      @spec notification_channel_factory(map()) :: any()
      def notification_channel_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        unique_id = System.unique_integer([:positive, :monotonic])
        channel_types = [:email, :sms, :push, :in_app, :webhook, :slack, :teams]

        channel_attrs =
          %{
            name: "Notification Channel #{unique_id}",
            channel_type: Enum.random(channel_types),
            is_enabled: true,
            configuration: %{},
            rate_limit_per_minute: 100,
            retry_attempts: 3,
            priority_order: 1,
            escalation_delay_minutes: 5
          }
          |> Map.merge(attrs_map)
          |> Map.delete(:tenant)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.Communication.NotificationChannel,
               channel_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, channel} ->
            channel

          {:error, changeset} ->
            raise "Failed to create notification channel: #{inspect(changeset)}"
        end
      end

      @spec bulk_create_notification_channels(any()) :: any()
      def bulk_create_notification_channels(count) do
        tenant = insert(:tenant)

        Enum.map(1..count, fn i ->
          insert(:notification_channel, %{
            tenant_id: tenant.id,
            name: "Bulk Channel #{i}",
            channel_type: Enum.at([:email, :sms, :push, :webhook, :slack], rem(i, 5))
          })
        end)
      end

      # ===== MESSAGE TEMPLATE FACTORY =====
      @spec message_template_factory() :: any()
      def message_template_factory do
        %{
          name: sequence(:template_name, &message_template_name/1),
          template_type: random_template_type(),
          subject: template_subject(),
          body: template_body(),
          variables: template_variables(),
          supported_channels: supported_channels_list(),
          is_active: Enum.random([true, false]),
          version: sequence(:template_version, &"v#{&1}.0"),
          locale: Enum.random(["en", "es", "fr", "de", "ja", "zh"]),
          category: template_category(),
          priority: Enum.random([:low, :normal, :high, :urgent]),
          approval_required: Enum.random([true, false]),
          content_type: Enum.random([:plain_text, :html, :markdown, :rich_text]),
          attachments_allowed: Enum.random([true, false]),
          personalization_level: Enum.random([:none, :basic, :advanced, :dynamic]),
          a_b_test_enabled: Enum.random([true, false]),
          compliance_checked: Enum.random([true, false]),
          last_used: random_last_used_time(),
          usage_count: Enum.random(0..10_000),
          metadata: message_template_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== MESSAGE FACTORY =====
      @spec message_factory() :: any()
      def message_factory do
        %{
          message_type: random_message_type(),
          subject: message_subject(),
          body: message_body(),
          recipient_email: Faker.Internet.email(),
          recipient_phone: random_phone_number(),
          recipient_user_id: fn -> Faker.UUID.v4() end,
          channel_type: random_channel_type(),
          priority: message_priority(),
          status: message_status(),
          scheduled_at: random_scheduled_time(),
          sent_at: random_sent_time(),
          delivered_at: random_delivered_time(),
          read_at: random_read_time(),
          variables: message_variables(),
          attachments: message_attachments(),
          delivery_attempts: Enum.random(1..5),
          last_error: random_error_message(),
          tracking_id: fn -> "msg_#{System.unique_integer([:positive])}" end,
          campaign_id: fn -> Faker.UUID.v4() end,
          correlation_id: fn -> Faker.UUID.v4() end,
          expires_at: random_expiry_time(),
          metadata: message_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          template_id: fn -> build(:message_template).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== NOTIFICATION RULE FACTORY =====
      @spec notification_rule_factory() :: any()
      def notification_rule_factory do
        %{
          name: sequence(:rule_name, &notification_rule_name/1),
          rule_type: random_rule_type(),
          event_types: notification_event_types(),
          conditions: notification_conditions(),
          actions: notification_actions(),
          recipients: notification_recipients(),
          channels: notification_channels(),
          is_active: Enum.random([true, false]),
          priority: Enum.random([:low, :medium, :high, :critical]),
          throttle_window: Enum.random([nil, 300, 900, 1800, 3600]),
          max_frequency: Enum.random([nil, 1, 5, 10, 50]),
          schedule: notification_schedule(),
          escalation_rules: notification_escalation_rules(),
          suppression_rules: suppression_rules(),
          template_mapping: template_mapping(),
          delivery_options: delivery_options(),
          success_criteria: success_criteria(),
          failure_handling: failure_handling_config(),
          audit_trail: Enum.random([true, false]),
          last_triggered: random_last_triggered(),
          trigger_count: Enum.random(0..1000),
          success_rate: Decimal.new(to_string(Enum.random(80..99)) <> ".2"),
          metadata: notification_rule_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== DELIVERY LOG FACTORY =====
      @spec delivery_log_factory() :: any()
      def delivery_log_factory do
        %{
          delivery_id: fn -> "del_#{System.unique_integer([:positive])}" end,
          channel_type: random_channel_type(),
          recipient: delivery_recipient(),
          status: delivery_status(),
          attempt_number: Enum.random(1..5),
          sent_at: random_delivery_sent_time(),
          delivered_at: random_delivery_delivered_time(),
          response_time: Enum.random(50..5000),
          provider_response: provider_response(),
          error_code: random_error_code(),
          error_message: random_error_description(),
          cost: random_delivery_cost(),
          tracking_data: tracking_data(),
          webhook_payload: webhook_payload(),
          retry_scheduled_at: random_retry_time(),
          final_status: final_delivery_status(),
          delivery_window: delivery_window_info(),
          geolocation: delivery_geolocation(),
          device_info: delivery_device_info(),
          user_agent: delivery_user_agent(),
          ip_address: Faker.Internet.ip_v4_address(),
          metadata: delivery_log_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          message_id: fn -> build(:message).id end,
          channel_id: fn -> build(:notification_channel).id end
        }
      end

      # ===== CONTACT GROUP FACTORY =====
      @spec contact_group_factory() :: any()
      def contact_group_factory do
        %{
          name: sequence(:group_name, &contact_group_name/1),
          description: contact_group_description(),
          group_type: random_group_type(),
          members: contact_group_members(),
          dynamic_rules: dynamic_group_rules(),
          is_active: Enum.random([true, false]),
          sync_frequency: Enum.random([:manual, :hourly, :daily, :weekly]),
          last_sync: random_last_sync_time(),
          member_count: Enum.random(1..500),
          tags: contact_group_tags(),
          permissions: contact_group_permissions(),
          notification_preferences: group_notification_preferences(),
          escalation_hierarchy: escalation_hierarchy(),
          on_call_schedule: on_call_schedule(),
          time_zone: Enum.random(["UTC", "America/New_York", "Europe/London", "Asia/Tokyo"]),
          external_sync: external_sync_config(),
          compliance_notes: compliance_notes(),
          metadata: contact_group_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== CONTACT PREFERENCE FACTORY =====
      @spec contact_preference_factory() :: any()
      def contact_preference_factory do
        %{
          user_id: fn -> Faker.UUID.v4() end,
          channel_preferences: channel_preferences(),
          delivery_windows: preference_delivery_windows(),
          frequency_limits: frequency_limits(),
          content_preferences: content_preferences(),
          language: Enum.random(["en", "es", "fr", "de", "ja", "zh"]),
          timezone: Enum.random(["UTC", "America/New_York", "Europe/London", "Asia/Tokyo"]),
          do_not_disturb: do_not_disturb_config(),
          emergency_override: Enum.random([true, false]),
          opt_out_categories: opt_out_categories(),
          subscription_status: subscription_status(),
          verification_status: verification_status(),
          gdpr_consent: gdpr_consent_status(),
          data_retention: data_retention_preference(),
          last_updated: random_preference_update(),
          sync_with_profile: Enum.random([true, false]),
          metadata: contact_preference_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== BROADCAST CAMPAIGN FACTORY =====
      @spec broadcast_campaign_factory() :: any()
      def broadcast_campaign_factory do
        campaign_basic_attrs()
        |> Map.merge(campaign_schedule_attrs())
        |> Map.merge(campaign_statistics())
        |> Map.merge(campaign_rate_metrics())
        |> Map.merge(campaign_cost_attrs())
        |> Map.merge(campaign_settings_attrs())
        |> Map.merge(campaign_identifiers())
      end

      @spec campaign_basic_attrs() :: map()
      defp campaign_basic_attrs do
        %{
          name: sequence(:campaign_name, &broadcast_campaign_name/1),
          campaign_type: random_campaign_type(),
          description: campaign_description(),
          target_audience: target_audience_config(),
          channels: campaign_channels(),
          template_mapping: campaign_template_mapping(),
          metadata: broadcast_campaign_metadata()
        }
      end

      @spec campaign_schedule_attrs() :: map()
      defp campaign_schedule_attrs do
        %{
          schedule: campaign_schedule(),
          status: campaign_status(),
          start_time: random_campaign_start(),
          end_time: random_campaign_end()
        }
      end

      @spec campaign_statistics() :: map()
      defp campaign_statistics do
        %{
          total_recipients: Enum.random(100..10_000),
          messages_sent: Enum.random(0..10_000),
          delivered_count: Enum.random(0..9500),
          failed_count: Enum.random(0..500),
          opened_count: Enum.random(0..8000),
          clicked_count: Enum.random(0..3000),
          unsubscribed_count: Enum.random(0..100)
        }
      end

      @spec campaign_rate_metrics() :: map()
      defp campaign_rate_metrics do
        %{
          delivery_rate: campaign_decimal_metric(85, 99, ".1"),
          open_rate: campaign_decimal_metric(15, 45, ".2"),
          click_rate: campaign_decimal_metric(2, 15, ".3")
        }
      end

      @spec campaign_decimal_metric(integer(), integer(), String.t()) :: Decimal.t()
      defp campaign_decimal_metric(min, max, suffix) do
        Decimal.new(to_string(Enum.random(min..max)) <> suffix)
      end

      @spec campaign_cost_attrs() :: map()
      defp campaign_cost_attrs do
        %{
          cost_total: random_campaign_cost(),
          cost_per_recipient: random_cost_per_recipient()
        }
      end

      @spec campaign_settings_attrs() :: map()
      defp campaign_settings_attrs do
        %{
          a_b_test_config: a_b_test_config(),
          personalization_level: Enum.random([:none, :basic, :advanced, :dynamic]),
          compliance_check: Enum.random([true, false]),
          approval_status: approval_status(),
          approved_by: fn -> Faker.UUID.v4() end,
          approved_at: random_approval_time()
        }
      end

      @spec campaign_identifiers() :: map()
      defp campaign_identifiers do
        %{
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== MESSAGE QUEUE FACTORY =====
      @spec message_queue_factory() :: any()
      def message_queue_factory do
        %{
          queue_name: sequence(:queue_name, &message_queue_name/1),
          queue_type: random_queue_type(),
          priority: queue_priority(),
          status: queue_status(),
          max_size: Enum.random([1000, 5000, 10_000, 50_000]),
          current_size: Enum.random(0..1000),
          processing_rate: Enum.random(10..1000),
          retry_policy: queue_retry_policy(),
          dead_letter_queue: dead_letter_config(),
          batch_size: Enum.random([1, 10, 50, 100]),
          visibility_timeout: Enum.random([30, 60, 300, 600]),
          message_retention: Enum.random([86_400, 604_800, 1_209_600]),
          encryption_enabled: Enum.random([true, false]),
          compression_enabled: Enum.random([true, false]),
          fifo_enabled: Enum.random([true, false]),
          deduplication_enabled: Enum.random([true, false]),
          monitoring_config: queue_monitoring_config(),
          auto_scaling: auto_scaling_config(),
          health_check: queue_health_check(),
          metrics: queue_metrics(),
          alerts: queue_alerts_config(),
          last_processed: random_last_processed(),
          created_at: random_queue_created(),
          metadata: message_queue_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      unquote(communication_factory_part_2())
    end
  end

  defp communication_factory_part_2 do
    quote do
      alias Faker

      # ===== HELPER FUNCTIONS =====

      @spec random_channel_type() :: any()
      defp random_channel_type do
        Enum.random([:email, :sms, :push, :webhook, :slack, :teams, :phone])
      end

      @spec notification_channel_name(term()) :: term()
      defp notification_channel_name(i) do
        types = ["Email", "SMS", "Push", "Webhook", "Slack", "Teams", "Phone"]
        providers = ["Primary", "Backup", "Emergency", "Test", "Fallback"]

        type = Enum.at(types, rem(i, length(types)))
        provider = Enum.at(providers, rem(div(i, length(types)), length(providers)))

        "#{type} #{provider} Channel #{i}"
      end

      @spec channel_provider_for_type() :: any()
      defp channel_provider_for_type do
        %{
          email: ["sendgrid", "mailgun", "ses", "postmark"],
          sms: ["twilio", "nexmo", "messagebird", "aws_sns"],
          push: ["fcm", "apns", "web_push", "onesignal"],
          webhook: ["custom", "zapier", "ifttt", "microsoft_flow"],
          slack: ["slack_api", "slack_webhook"],
          teams: ["teams_api", "teams_webhook"],
          phone: ["twilio_voice", "aws_connect", "plivo"]
        }
        |> Map.get(Enum.random([:email, :sms, :push, :webhook, :slack, :teams, :phone]))
        |> Enum.random()
      end

      @spec channel_configuration() :: any()
      defp channel_configuration do
        %{
          "api_key" => "test_key_#{:rand.uniform(999_999)}",
          "endpoint" => "https://api.example.com/v1/send",
          "timeout" => Enum.random([5000, 10_000, 30_000]),
          "max_retries" => Enum.random([3, 5, 10]),
          "batch_size" => Enum.random([1, 10, 100]),
          "rate_limit_per_minute" => Enum.random([60, 300, 1000]),
          "encryption" => Enum.random([true, false]),
          "compression" => Enum.random([true, false])
        }
      end

      @spec retry_policy_config() :: any()
      defp retry_policy_config do
        %{
          "max_attempts" => Enum.random([3, 5, 10]),
          "initial_delay" => Enum.random([1000, 5000, 10_000]),
          "max_delay" => Enum.random([300_000, 600_000, 1_800_000]),
          "backoff_multiplier" => Enum.random([1.5, 2.0, 3.0]),
          "jitter" => Enum.random([true, false])
        }
      end

      @spec random_cost_per_message() :: any()
      defp random_cost_per_message do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(100) / 1000))
        else
          nil
        end
      end

      @spec notification_channel_metadata() :: any()
      defp notification_channel_metadata do
        %{
          "region" => Enum.random(["us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1"]),
          "compliance" => Enum.random(["gdpr", "hipaa", "sox", "pci"]),
          "sla_tier" => Enum.random(["basic", "standard", "premium", "enterprise"]),
          "monitoring_enabled" => Enum.random([true, false])
        }
      end

      # ===== MISSING HELPER FUNCTIONS =====

      @spec broadcast_campaign_metadata() :: map()
      defp broadcast_campaign_metadata do
        %{
          "source" => Enum.random(["internal", "external", "automated", "manual"]),
          "created_by" => Faker.Person.name(),
          "department" => Enum.random(["marketing", "operations", "security", "hr"]),
          "budget_code" => "BUD-#{:rand.uniform(99_999)}",
          "tracking_enabled" => Enum.random([true, false])
        }
      end

      @spec random_approval_time() :: DateTime.t() | nil
      defp random_approval_time do
        if Enum.random([true, false]) do
          DateTime.utc_now()
          |> DateTime.add(-:rand.uniform(86_400 * 30), :second)
        else
          nil
        end
      end

      @spec approval_status() :: atom()
      defp approval_status do
        Enum.random([:pending, :approved, :rejected, :expired, :cancelled])
      end

      @spec a_b_test_config() :: map() | nil
      defp a_b_test_config do
        if Enum.random([true, false]) do
          %{
            "enabled" => true,
            "variants" => [
              %{"id" => "A", "weight" => 50, "subject" => "Variant A Subject"},
              %{"id" => "B", "weight" => 50, "subject" => "Variant B Subject"}
            ],
            "winner_criteria" => Enum.random(["open_rate", "click_rate", "conversion"]),
            "test_duration_hours" => Enum.random([24, 48, 72])
          }
        else
          nil
        end
      end

      @spec random_cost_per_recipient() :: Decimal.t() | nil
      defp random_cost_per_recipient do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(50) / 1000))
        else
          nil
        end
      end

      # ===== ADDITIONAL MESSAGE TEMPLATE HELPERS =====

      @spec message_template_name(integer()) :: String.t()
      defp message_template_name(i) do
        types = ["Welcome", "Alert", "Reminder", "Confirmation", "Report", "Update"]
        "#{Enum.random(types)} Template #{i}"
      end

      @spec random_template_type() :: atom()
      defp random_template_type do
        Enum.random([:notification, :alert, :report, :marketing, :transactional])
      end

      @spec template_subject() :: String.t()
      defp template_subject do
        Faker.Lorem.sentence(3..8)
      end

      @spec template_body() :: String.t()
      defp template_body do
        paragraphs = Faker.Lorem.paragraphs(1..3)
        Enum.join(paragraphs, "\n\n")
      end

      @spec template_variables() :: list()
      defp template_variables do
        Enum.take_random(
          ["user_name", "site_name", "alarm_type", "timestamp", "priority"],
          :rand.uniform(3)
        )
      end

      @spec supported_channels_list() :: list()
      defp supported_channels_list do
        Enum.take_random([:email, :sms, :push, :webhook, :slack], :rand.uniform(3) + 1)
      end

      @spec template_category() :: atom()
      defp template_category do
        Enum.random([:security, :operational, :marketing, :system, :compliance])
      end

      @spec random_last_used_time() :: DateTime.t() | nil
      defp random_last_used_time do
        if Enum.random([true, false, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400 * 90), :second)
        else
          nil
        end
      end

      @spec message_template_metadata() :: map()
      defp message_template_metadata do
        %{
          "author" => Faker.Person.name(),
          "version_notes" => Faker.Lorem.sentence(5..10),
          "review_status" => Enum.random(["draft", "reviewed", "approved"])
        }
      end

      # ===== MESSAGE HELPERS =====

      @spec random_message_type() :: atom()
      defp random_message_type do
        Enum.random([:notification, :alert, :reminder, :confirmation, :broadcast])
      end

      @spec message_subject() :: String.t()
      defp message_subject do
        Faker.Lorem.sentence(3..6)
      end

      @spec message_body() :: String.t()
      defp message_body do
        Faker.Lorem.paragraph(2..5)
      end

      @spec random_phone_number() :: String.t()
      defp random_phone_number do
        number = :rand.uniform(9_999_999_999)
        formatted = number |> Integer.to_string() |> String.pad_leading(10, "0")
        "+1#{formatted}"
      end

      @spec message_priority() :: atom()
      defp message_priority do
        Enum.random([:low, :normal, :high, :urgent, :critical])
      end

      @spec message_status() :: atom()
      defp message_status do
        Enum.random([:pending, :queued, :sending, :sent, :delivered, :failed, :bounced])
      end

      @spec random_scheduled_time() :: DateTime.t() | nil
      defp random_scheduled_time do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(:rand.uniform(86_400 * 7), :second)
        else
          nil
        end
      end

      @spec random_sent_time() :: DateTime.t() | nil
      defp random_sent_time do
        if Enum.random([true, false, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400), :second)
        else
          nil
        end
      end

      @spec random_delivered_time() :: DateTime.t() | nil
      defp random_delivered_time do
        if Enum.random([true, false, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(43_200), :second)
        else
          nil
        end
      end

      @spec random_read_time() :: DateTime.t() | nil
      defp random_read_time do
        if Enum.random([true, false, false, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(21_600), :second)
        else
          nil
        end
      end

      @spec message_variables() :: map()
      defp message_variables do
        %{
          "user_name" => Faker.Person.name(),
          "site_name" => Faker.Company.name(),
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      end

      @spec message_attachments() :: list()
      defp message_attachments do
        if Enum.random([true, false, false]) do
          [%{"filename" => "report.pdf", "size" => :rand.uniform(1_000_000)}]
        else
          []
        end
      end

      @spec random_error_message() :: String.t() | nil
      defp random_error_message do
        if Enum.random([true, false, false, false]) do
          Enum.random([
            "Connection timeout",
            "Invalid recipient",
            "Rate limit exceeded",
            "Server unavailable"
          ])
        else
          nil
        end
      end

      @spec random_expiry_time() :: DateTime.t() | nil
      defp random_expiry_time do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(:rand.uniform(86_400 * 30), :second)
        else
          nil
        end
      end

      @spec message_metadata() :: map()
      defp message_metadata do
        %{
          "source" => Enum.random(["api", "web", "mobile", "system"]),
          "ip_address" => Faker.Internet.ip_v4_address(),
          "user_agent" =>
            Enum.random([
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
              "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)",
              "Mozilla/5.0 (Linux; Android 13)"
            ])
        }
      end

      # ===== NOTIFICATION RULE HELPERS =====

      @spec notification_rule_name(integer()) :: String.t()
      defp notification_rule_name(i) do
        types = ["Security", "System", "Maintenance", "Alert", "Escalation"]
        "#{Enum.random(types)} Rule #{i}"
      end

      @spec random_rule_type() :: atom()
      defp random_rule_type do
        Enum.random([:event_based, :scheduled, :threshold, :composite, :pattern])
      end

      @spec notification_event_types() :: list()
      defp notification_event_types do
        Enum.take_random([:alarm, :access, :device, :system, :user], :rand.uniform(3) + 1)
      end

      @spec notification_conditions() :: map()
      defp notification_conditions do
        %{
          "operator" => Enum.random(["and", "or"]),
          "conditions" => [
            %{"field" => "priority", "op" => ">=", "value" => "high"}
          ]
        }
      end

      @spec notification_actions() :: list()
      defp notification_actions do
        [%{"type" => "send_notification", "channel" => Enum.random([:email, :sms, :push])}]
      end

      @spec notification_recipients() :: list()
      defp notification_recipients do
        [%{"type" => "user", "id" => Faker.UUID.v4()}]
      end

      @spec notification_channels() :: list()
      defp notification_channels do
        Enum.take_random([:email, :sms, :push, :webhook], :rand.uniform(2) + 1)
      end

      @spec notification_schedule() :: map() | nil
      defp notification_schedule do
        if Enum.random([true, false]) do
          %{"type" => "cron", "expression" => "0 9 * * *", "timezone" => "UTC"}
        else
          nil
        end
      end

      @spec notification_escalation_rules() :: list()
      defp notification_escalation_rules do
        [%{"delay_minutes" => 15, "action" => "escalate_to_manager"}]
      end

      @spec suppression_rules() :: map()
      defp suppression_rules do
        %{"duplicate_window_seconds" => 300, "max_per_hour" => 10}
      end

      @spec template_mapping() :: map()
      defp template_mapping do
        %{"default" => "template_001", "high_priority" => "template_002"}
      end

      @spec delivery_options() :: map()
      defp delivery_options do
        %{"retry_enabled" => true, "max_retries" => 3}
      end

      @spec success_criteria() :: map()
      defp success_criteria do
        %{"type" => "delivery_confirmed", "timeout_seconds" => 300}
      end

      @spec failure_handling_config() :: map()
      defp failure_handling_config do
        %{"fallback_channel" => :email, "alert_on_failure" => true}
      end

      @spec random_last_triggered() :: DateTime.t() | nil
      defp random_last_triggered do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400 * 7), :second)
        else
          nil
        end
      end

      @spec notification_rule_metadata() :: map()
      defp notification_rule_metadata do
        %{"owner" => Faker.Person.name(), "department" => Enum.random(["security", "ops"])}
      end

      # ===== DELIVERY LOG HELPERS =====

      @spec delivery_recipient() :: map()
      defp delivery_recipient do
        %{"email" => Faker.Internet.email(), "name" => Faker.Person.name()}
      end

      @spec delivery_status() :: atom()
      defp delivery_status do
        Enum.random([:pending, :sent, :delivered, :failed, :bounced, :rejected])
      end

      @spec random_delivery_sent_time() :: DateTime.t()
      defp random_delivery_sent_time do
        DateTime.utc_now() |> DateTime.add(-:rand.uniform(3600), :second)
      end

      @spec random_delivery_delivered_time() :: DateTime.t() | nil
      defp random_delivery_delivered_time do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(1800), :second)
        else
          nil
        end
      end

      @spec provider_response() :: map()
      defp provider_response do
        %{"status" => "accepted", "message_id" => "msg_#{:rand.uniform(999_999)}"}
      end

      @spec random_error_code() :: String.t() | nil
      defp random_error_code do
        if Enum.random([true, false, false, false]) do
          Enum.random(["ERR001", "ERR002", "TIMEOUT", "INVALID"])
        else
          nil
        end
      end

      @spec random_error_description() :: String.t() | nil
      defp random_error_description do
        if Enum.random([true, false, false, false]) do
          Enum.random(["Connection failed", "Invalid address", "Rate limited"])
        else
          nil
        end
      end

      @spec random_delivery_cost() :: Decimal.t() | nil
      defp random_delivery_cost do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(100) / 1000))
        else
          nil
        end
      end

      @spec tracking_data() :: map()
      defp tracking_data do
        %{"opens" => :rand.uniform(10), "clicks" => :rand.uniform(5)}
      end

      @spec webhook_payload() :: map() | nil
      defp webhook_payload do
        if Enum.random([true, false, false]) do
          %{"event" => "delivery", "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()}
        else
          nil
        end
      end

      @spec random_retry_time() :: DateTime.t() | nil
      defp random_retry_time do
        if Enum.random([true, false, false, false]) do
          DateTime.utc_now() |> DateTime.add(:rand.uniform(3600), :second)
        else
          nil
        end
      end

      @spec final_delivery_status() :: atom()
      defp final_delivery_status do
        Enum.random([:delivered, :failed, :bounced, :pending])
      end

      @spec delivery_window_info() :: map()
      defp delivery_window_info do
        %{"start" => "09:00", "end" => "18:00", "timezone" => "UTC"}
      end

      @spec delivery_geolocation() :: map() | nil
      defp delivery_geolocation do
        if Enum.random([true, false, false]) do
          %{"lat" => Faker.Address.latitude(), "lng" => Faker.Address.longitude()}
        else
          nil
        end
      end

      @spec delivery_device_info() :: map() | nil
      defp delivery_device_info do
        if Enum.random([true, false]) do
          %{
            "type" => Enum.random(["mobile", "desktop", "tablet"]),
            "os" => Enum.random(["iOS", "Android", "Windows"])
          }
        else
          nil
        end
      end

      @spec delivery_user_agent() :: String.t() | nil
      defp delivery_user_agent do
        if Enum.random([true, false]) do
          Enum.random([
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)",
            "Mozilla/5.0 (Linux; Android 13; Pixel 7)"
          ])
        else
          nil
        end
      end

      @spec delivery_log_metadata() :: map()
      defp delivery_log_metadata do
        %{"batch_id" => Faker.UUID.v4(), "priority" => Enum.random(["normal", "high"])}
      end

      # ===== CONTACT GROUP HELPERS =====

      @spec contact_group_name(integer()) :: String.t()
      defp contact_group_name(i) do
        types = ["Security Team", "Operations", "Managers", "On-Call", "Emergency"]
        "#{Enum.random(types)} #{i}"
      end

      @spec contact_group_description() :: String.t()
      defp contact_group_description do
        Faker.Lorem.sentence(8..15)
      end

      @spec random_group_type() :: atom()
      defp random_group_type do
        Enum.random([:static, :dynamic, :hybrid, :role_based, :location_based])
      end

      @spec contact_group_members() :: list()
      defp contact_group_members do
        Enum.map(1..:rand.uniform(10), fn _ -> %{"user_id" => Faker.UUID.v4()} end)
      end

      @spec dynamic_group_rules() :: map() | nil
      defp dynamic_group_rules do
        if Enum.random([true, false]) do
          %{"filter" => %{"role" => "security_officer"}}
        else
          nil
        end
      end

      @spec random_last_sync_time() :: DateTime.t() | nil
      defp random_last_sync_time do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400), :second)
        else
          nil
        end
      end

      @spec contact_group_tags() :: list()
      defp contact_group_tags do
        Enum.take_random(
          ["security", "operations", "vip", "emergency", "regional"],
          :rand.uniform(3)
        )
      end

      @spec contact_group_permissions() :: map()
      defp contact_group_permissions do
        %{"can_send" => true, "can_receive" => true, "can_escalate" => Enum.random([true, false])}
      end

      @spec group_notification_preferences() :: map()
      defp group_notification_preferences do
        %{"channels" => [:email, :sms], "quiet_hours" => false}
      end

      @spec escalation_hierarchy() :: list()
      defp escalation_hierarchy do
        [%{"level" => 1, "delay_minutes" => 15}, %{"level" => 2, "delay_minutes" => 30}]
      end

      @spec on_call_schedule() :: map() | nil
      defp on_call_schedule do
        if Enum.random([true, false]) do
          %{"type" => "weekly", "primary" => Faker.UUID.v4()}
        else
          nil
        end
      end

      @spec external_sync_config() :: map() | nil
      defp external_sync_config do
        if Enum.random([true, false, false]) do
          %{"provider" => "ldap", "sync_interval" => 3600}
        else
          nil
        end
      end

      @spec compliance_notes() :: String.t() | nil
      defp compliance_notes do
        if Enum.random([true, false, false]) do
          Faker.Lorem.sentence(10..20)
        else
          nil
        end
      end

      @spec contact_group_metadata() :: map()
      defp contact_group_metadata do
        %{
          "created_by" => Faker.Person.name(),
          "last_modified" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      end

      # ===== CONTACT PREFERENCE HELPERS =====

      @spec channel_preferences() :: map()
      defp channel_preferences do
        %{
          "email" => %{"enabled" => true, "priority" => 1},
          "sms" => %{"enabled" => Enum.random([true, false]), "priority" => 2}
        }
      end

      @spec preference_delivery_windows() :: map()
      defp preference_delivery_windows do
        %{"weekday" => %{"start" => "09:00", "end" => "18:00"}, "weekend" => nil}
      end

      @spec frequency_limits() :: map()
      defp frequency_limits do
        %{
          "max_per_hour" => Enum.random([5, 10, 20]),
          "max_per_day" => Enum.random([50, 100, 200])
        }
      end

      @spec content_preferences() :: map()
      defp content_preferences do
        %{"format" => Enum.random(["html", "plain_text"]), "language" => "en"}
      end

      @spec do_not_disturb_config() :: map()
      defp do_not_disturb_config do
        %{"enabled" => Enum.random([true, false]), "start" => "22:00", "end" => "07:00"}
      end

      @spec opt_out_categories() :: list()
      defp opt_out_categories do
        Enum.take_random(["marketing", "promotions", "newsletters"], :rand.uniform(2))
      end

      @spec subscription_status() :: map()
      defp subscription_status do
        %{"marketing" => Enum.random([true, false]), "operational" => true}
      end

      @spec verification_status() :: map()
      defp verification_status do
        %{"email" => Enum.random([true, false]), "phone" => Enum.random([true, false])}
      end

      @spec gdpr_consent_status() :: map()
      defp gdpr_consent_status do
        %{
          "given" => Enum.random([true, false]),
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      end

      @spec data_retention_preference() :: map()
      defp data_retention_preference do
        %{
          "period_days" => Enum.random([30, 90, 365]),
          "auto_delete" => Enum.random([true, false])
        }
      end

      @spec random_preference_update() :: DateTime.t()
      defp random_preference_update do
        DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400 * 30), :second)
      end

      @spec contact_preference_metadata() :: map()
      defp contact_preference_metadata do
        %{"source" => Enum.random(["web", "mobile", "api"]), "version" => "1.0"}
      end

      # ===== BROADCAST CAMPAIGN HELPERS =====

      @spec broadcast_campaign_name(integer()) :: String.t()
      defp broadcast_campaign_name(i) do
        types = ["Security Alert", "System Update", "Maintenance Notice", "Emergency"]
        "#{Enum.random(types)} Campaign #{i}"
      end

      @spec random_campaign_type() :: atom()
      defp random_campaign_type do
        Enum.random([:announcement, :alert, :promotional, :transactional, :emergency])
      end

      @spec campaign_description() :: String.t()
      defp campaign_description do
        Faker.Lorem.paragraph(2..4)
      end

      @spec target_audience_config() :: map()
      defp target_audience_config do
        %{"type" => Enum.random(["all", "segment", "dynamic"]), "filters" => []}
      end

      @spec campaign_channels() :: list()
      defp campaign_channels do
        Enum.take_random([:email, :sms, :push, :in_app], :rand.uniform(3) + 1)
      end

      @spec campaign_template_mapping() :: map()
      defp campaign_template_mapping do
        %{"email" => "template_email_001", "sms" => "template_sms_001"}
      end

      @spec campaign_schedule() :: map()
      defp campaign_schedule do
        %{"type" => Enum.random(["immediate", "scheduled"]), "send_time" => nil}
      end

      @spec campaign_status() :: atom()
      defp campaign_status do
        Enum.random([:draft, :scheduled, :running, :paused, :completed, :cancelled])
      end

      @spec random_campaign_start() :: DateTime.t() | nil
      defp random_campaign_start do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400 * 30), :second)
        else
          nil
        end
      end

      @spec random_campaign_end() :: DateTime.t() | nil
      defp random_campaign_end do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(:rand.uniform(86_400 * 30), :second)
        else
          nil
        end
      end

      @spec random_campaign_cost() :: Decimal.t() | nil
      defp random_campaign_cost do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(10_000)))
        else
          nil
        end
      end

      # ===== MESSAGE QUEUE HELPERS =====

      @spec message_queue_name(integer()) :: String.t()
      defp message_queue_name(i) do
        types = ["Priority", "Standard", "Bulk", "Emergency", "Delayed"]
        "#{Enum.random(types)} Queue #{i}"
      end

      @spec random_queue_type() :: atom()
      defp random_queue_type do
        Enum.random([:standard, :fifo, :priority, :delayed, :dead_letter])
      end

      @spec queue_priority() :: atom()
      defp queue_priority do
        Enum.random([:low, :normal, :high, :critical])
      end

      @spec queue_status() :: atom()
      defp queue_status do
        Enum.random([:active, :paused, :draining, :disabled])
      end

      @spec queue_retry_policy() :: map()
      defp queue_retry_policy do
        %{"max_attempts" => Enum.random([3, 5, 10]), "backoff_multiplier" => 2.0}
      end

      @spec dead_letter_config() :: map() | nil
      defp dead_letter_config do
        if Enum.random([true, false]) do
          %{"enabled" => true, "target_queue" => "dlq_main"}
        else
          nil
        end
      end

      @spec queue_monitoring_config() :: map()
      defp queue_monitoring_config do
        %{"enabled" => true, "alert_threshold" => 1000}
      end

      @spec auto_scaling_config() :: map() | nil
      defp auto_scaling_config do
        if Enum.random([true, false]) do
          %{"enabled" => true, "min_workers" => 1, "max_workers" => 10}
        else
          nil
        end
      end

      @spec queue_health_check() :: map()
      defp queue_health_check do
        %{"enabled" => true, "interval_seconds" => 30}
      end

      @spec queue_metrics() :: map()
      defp queue_metrics do
        %{
          "messages_in_flight" => :rand.uniform(100),
          "avg_processing_time_ms" => :rand.uniform(1000)
        }
      end

      @spec queue_alerts_config() :: map()
      defp queue_alerts_config do
        %{"enabled" => true, "channels" => [:email, :slack]}
      end

      @spec random_last_processed() :: DateTime.t() | nil
      defp random_last_processed do
        if Enum.random([true, false]) do
          DateTime.utc_now() |> DateTime.add(-:rand.uniform(3600), :second)
        else
          nil
        end
      end

      @spec random_queue_created() :: DateTime.t()
      defp random_queue_created do
        DateTime.utc_now() |> DateTime.add(-:rand.uniform(86_400 * 90), :second)
      end

      @spec message_queue_metadata() :: map()
      defp message_queue_metadata do
        %{
          "region" => Enum.random(["us-east", "eu-west"]),
          "tier" => Enum.random(["standard", "premium"])
        }
      end
    end
  end
end
