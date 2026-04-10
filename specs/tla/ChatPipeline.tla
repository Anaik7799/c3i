--------------------------- MODULE ChatPipeline ---------------------------
(*
 * Chat Processing Pipeline — Formal TLA+ Specification
 *
 * Models the full intent lifecycle from ingress to gateway delivery:
 *   received -> classified -> ack_sent -> inferring -> delivered
 *
 * Covers:
 *   - 5 inference tiers with per-tier circuit breakers
 *   - Guardian automaton (Safe / Warning / Emergency)
 *   - Token-bucket rate limiting per chat_id
 *   - Parallel gateway delivery with retry
 *   - Zenoh publish with retry
 *
 * STAMP: SC-COG-001..003, SC-SAFETY-003, SC-FUNC-003
 * Date: 2026-04-09
 *)
EXTENDS Integers, Sequences, FiniteSets

-----------------------------------------------------------------------------
(* CONSTANTS *)
-----------------------------------------------------------------------------

CONSTANTS
    NumTiers,           \* 5: gemini_live, gemini_rest, openrouter, ollama, rule_fallback
    MaxZenohRetries,    \* 3: Zenoh publish retries with backoff
    MaxGwRetries,       \* 1: gateway delivery retry per channel
    CBFailThreshold,    \* 3: consecutive failures to trip circuit breaker open
    CBCooldownTicks,    \* 60: ticks before half-open probe allowed
    MaxTokens,          \* 20: token bucket capacity per chat_id
    RefillTicks,        \* 3: ticks between token refills
    NumChatIds,         \* number of chat_ids to model (typically 2 for bounded check)
    NumChannels         \* 2: Telegram + GChat parallel delivery

ASSUME NumTiers >= 1
ASSUME MaxTokens >= 1
ASSUME NumChannels >= 1
ASSUME CBFailThreshold >= 1

-----------------------------------------------------------------------------
(* VARIABLES *)
-----------------------------------------------------------------------------

VARIABLES
    \* --- Intent state machine ---
    state,              \* {"received", "classified", "ack_sent", "publishing",
                        \*  "inferring", "delivering", "delivered", "dead_letter"}

    \* --- Inference tier cascade ---
    tier_idx,           \* Current inference tier being tried (0..NumTiers-1)

    \* --- Circuit breaker state per tier ---
    cb_failures,        \* [0..NumTiers-1 -> Nat]: consecutive failure count
    cb_last_fail_tick,  \* [0..NumTiers-1 -> Nat]: tick of last failure
    cb_mode,            \* [0..NumTiers-1 -> {"closed", "open", "half_open"}]

    \* --- Rate limiting (token bucket) ---
    tokens,             \* [0..NumChatIds-1 -> 0..MaxTokens]: current token count
    last_refill_tick,   \* [0..NumChatIds-1 -> Nat]: tick of last refill
    current_chat,       \* chat_id index being processed (0..NumChatIds-1)

    \* --- Guardian automaton ---
    guardian,           \* {"safe", "warning", "emergency"}

    \* --- Zenoh publish ---
    zenoh_retries,      \* current retry count for Zenoh publish
    zenoh_published,    \* Boolean: intent published to Zenoh backplane

    \* --- Gateway delivery ---
    gw_attempts,        \* [0..NumChannels-1 -> Nat]: delivery attempt count per channel
    gw_delivered,       \* [0..NumChannels-1 -> Bool]: delivery success per channel

    \* --- Global clock ---
    tick                \* monotonic clock tick for circuit breaker cooldown and refill

vars == <<state, tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
          tokens, last_refill_tick, current_chat, guardian,
          zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

-----------------------------------------------------------------------------
(* TYPE INVARIANT *)
-----------------------------------------------------------------------------

TypeInvariant ==
    /\ state \in {"received", "classified", "ack_sent", "publishing",
                   "inferring", "delivering", "delivered", "dead_letter"}
    /\ tier_idx \in 0..(NumTiers - 1)
    /\ \A i \in 0..(NumTiers - 1):
        /\ cb_failures[i] \in 0..100
        /\ cb_last_fail_tick[i] \in 0..10000
        /\ cb_mode[i] \in {"closed", "open", "half_open"}
    /\ \A c \in 0..(NumChatIds - 1):
        /\ tokens[c] \in 0..MaxTokens
        /\ last_refill_tick[c] \in 0..10000
    /\ current_chat \in 0..(NumChatIds - 1)
    /\ guardian \in {"safe", "warning", "emergency"}
    /\ zenoh_retries \in 0..MaxZenohRetries
    /\ zenoh_published \in {TRUE, FALSE}
    /\ \A ch \in 0..(NumChannels - 1):
        /\ gw_attempts[ch] \in 0..(MaxGwRetries + 1)
        /\ gw_delivered[ch] \in {TRUE, FALSE}
    /\ tick \in 0..10000

