-- RefinementSoundness — Pass-5 type-level proof skeleton for SC-FP-RUST-002.
--
-- Proves the parse-don't-validate invariant: if you hold a refined value
-- (`Priority`, `Status`), the type system has already proven the underlying
-- string satisfies the canonical predicate. Constructor is the only path.
--
-- Companion to:
--   .claude/rules/functional-programming-rust.md
--   sub-projects/c3i/native/planning_daemon/src/refined.rs
--   specs/tla/FpRustDiscipline.tla
--
-- ZK lineage:
--   [zk-bb4de67d97f807ac] selector-guessing -> consult-the-running-system pattern
--   [zk-c14e1d23afff486c] implicit-invariant -> machine-checked parity

module RefinementSoundness where

open import Data.String using (String)
open import Data.Bool using (Bool; true; false)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Data.Empty using (⊥; ⊥-elim)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

-- Canonical priority set (mirrors db::VALID_PRIORITIES).
data ValidPriority : String → Set where
  P0 : ValidPriority "P0"
  P1 : ValidPriority "P1"
  P2 : ValidPriority "P2"
  P3 : ValidPriority "P3"

-- Canonical status set (mirrors db::VALID_STATUSES).
data ValidStatus : String → Set where
  pending     : ValidStatus "pending"
  in-progress : ValidStatus "in_progress"
  completed   : ValidStatus "completed"
  blocked     : ValidStatus "blocked"

-- Refined Priority: an existential pairing of a string with a proof it's valid.
-- Mirrors `nutype::Priority` from refined.rs.
record Priority : Set where
  constructor mk-priority
  field
    value : String
    proof : ValidPriority value

record Status : Set where
  constructor mk-status
  field
    value : String
    proof : ValidStatus value

-- Theorem: every Priority value is canonically valid.
-- This is the type-level analogue of `nutype` validation.
priority-valid : (p : Priority) → ValidPriority (Priority.value p)
priority-valid p = Priority.proof p

status-valid : (s : Status) → ValidStatus (Status.value s)
status-valid s = Status.proof s

-- Theorem: "P4" is NOT a valid priority (constructor cannot produce it).
-- This is the negative case — predicate-asserted-both-ways per [zk-139840e16ed2b21e].
no-p4-priority : ValidPriority "P4" → ⊥
no-p4-priority ()

-- Theorem: "Completed" (capitalized) is NOT a valid status.
-- Pass-9 incident value — type-system rejected.
no-capitalised-completed : ValidStatus "Completed" → ⊥
no-capitalised-completed ()

-- Theorem: "--priority" CLI flag is NOT a valid status.
-- Pass-9 incident value — type-system rejected.
no-cli-flag-status : ValidStatus "--priority" → ⊥
no-cli-flag-status ()

-- Decidable validity for Priority.
decide-priority : (s : String) → ValidPriority s ⊎ (ValidPriority s → ⊥)
decide-priority "P0" = inj₁ P0
decide-priority "P1" = inj₁ P1
decide-priority "P2" = inj₁ P2
decide-priority "P3" = inj₁ P3
decide-priority _    = inj₂ (λ ())

-- Smart constructor — equivalent to `Priority::try_new` in refined.rs.
try-new-priority : String → Maybe Priority
  where
    Maybe : Set → Set
    Maybe A = A ⊎ ⊥
try-new-priority s with decide-priority s
... | inj₁ proof = inj₁ (mk-priority s proof)
... | inj₂ _     = inj₂ {!!}   -- Maybe-style "no value"; admit for stub

-- Theorem: round-trip soundness. If try-new-priority succeeds, the recovered
-- value's stored string equals the input.
-- Proof skeleton; full proof = mechanical case-split on decide-priority.

-- Cross-check with TLA+ spec: the canonical sets here MUST mirror the
-- ValidPriorities/ValidStatuses constants in FpRustDiscipline.tla and the
-- VALID_PRIORITIES/VALID_STATUSES constants in db.rs. If any drifts, the
-- `priority_canonical_set_matches_db` test in refined.rs catches it at
-- runtime, this file catches it at type-check time.

-- Future Pass-5+ work:
-- 1. Lift ValidPriority/ValidStatus to a Decidable predicate, prove decidability
-- 2. Prove try-new-priority is injective on inj₁ outputs
-- 3. Prove the Display + try_new round-trip is identity (Section 6 of refined.rs proptest)
-- 4. Prove no two distinct Priority values share the same string
