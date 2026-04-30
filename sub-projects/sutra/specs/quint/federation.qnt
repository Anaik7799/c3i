// federation.qnt — Matrix Server-to-Server Federation Protocol
// Ref: Matrix spec v1.13 server-server-api
module Federation {
  type ServerId = str
  type RoomId = str
  type EventId = str
  type PduEvent = {
    event_id: EventId, room_id: RoomId, sender: str,
    depth: int, origin: ServerId, signed: bool,
    prev_events: Set[EventId]
  }

  var servers: ServerId -> { known: Set[EventId], store: EventId -> PduEvent }
  var network: Set[{ from: ServerId, to: ServerId, events: Set[PduEvent] }]
  var clock: int

  pure val ALL_SERVERS: Set[ServerId] = Set("alpha", "beta", "gamma")
  pure val ROOM: RoomId = "!r1:alpha"

  pure def genesis(): PduEvent = {
    event_id: "$create", room_id: ROOM, sender: "@admin:alpha",
    depth: 0, origin: "alpha", signed: true, prev_events: Set()
  }

  action init = all {
    servers = Map(
      "alpha" -> { known: Set("$create"), store: Map("$create" -> genesis()) },
      "beta"  -> { known: Set("$create"), store: Map("$create" -> genesis()) },
      "gamma" -> { known: Set("$create"), store: Map("$create" -> genesis()) }
    ),
    network = Set(),
    clock = 1,
  }

  action send_event(origin: ServerId): bool = {
    val sv = servers.get(origin)
    val eid = "$ev_" + origin + "_" + clock.toString()
    val ev: PduEvent = {
      event_id: eid, room_id: ROOM, sender: "@user:" + origin,
      depth: clock, origin: origin, signed: true, prev_events: sv.known
    }
    val targets = ALL_SERVERS.filter(s => s != origin)
    val msgs = targets.map(t => { from: origin, to: t, events: Set(ev) })
    all {
      servers' = servers.set(origin, {
        known: sv.known.union(Set(eid)),
        store: sv.store.set(eid, ev),
      }),
      network' = network.union(msgs),
      clock' = clock + 1,
    }
  }

  action receive_txn(receiver: ServerId): bool = {
    nondet msg = network.filter(m => m.to == receiver).oneOf()
    val sv = servers.get(receiver)
    val valid = msg.events.filter(ev => ev.signed)
    val new_known = sv.known.union(valid.map(ev => ev.event_id))
    val new_store = valid.fold(sv.store, (s, ev) => s.set(ev.event_id, ev))
    all {
      servers' = servers.set(receiver, { known: new_known, store: new_store }),
      network' = network.exclude(Set(msg)),
      clock' = clock + 1,
    }
  }

  action step = nondet srv = ALL_SERVERS.oneOf()
    any { send_event(srv), receive_txn(srv) }

  // Safety: all stored events are signed
  val all_signed: bool = ALL_SERVERS.forall(s =>
    servers.get(s).store.keys().forall(eid =>
      servers.get(s).store.get(eid).signed
    )
  )

  // Safety: depth is monotone
  val depth_monotone: bool = ALL_SERVERS.forall(s =>
    servers.get(s).store.keys().forall(eid => {
      val ev = servers.get(s).store.get(eid)
      ev.prev_events.forall(pid =>
        not(servers.get(s).store.keys().contains(pid)) or
        servers.get(s).store.get(pid).depth < ev.depth
      )
    })
  )

  // Convergence when network drains
  val convergence: bool = network.size() == 0 implies {
    val sets = ALL_SERVERS.map(s => servers.get(s).known)
    sets.forall(a => sets.forall(b => a == b))
  }
}

module FederationSim {
  import Federation.*
  action init = Federation::init
  action step = Federation::step
  val invariant = Federation::all_signed and Federation::depth_monotone
}
