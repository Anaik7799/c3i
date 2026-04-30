// presence.qnt — Matrix Distributed Presence Protocol
// Ref: Matrix spec v1.13 client-server-api/#presence
module Presence {
  type UserId = str
  type ServerId = str
  type PresenceState = Online | Offline | Unavailable

  type PresenceRecord = {
    user_id: UserId, state: PresenceState,
    last_active: int, home_server: ServerId
  }

  type PresenceEDU = {
    origin: ServerId, dest: ServerId,
    user_id: UserId, new_state: PresenceState, ts: int
  }

  var server_presence: ServerId -> (UserId -> PresenceRecord)
  var network: Set[PresenceEDU]
  var clock: int

  pure val SERVERS: Set[ServerId] = Set("alpha", "beta")
  pure val USERS: Set[UserId] = Set("@alice:alpha", "@bob:beta")
  pure val UNAVAIL_TIMEOUT: int = 10

  pure def home_server(uid: UserId): ServerId =
    if (uid == "@alice:alpha") "alpha" else "beta"

  pure def init_rec(uid: UserId): PresenceRecord = {
    user_id: uid, state: Offline, last_active: 0,
    home_server: home_server(uid)
  }

  action init = all {
    server_presence = Map(
      "alpha" -> Map("@alice:alpha" -> init_rec("@alice:alpha"),
                     "@bob:beta" -> init_rec("@bob:beta")),
      "beta"  -> Map("@alice:alpha" -> init_rec("@alice:alpha"),
                     "@bob:beta" -> init_rec("@bob:beta"))
    ),
    network = Set(),
    clock = 0,
  }

  action set_presence(uid: UserId, new_state: PresenceState): bool = {
    val hs = home_server(uid)
    val rec = server_presence.get(hs).get(uid)
    val new_rec = { ...rec, state: new_state, last_active: clock }
    val others = SERVERS.filter(s => s != hs)
    val edus = others.map(dest => {
      origin: hs, dest: dest, user_id: uid, new_state: new_state, ts: clock
    })
    all {
      server_presence' = server_presence.set(hs,
        server_presence.get(hs).set(uid, new_rec)),
      network' = network.union(edus),
      clock' = clock + 1,
    }
  }

  action auto_unavailable(uid: UserId): bool = {
    val hs = home_server(uid)
    val rec = server_presence.get(hs).get(uid)
    rec.state == Online and (clock - rec.last_active) >= UNAVAIL_TIMEOUT and {
      val new_rec = { ...rec, state: Unavailable }
      val edus = SERVERS.filter(s => s != hs).map(dest => {
        origin: hs, dest: dest, user_id: uid, new_state: Unavailable, ts: clock
      })
      all {
        server_presence' = server_presence.set(hs,
          server_presence.get(hs).set(uid, new_rec)),
        network' = network.union(edus),
        clock' = clock + 1,
      }
    }
  }

  action receive_edu(receiver: ServerId): bool = {
    nondet edu = network.filter(e => e.dest == receiver).oneOf()
    // Only accept from user's home server
    edu.origin == home_server(edu.user_id) and {
      val new_rec: PresenceRecord = {
        user_id: edu.user_id, state: edu.new_state,
        last_active: edu.ts, home_server: edu.origin
      }
      all {
        server_presence' = server_presence.set(receiver,
          server_presence.get(receiver).set(edu.user_id, new_rec)),
        network' = network.exclude(Set(edu)),
        clock' = clock + 1,
      }
    }
  }

  action tick = all {
    server_presence' = server_presence,
    network' = network,
    clock' = clock + 1,
  }

  action step = nondet uid = USERS.oneOf()
    nondet srv = SERVERS.oneOf()
    any {
      set_presence(uid, Online), set_presence(uid, Offline),
      auto_unavailable(uid), receive_edu(srv), tick,
    }

  // Safety: valid states only
  val valid_states: bool = SERVERS.forall(s =>
    server_presence.get(s).keys().forall(uid => {
      val st = server_presence.get(s).get(uid).state
      st == Online or st == Offline or st == Unavailable
    })
  )

  // Safety: no forged EDU accepted (home_server matches)
  val no_forged: bool = SERVERS.forall(s =>
    server_presence.get(s).keys().forall(uid =>
      server_presence.get(s).get(uid).home_server == home_server(uid)
    )
  )

  // Convergence when quiet
  val convergence: bool = network.size() == 0 implies
    USERS.forall(uid => {
      val states = SERVERS.map(s => server_presence.get(s).get(uid).state)
      states.forall(a => states.forall(b => a == b))
    })
}

module PresenceSim {
  import Presence.*
  action init = Presence::init
  action step = Presence::step
  val invariant = Presence::valid_states and Presence::no_forged
}
