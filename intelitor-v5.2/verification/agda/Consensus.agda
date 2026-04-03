-- =============================================================================
-- AGDA MODULE: Five-Point Pattern System Consensus Verification
-- Purpose: Prove EP-110 prevention (consensus disagreement → emergency)
-- Context: Stream Beta (Task 30.1.5)
-- =============================================================================

module Consensus where

open import Intelitor.Foundations
open import Intelitor.Axioms

-- SC-PAN-002: 2oo3 Voting Logic Invariant
-- Every actuation requires agreement from 2 out of 3 independent nodes.

data Node : Set where
  live   : Node
  shadow : Node
  model  : Node

data Result : Set where
  actuate : Result
  halt    : Result

-- A Vote is a mapping from Node to Result
Vote = Node → Result

-- The 2oo3 judge helper: takes three results directly to avoid
-- with-clause product ambiguity (SplitError.BlockedType).
judge₃ : Result → Result → Result → Result
judge₃ actuate actuate _       = actuate
judge₃ actuate _       actuate = actuate
judge₃ _       actuate actuate = actuate
judge₃ _       _       _       = halt

-- The 2oo3 Judge Function
judge : Vote → Result
judge v = judge₃ (v live) (v shadow) (v model)

-- Helper lemma: given three concrete results and a proof that judge₃
-- returns actuate, produce equalities witnessing which two agree.
-- This avoids the with-clause abstraction problem where existentially
-- bound v(n1), v(n2) don't get replaced by the with variables.
quorum-witness : (a b c : Result) → judge₃ a b c ≡ actuate →
  ((a ≡ actuate) × (b ≡ actuate)) ⊎
  ((a ≡ actuate) × (c ≡ actuate)) ⊎
  ((b ≡ actuate) × (c ≡ actuate))
quorum-witness actuate actuate _       _ = inj₁ (refl , refl)
quorum-witness actuate halt    actuate _ = inj₂ (inj₁ (refl , refl))
quorum-witness halt    actuate actuate _ = inj₂ (inj₂ (refl , refl))
-- Remaining cases: judge₃ returns halt, so p : halt ≡ actuate is absurd
quorum-witness actuate halt    halt    ()
quorum-witness halt    actuate halt    ()
quorum-witness halt    halt    _       ()

-- PROOF: Quorum ensures safe actuation even if one node is Byzantine.
-- Strategy: delegate case analysis to quorum-witness, then use the
-- returned equalities to construct the existential witnesses.
quorum-safe : (v : Vote) → (judge v ≡ actuate) →
  ∃[ n1 ] ∃[ n2 ] ((n1 ≢ n2) × (v n1 ≡ actuate) × (v n2 ≡ actuate))
quorum-safe v p with quorum-witness (v live) (v shadow) (v model) p
... | inj₁ (eq₁ , eq₂)        = live   , (shadow , ((λ ()) , (eq₁ , eq₂)))
... | inj₂ (inj₁ (eq₁ , eq₂)) = live   , (model  , ((λ ()) , (eq₁ , eq₂)))
... | inj₂ (inj₂ (eq₁ , eq₂)) = shadow , (model  , ((λ ()) , (eq₁ , eq₂)))


-- ---------------------------------------------------------------------------
-- Validation Methods
-- ---------------------------------------------------------------------------

data ValidationMethod : Set where
  Pattern     : ValidationMethod
  AST         : ValidationMethod
  Statistical : ValidationMethod
  Binary      : ValidationMethod
  LineByLine  : ValidationMethod

allMethods : Vec ValidationMethod 5
allMethods = Pattern ∷ AST ∷ Statistical ∷ Binary ∷ LineByLine ∷ []

-- ---------------------------------------------------------------------------
-- Validation Result Record
-- ---------------------------------------------------------------------------

record ValidationResult : Set where
  constructor mkResult
  field
    errors   : ℕ
    warnings : ℕ

-- ---------------------------------------------------------------------------
-- Consensus Definition
-- ---------------------------------------------------------------------------

AllAgreeOnErrors : Vec ValidationResult 5 → Set
AllAgreeOnErrors results = All (λ r → ValidationResult.errors r ≡ e₀) results
  where
    e₀ = ValidationResult.errors (head results)

    All : {A : Set} {n : ℕ} → (A → Set) → Vec A n → Set
    All P []       = ⊤
    All P (x ∷ xs) = P x × All P xs

AllAgreeOnWarnings : Vec ValidationResult 5 → Set
AllAgreeOnWarnings results = All (λ r → ValidationResult.warnings r ≡ w₀) results
  where
    w₀ = ValidationResult.warnings (head results)

    All : {A : Set} {n : ℕ} → (A → Set) → Vec A n → Set
    All P []       = ⊤
    All P (x ∷ xs) = P x × All P xs

Consensus : Vec ValidationResult 5 → Set
Consensus results = AllAgreeOnErrors results × AllAgreeOnWarnings results

-- ---------------------------------------------------------------------------
-- Consensus Decision Type
-- ---------------------------------------------------------------------------

data ConsensusDecision : Set where
  Agreed    : (errors : ℕ) → (warnings : ℕ) → ConsensusDecision
  Emergency : ConsensusDecision

-- ---------------------------------------------------------------------------
-- Consensus Checker (With Decidability)
-- ---------------------------------------------------------------------------

checkConsensus : (results : Vec ValidationResult 5) →
                 Dec (Consensus results) →
                 ConsensusDecision
checkConsensus results (yes (errAgree , warnAgree)) =
  Agreed (ValidationResult.errors (head results))
         (ValidationResult.warnings (head results))
checkConsensus results (no _) = Emergency

-- ---------------------------------------------------------------------------
-- THEOREM: EP-110 Prevention Guarantee
-- ---------------------------------------------------------------------------

disagreement-triggers-emergency :
  (results : Vec ValidationResult 5) →
  (¬consensus : ¬ Consensus results) →
  checkConsensus results (no ¬consensus) ≡ Emergency
disagreement-triggers-emergency results ¬consensus = refl

-- ---------------------------------------------------------------------------
-- Safe Validation Function
-- ---------------------------------------------------------------------------

record SafeValidationResult : Set where
  field
    errors      : ℕ
    warnings    : ℕ
    methods     : Vec ValidationResult 5
    consensus   : Consensus methods
    errorsMatch : ValidationResult.errors (head methods) ≡ errors
    warnsMatch  : ValidationResult.warnings (head methods) ≡ warnings

validate : (methods : Vec ValidationResult 5) →
           (prf : Consensus methods) →
           SafeValidationResult
validate methods prf = record
  { errors      = ValidationResult.errors (head methods)
  ; warnings    = ValidationResult.warnings (head methods)
  ; methods     = methods
  ; consensus   = prf
  ; errorsMatch = refl
  ; warnsMatch  = refl
  }
