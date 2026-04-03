-- Cross-Holon Database Access: Version Vector Formal Proofs
-- Language: Agda (Dependently Typed Proof Assistant)
-- Version: 2.0.0 (ported from stdlib to Intelitor.Foundations)
-- Date: 2026-03-22
--
-- STAMP Compliance: SC-XHOLON-007, SC-CONC-001, SC-CONC-002
-- Properties Proven:
--   1. Monotonicity of increment
--   2. Commutativity of merge
--   3. Associativity of merge
--   4. Idempotency of merge
--   5. Merge upper bounds
--   6. Transitivity of happens-before
--   7. Irreflexivity of happens-before
--   8. Mutual exclusion of happens-before and concurrent
--   9. OCC correctness (compare-and-swap)
--  10. Merge preserves causality
--  11. Concurrent detection is symmetric

module VersionVector where

open import Intelitor.Foundations

-- ==========================================================================
-- ARITHMETIC INFRASTRUCTURE
-- ==========================================================================

-- Maximum (pointwise max used by merge)
_⊔_ : ℕ → ℕ → ℕ
zero  ⊔ n     = n
suc m ⊔ zero  = suc m
suc m ⊔ suc n = suc (m ⊔ n)

infixl 6 _⊔_

-- Ordering on naturals
data _≤_ : ℕ → ℕ → Set where
  z≤n : ∀ {n} → zero ≤ n
  s≤s : ∀ {m n} → m ≤ n → suc m ≤ suc n

infix 4 _≤_

_≥_ : ℕ → ℕ → Set
m ≥ n = n ≤ m

_<_ : ℕ → ℕ → Set
m < n = suc m ≤ n

-- Congruence (not in Foundations)
cong : {A B : Set} {x y : A} → (f : A → B) → x ≡ y → f x ≡ f y
cong f refl = refl

-- Conditional on Bool
if_then_else_ : {A : Set} → Bool → A → A → A
if true  then t else _ = t
if false then _ else f = f

-- Boolean equality on ℕ
_==_ : ℕ → ℕ → Bool
zero  == zero  = true
zero  == suc _ = false
suc _ == zero  = false
suc m == suc n = m == n

-- ==========================================================================
-- ORDERING LEMMAS
-- ==========================================================================

≤-refl : ∀ {n} → n ≤ n
≤-refl {zero}  = z≤n
≤-refl {suc n} = s≤s ≤-refl

≤-trans : ∀ {a b c} → a ≤ b → b ≤ c → a ≤ c
≤-trans z≤n     _       = z≤n
≤-trans (s≤s p) (s≤s q) = s≤s (≤-trans p q)

n≤suc-n : ∀ {n} → n ≤ suc n
n≤suc-n {zero}  = z≤n
n≤suc-n {suc n} = s≤s n≤suc-n

-- n < n is impossible
¬-<-refl : ∀ {n} → n < n → ⊥
¬-<-refl {suc n} (s≤s p) = ¬-<-refl p

-- ==-refl: n == n always yields true
==-refl : ∀ n → (n == n) ≡ true
==-refl zero    = refl
==-refl (suc n) = ==-refl n

-- ==========================================================================
-- MAXIMUM (⊔) LEMMAS
-- ==========================================================================

⊔-comm : ∀ m n → m ⊔ n ≡ n ⊔ m
⊔-comm zero    zero    = refl
⊔-comm zero    (suc n) = refl
⊔-comm (suc m) zero    = refl
⊔-comm (suc m) (suc n) = cong suc (⊔-comm m n)

⊔-assoc : ∀ m n p → (m ⊔ n) ⊔ p ≡ m ⊔ (n ⊔ p)
⊔-assoc zero    n       p       = refl
⊔-assoc (suc m) zero    p       = refl
⊔-assoc (suc m) (suc n) zero    = refl
⊔-assoc (suc m) (suc n) (suc p) = cong suc (⊔-assoc m n p)

⊔-idem : ∀ n → n ⊔ n ≡ n
⊔-idem zero    = refl
⊔-idem (suc n) = cong suc (⊔-idem n)

m≤m⊔n : ∀ m n → m ≤ m ⊔ n
m≤m⊔n zero    n       = z≤n
m≤m⊔n (suc m) zero    = ≤-refl
m≤m⊔n (suc m) (suc n) = s≤s (m≤m⊔n m n)

n≤m⊔n : ∀ m n → n ≤ m ⊔ n
n≤m⊔n zero    n       = ≤-refl
n≤m⊔n (suc m) zero    = z≤n
n≤m⊔n (suc m) (suc n) = s≤s (n≤m⊔n m n)

-- ==========================================================================
-- TYPE DEFINITIONS
-- ==========================================================================

