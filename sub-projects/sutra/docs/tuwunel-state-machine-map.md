# Tuwunel → Sutra State Machine Map

**Date**: 2026-04-18
**Source**: tuwunel (Rust Matrix homeserver, github.com/matrix-construct/tuwunel)
**Target**: Sutra (Gleam Matrix homeserver)

## Summary

13 state machines identified in tuwunel Rust source. Mapped to Gleam equivalents.

| # | State Machine | Criticality | Sutra Status | Tuwunel Source |
|---|--------------|-------------|-------------|----------------|
| 1 | Room Membership FSM | CRITICAL | Partial (types exist) | event_auth/room_member.rs |
| 2 | State Resolution v2 | CRITICAL | Implemented | state_res/resolve.rs |
| 3 | Event Authorization | CRITICAL | Partial (auth.gleam) | event_auth.rs |
| 4 | Presence FSM | MEDIUM | Types exist | presence/mod.rs |
| 5 | Sync Protocol | HIGH | Implemented (sync_engine) | sync/mod.rs |
| 6 | Typing Notification | LOW | Types exist | rooms/typing/mod.rs |
| 7 | Federation Transaction | MEDIUM | Stub | sending/sender.rs |
| 8 | UIAA (Interactive Auth) | MEDIUM | Missing | uiaa/mod.rs |
| 9 | Push Notification | MEDIUM | Types exist | pusher/mod.rs |
| 10 | Read Receipt | LOW | Types exist | rooms/read_receipt/mod.rs |
| 11 | Device/Key Verification | MEDIUM | Types exist | users/keys.rs |
| 12 | Room Lifecycle | LOW | Implemented | rooms/timeline/create.rs |
| 13 | Incoming PDU Handler | HIGH | Missing | event_handler/handle_incoming_pdu.rs |

---

## 1. Room Membership FSM (CRITICAL)

### Rust (tuwunel)
```
States: Join | Invite | Leave | Ban | Knock
Dispatch: check_room_member() → 5 sub-functions:
  - check_room_member_join: public/invite/knock/restricted rules
  - check_room_member_invite: sender joined, target not joined/banned
  - check_room_member_leave: self-leave or kick (power level check)
  - check_room_member_ban: sender joined, ban PL, target PL < sender PL
  - check_room_member_knock: v7+, knock/knock_restricted join rule
```

### Gleam (Sutra equivalent)
```gleam
pub type MembershipState { Join Invite Leave Ban Knock }

pub type TransitionError {
  NotAllowed(reason: String)
  InsufficientPower(required: Int, actual: Int)
  BannedUser
  WrongJoinRule
}

pub type AuthContext {
  AuthContext(
    sender: String,
    target: String,
    sender_membership: MembershipState,
    target_membership: MembershipState,
    sender_power: Int,
    target_power: Int,
    join_rule: String,
    room_version: String,
    kick_level: Int,
    ban_level: Int,
    invite_level: Int,
  )
}

pub fn transition(
  from: MembershipState,
  to: MembershipState,
  ctx: AuthContext,
) -> Result(MembershipState, TransitionError)
```

### TLA+ spec: `specs/tla/MembershipFSM.tla`

---

## 2. State Resolution v2 (CRITICAL)

### Rust (tuwunel): 5-step algorithm
```
1. split_conflicted.rs — partition unconflicted vs conflicted state
2. auth_difference.rs — compute auth chain difference
3. conflicted_subgraph.rs — build full conflicted set
4. power_sort.rs — reverse topological power ordering (RTP)
5. iterative_auth_check.rs — apply events if auth rules pass
6. mainline_sort.rs — mainline ordering for remaining events
```

### Gleam (Sutra): `matrix/state_resolution.gleam`
Already implements: unconflicted/conflicted detection, mainline ordering, conflict resolution.
**Gap**: Missing iterative auth check step (step 5 above).

---

## 3. Event Authorization (CRITICAL)

### Rust (tuwunel)
Two-phase auth in `event_auth.rs`:
- Phase 1 (state-independent): auth_events validation, m.room.create rules
- Phase 2 (state-dependent): federation check, membership delegation, power levels, redaction, state_key @ prefix

