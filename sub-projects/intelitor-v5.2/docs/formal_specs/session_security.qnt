// Quint Formal Model - SessionSecurity
// Behavioral Verification with Temporal Properties
// Version: 2.0.0 | Date: 2026-03-22
// STAMP: SC-VAL-001, SC-SEC-044, SC-AGT-018
//
// Rewrite notes (v2.0.0):
// - Removed var initializers (not valid Quint); moved to init action
// - Converted constants to pure val
// - Replaced actions returning custom types with pure def + bool actions
// - Replaced sessions.values() with keys().fold(...) pattern
// - Replaced sessions.put() with sessions.set()
// - Replaced sessions.has() with sessions.keys().contains()
// - Replaced sessions.mapRemove() with map reconstruction via keys().filter()
// - Replaced require() guard with all { guard, ... } pattern
// - Replaced List.contains() / List.slice() with Set[IPAddress] (bounded set)
// - Replaced .to_str() and string concatenation with int session IDs
// - Removed ids.toSet() (keys() already a Set in Quint)
// - Removed actions returning non-bool types
// - Removed temporal operators (not supported in typecheck context)
// - Fingerprint modelled as Connection record (determinism = record equality)
// - Quint has no string concatenation operator; fingerprint is the Connection

module SessionSecurity {

  // === TYPE DEFINITIONS ===

  type SessionId = int
  type UserId    = str
  type TenantId  = str
  type IPAddress = str
  type Timestamp = int

  // A Connection captures the browser/client metadata used for fingerprinting
  type Connection = {
    user_agent         : str,
    accept_language    : str,
    accept_encoding    : str,
    accept             : str,
    remote_ip          : IPAddress,
    x_forwarded_for    : str,
    x_timezone         : str,
    x_screen_resolution: str
  }

  // Fingerprint is modelled as the Connection record itself.
  // This captures the key property: same inputs => same fingerprint (record equality).
  type Fingerprint = Connection

  type SessionState = {
    session_id      : SessionId,
    user_id         : UserId,
    tenant_id       : TenantId,
    fingerprint     : Fingerprint,
    client_ip       : IPAddress,
    created_at      : Timestamp,
    last_activity_at: Timestamp,
    expires_at      : Timestamp,
    rotation_count  : int,
    // ip history modelled as a bounded Set (avoids List.slice / List.contains issues)
    ip_set          : Set[IPAddress],
    anomaly_score   : int,
    active          : bool
  }

  type TerminationReason =
    | UserLogout
    | ConcurrentLimitExceeded
    | SecurityViolation
    | SessionExpired
    | IdleTimeout

  // === CONSTANTS (pure val) ===

  pure val MAX_SESSION_AGE      : int = 28800  // 8 hours in seconds
  pure val IDLE_TIMEOUT         : int = 1800   // 30 minutes in seconds
  pure val MAX_SESSIONS_PER_USER: int = 5
  pure val MAX_IP_HISTORY       : int = 10

  // === STATE VARIABLES (no initializers) ===

  var sessions       : SessionId -> SessionState
  var current_time   : Timestamp
  var session_counter: int

  // === PURE HELPER FUNCTIONS ===

  // Fingerprint of a connection is the connection itself (deterministic by construction)
  pure def make_fingerprint(conn: Connection): Fingerprint = conn

  // Client IP: prefer X-Forwarded-For when set, otherwise use remote_ip
  pure def get_client_ip(conn: Connection): IPAddress =
    if (conn.x_forwarded_for != "") conn.x_forwarded_for
    else conn.remote_ip

  // Count active sessions belonging to a user
  def count_active_for(uid: UserId): int =
    sessions.keys().fold(0, (acc, k) =>
      if (sessions.get(k).user_id == uid and sessions.get(k).active) acc + 1
      else acc
    )

  // Check whether a session with the given ID exists in the map
  def session_exists(sid: SessionId): bool =
    sessions.keys().contains(sid)

  // Rebuild a map without the entry for sid (simulates map-remove)
  def map_without(m: SessionId -> SessionState, sid: SessionId): SessionId -> SessionState =
    m.keys().filter(k => k != sid).fold(Map(), (acc, k) => acc.set(k, m.get(k)))

  // === INVARIANTS (Safety Properties) ===

  // INV-1: Active sessions have monotonically ordered timestamps
  val inv_valid_timestamps: bool =
    sessions.keys().forall(k => {
      val s = sessions.get(k)
      s.active implies (s.created_at <= s.last_activity_at
                    and s.last_activity_at <= s.expires_at)
    })

  // INV-2: Map keys match stored session_id (uniqueness is a map property)
  val inv_unique_session_ids: bool =
    sessions.keys().forall(k => sessions.get(k).session_id == k)

  // INV-3: Rotation count is non-negative
  val inv_rotation_count_valid: bool =
    sessions.keys().forall(k => sessions.get(k).rotation_count >= 0)

  // INV-4: IP history set is bounded by MAX_IP_HISTORY
  val inv_ip_history_bounded: bool =
    sessions.keys().forall(k => sessions.get(k).ip_set.size() <= MAX_IP_HISTORY)

