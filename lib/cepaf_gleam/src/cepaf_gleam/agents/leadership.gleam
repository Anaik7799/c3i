//// [C3I-SIL6-MSTS] <c3i-module><identity><module>cepaf_gleam/agents/leadership</module></identity>
////   <fractal-topology><layer>L5_COGNITIVE</layer></fractal-topology>
////   <compliance><stamp-controls>SC-HA-001</stamp-controls></compliance>
//// </c3i-module>

import cepaf_gleam/moz/client as moz
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor

pub type LeadershipMessage {
  CheckLease
  GracefulDrain
  Stop
}

pub type Role {
  Primary
  Backup
  Draining
}

pub type LeadershipState {
  LeadershipState(
    id: String,
    role: Role,
    moz: moz.MoZClientState,
  )
}

pub fn start(id: String) -> Result(actor.Started(Subject(LeadershipMessage)), actor.StartError) {
  let initial = LeadershipState(
    id: id,
    role: Backup,
    moz: moz.new(),
  )
  
  actor.new(initial)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(state: LeadershipState, msg: LeadershipMessage) -> actor.Next(LeadershipState, LeadershipMessage) {
  case msg {
    CheckLease -> {
      // In prod, check Zenoh key indrajaal/l4/system/leader_lease
      actor.continue(state)
    }
    GracefulDrain -> {
      io.println("🛡️ HA: " <> state.id <> " entering Graceful Drain mode. Rejecting new intents.")
      actor.continue(LeadershipState(..state, role: Draining))
    }
    Stop -> actor.stop()
  }
}
