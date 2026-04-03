//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/ui/lustre/effects</module></identity>
////   <fractal-topology><layer>L4_SYSTEM</layer></fractal-topology>
////   <compliance><stamp-controls>SC-AGUI-014, SC-AGUI-017</stamp-controls></compliance>
//// </c3i-module>
////
//// AG-UI effect catalog for Lustre applications.
//// Maps AG-UI operations to Lustre effect.from() pattern.
//// Uses effect.batch() for parallel agent subscriptions (SC-AGUI-017).
//// STAMP: SC-AGUI-014, SC-AGUI-017

import gleam/json

/// AG-UI effect descriptor — describes an effect to be performed.
/// These are DATA describing side effects, not executed immediately.
/// The Lustre runtime executes them and dispatches resulting messages.
pub type AgUiEffect {
  /// Subscribe to an agent's event stream
  SubscribeAgent(agent_id: String, topics: List(String))
  /// Start an agent run
  StartRun(agent_id: String, input: String, thread_id: String)
  /// Send tool result back to agent
  SendToolResult(tool_call_id: String, result: String)
  /// Send HITL approval decision
  SendHitlDecision(request_id: String, decision: HitlDecision)
  /// Request A2UI component generation
  RequestGenerativeUI(context: json.Json)
  /// Subscribe to Zenoh topic for telemetry
  SubscribeZenoh(topic: String)
  /// Unsubscribe from Zenoh topic
  UnsubscribeZenoh(topic: String)
  /// Publish to Zenoh topic
  PublishZenoh(topic: String, payload: json.Json)
  /// No effect (identity)
  NoEffect
  /// Batch multiple effects
  BatchEffects(effects: List(AgUiEffect))
}

/// HITL decision types.
pub type HitlDecision {
  Approved
  Rejected
  Escalated
  Edited(new_value: String)
}

/// Create a subscribe-to-agent effect.
pub fn subscribe_agent(agent_id: String) -> AgUiEffect {
  SubscribeAgent(agent_id, ["c3i/agui/events/" <> agent_id])
}

/// Create a start-run effect.
pub fn start_run(agent_id: String, input: String) -> AgUiEffect {
  StartRun(agent_id, input, "")
}

/// Create a tool result effect.
pub fn send_tool_result(tool_call_id: String, result: String) -> AgUiEffect {
  SendToolResult(tool_call_id, result)
}

/// Create an HITL approval effect.
pub fn approve(request_id: String) -> AgUiEffect {
  SendHitlDecision(request_id, Approved)
}

/// Create an HITL rejection effect.
pub fn reject(request_id: String) -> AgUiEffect {
  SendHitlDecision(request_id, Rejected)
}

/// Create a Zenoh subscription effect.
pub fn subscribe_zenoh(topic: String) -> AgUiEffect {
  SubscribeZenoh(topic)
}

/// Create a batch of effects for parallel execution (SC-AGUI-017).
pub fn batch(effects: List(AgUiEffect)) -> AgUiEffect {
  BatchEffects(effects)
}

/// No-op effect.
pub fn none() -> AgUiEffect {
  NoEffect
}

/// Serialize an HITL decision to string.
pub fn decision_to_string(decision: HitlDecision) -> String {
  case decision {
    Approved -> "approved"
    Rejected -> "rejected"
    Escalated -> "escalated"
    Edited(v) -> "edited:" <> v
  }
}

/// Serialize effect to JSON for Wisp API dispatch.
pub fn effect_to_json(eff: AgUiEffect) -> json.Json {
  case eff {
    SubscribeAgent(id, topics) ->
      json.object([
        #("type", json.string("subscribe_agent")),
        #("agent_id", json.string(id)),
        #("topics", json.array(topics, json.string)),
      ])
    StartRun(id, input, tid) ->
      json.object([
        #("type", json.string("start_run")),
        #("agent_id", json.string(id)),
        #("input", json.string(input)),
        #("thread_id", json.string(tid)),
      ])
    SendToolResult(tcid, result) ->
      json.object([
        #("type", json.string("tool_result")),
        #("tool_call_id", json.string(tcid)),
        #("result", json.string(result)),
      ])
    SendHitlDecision(rid, decision) ->
      json.object([
        #("type", json.string("hitl_decision")),
        #("request_id", json.string(rid)),
        #("decision", json.string(decision_to_string(decision))),
      ])
    RequestGenerativeUI(ctx) ->
      json.object([
        #("type", json.string("request_generative_ui")),
        #("context", ctx),
      ])
    SubscribeZenoh(topic) ->
      json.object([
        #("type", json.string("subscribe_zenoh")),
        #("topic", json.string(topic)),
      ])
    UnsubscribeZenoh(topic) ->
      json.object([
        #("type", json.string("unsubscribe_zenoh")),
        #("topic", json.string(topic)),
      ])
    PublishZenoh(topic, payload) ->
      json.object([
        #("type", json.string("publish_zenoh")),
        #("topic", json.string(topic)),
        #("payload", payload),
      ])
    NoEffect -> json.object([#("type", json.string("none"))])
    BatchEffects(effs) ->
      json.object([
        #("type", json.string("batch")),
        #("effects", json.array(effs, effect_to_json)),
      ])
  }
}