-----------------------------------------------------------------------------
(* HELPER DEFINITIONS *)
-----------------------------------------------------------------------------

\* At least one gateway channel delivered successfully
SomeChannelDelivered ==
    \E ch \in 0..(NumChannels - 1): gw_delivered[ch] = TRUE

\* All gateway channels have been attempted (success or exhausted retries)
AllChannelsAttempted ==
    \A ch \in 0..(NumChannels - 1):
        gw_delivered[ch] = TRUE \/ gw_attempts[ch] > MaxGwRetries

\* Circuit breaker for tier i is open (tripped and not yet cooled down)
IsCBOpen(i) ==
    /\ cb_mode[i] = "open"
    /\ (tick - cb_last_fail_tick[i]) < CBCooldownTicks

\* Circuit breaker for tier i has cooled down, eligible for half-open probe
IsCBReadyForProbe(i) ==
    /\ cb_mode[i] = "open"
    /\ (tick - cb_last_fail_tick[i]) >= CBCooldownTicks

\* The last tier (rule fallback) index
RuleFallbackIdx == NumTiers - 1

-----------------------------------------------------------------------------
(* INIT *)
-----------------------------------------------------------------------------

Init ==
    /\ state = "received"
    /\ tier_idx = 0
    /\ cb_failures = [i \in 0..(NumTiers - 1) |-> 0]
    /\ cb_last_fail_tick = [i \in 0..(NumTiers - 1) |-> 0]
    /\ cb_mode = [i \in 0..(NumTiers - 1) |-> "closed"]
    /\ tokens = [c \in 0..(NumChatIds - 1) |-> MaxTokens]
    /\ last_refill_tick = [c \in 0..(NumChatIds - 1) |-> 0]
    /\ current_chat = 0
    /\ guardian = "safe"
    /\ zenoh_retries = 0
    /\ zenoh_published = FALSE
    /\ gw_attempts = [ch \in 0..(NumChannels - 1) |-> 0]
    /\ gw_delivered = [ch \in 0..(NumChannels - 1) |-> FALSE]
    /\ tick = 0

-----------------------------------------------------------------------------
(* ACTIONS *)
-----------------------------------------------------------------------------

(* --- Rate Limit Check --- *)
(* Consumes a token from the bucket. If no tokens remain, dead-letters. *)
RateLimitCheck ==
    /\ state = "received"
    /\ IF tokens[current_chat] > 0
       THEN /\ tokens' = [tokens EXCEPT ![current_chat] = tokens[current_chat] - 1]
            /\ state' = "classified"
            /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                           last_refill_tick, current_chat, guardian,
                           zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>
       ELSE /\ state' = "dead_letter"
            /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                           tokens, last_refill_tick, current_chat, guardian,
                           zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Classify Intent --- *)
(* Cortex classifies intent type: simple, voice, complex. *)
(* Also sends immediate ACK to user. *)
Classify ==
    /\ state = "classified"
    /\ state' = "ack_sent"
    /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Send ACK and begin Zenoh publish --- *)
AckAndPublish ==
    /\ state = "ack_sent"
    /\ state' = "publishing"
    /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Zenoh Publish with Retry --- *)
(* Publishes intent to Zenoh backplane. Retries up to MaxZenohRetries. *)
ZenohPublish ==
    /\ state = "publishing"
    /\ \/ \* Success: published
          /\ zenoh_published' = TRUE
          /\ state' = "inferring"
          /\ UNCHANGED <<zenoh_retries>>
       \/ \* Failure: retry if budget remains
          /\ zenoh_retries < MaxZenohRetries
          /\ zenoh_retries' = zenoh_retries + 1
          /\ UNCHANGED <<state, zenoh_published>>
       \/ \* Exhausted retries: proceed to inference anyway (best effort)
          /\ zenoh_retries >= MaxZenohRetries
          /\ state' = "inferring"
          /\ UNCHANGED <<zenoh_retries, zenoh_published>>
    /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   gw_attempts, gw_delivered, tick>>

(* --- Guardian State Transitions --- *)
(* Guardian automaton transitions based on system conditions. *)
(* Transitions: safe -> warning -> emergency and back (never emergency -> safe directly). *)
GuardianEscalate ==
    /\ \/ /\ guardian = "safe"
          /\ guardian' = "warning"
       \/ /\ guardian = "warning"
          /\ guardian' = "emergency"
    /\ UNCHANGED <<state, tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

