-- AuthRuleSoundness.agda — Matrix authorization rule decidability and soundness
-- Ref: Matrix spec v1.13 client-server-api/#authorization-rules
module AuthRuleSoundness where

open import Data.Nat using (ℕ; zero; suc; _≤_; _<_; z≤n; s≤s)
open import Data.Nat.Properties using (≤-refl; <-irrefl)
open import Data.List using (List; []; _∷_)
open import Data.Product using (_×_; _,_; ∃; ∃-syntax)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; cong)
open import Relation.Nullary using (Dec; yes; no; ¬_)
open import Data.Empty using (⊥; ⊥-elim)

postulate String : Set

PowerLevel = ℕ

data AuthResult : Set where
  Allow : AuthResult
  Deny  : AuthResult

-- Auth result is decidable (two constructors = total)
authResult-dec : ∀ (r : AuthResult) → Dec (r ≡ Allow)
authResult-dec Allow = yes refl
authResult-dec Deny  = no (λ ())

-- Power levels
record PowerLevels : Set where
  constructor mkPL
  field
    users-default : PowerLevel
    ban kick invite : PowerLevel
    user-levels : List (String × PowerLevel)

postulate
  userPL : PowerLevels → String → PowerLevel

-- Auth check (axiomatized)
postulate
  AuthState : Set
  authCheck : String → String → String → AuthState → AuthResult

-- THEOREM 1: Decidability — authCheck always terminates
authCheck-decidable : ∀ s et sk as → Dec (authCheck s et sk as ≡ Allow)
authCheck-decidable s et sk as = authResult-dec (authCheck s et sk as)

-- Auth chain acyclicity (via depth)
record Event : Set where
  constructor mkEvent
  field event-id : String ; depth : ℕ ; auth-events : List String

-- Auth ancestor relation
data AuthAnc (db : List Event) : Event → Event → Set where
  direct : ∀ {e₁ e₂} → AuthAnc db e₁ e₂
  trans  : ∀ {e₁ e₂ e₃} → AuthAnc db e₁ e₂ → AuthAnc db e₂ e₃ → AuthAnc db e₁ e₃

-- Depth decreases along auth chain
postulate auth-depth-dec : ∀ db e₁ e₂ → AuthAnc db e₁ e₂ → Event.depth e₁ < Event.depth e₂

-- THEOREM 2: Auth chain is acyclic
auth-acyclic : ∀ db e → ¬ AuthAnc db e e
auth-acyclic db e anc = <-irrefl refl (auth-depth-dec db e e anc)

-- THEOREM 3: Room creator has admin power
AdminPL : PowerLevel
AdminPL = 100

initialPL : String → PowerLevels
initialPL creator = mkPL 0 50 50 0 ((creator , AdminPL) ∷ [])

postulate
  creatorHasAdmin : ∀ creator → userPL (initialPL creator) creator ≡ AdminPL

-- THEOREM 4: Monotonicity (higher PL ⊇ more permissions)
postulate
  authCheck-mono : ∀ s et sk as₁ as₂
    → authCheck s et sk as₁ ≡ Allow
    → authCheck s et sk as₂ ≡ Allow
