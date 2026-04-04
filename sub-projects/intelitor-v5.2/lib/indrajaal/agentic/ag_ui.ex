defmodule Indrajaal.Agentic.AgUI do
  @moduledoc """
  AG-UI Protocol Implementation for Indrajaal.

  Implements the 13 AG-UI building blocks using Phoenix PubSub as the
  event transport layer, mapping the AG-UI specification to BEAM primitives.

  ## AG-UI Building Blocks → Phoenix Mapping

  | AG-UI Block | Phoenix Implementation |
  |-------------|----------------------|
  | Streaming chat | PubSub broadcast + LiveView handle_info |
  | Multimodality | File attachments + Audio API |
  | Generative UI (static) | Dynamic HEEx component rendering |
  | Generative UI (declarative) | Component tree from AI → LiveView mount |
  | Shared state | ETS table + PubSub diff broadcast |
  | Thinking steps | Trace event stream to LiveView |
  | Frontend tool calls | phx-click → GenServer → action |
  | Backend tool rendering | Podman output → styled component |
  | Interrupts (HITL) | Modal with approve/reject + state pause |
  | Sub-agents | Task.Supervisor for parallel checks |
  | Agent steering | Runtime config via PubSub message |
  | Tool output streaming | LiveView Streams for long-running ops |
  | Custom events | PubSub topics for domain events |

  ## Fractal Position
  - Layer: L5-Cognitive (Agent-User Interaction)
  - Element: Protocol / Communication
  - STAMP: SC-HMI-010, SC-SAFETY-001, SC-MON-001

  ## Source: https://docs.ag-ui.com/introduction
  """

  alias Phoenix.PubSub

  @pubsub Indrajaal.PubSub

  # ═══════════════════════════════════════════════════════════════════════
  # AG-UI Event Types
  # ═══════════════════════════════════════════════════════════════════════

  @type event_type ::
          :streaming
          | :thinking_step
          | :tool_output
          | :interrupt
          | :state_update
          | :custom
          | :generative_ui

  @type ag_event :: %{
          type: event_type(),
          topic: String.t(),
          payload: map(),
          timestamp: DateTime.t(),
          trace_id: String.t() | nil
        }

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 1: Streaming
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Stream a message token-by-token to all subscribers.
  AG-UI "Streaming chat" — live token and event streaming.

  ## Example
      AgUI.stream("ignition:progress", %{container: "zenoh-router-1", status: "starting"})
  """
  def stream(topic, payload) when is_binary(topic) and is_map(payload) do
    broadcast(
      topic,
      {:ag_stream,
       %{
         type: :streaming,
         payload: payload,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 5: Shared State
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Update shared state and broadcast diff to all subscribers.
  AG-UI "Shared state" — typed store shared between agent and app.
  Uses ETS for persistence, PubSub for real-time sync.
  """
  def update_shared_state(key, value) do
    old_value = get_shared_state(key)
    :ets.insert(:ag_ui_state, {key, value, DateTime.utc_now()})

    broadcast(
      "ag_ui:state",
      {:ag_state_update,
       %{
         key: key,
         old_value: old_value,
         new_value: value,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  def get_shared_state(key) do
    case :ets.lookup(:ag_ui_state, key) do
      [{^key, value, _ts}] -> value
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc """
  Initialize the shared state ETS table.
  Called from Application.start/2.
  """
  def init_shared_state do
    :ets.new(:ag_ui_state, [:named_table, :public, :set, read_concurrency: true])
  rescue
    # Table already exists
    ArgumentError -> :ok
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 6: Thinking Steps
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Emit a thinking step — intermediate reasoning from the agent.
  AG-UI "Thinking steps" — visualize intermediate reasoning.

  ## Example
      AgUI.thinking_step("preflight", "PF-2", "Checking pg_isready", :in_progress)
      AgUI.thinking_step("preflight", "PF-2", "pg_isready → exit 0 (230ms)", :pass)
  """
  def thinking_step(phase, step_id, message, status) do
    broadcast(
      "ag_ui:thinking",
      {:ag_thinking,
       %{
         phase: phase,
         step_id: step_id,
         message: message,
         status: status,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 9: Interrupts (Human-in-the-Loop)
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Request human approval for an action.
  AG-UI "Interrupts" — pause, approve, reject mid-flow.
  SC-SAFETY-001: Arm & Fire for destructive actions.

  Returns a unique interrupt_id that the UI uses to respond.
  """
  def request_approval(action, context, severity \\ :normal) do
    interrupt_id = Ecto.UUID.generate()

    broadcast(
      "ag_ui:interrupt",
      {:ag_interrupt,
       %{
         id: interrupt_id,
         action: action,
         context: context,
         severity: severity,
         status: :pending,
         timestamp: DateTime.utc_now()
       }}
    )

    interrupt_id
  end

  @doc """
  Respond to an interrupt (approve/reject).
  """
  def respond_to_interrupt(interrupt_id, decision) when decision in [:approve, :reject, :defer] do
    broadcast(
      "ag_ui:interrupt",
      {:ag_interrupt_response,
       %{
         id: interrupt_id,
         decision: decision,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 8: Backend Tool Rendering
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Emit a tool output event for rendering in the dashboard.
  AG-UI "Backend tool rendering" — visualize backend tool outputs.
  """
  def tool_output(tool_name, output, metadata \\ %{}) do
    broadcast(
      "ag_ui:tool",
      {:ag_tool_output,
       %{
         tool: tool_name,
         output: output,
         metadata: metadata,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 11: Agent Steering
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Send a steering command to redirect agent execution.
  AG-UI "Agent steering" — dynamically redirect agent execution.
  """
  def steer(target, command, params \\ %{}) do
    broadcast(
      "ag_ui:steer",
      {:ag_steer,
       %{
         target: target,
         command: command,
         params: params,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Building Block 13: Custom Events
  # ═══════════════════════════════════════════════════════════════════════

  @doc """
  Emit a custom domain event.
  AG-UI "Custom events" — open-ended data exchange.
  """
  def custom_event(event_name, payload) do
    broadcast(
      "ag_ui:custom:#{event_name}",
      {:ag_custom,
       %{
         event: event_name,
         payload: payload,
         timestamp: DateTime.utc_now()
       }}
    )
  end

  # ═══════════════════════════════════════════════════════════════════════
  # Helpers
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Subscribe to an AG-UI topic."
  def subscribe(topic) do
    PubSub.subscribe(@pubsub, topic)
  end

  defp broadcast(topic, message) do
    PubSub.broadcast(@pubsub, topic, message)
  end
end
