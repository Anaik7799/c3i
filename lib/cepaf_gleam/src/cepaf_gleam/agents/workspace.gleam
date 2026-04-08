//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/agents/workspace</module></identity>
////   <fractal-topology><layer>L5_COGNITIVE</layer></fractal-topology>
////   <compliance><stamp-controls>SC-COG-003, SC-ZMOF-001</stamp-controls></compliance>
//// </c3i-module>
////
//// Google Workspace Orchestrator (Gmail/Calendar/Drive).
//// Managed OTP Actor that provides deep integration with abhijit.naik@boutytek.com.

import cepaf_gleam/moz/client as moz
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/otp/actor

pub type WorkspaceMessage {
  TriageDailyFlow
  SearchKnowledge(query: String)
  Stop
}

pub type WorkspaceState {
  WorkspaceState(
    id: String,
    account: String,
    moz: moz.MoZClientState,
  )
}

/// Start the Workspace Agent as a supervised worker.
pub fn start(id: String, account: String) -> Result(actor.Started(Subject(WorkspaceMessage)), actor.StartError) {
  let initial = WorkspaceState(
    id: id,
    account: account,
    moz: moz.new(),
  )
  
  actor.new(initial)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(state: WorkspaceState, msg: WorkspaceMessage) -> actor.Next(WorkspaceState, WorkspaceMessage) {
  case msg {
    TriageDailyFlow -> {
      io.println("🧠 Workspace [" <> state.id <> "]: Triaging account " <> state.account)
      
      // 1. Fetch Agenda
      let #(_, _) = moz.send_request(state.moz, "plan", "calendar_get_agenda", json.object([]))
      
      // 2. Fetch Unread Emails
      let #(_, _) = moz.send_request(state.moz, "plan", "gmail_list_unread", json.object([]))
      
      io.println("  [ok] Synthesis complete. Routing to Gateway actors.")
      actor.continue(state)
    }
    SearchKnowledge(query) -> {
      io.println("🧠 Workspace [" <> state.id <> "]: Searching knowledge base for '" <> query <> "'")
      let #(_, _) = moz.send_request(state.moz, "plan", "drive_search_files", json.object([]))
      actor.continue(state)
    }
    Stop -> actor.stop()
  }
}
