-- =============================================================================
-- AGDA MODULE: Emergency Response Termination Proof
-- Purpose: Prove emergency handling ALWAYS terminates
-- Context: Stream Beta (Task 30.1.4)
-- =============================================================================

module Intelitor.Emergency where

open import Intelitor.Foundations
open import Induction.WellFounded

-- ---------------------------------------------------------------------------
-- Emergency Phases (Ordered Progression)
-- ---------------------------------------------------------------------------

data EmergencyPhase : Set where
  Detected   : EmergencyPhase
  Halted     : EmergencyPhase
  Logged     : EmergencyPhase
  RCAStarted : EmergencyPhase
  Mitigated  : EmergencyPhase
  Recovered  : EmergencyPhase

-- ---------------------------------------------------------------------------
-- Phase Ordering (Strict Order)
-- ---------------------------------------------------------------------------

data _<ₚ_ : EmergencyPhase → EmergencyPhase → Set where
  det<hal : Detected   <ₚ Halted
  hal<log : Halted     <ₚ Logged
  log<rca : Logged     <ₚ RCAStarted
  rca<mit : RCAStarted <ₚ Mitigated
  mit<rec : Mitigated  <ₚ Recovered

-- ---------------------------------------------------------------------------
-- THEOREM: Phase Ordering is Well-Founded
-- ---------------------------------------------------------------------------

<ₚ-wellFounded : WellFounded _<ₚ_
<ₚ-wellFounded Detected   = acc (λ y ())
<ₚ-wellFounded Halted     = acc (λ { Detected det<hal → <ₚ-wellFounded Detected })
<ₚ-wellFounded Logged     = acc (λ { Halted hal<log → <ₚ-wellFounded Halted })
<ₚ-wellFounded RCAStarted = acc (λ { Logged log<rca → <ₚ-wellFounded Logged })
<ₚ-wellFounded Mitigated  = acc (λ { RCAStarted rca<mit → <ₚ-wellFounded RCAStarted })
<ₚ-wellFounded Recovered  = acc (λ { Mitigated mit<rec → <ₚ-wellFounded Mitigated })

-- ---------------------------------------------------------------------------
-- Emergency Handler (Monotonic Progress)
-- ---------------------------------------------------------------------------

handleEmergency : EmergencyPhase → EmergencyPhase
handleEmergency Detected   = Halted
handleEmergency Halted     = Logged
handleEmergency Logged     = RCAStarted
handleEmergency RCAStarted = Mitigated
handleEmergency Mitigated  = Recovered
handleEmergency Recovered  = Recovered

-- ---------------------------------------------------------------------------
-- THEOREM: Handler Makes Progress
-- ---------------------------------------------------------------------------

handler-progress : (p : EmergencyPhase) →
                   ¬ (p ≡ Recovered) →
                   p <ₚ handleEmergency p
handler-progress Detected   _ = det<hal
handler-progress Halted     _ = hal<log
handler-progress Logged     _ = log<rca
handler-progress RCAStarted _ = rca<mit
handler-progress Mitigated  _ = mit<rec
handler-progress Recovered  p≢r = ⊥-elim (p≢r refl)

-- ---------------------------------------------------------------------------
-- THEOREM: Eventually Reaches Recovered
-- ---------------------------------------------------------------------------

stepsToRecovered : EmergencyPhase → ℕ
stepsToRecovered Detected   = 5
stepsToRecovered Halted     = 4
stepsToRecovered Logged     = 3
stepsToRecovered RCAStarted = 2
stepsToRecovered Mitigated  = 1
stepsToRecovered Recovered  = 0

iterate : {A : Set} → (A → A) → ℕ → A → A
iterate f zero    x = x
iterate f (suc n) x = iterate f n (f x)

eventually-recovered : (p : EmergencyPhase) →
                       iterate handleEmergency (stepsToRecovered p) p ≡ Recovered
eventually-recovered Detected   = refl
eventually-recovered Halted     = refl
eventually-recovered Logged     = refl
eventually-recovered RCAStarted = refl
eventually-recovered Mitigated  = refl
eventually-recovered Recovered  = refl
