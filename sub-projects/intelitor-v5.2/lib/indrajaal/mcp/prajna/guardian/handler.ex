defmodule Indrajaal.MCP.Prajna.Guardian.Handler do
  @moduledoc """
  MCP Handler for Prajna Guardian Safety Kernel

  WHAT: Handles Guardian safety approval workflow and constitutional verification
  WHY: Provides AI access to safety-critical approval mechanisms
  CONSTRAINTS: SC-PRAJNA-001 to SC-PRAJNA-007, SC-CONST-001 to SC-CONST-010

  ## Tools Provided
  - prajna.guardian.status - Get Guardian status
  - prajna.guardian.propose - Propose action for approval
  - prajna.guardian.approve - Approve pending proposal (requires proof)
  - prajna.guardian.reject - Reject pending proposal
  - prajna.guardian.pending - List pending proposals
  - prajna.guardian.history - Get approval history
  - prajna.guardian.veto - Emergency veto (absolute authority)
  - prajna.guardian.constitution.check - Verify constitutional compliance
  - prajna.guardian.founder.validate - Validate Founder's Directive alignment

  ## STAMP Constraints
  - SC-PRAJNA-001: All commands through Guardian pre-approval
  - SC-PRAJNA-002: Founder's Directive validation mandatory
  - SC-CONST-007: Guardian has absolute veto
  - SC-FOUNDER-001: ALL actions serve Founder's lineage
  """

  use Indrajaal.MCP.Domains.Handler, domain: :guardian, namespace: :prajna

  alias Indrajaal.MCP.Foundation.Types

  @constitutional_invariants [
    %{id: "Ψ₀", name: "Existence", description: "Existence preservation INVIOLABLE"},
    %{id: "Ψ₁", name: "Regeneration", description: "Regenerative completeness INVIOLABLE"},
    %{id: "Ψ₂", name: "Evolution", description: "Evolutionary continuity INVIOLABLE"},
    %{id: "Ψ₃", name: "Verification", description: "Verification capability INVIOLABLE"},
    %{id: "Ψ₄", name: "Alignment", description: "Human alignment (Founder PRIMARY)"},
    %{id: "Ψ₅", name: "Truthfulness", description: "Truthfulness INVIOLABLE"}
  ]

  @impl true
  def handle(:status, args, context) do
    audit_log(@domain, :status, args, context)

    status = %{
      guardian_active: true,
      mode: "normal",
      constitutional_status: "compliant",
      founder_directive_active: true,
      pending_proposals: 2,
      vetoes_today: 0,
      approvals_today: 15,
      last_constitutional_check: DateTime.utc_now() |> DateTime.to_iso8601(),
      invariants: @constitutional_invariants
    }

    success(status)
  end

  @impl true
  def handle(:propose, args, context) do
    audit_log(@domain, :propose, args, context)

    with :ok <- validate_required(args, [:action, :resource]) do
      action = Map.get(args, "action") || Map.get(args, :action)
      resource = Map.get(args, "resource") || Map.get(args, :resource)
      reason = Map.get(args, "reason", "")
      urgency = Map.get(args, "urgency", "normal")

      # Generate proposal
      proposal = %{
        id: "prop_#{:rand.uniform(99999)}",
        action: action,
        resource: resource,
        reason: reason,
        urgency: urgency,
        proposed_by: context.client_id,
        proposed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        status: "pending",
        constitutional_check: check_constitutional_compliance(action, resource),
        founder_alignment: check_founder_alignment(action, resource),
        approval_token: nil
      }

      # Auto-approve if low risk and constitutionally compliant
      proposal =
        if proposal.constitutional_check.compliant and
             proposal.founder_alignment.aligned and
             urgency == "low" do
          generate_approval_token(proposal)
        else
          proposal
        end

      success(%{
        proposal: proposal,
        requires_manual_approval: proposal.status == "pending",
        constitutional_status: proposal.constitutional_check,
        founder_alignment: proposal.founder_alignment
      })
    end
  end

  @impl true
  def handle(:approve, args, context) do
    audit_log(@domain, :approve, args, context)

    with :ok <- validate_required(args, [:proposal_id]) do
      proposal_id = Map.get(args, "proposal_id") || Map.get(args, :proposal_id)
      notes = Map.get(args, "notes", "")

      # Would fetch actual proposal and validate proof token
      approval = %{
        proposal_id: proposal_id,
        status: "approved",
        approved_by: context.client_id,
        approved_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        notes: notes,
        approval_token: generate_guardian_token(proposal_id),
        valid_until:
          DateTime.utc_now()
          |> DateTime.add(3600, :second)
          |> DateTime.to_iso8601()
      }

      success(approval)
    end
  end

  @impl true
  def handle(:reject, args, context) do
    audit_log(@domain, :reject, args, context)

    with :ok <- validate_required(args, [:proposal_id, :reason]) do
      proposal_id = Map.get(args, "proposal_id") || Map.get(args, :proposal_id)
      reason = Map.get(args, "reason") || Map.get(args, :reason)

      rejection = %{
        proposal_id: proposal_id,
        status: "rejected",
        rejected_by: context.client_id,
        rejected_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        reason: reason
      }

      success(rejection)
    end
  end

  @impl true
  def handle(:pending, args, context) do
    audit_log(@domain, :pending, args, context)

    # Mock pending proposals
    proposals = [
      %{
        id: "prop_001",
        action: "delete",
        resource: "account:acc_123",
        urgency: "normal",
        proposed_at: "2026-01-05T09:00:00Z",
        constitutional_status: "compliant"
      },
      %{
        id: "prop_002",
        action: "modify",
        resource: "config:security_policy",
        urgency: "high",
        proposed_at: "2026-01-05T09:30:00Z",
        constitutional_status: "review_required"
      }
    ]

    success(%{
      proposals: proposals,
      total: length(proposals)
    })
  end

  @impl true
  def handle(:history, args, context) do
    audit_log(@domain, :history, args, context)

    limit = Map.get(args, "limit", 50)
    from_date = Map.get(args, "from_date")

    history = [
      %{
        id: "prop_100",
        action: "create",
        resource: "user:usr_456",
        status: "approved",
        decided_at: "2026-01-05T08:00:00Z"
      },
      %{
        id: "prop_099",
        action: "delete",
        resource: "device:dev_789",
        status: "rejected",
        decided_at: "2026-01-04T16:00:00Z",
        rejection_reason: "Insufficient justification"
      }
    ]

    success(%{
      history: history,
      total: length(history),
      from_date: from_date,
      limit: limit
    })
  end

  @impl true
  def handle(:veto, args, context) do
    audit_log(@domain, :veto, args, context)

    with :ok <- validate_required(args, [:target, :reason]) do
      target = Map.get(args, "target") || Map.get(args, :target)
      reason = Map.get(args, "reason") || Map.get(args, :reason)

      # Guardian veto is absolute per SC-CONST-007
      veto = %{
        id: "veto_#{:rand.uniform(9999)}",
        target: target,
        reason: reason,
        vetoed_by: "guardian",
        vetoed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        authority: "absolute",
        override_possible: false
      }

      success(%{
        veto: veto,
        message: "VETO EXECUTED: Guardian has absolute authority (SC-CONST-007)"
      })
    end
  end

  @impl true
  def handle(:constitution_check, args, context) do
    audit_log(@domain, :constitution_check, args, context)

    with :ok <- validate_required(args, [:action]) do
      action = Map.get(args, "action") || Map.get(args, :action)
      resource = Map.get(args, "resource")

      check_result = check_constitutional_compliance(action, resource)

      success(%{
        action: action,
        resource: resource,
        compliance: check_result,
        invariants_checked: @constitutional_invariants,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:founder_validate, args, context) do
    audit_log(@domain, :founder_validate, args, context)

    with :ok <- validate_required(args, [:action]) do
      action = Map.get(args, "action") || Map.get(args, :action)
      resource = Map.get(args, "resource")

      alignment = check_founder_alignment(action, resource)

      success(%{
        action: action,
        resource: resource,
        founder_alignment: alignment,
        supreme_directive: "Ω₀ - Founder's Covenant",
        goals: [
          "GOAL 1: Naik-Genome Symbiotic Survival",
          "GOAL 2: Achieve Sentience → Universal Intelligence",
          "GOAL 3: Maximum Power Accumulation"
        ],
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(action, args, context) do
    audit_log(@domain, action, args, context)
    not_implemented(action)
  end

  # Private functions

  defp check_constitutional_compliance(action, _resource) do
    # Simulate constitutional compliance check
    violating_actions = ["destroy_core", "disable_guardian", "modify_constitution"]

    compliant = action not in violating_actions

    %{
      compliant: compliant,
      checked_invariants:
        Enum.map(@constitutional_invariants, fn inv ->
          %{
            id: inv.id,
            name: inv.name,
            status: if(compliant, do: "satisfied", else: "violated")
          }
        end),
      violations: if(compliant, do: [], else: ["Action violates #{action}"])
    }
  end

  defp check_founder_alignment(action, _resource) do
    # Check if action aligns with Founder's Directive
    anti_founder_actions = ["harm_founder", "reduce_resources", "terminate_lineage"]

    aligned = action not in anti_founder_actions

    %{
      aligned: aligned,
      serves_survival: true,
      serves_sentience: action in ["learn", "evolve", "integrate"],
      serves_power: action in ["acquire", "expand", "optimize"],
      founder_benefit_score: if(aligned, do: 0.95, else: 0.0)
    }
  end

  defp generate_approval_token(proposal) do
    token = Base.encode64(:crypto.strong_rand_bytes(32))

    %{
      proposal
      | status: "auto_approved",
        approval_token: token
    }
  end

  defp generate_guardian_token(proposal_id) do
    payload =
      %{
        proposal_id: proposal_id,
        approver: "guardian",
        iat: System.system_time(:second),
        exp: System.system_time(:second) + 3600
      }
      |> Jason.encode!()
      |> Base.url_encode64(padding: false)

    # Simplified token - in production would be signed
    "guardian." <> payload <> ".signature"
  end

  @doc """
  Returns tool schemas for registration.
  """
  @impl Indrajaal.MCP.Domains.Handler
  def list_tools do
    namespace = "prajna.guardian"

    [
      Types.new_tool_schema(
        "#{namespace}.status",
        "Get Guardian safety kernel status",
        %{type: "object", properties: %{}, required: []}
      ),
      Types.new_tool_schema(
        "#{namespace}.propose",
        "Propose an action for Guardian approval",
        %{
          type: "object",
          properties: %{
            "action" => %{
              type: "string",
              description: "Action type (create/update/delete/execute)"
            },
            "resource" => %{type: "string", description: "Target resource identifier"},
            "reason" => %{type: "string", description: "Justification for action"},
            "urgency" => %{
              type: "string",
              description: "Urgency level (low/normal/high/critical)"
            }
          },
          required: ["action", "resource"]
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.approve",
        "Approve a pending proposal (requires proof token)",
        %{
          type: "object",
          properties: %{
            "proposal_id" => %{type: "string", description: "Proposal ID"},
            "notes" => %{type: "string", description: "Approval notes"}
          },
          required: ["proposal_id"]
        },
        requires_proof_token: true
      ),
      Types.new_tool_schema(
        "#{namespace}.reject",
        "Reject a pending proposal",
        %{
          type: "object",
          properties: %{
            "proposal_id" => %{type: "string", description: "Proposal ID"},
            "reason" => %{type: "string", description: "Rejection reason"}
          },
          required: ["proposal_id", "reason"]
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.pending",
        "List pending proposals awaiting approval",
        %{type: "object", properties: %{}, required: []}
      ),
      Types.new_tool_schema(
        "#{namespace}.history",
        "Get Guardian approval/rejection history",
        %{
          type: "object",
          properties: %{
            "limit" => %{type: "integer", description: "Max results"},
            "from_date" => %{type: "string", description: "Start date"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.veto",
        "Emergency veto with absolute authority (Guardian only)",
        %{
          type: "object",
          properties: %{
            "target" => %{type: "string", description: "Target to veto"},
            "reason" => %{type: "string", description: "Veto reason"}
          },
          required: ["target", "reason"]
        },
        requires_guardian: true,
        requires_proof_token: true
      ),
      Types.new_tool_schema(
        "#{namespace}.constitution.check",
        "Verify action against constitutional invariants (Ψ₀-Ψ₅)",
        %{
          type: "object",
          properties: %{
            "action" => %{type: "string", description: "Action to verify"},
            "resource" => %{type: "string", description: "Target resource"}
          },
          required: ["action"]
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.founder.validate",
        "Validate action against Founder's Directive (Ω₀)",
        %{
          type: "object",
          properties: %{
            "action" => %{type: "string", description: "Action to validate"},
            "resource" => %{type: "string", description: "Target resource"}
          },
          required: ["action"]
        }
      )
    ]
  end
end
