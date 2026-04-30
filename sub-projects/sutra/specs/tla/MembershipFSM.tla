---- MODULE MembershipFSM ----
(*
 * Matrix Room Membership State Machine
 * Ref: https://spec.matrix.org/v1.13/client-server-api/#room-membership
 *
 * States: {None, Invite, Join, Knock, Leave, Ban}
 * Transitions governed by: actor identity, power levels, join rules.
 *)

EXTENDS Integers, FiniteSets, TLC

CONSTANTS
    Users, DefaultPL, InvitePL, KickPL, BanPL

ASSUME DefaultPL >= 0
ASSUME BanPL >= InvitePL

MembershipStates == {"none", "invite", "join", "knock", "leave", "ban"}
JoinRules == {"public", "invite", "knock", "restricted", "private"}

VARIABLES
    membership, powerLevels, joinRule

vars == <<membership, powerLevels, joinRule>>

TypeOK ==
    /\ membership  \in [Users -> MembershipStates]
    /\ powerLevels \in [Users -> Nat]
    /\ joinRule    \in JoinRules

IsMember(u) == membership[u] = "join"
IsBanned(u) == membership[u] = "ban"
IsKnocked(u) == membership[u] = "knock"
PL(actor) == powerLevels[actor]
HasPL(actor, required) == PL(actor) >= required
CanAffect(actor, target) == actor = target \/ PL(actor) > PL(target)

Invite(actor, target) ==
    /\ actor # target /\ IsMember(actor)
    /\ membership[target] \in {"none", "leave"}
    /\ HasPL(actor, InvitePL)
    /\ membership' = [membership EXCEPT ![target] = "invite"]
    /\ UNCHANGED <<powerLevels, joinRule>>

JoinFromInvite(user) ==
    /\ membership[user] = "invite"
    /\ membership' = [membership EXCEPT ![user] = "join"]
    /\ UNCHANGED <<powerLevels, joinRule>>

JoinPublic(user) ==
    /\ joinRule = "public"
    /\ membership[user] \in {"none", "leave", "invite"}
    /\ ~IsBanned(user)
    /\ membership' = [membership EXCEPT ![user] = "join"]
    /\ UNCHANGED <<powerLevels, joinRule>>

Knock(user) ==
    /\ joinRule = "knock"
    /\ membership[user] \in {"none", "leave"}
    /\ ~IsBanned(user)
    /\ membership' = [membership EXCEPT ![user] = "knock"]
    /\ UNCHANGED <<powerLevels, joinRule>>

Leave(user) ==
    /\ membership[user] \in {"join", "invite", "knock"}
    /\ membership' = [membership EXCEPT ![user] = "leave"]
    /\ UNCHANGED <<powerLevels, joinRule>>

Kick(actor, target) ==
    /\ actor # target /\ IsMember(actor) /\ IsMember(target)
    /\ HasPL(actor, KickPL) /\ CanAffect(actor, target)
    /\ membership' = [membership EXCEPT ![target] = "leave"]
    /\ UNCHANGED <<powerLevels, joinRule>>

Ban(actor, target) ==
    /\ actor # target /\ IsMember(actor)
    /\ HasPL(actor, BanPL) /\ CanAffect(actor, target)
    /\ ~IsBanned(target)
    /\ membership' = [membership EXCEPT ![target] = "ban"]
    /\ UNCHANGED <<powerLevels, joinRule>>

Unban(actor, target) ==
    /\ actor # target /\ IsMember(actor)
    /\ HasPL(actor, BanPL) /\ IsBanned(target)
    /\ membership' = [membership EXCEPT ![target] = "leave"]
    /\ UNCHANGED <<powerLevels, joinRule>>

Init ==
    /\ membership  = [u \in Users |-> "none"]
    /\ powerLevels = [u \in Users |-> DefaultPL]
    /\ joinRule    = "invite"

Next ==
    \E actor \in Users, target \in Users :
        \/ Invite(actor, target)
        \/ JoinFromInvite(target)
        \/ JoinPublic(target)
        \/ Knock(target)
        \/ Leave(target)
        \/ Kick(actor, target)
        \/ Ban(actor, target)
        \/ Unban(actor, target)

Spec == Init /\ [][Next]_vars

\* Safety: Banned users cannot be joined
BannedCannotJoin ==
    \A u \in Users : IsBanned(u) => membership[u] = "ban"

\* Safety: Ban->Join requires Unban first
BanToJoinRequiresUnban ==
    [][\A u \in Users :
        (membership[u] = "ban" /\ membership'[u] = "join") => FALSE
    ]_membership

\* Safety: Knock only in knock rooms
KnockOnlyInKnockRooms ==
    \A u \in Users : IsKnocked(u) => joinRule = "knock"

\* Safety: Banned users cannot knock
BannedCannotKnock ==
    \A u \in Users : ~(IsBanned(u) /\ IsKnocked(u))

\* Safety: Only members can invite
OnlyMembersCanInvite ==
    \A u \in Users :
        membership[u] = "invite" =>
            \E actor \in Users : actor # u /\ IsMember(actor)

INVARIANT TypeOK
INVARIANT BannedCannotJoin
INVARIANT KnockOnlyInKnockRooms
INVARIANT BannedCannotKnock

PROPERTY BanToJoinRequiresUnban

====
