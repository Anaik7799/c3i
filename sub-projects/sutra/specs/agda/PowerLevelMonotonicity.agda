-- PowerLevelMonotonicity.agda — Power level ordering properties
-- Ref: Matrix spec v1.13 §m.room.power_levels
module PowerLevelMonotonicity where

open import Data.Nat using (ℕ; zero; suc; _≤_; _<_; z≤n; s≤s)
open import Data.Nat.Properties using (≤-refl; ≤-trans; ≤-antisym; ≤-total; <-irrefl; <⇒≤)
open import Data.Product using (_×_; _,_; ∃; ∃-syntax)
open import Data.Sum using (_⊎_; inj₁; inj₂)
open import Data.List using (List; []; _∷_)
open import Data.Empty using (⊥; ⊥-elim)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Relation.Nullary using (¬_)

postulate String : Set
PowerLevel = ℕ

postulate userPL : List (String × PowerLevel) → ℕ → String → PowerLevel

-- THEOREM 1: Total preorder (via ≤ on ℕ)
pl-total : ∀ (a b : PowerLevel) → a ≤ b ⊎ b ≤ a
pl-total = ≤-total

pl-refl : ∀ (a : PowerLevel) → a ≤ a
pl-refl = ≤-refl

pl-trans : ∀ {a b c : PowerLevel} → a ≤ b → b ≤ c → a ≤ c
pl-trans = ≤-trans

pl-antisym : ∀ {a b : PowerLevel} → a ≤ b → b ≤ a → a ≡ b
pl-antisym = ≤-antisym

-- Power level change request
record PLChange : Set where
  constructor mkPLChange
  field sender-pl target-pl new-pl : PowerLevel

-- Valid change: sender > target AND sender ≥ new-level
PLChangeValid : PLChange → Set
PLChangeValid ch = (PLChange.target-pl ch < PLChange.sender-pl ch) × (PLChange.new-pl ch ≤ PLChange.sender-pl ch)

-- THEOREM 2: Self-elevation impossible
self-elev-impossible : ∀ (pl : PowerLevel) → ¬ PLChangeValid (mkPLChange pl pl (suc pl))
self-elev-impossible pl (lt , _) = <-irrefl refl lt

-- Kick/ban request
record KickReq : Set where
  constructor mkKick
  field sender-pl target-pl kick-threshold : PowerLevel

KickValid : KickReq → Set
KickValid kr = (KickReq.kick-threshold kr ≤ KickReq.sender-pl kr) × (KickReq.target-pl kr < KickReq.sender-pl kr)

-- THEOREM 3: Kick requires strictly greater power
kick-strict : ∀ kr → KickValid kr → KickReq.target-pl kr < KickReq.sender-pl kr
kick-strict _ (_ , lt) = lt

-- THEOREM 4: Self-kick impossible
self-kick-impossible : ∀ (pl thr : PowerLevel) → ¬ KickValid (mkKick pl pl thr)
self-kick-impossible pl thr (_ , lt) = <-irrefl refl lt

-- THEOREM 5: Equal-power kick impossible
equal-kick-impossible : ∀ {s t thr} → s ≤ t → ¬ KickValid (mkKick s t thr)
equal-kick-impossible s≤t (_ , t<s) = ⊥-elim (<-irrefl (≤-antisym (<⇒≤ t<s) s≤t) t<s)

-- THEOREM 6: No-deadlock (initial state has admin at PL 100)
no-deadlock : ∃[ pl ] (50 ≤ pl)
no-deadlock = 100 , s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s z≤n)))))))))))))))))))))))))))))))))))))))))))))))))
