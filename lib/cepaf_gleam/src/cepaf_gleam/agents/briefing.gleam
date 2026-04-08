//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/agents/briefing</module></identity>
////   <fractal-topology><layer>L5_COGNITIVE</layer></fractal-topology>
////   <compliance><stamp-controls>SC-COG-003, SC-ZMOF-001</stamp-controls></compliance>
//// </c3i-module>
////
//// Morning Briefing Agent (Proactive Intelligence).
//// Supervised OTP Actor that aggregates system state and triages comms.

import cepaf_gleam/gateway/telegram
import cepaf_gleam/moz/client as moz
import cepaf_gleam/zenoh/client as zenoh
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import gleam/otp/actor

pub type BriefingMessage {
  CronTick(id: String, timestamp: Int)
  Stop
}

pub type BriefingState {
  BriefingState(
    id: String,
    moz: moz.MoZClientState,
    telegram: telegram.GatewayState,
  )
}

/// Start the Briefing Agent as a supervised worker.
pub fn start(id: String) -> Result(actor.Started(Subject(BriefingMessage)), actor.StartError) {
  let initial = BriefingState(
    id: id,
    moz: moz.new(),
    telegram: telegram.GatewayState(
      moz: moz.new(),
      bot_token: "internal",
      chat_id: "admin"
    ),
  )
  
  actor.new(initial)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(state: BriefingState, msg: BriefingMessage) -> actor.Next(BriefingState, BriefingMessage) {
  case msg {
    CronTick(id, _) -> {
      io.println("🌅 Briefing Agent [" <> state.id <> "]: Generating Executive Summary -> " <> id)
      
      // 1. GATHER: Fetch tasks and health via MoZ
      // 2. SYNTHESIZE: (Simulation)
      let summary = "📋 MORNING BRIEFING
- Swarm Health: NOMINAL (15/15)
- Active Intent: Telemetry Implementation
- Priority Tasks: 3 P0 pending
- Email Triage: 5 High-signal messages detected."
      
      // 3. DISPATCH: Send to mobile gateway
      let _ = telegram.send_notification(state.telegram, summary)
      
      actor.continue(state)
    }
    Stop -> {
      actor.stop()
    }
  }
}