### Gleam (Sutra): `matrix/auth.gleam`
Has event authorization but needs the two-phase split and full power level checking.

---

## 4. Presence FSM (MEDIUM)

### States & Transitions
```
Online → Unavailable (idle timeout, typically 5 min)
Online → Offline (explicit or extended timeout, typically 30 min)
Unavailable → Offline (extended timeout)
Unavailable → Online (user activity)
Offline → Online (explicit set)
```

### Multi-device aggregation
Most active device wins. Push suppression when Online.

### Sutra: `matrix/presence.gleam` — has PresenceStore, needs FSM + timers.

---

## 5. Sync Protocol (HIGH)

### Rust (tuwunel)
Sliding sync (MSC3575) with sticky parameters:
- `Connection` struct: globalsince, next_batch, lists, extensions
- Lifecycle: load → update_cache → compute response → store

### Sutra: `matrix/sync_engine.gleam` — implements initial + incremental sync.
**Gap**: No sliding sync (MSC3575) support.

---

## 6. Typing Notification (LOW)

In-memory `BTreeMap<RoomId, BTreeMap<UserId, timeout_ts>>`. GC expired entries.
Federation EDU for local users.
Sutra: Partially in `presence.gleam` TypingStore.

---

## 7. Federation Transaction FSM (MEDIUM)

### States
```
TransactionStatus: Running | Failed(count, last_time) | Retrying(count)
Destinations: Federation(ServerName) | Appservice(String) | Push(UserId, pushkey)
```
Sharded channel workers, exponential backoff.
Sutra: `federation/transport.gleam` — types exist, needs FSM.

---

## 8. UIAA (Interactive Auth) FSM (MEDIUM)

Session-based multi-stage authentication:
- Stages: Password, RegistrationToken, Dummy, FallbackAcknowledgement
- Each flow = list of required stages
- Session tracks completed stages
- All stages in any flow complete → auth succeeds

Sutra: **MISSING** — currently returns 200 always. Fix: return 401 with flows on first POST.

---

## 9. Push Notification (MEDIUM)

Rule evaluation via `Ruleset::get_actions`:
- Actions: Notify, DontNotify, SetTweak(sound/highlight)
- Suppression when user is Online (presence integration)
- Flush on presence transition away from Online

Sutra: `matrix/push.gleam` — has PushStore with 8 default rules.

---

## 10. Read Receipt (LOW)

Three types: m.read (public), m.read.private, m.fully_read.
Federation EDU for local users.
Sutra: `matrix/receipts.gleam` — has ReceiptStore.

---

## 11. Device/Key Verification (MEDIUM)

One-time key lifecycle: upload → available → claimed (consumed).
Cross-signing: master, self_signing, user_signing keys.
Device key tracking with count limits and pruning.
Sutra: `matrix/encryption.gleam` — has full types, needs claim lifecycle.

---

## 12. Room Lifecycle (LOW)

States: Creating → Active → Tombstoned(replacement) / Disabled / Deleted.
Sutra: `matrix/room_lifecycle.gleam` — implemented.

---

## 13. Incoming PDU Handler (HIGH)

14-step pipeline for federation PDU processing:
1. Check if already known
2. Check server in room / room not disabled
3. ACL checks (origin + sender)
4. Signature verification
5. Content hash check (redact if mismatch)
6. Fetch missing auth events
7. Reject if auth events fail
8. Persist as outlier
9. Fetch missing prev events
10. Fetch missing state via /state_ids
11. Auth check against state
12. State derivation verification
13. State resolution
14. Soft-fail check against current state

Sutra: **MISSING** — critical for federation. Needs full implementation.

---

## Priority Implementation Order

1. **UIAA FSM** (P0 — FluffyChat needs it for register)
2. **Membership FSM transition()** (P0 — all room ops depend on it)
3. **Incoming PDU Handler** (P1 — federation depends on it)
4. **Iterative Auth Check** in state resolution (P1 — correctness)
5. **Presence FSM** with timers (P2 — user experience)
6. **Federation Transaction FSM** with retry (P2 — reliability)
7. **OTK claim lifecycle** (P2 — E2EE)
8. **Push suppression** with presence integration (P3)
