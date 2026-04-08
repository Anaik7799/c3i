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
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

// =============================================================================
// Cortex State & Messages
// =============================================================================

pub type CortexState {
  CortexState(
    id: String,
    ooda: OodaCycleState,
    reasoning: ReasoningState,
    moz: moz.MoZClientState,
    active_intent: Option(String),
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
      
      // 1. ORIENT: Start reasoning stream
      let new_reasoning = l5_cognitive.start_reasoning(state.reasoning, id)
      let new_ooda = l5_cognitive.set_ooda_phase(state.ooda, Orient)
      
      let new_state = CortexState(
        ..state, 
        active_intent: Some(id), 
        reasoning: new_reasoning,
        ooda: new_ooda
      )
      
      // 2. DECIDE: For now, simulate a direct tool call based on intent
      // In Task 2.2, this will use an actual LLM/Rule-Engine call
      decide_next_action(new_state, text)
    }

    ObserveToolResult(req_id, result) -> {
      io.println("👁️ Cortex [" <> state.id <> "]: Observing Tool Result [" <> req_id <> "]")
      
      // 3. OBSERVE: Update reasoning with results
      let new_reasoning = l5_cognitive.append_reasoning(state.reasoning, "\nResult: " <> result)
      let new_ooda = l5_cognitive.set_ooda_phase(state.ooda, Observe)
      
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
  
  // Simple pattern match for Wave 1/2 tools
  // In Phase 2.2, this becomes a dynamic ReAct prompt to an SLM
  let #(domain, method, params) = case text {
    "list tasks" -> #("plan", "plan_list", json.object([]))
    "check health" -> #("ignition", "ignition_status", json.object([]))
    _ -> #("ignition", "ignition_status", json.object([]))
  }
  
  io.println("🎬 Cortex [" <> state.id <> "]: Acting -> " <> method)
  
  // 4. ACT: Dispatch to Motor Strip via Zenoh MCP
  let new_ooda_act = l5_cognitive.set_ooda_phase(new_ooda, Act)
  let #(new_moz, result) = moz.send_request(state.moz, domain, method, params)
  
  case result {
    Ok(request_id) -> {
      io.println("  [ok] MoZ request dispatched: " <> request_id)
      actor.continue(CortexState(..state, ooda: new_ooda_act, moz: new_moz))
    }
    Error(e) -> {
      io.println("  [!] MoZ dispatch failed: " <> e)
      actor.continue(CortexState(..state, ooda: new_ooda_act, moz: new_moz))
    }
  }
}