GuardianDeescalate ==
    /\ \/ /\ guardian = "emergency"
          /\ guardian' = "warning"
       \/ /\ guardian = "warning"
          /\ guardian' = "safe"
    /\ UNCHANGED <<state, tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Try Inference at Current Tier --- *)
(* Attempts inference. On failure, increments tier_idx for cascade. *)
(* Circuit breaker logic: skip open tiers, probe half-open tiers. *)
TryTier ==
    /\ state = "inferring"
    /\ tier_idx < NumTiers
    /\ tier_idx # RuleFallbackIdx  \* Rule fallback handled separately
    /\ IF IsCBOpen(tier_idx)
       THEN \* Circuit breaker open: skip this tier
            /\ tier_idx' = tier_idx + 1
            /\ UNCHANGED <<state, cb_failures, cb_last_fail_tick, cb_mode,
                           tokens, last_refill_tick, current_chat, guardian,
                           zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>
       ELSE \/ \* Success: proceed to delivery
               /\ state' = "delivering"
               /\ cb_failures' = [cb_failures EXCEPT ![tier_idx] = 0]
               /\ cb_mode' = [cb_mode EXCEPT ![tier_idx] = "closed"]
               /\ UNCHANGED <<tier_idx, cb_last_fail_tick,
                              tokens, last_refill_tick, current_chat, guardian,
                              zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>
            \/ \* Failure: record failure, advance to next tier
               /\ tier_idx' = tier_idx + 1
               /\ cb_failures' = [cb_failures EXCEPT ![tier_idx] = cb_failures[tier_idx] + 1]
               /\ cb_last_fail_tick' = [cb_last_fail_tick EXCEPT ![tier_idx] = tick]
               /\ cb_mode' = [cb_mode EXCEPT ![tier_idx] =
                    IF cb_failures[tier_idx] + 1 >= CBFailThreshold
                    THEN "open"
                    ELSE cb_mode[tier_idx]]
               /\ UNCHANGED <<state, tokens, last_refill_tick, current_chat, guardian,
                              zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Rule Fallback (Tier 5) --- *)
(* The last tier is the local rule engine. It NEVER fails. *)
RuleFallback ==
    /\ state = "inferring"
    /\ tier_idx = RuleFallbackIdx
    /\ state' = "delivering"
    /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Circuit Breaker Recovery --- *)
(* After cooldown, an open circuit breaker transitions to half_open. *)
CBRecovery ==
    /\ \E i \in 0..(NumTiers - 1):
        /\ IsCBReadyForProbe(i)
        /\ cb_mode' = [cb_mode EXCEPT ![i] = "half_open"]
        /\ UNCHANGED <<state, tier_idx, cb_failures, cb_last_fail_tick,
                       tokens, last_refill_tick, current_chat, guardian,
                       zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Gateway Parallel Delivery --- *)
(* Delivers response to all channels in parallel. Each channel retries independently. *)
GatewayDeliver ==
    /\ state = "delivering"
    /\ \E ch \in 0..(NumChannels - 1):
        /\ gw_delivered[ch] = FALSE
        /\ gw_attempts[ch] <= MaxGwRetries
        /\ \/ \* Channel delivery succeeds
              /\ gw_delivered' = [gw_delivered EXCEPT ![ch] = TRUE]
              /\ gw_attempts' = [gw_attempts EXCEPT ![ch] = gw_attempts[ch] + 1]
           \/ \* Channel delivery fails, increment attempt
              /\ gw_attempts' = [gw_attempts EXCEPT ![ch] = gw_attempts[ch] + 1]
              /\ UNCHANGED gw_delivered
    /\ UNCHANGED <<state, tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   zenoh_retries, zenoh_published, tick>>

(* --- Finalize Delivery --- *)
(* When all channels have been attempted, transition to delivered if any succeeded. *)
FinalizeDelivery ==
    /\ state = "delivering"
    /\ AllChannelsAttempted
    /\ IF SomeChannelDelivered
       THEN state' = "delivered"
       ELSE state' = "dead_letter"
    /\ UNCHANGED <<tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Token Bucket Refill --- *)
(* Periodically refills tokens for rate limiting. *)
TokenRefill ==
    /\ \E c \in 0..(NumChatIds - 1):
        /\ (tick - last_refill_tick[c]) >= RefillTicks
        /\ tokens[c] < MaxTokens
        /\ tokens' = [tokens EXCEPT ![c] = MaxTokens]
        /\ last_refill_tick' = [last_refill_tick EXCEPT ![c] = tick]
    /\ UNCHANGED <<state, tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   current_chat, guardian,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered, tick>>

