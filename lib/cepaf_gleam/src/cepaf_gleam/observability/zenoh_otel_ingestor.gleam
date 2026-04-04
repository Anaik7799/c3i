// STAMP: SC-ZENOH-OTEL-001, SC-OBS-001
// AOR: AOR-GLM-001
// Criticality: Level 2 (HIGH) - Zenoh OTel Ingestor

import cepaf_gleam/zenoh/client as zenoh
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/result

pub type State {
  State(session: zenoh.Session)
}

pub type Message {
  ZenohMessage(topic: String, payload: String)
}

const span_topic_prefix = "indrajaal/otel/span/"

pub fn start(session: zenoh.Session) -> Result(Subject(Message), actor.StartError) {
  actor.new(State(session: session))
  |> actor.on_message(handle_message)
  |> actor.start()
  |> result.map(fn(started) {
    let subject = started.data
    let assert Ok(pid) = process.subject_owner(subject)
    let _ = zenoh.subscribe(
      session,
      span_topic_prefix <> "**",
      pid,
    )
    subject
  })
}

fn handle_message(state: State, msg: Message) -> actor.Next(State, Message) {
  case msg {
    ZenohMessage(_topic, payload) -> {
      let _ = process_span(payload)
      actor.continue(state)
    }
  }
}

fn process_span(_payload: String) -> Result(Nil, Nil) {
  // TODO: Implement actual JSON parsing using gleam/dynamic/decode
  Ok(Nil)
}

pub fn receive_zenoh_message(
  subject: Subject(Message),
  topic: String,
  payload: String,
) {
  process.send(subject, ZenohMessage(topic, payload))
}