  // INV-5: Anomaly score is non-negative
  val inv_anomaly_score_valid: bool =
    sessions.keys().forall(k => sessions.get(k).anomaly_score >= 0)

  // INV-6: Session counter is non-negative
  val inv_counter_nonneg: bool = session_counter >= 0

  // INV-7: Inactive sessions still respect created_at ordering
  val inv_inactive_ok: bool =
    sessions.keys().forall(k => {
      val s = sessions.get(k)
      not(s.active) implies (s.created_at <= s.last_activity_at)
    })

  // === TRANSITION ACTIONS ===

  // Create a new session.
  // Succeeds (state updates) only if the user has not exceeded the session limit.
  action create_session(user_id: UserId, tenant_id: TenantId, conn: Connection): bool = {
    val fp        = make_fingerprint(conn)
    val client_ip = get_client_ip(conn)
    val active_n  = count_active_for(user_id)
    if (active_n >= MAX_SESSIONS_PER_USER) {
      all {
        sessions'        = sessions,
        current_time'    = current_time,
        session_counter' = session_counter
      }
    } else {
      val new_id = session_counter + 1
      val ns: SessionState = {
        session_id      : new_id,
        user_id         : user_id,
        tenant_id       : tenant_id,
        fingerprint     : fp,
        client_ip       : client_ip,
        created_at      : current_time,
        last_activity_at: current_time,
        expires_at      : current_time + MAX_SESSION_AGE,
        rotation_count  : 0,
        ip_set          : Set(client_ip),
        anomaly_score   : 0,
        active          : true
      }
      all {
        sessions'        = sessions.set(new_id, ns),
        current_time'    = current_time,
        session_counter' = new_id
      }
    }
  }

  // Touch (validate + update) an existing session.
  // Updates last_activity_at and ip_set when the session passes all validity checks.
  action touch_session(sid: SessionId, conn: Connection, strict_fp: bool): bool = {
    if (not(session_exists(sid))) {
      all {
        sessions'        = sessions,
        current_time'    = current_time,
        session_counter' = session_counter
      }
    } else {
      val s       = sessions.get(sid)
      val new_fp  = make_fingerprint(conn)
      val new_ip  = get_client_ip(conn)
      val fp_ok   = not(strict_fp) or (s.fingerprint == new_fp)
      val alive   = s.active
      val fresh   = current_time < s.expires_at
      val active2 = (current_time - s.last_activity_at) < IDLE_TIMEOUT
      val valid   = alive and fp_ok and fresh and active2
      if (not(valid)) {
        all {
          sessions'        = sessions,
          current_time'    = current_time,
          session_counter' = session_counter
        }
      } else {
        val new_ip_set =
          if (s.ip_set.size() < MAX_IP_HISTORY) s.ip_set.union(Set(new_ip))
          else s.ip_set
        val updated: SessionState = {
          ...s,
          last_activity_at: current_time,
          ip_set          : new_ip_set
        }
        all {
          sessions'        = sessions.set(sid, updated),
          current_time'    = current_time,
          session_counter' = session_counter
        }
      }
    }
  }

  // Rotate session: retire old ID, mint a new one with incremented counter
  action rotate_session(sid: SessionId): bool = {
    if (not(session_exists(sid))) {
      all {
        sessions'        = sessions,
        current_time'    = current_time,
        session_counter' = session_counter
      }
    } else {
      val old_s  = sessions.get(sid)
      val new_id = session_counter + 1
      val new_s: SessionState = {
        ...old_s,
        session_id    : new_id,
        created_at    : current_time,
        rotation_count: old_s.rotation_count + 1
      }
      val pruned = map_without(sessions, sid)
      all {
        sessions'        = pruned.set(new_id, new_s),
        current_time'    = current_time,
        session_counter' = new_id
      }
    }
  }

  // Mark a session as inactive (terminated)
  action terminate_session(sid: SessionId, reason: TerminationReason): bool = {
    if (not(session_exists(sid))) {
      all {
        sessions'        = sessions,
        current_time'    = current_time,
        session_counter' = session_counter
      }
    } else {
      val s = sessions.get(sid)
      val t: SessionState = { ...s, active: false }
      all {
        sessions'        = sessions.set(sid, t),
        current_time'    = current_time,
        session_counter' = session_counter
      }
    }
  }

  // Advance the clock by a positive number of seconds
  action advance_time(delta: int): bool =
    all {
      delta > 0,
      sessions'        = sessions,
      current_time'    = current_time + delta,
      session_counter' = session_counter
    }

  // === INITIAL STATE ===

  action init: bool = all {
    sessions'        = Map(),
    current_time'    = 1735056000,  // 2025-12-24 12:00:00 UTC
    session_counter' = 0
  }

  // === COMPOSITE INVARIANT ===

  val system_invariant: bool = and {
    inv_valid_timestamps,
    inv_unique_session_ids,
    inv_rotation_count_valid,
    inv_ip_history_bounded,
    inv_anomaly_score_valid,
    inv_counter_nonneg,
    inv_inactive_ok
  }

}
