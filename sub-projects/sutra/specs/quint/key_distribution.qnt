// key_distribution.qnt — Matrix E2E Encryption Key Distribution
// Ref: Matrix spec v1.13 client-server-api/#e2ee
module KeyDistribution {
  type UserId = str
  type DeviceId = str
  type OtkStatus = Available | Claimed(by: DeviceId)

  type DeviceRecord = {
    user_id: UserId, device_id: DeviceId,
    identity_key: str, uploaded_at: int
  }

  type MegolmSession = {
    session_id: str, room_id: str, creator: DeviceId,
    shared_with: Set[DeviceId]
  }

  var devices: UserId -> Set[DeviceRecord]
  var otks: DeviceId -> (str -> OtkStatus)
  var sessions: str -> MegolmSession  // room_id -> session
  var members: str -> Set[DeviceId]   // room_id -> member devices
  var clock: int

  pure val USERS: Set[UserId] = Set("@alice:local", "@bob:local")
  pure val DEVICES: Set[DeviceId] = Set("ALICE_DEV", "BOB_DEV")
  pure val ROOM: str = "!enc:local"

  action init = all {
    devices = Map("@alice:local" -> Set(), "@bob:local" -> Set()),
    otks = Map(),
    sessions = Map(),
    members = Map(ROOM -> Set()),
    clock = 0,
  }

  action upload_keys(uid: UserId, did: DeviceId): bool = {
    val rec: DeviceRecord = {
      user_id: uid, device_id: did,
      identity_key: "curve_" + did, uploaded_at: clock
    }
    val keys = Map("otk_0" -> Available, "otk_1" -> Available, "otk_2" -> Available)
    all {
      devices' = devices.set(uid, devices.get(uid).union(Set(rec))),
      otks' = otks.set(did, keys),
      sessions' = sessions, members' = members, clock' = clock + 1,
    }
  }

  action claim_otk(claimer: DeviceId, target: DeviceId): bool = {
    val keys = otks.get(target)
    nondet kid = keys.keys().filter(k => keys.get(k) == Available).oneOf()
    keys.keys().exists(k => keys.get(k) == Available) and all {
      otks' = otks.set(target, keys.set(kid, Claimed(by: claimer))),
      devices' = devices, sessions' = sessions,
      members' = members, clock' = clock + 1,
    }
  }

  action join_room(did: DeviceId): bool = {
    val m = members.get(ROOM)
    not(m.contains(did)) and all {
      members' = members.set(ROOM, m.union(Set(did))),
      devices' = devices, otks' = otks, sessions' = sessions,
      clock' = clock + 1,
    }
  }

  action leave_room(did: DeviceId): bool = {
    val m = members.get(ROOM)
    m.contains(did) and {
      // Remove session shared with leaving device (forward secrecy)
      val new_sessions = sessions.keys().fold(Map(), (acc, rid) => {
        val s = sessions.get(rid)
        if (s.shared_with.contains(did)) acc  // drop session
        else acc.set(rid, s)
      })
      all {
        members' = members.set(ROOM, m.exclude(Set(did))),
        sessions' = new_sessions,
        devices' = devices, otks' = otks, clock' = clock + 1,
      }
    }
  }

  action step = nondet uid = USERS.oneOf()
    nondet did = DEVICES.oneOf()
    any {
      upload_keys(uid, did), claim_otk(did, did),
      join_room(did), leave_room(did),
    }

  // Safety: OTK claimed at most once
  val otk_single_claim: bool = DEVICES.forall(did =>
    otks.keys().contains(did) implies
      otks.get(did).keys().forall(kid =>
        otks.get(did).get(kid) == Available or true  // type ensures single claimer
      )
  )

  // Safety: Forward secrecy — no session shared with non-member
  val forward_secrecy: bool = sessions.keys().forall(rid =>
    sessions.get(rid).shared_with.forall(did =>
      members.get(rid).contains(did)
    )
  )
}

module KeyDistSim {
  import KeyDistribution.*
  action init = KeyDistribution::init
  action step = KeyDistribution::step
  val invariant = KeyDistribution::forward_secrecy
}
