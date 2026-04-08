//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/agents/cortex</module>
////   <fsharp-lineage>Cepaf.Agents.Cortex</fsharp-lineage></identity>
////   <fractal-topology><layer>L5_COGNITIVE</layer></fractal-topology>
////   <compliance><stamp-controls>SC-COG-001, SC-ZMOF-001</stamp-controls></compliance>
//// </c3i-module>
////
//// Prefrontal Cortex — The Seat of Swarm Consciousness (ReAct Loop).
//// Orchestrates MCP tool calls via Zenoh MoZ to achieve User Goals.

import cepaf_gleam/fractal/l5_cognitive.{
  type OodaCycleState, type ReasoningState, Act, Decide, Observe, Orient,
}
import cepaf_gleam/moz/client as moz
import cepaf_gleam/telemetry/otel.{type SpanContext}
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

// =============================================================================
// Cortex State & Messages
// =============================================================================

pub type EventLogEntry {
  EventLogEntry(
    id: String,
    timestamp: String,
    agent_id: String,
    intent_id: Option(String),
    action: String,
    payload: Option(String),
    result: Option(String),
    status: String,
  )
}

pub type CortexState {
  CortexState(
    id: String,
    ooda: OodaCycleState,
    reasoning: ReasoningState,
    moz: moz.MoZClientState,
    active_intent: Option(String),
    memory: List(EventLogEntry),
    span_ctx: Option(SpanContext),
  )
}

pub type CortexMessage {
  /// Ingest a new User Intent stimuli.
  ProcessIntent(id: String, raw_text: String)
  /// Observe the result of an MCP tool call.
  ObserveToolResult(request_id: String, result: String)
  /// Internal tick for the OODA cycle.
  OodaTick
}

// =============================================================================
// ReAct Loop Implementation (Task 2.1)
// =============================================================================

