defmodule Indrajaal.Integrations.WebhookTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Integrations.Webhook

  describe "Webhook resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)

      {:ok, tenant: tenant, organization: organization}
    end

    test "creates a webhook with valid attributes",
         %{tenant: tenant, organization: organization} do
      attrs = %{
        name: "Alarm Notification Webhook",
        url: "https://api.example.com / webhooks / alarms",
        secret_key: "secret123",
        __events: ["alarm.triggered", "alarm.resolved"],
        http_method: :post,
        timeout_seconds: 30,
        retry_attempts: 3,
        custom_headers: %{"Authorization" => "Bearer token123"},
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, webhook} = Webhook.create(attrs)

      assert webhook.name == "Alarm Notification Webhook"
      assert webhook.url == "https://api.example.com / webhooks / alarms"
      assert webhook.__events == ["alarm.triggered", "alarm.resolved"]
      assert webhook.http_method == :post
      assert webhook.active? == true
      assert webhook.failure_count == 0
      assert webhook.total_calls == 0
      assert webhook.tenant_id == tenant.id
      assert webhook.organization_id == organization.id
    end

    test "validates __required fields" do
      {:error, changeset} = Webhook.create(%{})

      assert changeset.errors[:name]
      assert changeset.errors[:url]
      assert changeset.errors[:organization_id]
    end

    test "validates unique name per tenant",
         %{tenant: tenant, organization: organization} do
      insert(:webhook,
        name: "Duplicate Webhook",
        tenant: tenant,
        organization: organization
      )

      {:error, changeset} =
        Webhook.create(%{
          name: "Duplicate Webhook",
          url: "https://api.example.com / webhook2",
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:name]
    end

    test "validates URL format",
         %{tenant: tenant, organization: organization} do
      attrs = %{
        name: "Invalid URL Webhook",
        url: "not - a-valid - url",
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:error, changeset} = Webhook.create(attrs)
      assert changeset.errors[:url]
    end

    test "validates __event types",
         %{tenant: tenant, organization: organization} do
      attrs = %{
        name: "Invalid Events Webhook",
        url: "https://api.example.com / webhook",
        __events: ["alarm.triggered", "invalid.__event"],
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:error, changeset} = Webhook.create(attrs)
      assert changeset.errors[:__events]
    end

    test "activates and deactivates webhook",
         %{tenant: tenant, organization: organization} do
      webhook =
        insert(:webhook,
          active?: false,
          tenant: tenant,
          organization: organization
        )

      {:ok, activated} = Webhook.activate(webhook)
      assert activated.active? == true

      {:ok, deactivated} = Webhook.deactivate(activated)
      assert deactivated.active? == false
    end

    test "records successful webhook calls",
         %{tenant: tenant, organization: organization} do
      webhook =
        insert(:webhook,
          total_calls: 5,
          failure_count: 2,
          tenant: tenant,
          organization: organization
        )

      {:ok, updated} = Webhook.record_success(webhook)

      assert updated.total_calls == 6
      assert updated.failure_count == 0
      assert updated.last_success_at != nil
    end

    test "records failed webhook calls",
         %{tenant: tenant, organization: organization} do
      webhook =
        insert(:webhook,
          total_calls: 5,
          failure_count: 1,
          tenant: tenant,
          organization: organization
        )

      {:ok, updated} = Webhook.record_failure(webhook)

      assert updated.total_calls == 6
      assert updated.failure_count == 2
      assert updated.last_failure_at != nil
    end

    test "calculates success rate",
         %{tenant: tenant, organization: organization} do
      webhook =
        insert(:webhook,
          total_calls: 100,
          failure_count: 10,
          tenant: tenant,
          organization: organization
        )

      webhook_with_calc = Webhook.read!(webhook.id, load: [:success_rate])
      assert webhook_with_calc.success_rate == 90.0
    end

    test "calculates health status",
         %{tenant: tenant, organization: organization} do
      healthy_webhook =
        insert(:webhook,
          active?: true,
          failure_count: 2,
          tenant: tenant,
          organization: organization
        )

      unhealthy_webhook =
        insert(:webhook,
          active?: true,
          failure_count: 10,
          tenant: tenant,
          organization: organization
        )

      healthy_with_calc = Webhook.read!(healthy_webhook.id, load: [:is_healthy?])
      unhealthy_with_calc = Webhook.read!(unhealthy_webhook.id, load: [:is_healthy?])

      assert healthy_with_calc.is_healthy? == true
      assert unhealthy_with_calc.is_healthy? == false
    end

    test "validates timeout constraints",
         %{tenant: tenant, organization: organization} do
      # Valid timeout
      valid_attrs = %{
        name: "Valid Timeout Webhook",
        url: "https://api.example.com / webhook",
        timeout_seconds: 60,
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, _webhook} = Webhook.create(valid_attrs)

      # Invalid timeout (too high)
      invalid_attrs = %{
        name: "Invalid Timeout Webhook",
        url: "https://api.example.com / webhook",
        timeout_seconds: 500,
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:error, changeset} = Webhook.create(invalid_attrs)
      assert changeset.errors[:timeout_seconds]
    end

    test "validates retry attempts constraints",
         %{tenant: tenant, organization: organization} do
      # Valid retry attempts
      valid_attrs = %{
        name: "Valid Retry Webhook",
        url: "https://api.example.com / webhook",
        retry_attempts: 5,
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, _webhook} = Webhook.create(valid_attrs)

      # Invalid retry attempts (too high)
      invalid_attrs = %{
        name: "Invalid Retry Webhook",
        url: "https://api.example.com / webhook",
        retry_attempts: 15,
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:error, changeset} = Webhook.create(invalid_attrs)
      assert changeset.errors[:retry_attempts]
    end

    test "supports different HTTP methods",
         %{tenant: tenant, organization: organization} do
      methods = [:post, :put, :patch]

      for method <- methods do
        attrs = %{
          name: "#{method |> Atom.to_string() |> String.upcase()} Webhook",
          url: "https://api.example.com / webhook/#{method}",
          http_method: method,
          organization_id: organization.id,
          tenant_id: tenant.id
        }

        {:ok, webhook} = Webhook.create(attrs)
        assert webhook.http_method == method
      end
    end

    test "stores custom headers",
         %{tenant: tenant, organization: organization} do
      attrs = %{
        name: "Custom Headers Webhook",
        url: "https://api.example.com / webhook",
        custom_headers: %{
          "Authorization" => "Bearer token123",
          "X-Custom-Header" => "custom-value",
          "Content - Type" => "application / json"
        },
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, webhook} = Webhook.create(attrs)

      assert webhook.custom_headers["Authorization"] == "Bearer token123"
      assert webhook.custom_headers["X-Custom-Header"] == "custom-value"
      assert webhook.custom_headers["Content - Type"] == "application / json"
    end

    test "enforces tenant isolation", %{organization: organization} do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      org1 = insert(:organization, tenant: tenant1)
      org2 = insert(:organization, tenant: tenant2)

      webhook1 = insert(:webhook, tenant: tenant1, organization: org1)
      webhook2 = insert(:webhook, tenant: tenant2, organization: org2)

      # Query with tenant1 __context should only return webhook1
      webhooks_tenant1 = Webhook.read!(tenant: tenant1)
      assert length(webhooks_tenant1) == 1
      assert Enum.any?(webhooks_tenant1, &(&1.id == webhook1.id))
      refute Enum.any?(webhooks_tenant1, &(&1.id == webhook2.id))
    end

    test "handles metadata storage",
         %{tenant: tenant, organization: organization} do
      attrs = %{
        name: "Meta__data Webhook",
        url: "https://api.example.com / webhook",
        metadata: %{
          "created_by" => "admin",
          "purpose" => "alarm notifications",
          "version" => "1.0"
        },
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, webhook} = Webhook.create(attrs)

      assert webhook.metadata["created_by"] == "admin"
      assert webhook.metadata["purpose"] == "alarm notifications"
      assert webhook.metadata["version"] == "1.0"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