-- Use ℕ for holon identifiers (avoids String/BUILTIN NATURAL conflict)
HolonId : Set
HolonId = ℕ

Version : Set
Version = ℕ

-- Version vector as a function from holon ID to version
record VersionVec : Set where
  constructor mkVV
  field
    lookup : HolonId → Version

open VersionVec

-- ==========================================================================
-- BASIC OPERATIONS
-- ==========================================================================

-- Empty version vector (all zeros)
emptyVV : VersionVec
emptyVV = mkVV (λ _ → zero)

-- Increment version for a specific holon
increment : VersionVec → HolonId → VersionVec
increment vv h = mkVV (λ h' → if h == h' then suc (lookup vv h') else lookup vv h')

-- Merge two version vectors (pointwise maximum)
merge : VersionVec → VersionVec → VersionVec
merge vv₁ vv₂ = mkVV (λ h → lookup vv₁ h ⊔ lookup vv₂ h)

-- ==========================================================================
-- ORDERING RELATIONS
-- ==========================================================================

-- Pointwise less-than-or-equal
_≤ᵥ_ : VersionVec → VersionVec → Set
vv₁ ≤ᵥ vv₂ = ∀ (h : HolonId) → lookup vv₁ h ≤ lookup vv₂ h

-- Happens-before: pointwise ≤ with at least one strict <
_<ᵥ_ : VersionVec → VersionVec → Set
vv₁ <ᵥ vv₂ = (vv₁ ≤ᵥ vv₂) × (∃ λ h → lookup vv₁ h < lookup vv₂ h)

-- Concurrent: neither happens-before the other
concurrent : VersionVec → VersionVec → Set
concurrent vv₁ vv₂ = ¬ (vv₁ <ᵥ vv₂) × ¬ (vv₂ <ᵥ vv₁)

-- Greater-than-or-equal (for OCC checking)
_≥ᵥ_ : VersionVec → VersionVec → Set
vv₁ ≥ᵥ vv₂ = vv₂ ≤ᵥ vv₁

-- ==========================================================================
-- PROPERTY 1: MONOTONICITY OF INCREMENT
-- SC-XHOLON-007: Version vectors MUST be monotonically increasing
-- ==========================================================================

-- Incrementing a version vector always produces a ≥ version
increment-monotonic : ∀ (vv : VersionVec) (h : HolonId)
                    → vv ≤ᵥ increment vv h
increment-monotonic vv h h' with h == h'
... | true  = n≤suc-n
... | false = ≤-refl

-- Incrementing strictly increases the version at that holon
increment-strict : ∀ (vv : VersionVec) (h : HolonId)
                 → lookup vv h < lookup (increment vv h) h
increment-strict vv h rewrite ==-refl h = ≤-refl

-- ==========================================================================
-- PROPERTY 2: COMMUTATIVITY OF MERGE
-- ==========================================================================

merge-comm : ∀ (vv₁ vv₂ : VersionVec)
           → ∀ (h : HolonId)
           → lookup (merge vv₁ vv₂) h ≡ lookup (merge vv₂ vv₁) h
merge-comm vv₁ vv₂ h = ⊔-comm (lookup vv₁ h) (lookup vv₂ h)

-- ==========================================================================
-- PROPERTY 3: ASSOCIATIVITY OF MERGE
-- ==========================================================================

merge-assoc : ∀ (vv₁ vv₂ vv₃ : VersionVec)
            → ∀ (h : HolonId)
            → lookup (merge (merge vv₁ vv₂) vv₃) h ≡ lookup (merge vv₁ (merge vv₂ vv₃)) h
merge-assoc vv₁ vv₂ vv₃ h = ⊔-assoc (lookup vv₁ h) (lookup vv₂ h) (lookup vv₃ h)

-- ==========================================================================
-- PROPERTY 4: IDEMPOTENCY OF MERGE
-- ==========================================================================

merge-idem : ∀ (vv : VersionVec)
           → ∀ (h : HolonId)
           → lookup (merge vv vv) h ≡ lookup vv h
merge-idem vv h = ⊔-idem (lookup vv h)

-- ==========================================================================
-- PROPERTY 5: MERGE PRODUCES UPPER BOUND
-- ==========================================================================

merge-upper-bound₁ : ∀ (vv₁ vv₂ : VersionVec)
                   → vv₁ ≤ᵥ merge vv₁ vv₂
merge-upper-bound₁ vv₁ vv₂ h = m≤m⊔n (lookup vv₁ h) (lookup vv₂ h)

merge-upper-bound₂ : ∀ (vv₁ vv₂ : VersionVec)
                   → vv₂ ≤ᵥ merge vv₁ vv₂
merge-upper-bound₂ vv₁ vv₂ h = n≤m⊔n (lookup vv₁ h) (lookup vv₂ h)

-- ==========================================================================
-- PROPERTY 6: TRANSITIVITY OF HAPPENS-BEFORE
-- ==========================================================================

happensBefore-trans : ∀ {vv₁ vv₂ vv₃ : VersionVec}
                    → vv₁ <ᵥ vv₂
                    → vv₂ <ᵥ vv₃
                    → vv₁ <ᵥ vv₃
happensBefore-trans {vv₁} {vv₂} {vv₃} (≤₁₂ , h₁ , <₁₂) (≤₂₃ , h₂ , <₂₃) =
  (λ h → ≤-trans (≤₁₂ h) (≤₂₃ h)) , (h₁ , ≤-trans <₁₂ (≤₂₃ h₁))

-- ==========================================================================
-- PROPERTY 7: IRREFLEXIVITY OF HAPPENS-BEFORE
-- ==========================================================================

happensBefore-irrefl : ∀ (vv : VersionVec) → ¬ (vv <ᵥ vv)
happensBefore-irrefl vv (_ , _ , lt) = ¬-<-refl lt

-- ==========================================================================
-- PROPERTY 8: MUTUAL EXCLUSION OF HAPPENS-BEFORE AND CONCURRENT
-- ==========================================================================

concurrent-not-happensBefore : ∀ {vv₁ vv₂ : VersionVec}
                              → concurrent vv₁ vv₂
                              → ¬ (vv₁ <ᵥ vv₂) × ¬ (vv₂ <ᵥ vv₁)
concurrent-not-happensBefore conc = conc

-- ==========================================================================
-- PROPERTY 9: OCC CORRECTNESS
-- Compare-and-swap succeeds only if current version ≥ expected version
-- ==========================================================================

cas-correctness : ∀ (current expected : VersionVec)
                → current ≥ᵥ expected
                → ∀ (h : HolonId) → lookup expected h ≤ lookup current h
cas-correctness current expected current≥expected h = current≥expected h

-- After a successful CAS, the new version is greater than the old
cas-increment : ∀ (vv : VersionVec) (writer : HolonId)
              → vv <ᵥ increment vv writer
cas-increment vv writer =
  increment-monotonic vv writer , (writer , increment-strict vv writer)

-- ==========================================================================
-- PROPERTY 10: MERGE PRESERVES CAUSALITY
-- ==========================================================================

merge-preserves-causality : ∀ {vv₁ vv₂ vv₃ : VersionVec}
                          → vv₁ <ᵥ vv₂
                          → vv₁ <ᵥ merge vv₂ vv₃
merge-preserves-causality {vv₁} {vv₂} {vv₃} (≤₁₂ , h , <₁₂) =
  (λ h' → ≤-trans (≤₁₂ h') (merge-upper-bound₁ vv₂ vv₃ h')) ,
  (h , ≤-trans <₁₂ (merge-upper-bound₁ vv₂ vv₃ h))

-- ==========================================================================
-- PROPERTY 11: CONCURRENT DETECTION IS SYMMETRIC
-- ==========================================================================

concurrent-sym : ∀ {vv₁ vv₂ : VersionVec}
               → concurrent vv₁ vv₂
               → concurrent vv₂ vv₁
concurrent-sym (¬<₁ , ¬<₂) = (¬<₂ , ¬<₁)

-- ==========================================================================
-- SUMMARY OF PROVEN PROPERTIES
-- ==========================================================================

{-
The following properties have been formally proven (constructive, --safe):

 1. increment-monotonic:     Incrementing preserves ≤ᵥ (SC-XHOLON-007)
 2. increment-strict:        Incrementing strictly increases target component
 3. merge-comm:              Merge is commutative (SC-CONC-001)
 4. merge-assoc:             Merge is associative (SC-CONC-001)
 5. merge-idem:              Merge is idempotent (SC-CONC-001)
 6. merge-upper-bound₁/₂:   Merge produces upper bound (SC-CONC-001)
 7. happensBefore-trans:     Happens-before is transitive (SC-CONC-002)
 8. happensBefore-irrefl:    Happens-before is irreflexive (SC-CONC-002)
 9. concurrent-not-happensBefore: Concurrent excludes happens-before (SC-CONC-002)
10. cas-correctness:         CAS preserves ordering (SC-CONC-002)
11. cas-increment:           CAS + increment produces strictly greater version
12. merge-preserves-causality: Merge preserves <ᵥ (SC-CONC-001)
13. concurrent-sym:          Concurrent is symmetric (SC-CONC-002)

These proofs establish the mathematical foundation for the OCC algorithm
used in the cross-holon database access system. All proofs are constructive
and pass Agda's --safe mode (no postulates, no unsafe features).
-}
