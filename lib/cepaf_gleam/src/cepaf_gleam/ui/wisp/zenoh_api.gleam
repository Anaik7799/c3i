/// Wisp API for Zenoh Mesh plane (SC-GLM-UI-001, SC-GLM-UI-003).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007
import cepaf_gleam/zenoh/domain.{
  type ConnectionStatus, type ZenohHealth, Connected, Connecting, Disconnected,
}
import gleam/json
import gleam/list

pub fn zenoh_health_json(health: ZenohHealth) -> String {
  json.object([
    #("plane", json.string("zenoh")),
    #("status", json.string(connection_status_string(health.status))),
    #("session_id", json.string(health.session_id)),
    #("connected_at", json.int(health.connected_at)),
    #("last_heartbeat", json.int(health.last_heartbeat)),
    #("reconnect_count", json.int(health.reconnect_count)),
    #("messages_published", json.int(health.messages_published)),
    #("messages_received", json.int(health.messages_received)),
    #("error_count", json.int(health.error_count)),
  ])
  |> json.to_string()
}

pub fn subscriptions_json(topics: List(String)) -> String {
  json.object([
    #("plane", json.string("zenoh")),
    #("subscription_count", json.int(list.length(topics))),
    #("topics", json.array(topics, json.string)),
  ])
  |> json.to_string()
}

fn connection_status_string(status: ConnectionStatus) -> String {
  case status {
    Connected -> "connected"
    Disconnected -> "disconnected"
    Connecting -> "connecting"
    domain.Error(msg) -> "error: " <> msg
  }
}