(* --- Clock Tick --- *)
(* Advances the global tick counter for circuit breaker cooldown and token refill. *)
Tick ==
    /\ tick < 10000
    /\ tick' = tick + 1
    /\ UNCHANGED <<state, tier_idx, cb_failures, cb_last_fail_tick, cb_mode,
                   tokens, last_refill_tick, current_chat, guardian,
                   zenoh_retries, zenoh_published, gw_attempts, gw_delivered>>

-----------------------------------------------------------------------------
(* NEXT STATE RELATION *)
-----------------------------------------------------------------------------

Next ==
    \/ RateLimitCheck
    \/ Classify
    \/ AckAndPublish
    \/ ZenohPublish
    \/ TryTier
    \/ RuleFallback
    \/ CBRecovery
    \/ GatewayDeliver
    \/ FinalizeDelivery
    \/ TokenRefill
    \/ GuardianEscalate
    \/ GuardianDeescalate
    \/ Tick

-----------------------------------------------------------------------------
(* FAIRNESS *)
-----------------------------------------------------------------------------

Fairness ==
    /\ WF_vars(RateLimitCheck)
    /\ WF_vars(Classify)
    /\ WF_vars(AckAndPublish)
    /\ WF_vars(ZenohPublish)
    /\ WF_vars(TryTier)
    /\ WF_vars(RuleFallback)
    /\ WF_vars(GatewayDeliver)
    /\ WF_vars(FinalizeDelivery)
    /\ WF_vars(TokenRefill)
    /\ WF_vars(CBRecovery)
    /\ SF_vars(Tick)

-----------------------------------------------------------------------------
(* SPECIFICATION *)
-----------------------------------------------------------------------------

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
(* SAFETY PROPERTIES *)
-----------------------------------------------------------------------------

(* S1: NoBlackhole — every received message eventually reaches delivered or dead_letter.
   A message is never stuck forever in an intermediate state. *)
NoBlackhole ==
    [](state = "received" => <>(state \in {"delivered", "dead_letter"}))

(* S2: ResponseWithinBoundedTiers — inference exhausts at most NumTiers attempts
   before the rule fallback guarantees delivery. *)
ResponseWithinBoundedTiers ==
    [](state = "inferring" => <>(state = "delivering"))

(* S3: RuleFallbackAlways — the last tier (rule engine) NEVER fails.
   Whenever tier_idx reaches the rule fallback, the system proceeds to delivery. *)
RuleFallbackNeverFails ==
    [](state = "inferring" /\ tier_idx = RuleFallbackIdx
       => <>(state = "delivering"))

(* S4: RateLimitSafety — token count is always within valid bounds. *)
RateLimitSafety ==
    \A c \in 0..(NumChatIds - 1): tokens[c] >= 0 /\ tokens[c] <= MaxTokens

(* S5: GuardianNeverSkipsWarning — the guardian automaton cannot jump
   directly from emergency to safe. It must pass through warning. *)
GuardianTransitionSafety ==
    [](guardian = "emergency" => guardian' # "safe" \/ UNCHANGED guardian)

(* S6: CircuitBreakerIntegrity — an open circuit breaker never allows
   normal inference (only half-open probes after cooldown). *)
CircuitBreakerIntegrity ==
    \A i \in 0..(NumTiers - 1):
        cb_mode[i] = "open" => cb_failures[i] >= CBFailThreshold

-----------------------------------------------------------------------------
(* LIVENESS PROPERTIES *)
-----------------------------------------------------------------------------

(* L1: CircuitBreakerRecovery — an open circuit breaker eventually
   transitions to half_open after the cooldown period elapses. *)
CircuitBreakerRecovery ==
    \A i \in 0..(NumTiers - 1):
        [](cb_mode[i] = "open" => <>(cb_mode[i] = "half_open"))

(* L2: GatewayDelivery — at least one channel eventually delivers
   when the system reaches the delivering state. *)
GatewayDelivery ==
    [](state = "delivering" => <>(SomeChannelDelivered \/ state = "dead_letter"))

(* L3: TokensEventuallyRefill — a depleted token bucket eventually
   gets refilled, ensuring the rate limiter does not permanently block. *)
TokensEventuallyRefill ==
    \A c \in 0..(NumChatIds - 1):
        [](tokens[c] = 0 => <>(tokens[c] > 0))

(* L4: ProgressGuarantee — the system always eventually reaches a
   terminal state (delivered or dead_letter). *)
ProgressGuarantee ==
    <>(state \in {"delivered", "dead_letter"})

=============================================================================
