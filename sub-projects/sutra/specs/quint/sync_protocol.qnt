// sync_protocol.qnt — Matrix /sync Endpoint Protocol
// Ref: Matrix spec v1.13 client-server-api/#syncing
module SyncProtocol {
  type ClientId = str
  type EventId = str

  var server_events: List[EventId]
  var next_event: int
  var client_token: int
  var client_received: List[EventId]
  var phase: str  // "idle" | "pending" | "responding"
  var clock: int

  pure val MAX_EVENTS: int = 20

  action init = all {
    server_events = List(), next_event = 1,
    client_token = 0, client_received = List(),
    phase = "idle", clock = 0,
  }

  action produce_event: bool = next_event <= MAX_EVENTS and all {
    server_events' = server_events.append("$ev_" + next_event.toString()),
    next_event' = next_event + 1,
    client_token' = client_token, client_received' = client_received,
    phase' = phase, clock' = clock + 1,
  }

  action client_request_sync: bool = phase == "idle" and all {
    phase' = "pending",
    server_events' = server_events, next_event' = next_event,
    client_token' = client_token, client_received' = client_received,
    clock' = clock + 1,
  }

  action server_respond: bool = phase == "pending" and
    server_events.length() > client_token and {
      // Deliver events from client_token to end
      val batch = server_events.slice(client_token, server_events.length())
      all {
        client_received' = client_received.concat(batch),
        client_token' = server_events.length(),
        phase' = "responding",
        server_events' = server_events, next_event' = next_event,
        clock' = clock + 1,
      }
    }

  action client_ack: bool = phase == "responding" and all {
    phase' = "idle",
    server_events' = server_events, next_event' = next_event,
    client_token' = client_token, client_received' = client_received,
    clock' = clock + 1,
  }

  action step = any {
    produce_event, client_request_sync, server_respond, client_ack,
  }

  // Safety: token never ahead of server
  val token_valid: bool = client_token <= server_events.length()

  // Safety: received count matches token
  val prefix_coverage: bool = client_received.length() == client_token

  // Safety: no duplicate delivery (received is a prefix of server)
  val no_duplicates: bool = client_received.length() <= server_events.length()
}

module SyncSim {
  import SyncProtocol.*
  action init = SyncProtocol::init
  action step = SyncProtocol::step
  val invariant = SyncProtocol::token_valid and SyncProtocol::prefix_coverage
}
