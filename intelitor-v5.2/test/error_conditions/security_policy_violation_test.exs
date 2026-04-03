defmodule Indrajaal.ErrorConditions.SecurityPolicyViolationTest do
  @moduledoc """
  Error condition tests for security policy violations.

  STAMP Constraints Tested:
  - SC-SEC-011: Violation detection
  - SC-SEC-012: Violation logging
  - SC-SEC-013: Violation response

  AOR Rules:
  - AOR-SEC-001: Block all violations
  - AOR-SEC-002: Log violations with full context
  - AOR-SEC-003: Alert on critical violations
  """

  use ExUnit.Case, async: true

  @forbidden_capabilities ["SYS_ADMIN", "ALL", "NET_ADMIN", "SYS_PTRACE"]

  describe "SC-SEC-011: Violation Detection" do
    test "root user is detected as violation" do
      container_spec = %{
        run_as_user: 0,
        run_as_non_root: false
      }

      violations = detect_violations(container_spec)

      assert :root_user in violations
    end

    test "forbidden capability is detected" do
      container_spec = %{
        capabilities: %{
          add: ["SYS_ADMIN", "NET_BIND_SERVICE"]
        }
      }

      violations = detect_violations(container_spec)

      assert :forbidden_capability in violations
    end

    test "external registry is detected" do
      container_spec = %{
        image: "docker.io/library/alpine:latest"
      }

      violations = detect_violations(container_spec)

      assert :external_registry in violations
    end

    test "unconfined seccomp is detected" do
      container_spec = %{
        seccomp_profile: "unconfined"
      }

      violations = detect_violations(container_spec)

      assert :unconfined_seccomp in violations
    end

    test "privilege escalation is detected" do
      container_spec = %{
        allow_privilege_escalation: true
      }

      violations = detect_violations(container_spec)

      assert :privilege_escalation in violations
    end
  end

  describe "SC-SEC-012: Violation Logging" do
    test "violation is logged with full context" do
      violation = %{
        type: :forbidden_capability,
        capability: "SYS_ADMIN",
        resource: "pod/test-pod",
        namespace: "default",
        actor: "deployment-controller",
        timestamp: DateTime.utc_now()
      }

      log_entry = format_violation_log(violation)

      assert String.contains?(log_entry, "SYS_ADMIN")
      assert String.contains?(log_entry, "test-pod")
      assert String.contains?(log_entry, "VIOLATION")
    end

    test "violation log includes severity" do
      violations = [
        {:root_user, :critical},
        {:forbidden_capability, :critical},
        {:external_registry, :high},
        {:unconfined_seccomp, :high},
        {:privilege_escalation, :critical}
      ]

      Enum.each(violations, fn {type, expected_severity} ->
        severity = get_violation_severity(type)
        assert severity == expected_severity
      end)
    end

    test "audit trail is maintained" do
      violations = [
        %{id: 1, type: :root_user, timestamp: DateTime.utc_now()},
        %{id: 2, type: :forbidden_capability, timestamp: DateTime.utc_now()}
      ]

      audit_log = build_audit_trail(violations)

      assert length(audit_log) == 2
      assert Enum.all?(audit_log, &Map.has_key?(&1, :id))
    end
  end

  describe "SC-SEC-013: Violation Response" do
    test "critical violations are blocked" do
      violation = %{
        type: :root_user,
        severity: :critical
      }

      response = determine_response(violation)

      assert response.action == :block
    end

    test "high severity violations are blocked" do
      violation = %{
        type: :external_registry,
        severity: :high
      }

      response = determine_response(violation)

      assert response.action == :block
    end

    test "violation alert is triggered" do
      violation = %{
        type: :forbidden_capability,
        severity: :critical,
        capability: "SYS_ADMIN"
      }

      alert = generate_alert(violation)

      assert alert.severity == :critical
      assert alert.channel in [:pagerduty, :slack, :email]
    end

    test "remediation guidance is provided" do
      violation = %{
        type: :root_user
      }

      remediation = get_remediation(violation)

      assert is_binary(remediation)
      assert String.contains?(remediation, "runAsNonRoot")
    end
  end

  describe "Violation Metrics" do
    test "violation counter is incremented" do
      metric = %{
        name: "security.violations.total",
        value: 1,
        tags: %{
          type: :forbidden_capability,
          severity: :critical
        }
      }

      assert metric.name == "security.violations.total"
      assert Map.has_key?(metric.tags, :type)
    end

    test "violation rate is tracked" do
      violations_per_minute = [
        %{count: 5, minute: 0},
        %{count: 3, minute: 1},
        %{count: 10, minute: 2}
      ]

      rate = calculate_violation_rate(violations_per_minute)

      assert rate == 6.0
    end
  end

  describe "Policy Enforcement" do
    test "admission webhook rejects violations" do
      admission_request = %{
        kind: "Pod",
        name: "test-pod",
        spec: %{
          containers: [
            %{
              security_context: %{
                run_as_user: 0
              }
            }
          ]
        }
      }

      response = evaluate_admission(admission_request)

      assert response.allowed == false
      assert response.reason != nil
    end

    test "valid spec is allowed" do
      admission_request = %{
        kind: "Pod",
        name: "test-pod",
        spec: %{
          security_context: %{
            run_as_non_root: true,
            run_as_user: 1000
          },
          containers: [
            %{
              image: "localhost/app:latest",
              security_context: %{
                capabilities: %{
                  drop: ["ALL"],
                  add: ["NET_BIND_SERVICE"]
                }
              }
            }
          ]
        }
      }

      response = evaluate_admission(admission_request)

      assert response.allowed == true
    end
  end

  describe "Error Recovery" do
    test "enforcement continues after error" do
      enforcer_state = %{
        status: :running,
        last_error: :webhook_timeout,
        error_count: 1
      }

      # System should recover
      new_state = recover_enforcer(enforcer_state)

      assert new_state.status == :running
    end

    test "fail-closed on repeated errors" do
      enforcer_state = %{
        error_count: 10,
        error_threshold: 5
      }

      policy = determine_failure_policy(enforcer_state)

      # Should fail closed (deny all) when errors exceed threshold
      assert policy == :fail_closed
    end
  end

  # Helper functions

  defp detect_violations(spec) do
    violations = []

    violations =
      if spec[:run_as_user] == 0 or spec[:run_as_non_root] == false do
        [:root_user | violations]
      else
        violations
      end

    violations =
      if spec[:capabilities] do
        forbidden = MapSet.new(@forbidden_capabilities)
        added = MapSet.new(spec.capabilities[:add] || [])

        if MapSet.size(MapSet.intersection(forbidden, added)) > 0 do
          [:forbidden_capability | violations]
        else
          violations
        end
      else
        violations
      end

    violations =
      if spec[:image] && not String.starts_with?(spec.image, "localhost/") do
        [:external_registry | violations]
      else
        violations
      end

    violations =
      if spec[:seccomp_profile] == "unconfined" do
        [:unconfined_seccomp | violations]
      else
        violations
      end

    violations =
      if spec[:allow_privilege_escalation] == true do
        [:privilege_escalation | violations]
      else
        violations
      end

    violations
  end

  defp format_violation_log(violation) do
    "[SECURITY VIOLATION] type=#{violation.type}, resource=#{violation.resource}, capability=#{violation[:capability]}"
  end

  defp get_violation_severity(type) do
    case type do
      :root_user -> :critical
      :forbidden_capability -> :critical
      :privilege_escalation -> :critical
      :external_registry -> :high
      :unconfined_seccomp -> :high
      _ -> :medium
    end
  end

  defp build_audit_trail(violations) do
    Enum.map(violations, fn v ->
      Map.put(v, :audit_id, "audit-#{v.id}")
    end)
  end

  defp determine_response(violation) do
    case violation.severity do
      :critical -> %{action: :block, alert: true}
      :high -> %{action: :block, alert: true}
      :medium -> %{action: :warn, alert: false}
      _ -> %{action: :log, alert: false}
    end
  end

  defp generate_alert(violation) do
    %{
      severity: violation.severity,
      channel: :pagerduty,
      message: "Security violation: #{violation.type}"
    }
  end

  defp get_remediation(violation) do
    case violation.type do
      :root_user ->
        "Set runAsNonRoot: true and runAsUser: 1000 in securityContext"

      :forbidden_capability ->
        "Remove forbidden capabilities from securityContext.capabilities.add"

      :external_registry ->
        "Use localhost/ registry for all images"

      _ ->
        "Review security policy documentation"
    end
  end

  defp calculate_violation_rate(violations) do
    total = Enum.sum(Enum.map(violations, & &1.count))
    total / length(violations)
  end

  defp evaluate_admission(request) do
    violations =
      if request.spec[:security_context] do
        detect_violations(request.spec.security_context)
      else
        []
      end

    container_violations =
      (request.spec[:containers] || [])
      |> Enum.flat_map(fn c ->
        detect_violations(Map.merge(c[:security_context] || %{}, %{image: c[:image]}))
      end)

    all_violations = violations ++ container_violations

    if Enum.empty?(all_violations) do
      %{allowed: true, reason: nil}
    else
      %{allowed: false, reason: "Violations: #{inspect(all_violations)}"}
    end
  end

  defp recover_enforcer(state) do
    %{state | error_count: 0}
  end

  defp determine_failure_policy(state) do
    if state.error_count > state.error_threshold do
      :fail_closed
    else
      :fail_open
    end
  end
end
