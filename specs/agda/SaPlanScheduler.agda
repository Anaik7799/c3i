------------------------------------------------------------------------
-- SaPlanScheduler.agda
--
-- Formal verification of the sa-plan-daemon Oban-style job scheduler
-- with the Marionette gleam_run worker.
--
-- Companion TLA+ specification: specs/tla/SaPlanScheduler.tla
--
-- ZK refs: [zk-1244561d0d947e93] current scheduling ontology,
--          [zk-82e186046d331ccf] execution detail.
--
-- Agda 2.x — uses UTF-8 mathematical operators.
------------------------------------------------------------------------

module SaPlanScheduler where

open import Data.Product using (Σ; _×_; _,_; ∃)
open import Data.Empty   using (⊥)
open import Data.Sum     using (_⊎_; inj₁; inj₂)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Relation.Nullary using (¬_; Dec; yes; no)

------------------------------------------------------------------------
-- §1. Job state ADT
--
-- Eight states model the job lifecycle. The state-space size N = 8;
-- the transition relation has |T| = 12 valid edges, giving an
-- edge density ρ = 12 / (8²) = 0.1875.
------------------------------------------------------------------------

data State : Set where
  Scheduled  : State    -- enqueued, scheduled_at in future
  Available  : State    -- ready to be claimed by a worker
  Executing  : State    -- claimed by a worker, running
  Completed  : State    -- terminal: success
  Failed     : State    -- terminal: exhausted retries
  Retryable  : State    -- transient failure, awaiting backoff
  Discarded  : State    -- terminal: explicitly dropped
  Cancelled  : State    -- terminal: cancelled by operator

------------------------------------------------------------------------
-- §2. Terminal predicate
------------------------------------------------------------------------

data Terminal : State → Set where
  term-completed : Terminal Completed
  term-failed    : Terminal Failed
  term-discarded : Terminal Discarded
  term-cancelled : Terminal Cancelled

------------------------------------------------------------------------
-- §3. Transition relation
--
-- Each constructor names a real edge in the scheduler state machine.
-- The 12 edges:
--   Scheduled → Available   (Tick)
--   Available → Executing   (Claim)
--   Executing → Completed   (Success)
--   Executing → Retryable   (Failure-Retryable)
--   Executing → Failed      (Failure-Final)
--   Executing → Available   (Lifeline)         -- stuck-job recovery
--   Retryable → Available   (Backoff)
--   Available → Cancelled   (Cancel-Available)
--   Scheduled → Cancelled   (Cancel-Scheduled)
--   Retryable → Cancelled   (Cancel-Retryable)
--   Available → Discarded   (Discard)
--   Scheduled → Discarded   (Discard-Scheduled)
------------------------------------------------------------------------

data Transition : State → State → Set where
  Tick               : Transition Scheduled Available
  Claim              : Transition Available Executing
  Success            : Transition Executing Completed
  Failure-Retryable  : Transition Executing Retryable
  Failure-Final      : Transition Executing Failed
  Lifeline           : Transition Executing Available
  Backoff            : Transition Retryable Available
  Cancel-Available   : Transition Available Cancelled
  Cancel-Scheduled   : Transition Scheduled Cancelled
  Cancel-Retryable   : Transition Retryable Cancelled
  Discard            : Transition Available Discarded
  Discard-Scheduled  : Transition Scheduled Discarded

------------------------------------------------------------------------
-- §4. Decidable validity over state pairs
--
-- ValidEdge enumerates the same 12 pairs as data; well-formed shows
-- that every Transition inhabits a ValidEdge.
------------------------------------------------------------------------

data ValidEdge : State → State → Set where
  ve-tick        : ValidEdge Scheduled Available
  ve-claim       : ValidEdge Available Executing
  ve-success     : ValidEdge Executing Completed
  ve-fail-retry  : ValidEdge Executing Retryable
  ve-fail-final  : ValidEdge Executing Failed
  ve-lifeline    : ValidEdge Executing Available
  ve-backoff     : ValidEdge Retryable Available
  ve-cancel-a    : ValidEdge Available Cancelled
  ve-cancel-s    : ValidEdge Scheduled Cancelled
  ve-cancel-r    : ValidEdge Retryable Cancelled
  ve-discard-a   : ValidEdge Available Discarded
  ve-discard-s   : ValidEdge Scheduled Discarded

well-formed : ∀ {s s'} → Transition s s' → ValidEdge s s'
well-formed Tick               = ve-tick
well-formed Claim              = ve-claim
well-formed Success            = ve-success
well-formed Failure-Retryable  = ve-fail-retry
well-formed Failure-Final      = ve-fail-final
well-formed Lifeline           = ve-lifeline
well-formed Backoff            = ve-backoff
well-formed Cancel-Available   = ve-cancel-a
well-formed Cancel-Scheduled   = ve-cancel-s
well-formed Cancel-Retryable   = ve-cancel-r
well-formed Discard            = ve-discard-a
well-formed Discard-Scheduled  = ve-discard-s

------------------------------------------------------------------------
-- §5. Reachability (reflexive-transitive closure)
------------------------------------------------------------------------

data Reachable : State → State → Set where
  refl-r  : ∀ {s} → Reachable s s
  step-r  : ∀ {s t u} → Transition s t → Reachable t u → Reachable s u

------------------------------------------------------------------------
-- §6. Liveness assumption
--
-- Workers pick up Available jobs and complete them with non-zero
-- probability. We model this as a constructor witnessing fairness
-- of the scheduler's claim+execute pair.
------------------------------------------------------------------------

postulate
  fair-claim   : Transition Available Executing            -- = Claim
  fair-finish  : Transition Executing Completed            -- = Success

------------------------------------------------------------------------
-- §7. Main theorem — terminal-reachable
--
-- From any state reachable from Available, some terminal state is
-- reachable. The witness goes through Claim ∘ Success.
------------------------------------------------------------------------

terminal-reachable : ∀ {s}
                   → Reachable Available s
                   → ∃ λ t → Terminal t × Reachable s t
terminal-reachable {Available} _ =
  Completed ,
  term-completed ,
  step-r fair-claim (step-r fair-finish refl-r)
terminal-reachable {Executing} _ =
  Completed ,
  term-completed ,
  step-r fair-finish refl-r
terminal-reachable {Completed} _ =
  Completed , term-completed , refl-r
terminal-reachable {Failed} _ =
  Failed , term-failed , refl-r
terminal-reachable {Discarded} _ =
  Discarded , term-discarded , refl-r
terminal-reachable {Cancelled} _ =
  Cancelled , term-cancelled , refl-r
terminal-reachable {Retryable} _ =
  Completed ,
  term-completed ,
  step-r Backoff (step-r fair-claim (step-r fair-finish refl-r))
terminal-reachable {Scheduled} _ =
  Completed ,
  term-completed ,
  step-r Tick (step-r fair-claim (step-r fair-finish refl-r))

------------------------------------------------------------------------
-- §8. Safety lemma — terminal states have no outgoing transitions.
------------------------------------------------------------------------

terminal-stuck : ∀ {s s'} → Terminal s → ¬ Transition s s'
terminal-stuck term-completed ()
terminal-stuck term-failed    ()
terminal-stuck term-discarded ()
terminal-stuck term-cancelled ()

------------------------------------------------------------------------
-- End of SaPlanScheduler.agda
------------------------------------------------------------------------
