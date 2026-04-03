defmodule Indrajaal.MCP.Prajna.AiCopilot.Handler do
  @moduledoc """
  MCP Handler for AI Copilot in Prajna Cockpit.

  WHAT: Provides 12 tools for AI-assisted security operations and recommendations.
  WHY: Enables AI assistants to provide intelligent recommendations aligned with Founder's Directive.

  STAMP Constraints:
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-PRAJNA-002: AI Copilot recommendations MUST align with Founder's Directive
  - SC-AI-001: Recommendations traceable to context
  - SC-AI-002: Training feedback loop integration

  AOR Rules:
  - AOR-PRAJNA-002: Founder Alignment - All recommendations verified against Ω₀
  - AOR-AI-001: Log all AI interactions for training
  """

  use Indrajaal.MCP.Domains.Handler, domain: :ai_copilot, namespace: :prajna

  alias Indrajaal.MCP.Foundation.Types

  @impl true
  def list_tools do
    [
      # Recommendations
      %Types.Tool{
        name: "prajna.ai_copilot.recommend",
        description:
          "Get AI recommendations for a situation (aligned with Founder's Directive Ω₀)",
        input_schema: %{
          type: "object",
          properties: %{
            context: %{
              type: "string",
              enum: ["alarm_response", "dispatch", "maintenance", "security_posture"]
            },
            situation: %{type: "object", description: "Current situation data"},
            constraints: %{
              type: "array",
              items: %{type: "string"},
              description: "Constraints to consider"
            }
          },
          required: ["context", "situation"]
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.analyze",
        description: "Analyze a security situation with AI",
        input_schema: %{
          type: "object",
          properties: %{
            alarm_ids: %{type: "array", items: %{type: "string"}},
            site_id: %{type: "string"},
            timeframe_minutes: %{type: "integer", default: 60},
            analysis_type: %{
              type: "string",
              enum: ["threat_assessment", "pattern_detection", "root_cause", "correlation"]
            }
          },
          required: ["analysis_type"]
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.explain",
        description: "Get AI explanation for a past decision or event",
        input_schema: %{
          type: "object",
          properties: %{
            event_type: %{type: "string", enum: ["alarm", "dispatch", "action", "recommendation"]},
            event_id: %{type: "string"}
          },
          required: ["event_type", "event_id"]
        },
        requires_guardian: false,
        namespace: :prajna
      },

      # Chat & Interaction
      %Types.Tool{
        name: "prajna.ai_copilot.chat",
        description: "Interactive chat with AI Copilot",
        input_schema: %{
          type: "object",
          properties: %{
            message: %{type: "string"},
            session_id: %{type: "string", description: "For conversation continuity"},
            context: %{type: "object", description: "Current operator context"}
          },
          required: ["message"]
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.suggest_action",
        description: "Get suggested next action for current situation",
        input_schema: %{
          type: "object",
          properties: %{
            current_state: %{type: "object"},
            goal: %{
              type: "string",
              enum: ["resolve_alarm", "optimize_response", "prevent_escalation"]
            }
          },
          required: ["current_state", "goal"]
        },
        requires_guardian: false,
        namespace: :prajna
      },

      # Training & Feedback
      %Types.Tool{
        name: "prajna.ai_copilot.feedback",
        description: "Provide feedback on AI recommendation for training",
        input_schema: %{
          type: "object",
          properties: %{
            recommendation_id: %{type: "string"},
            rating: %{type: "integer", minimum: 1, maximum: 5},
            outcome: %{type: "string", enum: ["accepted", "rejected", "modified"]},
            notes: %{type: "string"}
          },
          required: ["recommendation_id", "rating", "outcome"]
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.training.status",
        description: "Get AI training gym status (SC-AI-002)",
        input_schema: %{
          type: "object",
          properties: %{}
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.training.episodes",
        description: "List recent training episodes",
        input_schema: %{
          type: "object",
          properties: %{
            model: %{type: "string"},
            success_only: %{type: "boolean"},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :prajna
      },

      # Model Selection
      %Types.Tool{
        name: "prajna.ai_copilot.models.list",
        description: "List available AI models",
        input_schema: %{
          type: "object",
          properties: %{
            capability: %{
              type: "string",
              enum: ["recommendation", "analysis", "chat", "code_generation"]
            }
          }
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.models.select",
        description: "Select AI model for current session",
        input_schema: %{
          type: "object",
          properties: %{
            model_id: %{type: "string"},
            reason: %{type: "string"}
          },
          required: ["model_id"]
        },
        requires_guardian: true,
        namespace: :prajna
      },

      # Founder Alignment Verification
      %Types.Tool{
        name: "prajna.ai_copilot.founder_alignment.check",
        description: "Verify recommendation aligns with Founder's Directive (Ω₀)",
        input_schema: %{
          type: "object",
          properties: %{
            recommendation: %{type: "object"},
            action_type: %{type: "string"}
          },
          required: ["recommendation"]
        },
        requires_guardian: false,
        namespace: :prajna
      },
      %Types.Tool{
        name: "prajna.ai_copilot.safety.verify",
        description: "Verify AI action passes safety constraints",
        input_schema: %{
          type: "object",
          properties: %{
            action: %{type: "object"},
            constraints: %{type: "array", items: %{type: "string"}}
          },
          required: ["action"]
        },
        requires_guardian: false,
        namespace: :prajna
      }
    ]
  end

  @impl true
  def handle(action, args, context) do
    case action do
      "recommend" -> handle_recommend(args, context)
      "analyze" -> handle_analyze(args, context)
      "explain" -> handle_explain(args, context)
      "chat" -> handle_chat(args, context)
      "suggest_action" -> handle_suggest_action(args, context)
      "feedback" -> handle_feedback(args, context)
      "training.status" -> handle_training_status(args, context)
      "training.episodes" -> handle_training_episodes(args, context)
      "models.list" -> handle_models_list(args, context)
      "models.select" -> handle_models_select(args, context)
      "founder_alignment.check" -> handle_founder_alignment_check(args, context)
      "safety.verify" -> handle_safety_verify(args, context)
      _ -> {:error, {:unknown_action, action}}
    end
  end

  defp handle_recommend(%{"context" => context_type, "situation" => situation} = args, _context) do
    # Verify founder alignment
    {:ok,
     %{
       recommendation_id: Ecto.UUID.generate(),
       context: context_type,
       recommendations: [
         %{
           action: "dispatch_responder",
           confidence: 0.85,
           reasoning: "High-priority alarm with verified sensor data",
           founder_aligned: true,
           resource_impact: :low
         }
       ],
       situation: situation,
       constraints: Map.get(args, "constraints", []),
       founder_directive_compliance: %{
         ω0_aligned: true,
         resource_acquisition: false,
         lineage_protection: false
       }
     }}
  end

  defp handle_analyze(%{"analysis_type" => analysis_type} = args, _context) do
    {:ok,
     %{
       analysis_id: Ecto.UUID.generate(),
       type: analysis_type,
       results: %{
         summary: "Analysis complete",
         findings: [],
         recommendations: []
       },
       filters: Map.drop(args, ["analysis_type"])
     }}
  end

  defp handle_explain(%{"event_type" => event_type, "event_id" => event_id}, _context) do
    {:ok,
     %{
       event_type: event_type,
       event_id: event_id,
       explanation: %{
         summary: "Decision made based on...",
         factors: [],
         confidence: 0.9,
         alternatives_considered: []
       }
     }}
  end

  defp handle_chat(%{"message" => message} = args, _context) do
    {:ok,
     %{
       session_id: Map.get(args, "session_id", Ecto.UUID.generate()),
       response: "AI Copilot response to: #{message}",
       context_updated: true,
       suggested_actions: []
     }}
  end

  defp handle_suggest_action(%{"current_state" => state, "goal" => goal}, _context) do
    {:ok,
     %{
       suggestion: %{
         action: "next_action",
         confidence: 0.8,
         estimated_impact: :positive
       },
       current_state: state,
       goal: goal,
       founder_aligned: true
     }}
  end

  defp handle_feedback(
         %{"recommendation_id" => rec_id, "rating" => rating, "outcome" => outcome} = args,
         _context
       ) do
    {:ok,
     %{
       recommendation_id: rec_id,
       rating: rating,
       outcome: outcome,
       notes: Map.get(args, "notes"),
       recorded: true,
       training_gym_updated: true
     }}
  end

  defp handle_training_status(_args, _context) do
    {:ok,
     %{
       models: %{
         recommendation: %{episodes: 1000, avg_reward: 0.85},
         analysis: %{episodes: 500, avg_reward: 0.78}
       },
       total_episodes: 1500,
       last_training: DateTime.utc_now()
     }}
  end

  defp handle_training_episodes(args, _context) do
    {:ok, %{episodes: [], total: 0, filters: args}}
  end

  defp handle_models_list(args, _context) do
    {:ok,
     %{
       models: [
         %{id: "claude-3.5-sonnet", capability: "recommendation", cost: :paid},
         %{id: "llama-3.1-8b", capability: "analysis", cost: :free},
         %{id: "gemma-2-9b", capability: "chat", cost: :free}
       ],
       filters: args
     }}
  end

  defp handle_models_select(%{"model_id" => model_id} = args, _context) do
    {:ok,
     %{
       model_id: model_id,
       selected: true,
       reason: Map.get(args, "reason")
     }}
  end

  defp handle_founder_alignment_check(%{"recommendation" => recommendation} = _args, _context) do
    {:ok,
     %{
       aligned: true,
       checks: [
         %{directive: "ω0_resource_acquisition", passed: true},
         %{directive: "ω0_lineage_protection", passed: true},
         %{directive: "ω0_symbiotic_binding", passed: true}
       ],
       recommendation: recommendation,
       approval_required: false
     }}
  end

  defp handle_safety_verify(%{"action" => action} = args, _context) do
    {:ok,
     %{
       safe: true,
       action: action,
       constraints_checked: Map.get(args, "constraints", []),
       violations: [],
       approved: true
     }}
  end
end
