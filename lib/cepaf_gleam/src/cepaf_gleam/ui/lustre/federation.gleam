//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/ui/lustre/federation</module></identity>
////   <fractal-topology><layer>L7_FEDERATION</layer></fractal-topology>
////   <compliance><stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002, SC-FED-001</stamp-controls></compliance>
//// </c3i-module>
////
//// Lustre MVU component for the L7 Federation plane.
//// Tracks peer discovery, version vectors, and attestation state.
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009, SC-FED-001, SC-FED-006

import cepaf_gleam/fractal/l7_federation.{
  type FederationPeer, type FederationState, add_peer, all_attested,
  connected_peers, increment_version, peer_count, remove_peer,
}
import gleam/option.{type Option, None, Some}

/// Lustre model for the Federation page.
pub type FederationModel {
  FederationModel(
    state: Option(FederationState),
    loading: Bool,
    error: Option(String),
  )
}

/// Messages for the Federation Lustre component.
pub type FederationMsg {
  StateReceived(FederationState)
  PeerAdded(FederationPeer)
  PeerRemoved(String)
  VersionIncremented
  RefreshFederation
  ErrorReceived(String)
}

/// Initial model — no state loaded yet.
pub fn init() -> FederationModel {
  FederationModel(state: None, loading: False, error: None)
}

/// Pure update function — deterministic, no side effects.
pub fn update(model: FederationModel, msg: FederationMsg) -> FederationModel {
  case msg {
    StateReceived(s) ->
      FederationModel(state: Some(s), loading: False, error: None)

    PeerAdded(peer) ->
      case model.state {
        None -> model
        Some(s) ->
          FederationModel(..model, state: Some(add_peer(s, peer)))
      }

    PeerRemoved(id) ->
      case model.state {
        None -> model
        Some(s) ->
          FederationModel(..model, state: Some(remove_peer(s, id)))
      }

    VersionIncremented ->
      case model.state {
        None -> model
        Some(s) ->
          FederationModel(..model, state: Some(increment_version(s)))
      }

    RefreshFederation -> FederationModel(..model, loading: True)

    ErrorReceived(err) ->
      FederationModel(..model, error: Some(err), loading: False)
  }
}

/// Count connected peers in the current model state.
pub fn connected_count(model: FederationModel) -> Int {
  case model.state {
    None -> 0
    Some(s) -> connected_peers(s) |> list_length()
  }
}

/// Check whether all peers in the current model are attested.
pub fn all_attested_check(model: FederationModel) -> Bool {
  case model.state {
    None -> False
    Some(s) -> all_attested(s)
  }
}

/// Total peer count from the current model state.
pub fn total_peer_count(model: FederationModel) -> Int {
  case model.state {
    None -> 0
    Some(s) -> peer_count(s)
  }
}

// Internal helper — avoids importing gleam/list just for length.
fn list_length(lst: List(a)) -> Int {
  list_length_acc(lst, 0)
}

fn list_length_acc(lst: List(a), acc: Int) -> Int {
  case lst {
    [] -> acc
    [_, ..rest] -> list_length_acc(rest, acc + 1)
  }
}