pub fn start(id: String) -> Result(actor.Started(Subject(CortexMessage)), actor.StartError) {
  let initial_state =
    CortexState(
      id: id,
      ooda: l5_cognitive.initial_ooda(),
      reasoning: l5_cognitive.initial_reasoning(),
      moz: moz.new(),
      active_intent: None,
      memory: [],
      span_ctx: None,
    )

  actor.new(initial_state)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(
  state: CortexState,
  msg: CortexMessage,
) -> actor.Next(CortexState, CortexMessage) {
  case msg {
    ProcessIntent(id, text) -> {
      io.println("🧠 Cortex [" <> state.id <> "]: Ingesting Intent -> " <> id)

      // 1. ORIENT: Fetch context, preferences, and start reasoning stream
      let memory = fetch_context(state.moz)
      let voice_pref = fetch_preference(state.moz, "executive_voice")
      let new_reasoning = l5_cognitive.start_reasoning(state.reasoning, id)
      let new_ooda = l5_cognitive.set_ooda_phase(state.ooda, Orient)

      // 1.1 TELEMETRY: Start a new recursive span for this intent
      let ctx = otel.generate_context(state.span_ctx)
      otel.start_span(["cepaf", "cortex", "intent"], dict.new(), Some(ctx))

      let new_state = CortexState(
        ..state, 
        active_intent: Some(id), 
        reasoning: new_reasoning,
        ooda: new_ooda,
        memory: memory,
        span_ctx: Some(ctx)
      )

      // 1.2 PERSONA INJECTION: Use voice preference if available
      let text_with_persona = case voice_pref {
        Some(voice) -> "Persona[" <> voice <> "]: " <> text
        None -> text
      }

      // 2. DECIDE
      decide_next_action(new_state, text_with_persona)
    }

    ObserveToolResult(req_id, result) -> {
      io.println("👁️ Cortex [" <> state.id <> "]: Observing Tool Result [" <> req_id <> "]")

      // 3. OBSERVE: Update reasoning with results
      let new_reasoning = l5_cognitive.append_reasoning(state.reasoning, "\nResult: " <> result)
      let new_ooda = l5_cognitive.set_ooda_phase(state.ooda, Observe)

      // 3.1 TELEMETRY: Close intent span
      otel.stop_span(["cepaf", "cortex", "intent"], 0.0, dict.new(), state.span_ctx)

      actor.continue(CortexState(..state, reasoning: new_reasoning, ooda: new_ooda))
    }

    OodaTick -> {
      // Periodic OODA cycle maintenance
      actor.continue(state)
    }
  }
}

fn decide_next_action(state: CortexState, text: String) -> actor.Next(CortexState, CortexMessage) {
  let new_ooda = l5_cognitive.set_ooda_phase(state.ooda, Decide)
  
  // 2.1 CONTEXTUAL AWARENESS: Inject summarized memory into logic
  let context_summary = summarize_memory(state.memory)
  io.println("🧠 Cortex Context: " <> context_summary)

  // Simple pattern match for Wave 1/2 tools
  let #(domain, method, params) = case text {
    "list tasks" -> #("plan", "plan_list", json.object([]))
    "check health" -> #("ignition", "ignition_status", json.object([]))
    _ -> #("ignition", "ignition_status", json.object([]))
  }
  
  io.println("🎬 Cortex [" <> state.id <> "]: Acting -> " <> method)
  
  // 4. ACT: Dispatch to Motor Strip via Zenoh MCP
  let new_ooda_act = l5_cognitive.set_ooda_phase(new_ooda, Act)
  
  // 4.1 TELEMETRY: Trace the tool call
  let tool_ctx = otel.generate_context(state.span_ctx)
  otel.start_span(["cepaf", "cortex", "tool"], dict.from_list([#("method", method)]), Some(tool_ctx))

  // Inject span context into MCP params for recursive tracing in Rust
  let params_with_ctx = case params {
    _ -> {
      // In a real implementation, we'd merge the trace_id into the JSON object
      params
    }
  }

  let #(new_moz, result) = moz.send_request(state.moz, domain, method, params_with_ctx)
  
  // 4.2 EPISODIC LOGGING: Record the action decision
  let _ = log_cortex_action(state, method, "dispatched")

  case result {
    Ok(request_id) -> {
      io.println("  [ok] MoZ request dispatched: " <> request_id)
      otel.stop_span(["cepaf", "cortex", "tool"], 0.0, dict.new(), Some(tool_ctx))
      actor.continue(CortexState(..state, ooda: new_ooda_act, moz: new_moz))
    }
    Error(e) -> {
      io.println("  [!] MoZ dispatch failed: " <> e)
      otel.error_span(["cepaf", "cortex", "tool"], 0.0, e, dict.new(), Some(tool_ctx))
      actor.continue(CortexState(..state, ooda: new_ooda_act, moz: new_moz))
    }
  }
}

fn fetch_context(moz_state: moz.MoZClientState) -> List(EventLogEntry) {
  case moz.send_query(moz_state, "plan", "list_events") {
    #(_, Ok(payload)) -> {
      case parse_event_list(payload) {
        Ok(events) -> events
        Error(_) -> []
      }
    }
    _ -> []
  }
}

fn fetch_preference(moz_state: moz.MoZClientState, key: String) -> Option(String) {
  let _params = json.object([#("key", json.string(key))])
  // Standard MoZ query for a single preference
  case moz.send_query(moz_state, "plan", "plan_get_pref") {
    #(_, Ok(payload)) -> {
      // Decode Option(String) result from McpResponse
      let decoder = {
        use result <- decode.field("result", decode.optional(decode.string))
        decode.success(result)
      }
      case json.parse(from: payload, using: decoder) {
        Ok(val) -> val
        Error(_) -> None
      }
    }
    _ -> None
  }
}

fn parse_event_list(payload: String) -> Result(List(EventLogEntry), String) {
  let event_decoder = {
    use id <- decode.field("id", decode.string)
    use timestamp <- decode.field("timestamp", decode.string)
    use agent_id <- decode.field("agent_id", decode.string)
    use intent_id <- decode.optional_field("intent_id", None, decode.optional(decode.string))
    use action <- decode.field("action", decode.string)
    use payload_field <- decode.optional_field("payload", None, decode.optional(decode.string))
    use result <- decode.optional_field("result", None, decode.optional(decode.string))
    use status <- decode.field("status", decode.string)

    decode.success(EventLogEntry(
      id: id,
      timestamp: timestamp,
      agent_id: agent_id,
      intent_id: intent_id,
      action: action,
      payload: payload_field,
      result: result,
      status: status,
    ))
  }

  let response_decoder = {
    use result <- decode.field("result", decode.list(event_decoder))
    decode.success(result)
  }

  case json.parse(from: payload, using: response_decoder) {
    Ok(events) -> Ok(events)
    Error(_) -> Error("Failed to decode Event log")
  }
}

fn summarize_memory(memory: List(EventLogEntry)) -> String {
  case list.length(memory) {
    0 -> "No previous events."
    n -> "Last " <> int_to_string(n) <> " actions performed successfully."
  }
}

fn log_cortex_action(state: CortexState, action: String, status: String) {
  let params = json.object([
    #("agent_id", json.string(state.id)),
    #("action", json.string(action)),
    #("status", json.string(status)),
    #("intent_id", case state.active_intent {
      Some(id) -> json.string(id)
      None -> json.null()
    })
  ])
  let _ = moz.send_request(state.moz, "plan", "plan_log", params)
  Nil
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String
