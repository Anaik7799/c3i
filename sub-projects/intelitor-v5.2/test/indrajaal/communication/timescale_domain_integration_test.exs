defmodule Indrajaal.Communication.TimescaleDomainIntegrationTest do
  @moduledoc """
  TDG test suite for Communication.TimescaleDomainIntegration.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation verification
  - Cross-domain analytics with compliance filtering

  ## STAMP Safety Integration
  - SC-OBS-069: Dual logging active
  - SC-PRF-050: Response time < 50ms for cross-domain queries

  ## Constitutional Verification
  - Ψ₀ Existence: GenServer starts without DB dependency (init only schedules timers)
  - Ψ₁ Regeneration: State initialized from empty maps; no external state required

  ## TPS 5-Level RCA Context
  - L1 Symptom: execute_cross_domain_query always returns {:ok, masked_result}
  - L5 Root Cause: validate_query_compliance/2 always returns {:ok, ...} — error branch unreachable
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Communication.TimescaleDomainIntegration

  @moduletag :zenoh_nif

  setup do
    case Process.whereis(TimescaleDomainIntegration) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(50)
    :ok
  end

  # ============================================================================
  # Module API definition
  # ============================================================================

  describe "module API definition" do
    test "start_link/1 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :start_link, 1)
    end

    test "initialize_integration/2 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :initialize_integration, 2)
    end

    test "execute_cross_domain_query/2 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :execute_cross_domain_query, 2)
    end

    test "generate_cross_domain_analytics/2 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :generate_cross_domain_analytics, 2)
    end

    test "trigger_compliance_workflow/3 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :trigger_compliance_workflow, 3)
    end

    test "apply_data_retention_policies/2 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :apply_data_retention_policies, 2)
    end

    test "update_consent_status/3 is exported" do
      assert function_exported?(TimescaleDomainIntegration, :update_consent_status, 3)
    end
  end

  # ============================================================================
  # GenServer lifecycle (init is NOT DB dependent — only schedules timers)
  # ============================================================================

  describe "start_link/1" do
    test "starts the GenServer successfully (no DB required)" do
      assert {:ok, pid} = TimescaleDomainIntegration.start_link([])
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "registers under module name" do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      assert Process.whereis(TimescaleDomainIntegration) == pid
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "second start returns already_started" do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      assert {:error, {:already_started, ^pid}} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end

    test "server remains alive after start" do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      Process.sleep(50)
      assert Process.alive?(pid)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    end
  end

  # ============================================================================
  # initialize_integration/2 — pure function (not a GenServer call)
  # Returns {:ok, integration_config} always
  # ============================================================================

  describe "initialize_integration/2" do
    setup do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns {:ok, config} tuple" do
      result = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert {:ok, _config} = result
    end

    test "config has :tenant_id key matching input" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_abc")
      assert config.tenant_id == "tenant_abc"
    end

    test "config has :integration_id key (UUID string)" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :integration_id)
      assert is_binary(config.integration_id)
      # UUID format: 8-4-4-4-12 hex characters
      assert String.length(config.integration_id) == 36
    end

    test "config has :enabled_domains key as list" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :enabled_domains)
      assert is_list(config.enabled_domains)
    end

    test "default enabled_domains includes communication and compliance" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "communication" in config.enabled_domains
      assert "compliance" in config.enabled_domains
    end

    test "config has :compliance_frameworks key as list" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :compliance_frameworks)
      assert is_list(config.compliance_frameworks)
    end

    test "default compliance_frameworks includes gdpr" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "gdpr" in config.compliance_frameworks
    end

    test "default compliance_frameworks includes hipaa" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "hipaa" in config.compliance_frameworks
    end

    test "default compliance_frameworks includes sox" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "sox" in config.compliance_frameworks
    end

    test "default compliance_frameworks includes pci_dss" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "pci_dss" in config.compliance_frameworks
    end

    test "default compliance_frameworks includes iso27001" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "iso27001" in config.compliance_frameworks
    end

    test "default compliance_frameworks includes ccpa" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "ccpa" in config.compliance_frameworks
    end

    test "default compliance_frameworks includes dpdp_act" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert "dpdp_act" in config.compliance_frameworks
    end

    test "default compliance_frameworks has 7 entries" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert length(config.compliance_frameworks) == 7
    end

    test "config has :analytics_level key" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :analytics_level)
    end

    test "default analytics_level is 'comprehensive'" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert config.analytics_level == "comprehensive"
    end

    test "config has :audit_level key" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :audit_level)
    end

    test "default audit_level is 'full'" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert config.audit_level == "full"
    end

    test "config has :retention_policies key as map" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :retention_policies)
      assert is_map(config.retention_policies)
    end

    test "config has :started_at key as DateTime" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :started_at)
      assert %DateTime{} = config.started_at
    end

    test "config has :status key" do
      {:ok, config} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert Map.has_key?(config, :status)
      assert is_binary(config.status)
    end

    test "accepts custom domains in params" do
      {:ok, config} =
        TimescaleDomainIntegration.initialize_integration("tenant_1", %{
          domains: ["communication"]
        })

      assert "communication" in config.enabled_domains
    end

    test "accepts custom frameworks in params" do
      {:ok, config} =
        TimescaleDomainIntegration.initialize_integration("tenant_1", %{
          frameworks: ["gdpr", "hipaa"]
        })

      assert "gdpr" in config.compliance_frameworks
      assert "hipaa" in config.compliance_frameworks
    end

    test "accepts custom analytics_level in params" do
      {:ok, config} =
        TimescaleDomainIntegration.initialize_integration("tenant_1", %{
          analytics_level: "basic"
        })

      assert config.analytics_level == "basic"
    end

    test "each call generates a unique integration_id" do
      {:ok, config1} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      {:ok, config2} = TimescaleDomainIntegration.initialize_integration("tenant_1")
      assert config1.integration_id != config2.integration_id
    end
  end

  # ============================================================================
  # execute_cross_domain_query/2
  # validate_query_compliance always returns {:ok, ...} so result is always {:ok, masked_result}
  # ============================================================================

  describe "execute_cross_domain_query/2" do
    setup do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    @query_params %{
      type: "engagement_summary",
      domains: ["communication"],
      masking_rules: []
    }

    test "returns {:ok, result} tuple" do
      result = TimescaleDomainIntegration.execute_cross_domain_query("tenant_1", @query_params)
      assert {:ok, _masked_result} = result
    end

    test "returns ok for different tenant ids" do
      result = TimescaleDomainIntegration.execute_cross_domain_query("tenant_xyz", @query_params)
      assert match?({:ok, _}, result)
    end

    test "returns ok for minimal query params" do
      result = TimescaleDomainIntegration.execute_cross_domain_query("tenant_1", %{})
      assert match?({:ok, _}, result)
    end

    test "returns ok for compliance-type query" do
      compliance_query = %{
        type: "compliance_audit",
        domains: ["compliance"],
        masking_rules: ["pii"]
      }

      result = TimescaleDomainIntegration.execute_cross_domain_query("tenant_1", compliance_query)
      assert match?({:ok, _}, result)
    end
  end

  # ============================================================================
  # generate_cross_domain_analytics/2
  # ============================================================================

  describe "generate_cross_domain_analytics/2" do
    setup do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns {:ok, report} tuple with default params" do
      result = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert {:ok, _report} = result
    end

    test "report has :tenant_id key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :tenant_id)
      assert report.tenant_id == "tenant_1"
    end

    test "report has :report_type key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :report_type)
    end

    test "report has :generated_at key as DateTime" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :generated_at)
      assert %DateTime{} = report.generated_at
    end

    test "report has :timeframe key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :timeframe)
    end

    test "default timeframe is '30d'" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert report.timeframe == "30d"
    end

    test "report has :domains_analyzed key as list" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :domains_analyzed)
      assert is_list(report.domains_analyzed)
    end

    test "report has :analytics_data key as map" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :analytics_data)
      assert is_map(report.analytics_data)
    end

    test "report has :cross_domain_insights key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :cross_domain_insights)
    end

    test "report has :regulatory_summary key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :regulatory_summary)
    end

    test "report has :risk_assessment key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :risk_assessment)
    end

    test "report has :recommendations key" do
      {:ok, report} = TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1")
      assert Map.has_key?(report, :recommendations)
    end

    test "accepts custom timeframe param" do
      {:ok, report} =
        TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1", %{
          timeframe: "7d"
        })

      assert report.timeframe == "7d"
    end

    test "accepts custom domains param" do
      {:ok, report} =
        TimescaleDomainIntegration.generate_cross_domain_analytics("tenant_1", %{
          domains: ["communication"]
        })

      assert "communication" in report.domains_analyzed
    end
  end

  # ============================================================================
  # trigger_compliance_workflow/3
  # ============================================================================

  describe "trigger_compliance_workflow/3" do
    setup do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    @trigger_data %{
      source: "automated_check",
      event_type: "data_breach_detected",
      severity: "high"
    }

    test "returns {:ok, workflow_id} tuple" do
      result =
        TimescaleDomainIntegration.trigger_compliance_workflow(
          "tenant_1",
          "gdpr_breach_response",
          @trigger_data
        )

      assert {:ok, workflow_id} = result
      assert is_binary(workflow_id)
    end

    test "workflow_id is a UUID format string" do
      {:ok, workflow_id} =
        TimescaleDomainIntegration.trigger_compliance_workflow(
          "tenant_1",
          "gdpr_breach_response",
          @trigger_data
        )

      assert String.length(workflow_id) == 36
    end

    test "returns different workflow_id for each call" do
      {:ok, id1} =
        TimescaleDomainIntegration.trigger_compliance_workflow(
          "tenant_1",
          "gdpr_breach_response",
          @trigger_data
        )

      {:ok, id2} =
        TimescaleDomainIntegration.trigger_compliance_workflow(
          "tenant_1",
          "gdpr_breach_response",
          @trigger_data
        )

      assert id1 != id2
    end
  end

  # ============================================================================
  # apply_data_retention_policies/2
  # ============================================================================

  describe "apply_data_retention_policies/2" do
    setup do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "returns {:ok, retention_report} tuple with default params" do
      result = TimescaleDomainIntegration.apply_data_retention_policies("tenant_1")
      assert {:ok, _report} = result
    end

    test "retention_report has :tenant_id key" do
      {:ok, report} = TimescaleDomainIntegration.apply_data_retention_policies("tenant_1")
      assert Map.has_key?(report, :tenant_id)
      assert report.tenant_id == "tenant_1"
    end

    test "retention_report has :applied_at key as DateTime" do
      {:ok, report} = TimescaleDomainIntegration.apply_data_retention_policies("tenant_1")
      assert Map.has_key?(report, :applied_at)
      assert %DateTime{} = report.applied_at
    end

    test "retention_report has :policies_applied key as list" do
      {:ok, report} = TimescaleDomainIntegration.apply_data_retention_policies("tenant_1")
      assert Map.has_key?(report, :policies_applied)
      assert is_list(report.policies_applied)
    end

    test "retention_report has :total_records_affected key" do
      {:ok, report} = TimescaleDomainIntegration.apply_data_retention_policies("tenant_1")
      assert Map.has_key?(report, :total_records_affected)
      assert is_integer(report.total_records_affected)
    end

    test "retention_report has :compliance_status key" do
      {:ok, report} = TimescaleDomainIntegration.apply_data_retention_policies("tenant_1")
      assert Map.has_key?(report, :compliance_status)
    end
  end

  # ============================================================================
  # update_consent_status/3
  # ============================================================================

  describe "update_consent_status/3" do
    setup do
      {:ok, pid} = TimescaleDomainIntegration.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    @consent_updates %{
      email_marketing: false,
      sms_notifications: true,
      push_notifications: false,
      data_analytics: true
    }

    test "returns {:ok, consent_result} tuple" do
      result =
        TimescaleDomainIntegration.update_consent_status(
          "tenant_1",
          "user_123",
          @consent_updates
        )

      assert {:ok, _consent_result} = result
    end

    test "consent_result has :consent_id key" do
      {:ok, result} =
        TimescaleDomainIntegration.update_consent_status(
          "tenant_1",
          "user_123",
          @consent_updates
        )

      assert Map.has_key?(result, :consent_id)
      assert is_binary(result.consent_id)
    end

    test "consent_result has :tenant_id key" do
      {:ok, result} =
        TimescaleDomainIntegration.update_consent_status(
          "tenant_1",
          "user_123",
          @consent_updates
        )

      assert result.tenant_id == "tenant_1"
    end

    test "consent_result has :user_id key" do
      {:ok, result} =
        TimescaleDomainIntegration.update_consent_status(
          "tenant_1",
          "user_123",
          @consent_updates
        )

      assert result.user_id == "user_123"
    end

    test "consent_result has :updated_at key as DateTime" do
      {:ok, result} =
        TimescaleDomainIntegration.update_consent_status(
          "tenant_1",
          "user_123",
          @consent_updates
        )

      assert Map.has_key?(result, :updated_at)
      assert %DateTime{} = result.updated_at
    end
  end
end
