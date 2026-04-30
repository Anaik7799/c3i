-- CRDTConvergence.agda — Strong Eventual Consistency for Matrix room state
-- Ref: Matrix spec v1.13 rooms/v11 — State Resolution v2
module CRDTConvergence where

open import Data.Nat using (ℕ; zero; suc; _<_; s≤s)
open import Data.List using (List; []; _∷_; _++_)
open import Data.Product using (_×_; _,_; proj₁; proj₂)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym; trans; cong)
open import Relation.Nullary using (¬_)

-- Matrix event (simplified)
postulate String : Set

record Event : Set where
  constructor mkEvent
  field event-id : String ; depth : ℕ

EventSet  = List Event
StateKey  = String × String
RoomState = List (StateKey × Event)

-- Set equivalence (permutation — axiomatized)
postulate
  SetEquiv : EventSet → EventSet → Set
  SE-refl  : ∀ {S} → SetEquiv S S
  SE-sym   : ∀ {S T} → SetEquiv S T → SetEquiv T S
  SE-trans : ∀ {S T U} → SetEquiv S T → SetEquiv T U → SetEquiv S U
  SE-comm  : ∀ S T → SetEquiv (S ++ T) (T ++ S)

-- State resolution (axiomatized algebraic properties)
postulate
  resolve : EventSet → RoomState
  resolve-ext  : ∀ {S₁ S₂} → SetEquiv S₁ S₂ → resolve S₁ ≡ resolve S₂
  resolve-idemp : ∀ S → resolve (S ++ S) ≡ resolve S

-- Join operator (set union via list append)
join : EventSet → EventSet → EventSet
join = _++_

-- THEOREM 1: Strong Eventual Consistency
sec : ∀ v₁ v₂ → SetEquiv v₁ v₂ → resolve v₁ ≡ resolve v₂
sec v₁ v₂ = resolve-ext

-- THEOREM 2: Merge commutativity
merge-comm : ∀ A B → resolve (join A B) ≡ resolve (join B A)
merge-comm A B = resolve-ext (SE-comm A B)

-- THEOREM 3: Three-server convergence
three-conv : ∀ v₁ v₂ v₃ → SetEquiv v₁ v₂ → SetEquiv v₂ v₃ → resolve v₁ ≡ resolve v₃
three-conv v₁ v₂ v₃ e₁₂ e₂₃ = trans (sec v₁ v₂ e₁₂) (sec v₂ v₃ e₂₃)

-- Causal order (depth-based)
_before_ : Event → Event → Set
e₁ before e₂ = Event.depth e₁ < Event.depth e₂

causal-irrefl : ∀ {e} → ¬ (e before e)
causal-irrefl (s≤s h) = causal-irrefl h
