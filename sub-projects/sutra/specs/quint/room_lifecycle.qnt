// room_lifecycle.qnt — Matrix Room Lifecycle Model
// Ref: Matrix spec v1.13 client-server-api/#rooms
module RoomLifecycle {
  type UserId = str
  type RoomId = str
  type Membership = Join | Leave | Invite | Knock | Ban

  type RoomState = {
    room_id: RoomId, creator: UserId,
    members: UserId -> Membership,
    join_rule: str, is_tombstoned: bool,
    replacement: str, event_count: int
  }

  var rooms: RoomId -> RoomState
  var clock: int

  pure val USERS: Set[UserId] = Set("@alice:l", "@bob:l", "@carol:l")
  pure val ROOM1: RoomId = "!r1:l"

  pure def user_power(creator: UserId, uid: UserId): int =
    if (uid == creator) 100 else 0

  action init = all {
    rooms = Map(),
    clock = 0,
  }

  action create_room(creator: UserId, rid: RoomId): bool =
    not(rooms.keys().contains(rid)) and all {
      rooms' = rooms.set(rid, {
        room_id: rid, creator: creator,
        members: Map(creator -> Join),
        join_rule: "invite", is_tombstoned: false,
        replacement: "", event_count: 1
      }),
      clock' = clock + 1,
    }

  action invite(rid: RoomId, actor: UserId, target: UserId): bool =
    rooms.keys().contains(rid) and {
      val rs = rooms.get(rid)
      not(rs.is_tombstoned) and
      rs.members.get(actor) == Join and
      rs.members.get(target) != Join and
      rs.members.get(target) != Ban and all {
        rooms' = rooms.set(rid, { ...rs, members: rs.members.set(target, Invite) }),
        clock' = clock + 1,
      }
    }

  action join(rid: RoomId, user: UserId): bool =
    rooms.keys().contains(rid) and {
      val rs = rooms.get(rid)
      not(rs.is_tombstoned) and
      rs.members.get(user) != Ban and
      (rs.join_rule == "public" or rs.members.get(user) == Invite) and all {
        rooms' = rooms.set(rid, { ...rs, members: rs.members.set(user, Join) }),
        clock' = clock + 1,
      }
    }

  action leave(rid: RoomId, user: UserId): bool =
    rooms.keys().contains(rid) and {
      val rs = rooms.get(rid)
      (rs.members.get(user) == Join or rs.members.get(user) == Invite) and all {
        rooms' = rooms.set(rid, { ...rs, members: rs.members.set(user, Leave) }),
        clock' = clock + 1,
      }
    }

  action ban(rid: RoomId, actor: UserId, target: UserId): bool =
    rooms.keys().contains(rid) and actor != target and {
      val rs = rooms.get(rid)
      rs.members.get(actor) == Join and
      user_power(rs.creator, actor) > user_power(rs.creator, target) and
      rs.members.get(target) != Ban and all {
        rooms' = rooms.set(rid, { ...rs, members: rs.members.set(target, Ban) }),
        clock' = clock + 1,
      }
    }

  action upgrade(rid: RoomId, actor: UserId, new_rid: RoomId): bool =
    rooms.keys().contains(rid) and not(rooms.keys().contains(new_rid)) and {
      val rs = rooms.get(rid)
      not(rs.is_tombstoned) and rs.members.get(actor) == Join and
      user_power(rs.creator, actor) >= 50 and {
        val joined = rs.members.keys().filter(u => rs.members.get(u) == Join)
        val new_members = joined.fold(Map(), (m, u) =>
          m.set(u, if (u == actor) Join else Invite))
        all {
          rooms' = rooms
            .set(rid, { ...rs, is_tombstoned: true, replacement: new_rid })
            .set(new_rid, {
              room_id: new_rid, creator: actor, members: new_members,
              join_rule: rs.join_rule, is_tombstoned: false,
              replacement: "", event_count: 1
            }),
          clock' = clock + 1,
        }
      }
    }

  action step = nondet rid = Set(ROOM1, "!r2:l").oneOf()
    nondet nrid = Set("!r2:l", "!r3:l").oneOf()
    nondet actor = USERS.oneOf()
    nondet target = USERS.oneOf()
    any {
      create_room(actor, rid), invite(rid, actor, target),
      join(rid, target), leave(rid, actor),
      ban(rid, actor, target), upgrade(rid, actor, nrid),
    }

  // Safety: banned users never in Join
  val no_banned_joiner: bool = rooms.keys().forall(rid =>
    rooms.get(rid).members.keys().forall(u =>
      not(rooms.get(rid).members.get(u) == Ban and rooms.get(rid).members.get(u) == Join)
    )
  )

  // Safety: tombstoned room stays tombstoned
  val tombstone_permanent: bool = rooms.keys().forall(rid =>
    rooms.get(rid).is_tombstoned implies rooms.get(rid).replacement != ""
  )

  // Safety: upgrade preserves joined members
  val upgrade_preserves: bool = rooms.keys().forall(rid => {
    val rs = rooms.get(rid)
    rs.is_tombstoned and rs.replacement != "" implies
      (not(rooms.keys().contains(rs.replacement)) or
       rs.members.keys().filter(u => rs.members.get(u) == Join).forall(u =>
         rooms.get(rs.replacement).members.get(u) == Join or
         rooms.get(rs.replacement).members.get(u) == Invite))
  })
}

module RoomLifecycleSim {
  import RoomLifecycle.*
  action init = RoomLifecycle::init
  action step = RoomLifecycle::step
  val invariant = RoomLifecycle::no_banned_joiner and RoomLifecycle::tombstone_permanent
}
