-- =============================================================================
-- AGDA MODULE: Core Type Foundations for Intelitor
-- Purpose: Base types, equality, and logical operators for eternal proofs
-- =============================================================================

module Intelitor.Foundations where

-- ---------------------------------------------------------------------------
-- §A1.1 Minimal Built-in Types (Simulated Foundations)
-- ---------------------------------------------------------------------------

data ℕ : Set where
  zero : ℕ
  suc  : ℕ → ℕ

{-# BUILTIN NATURAL ℕ #-}

data Bool : Set where
  true  : Bool
  false : Bool

data ⊥ : Set where

record ⊤ : Set where
  constructor tt

-- ---------------------------------------------------------------------------
-- §A1.2 Equality and Logic
-- ---------------------------------------------------------------------------

data _≡_ {A : Set} (x : A) : A → Set where
  refl : x ≡ x

infix 4 _≡_

{-# BUILTIN EQUALITY _≡_ #-}

-- Negation
¬_ : Set → Set
¬ P = P → ⊥

-- ---------------------------------------------------------------------------
-- §A1.3 Decidability
-- ---------------------------------------------------------------------------

data Dec (A : Set) : Set where
  yes : A → Dec A
  no  : (A → ⊥) → Dec A

-- ---------------------------------------------------------------------------
-- §A1.4 Theorems and Axioms
-- ---------------------------------------------------------------------------

-- Ex falso quodlibet
absurd : {A : Set} → ⊥ → A
absurd ()

-- Symmetry of equality
sym : {A : Set} {x y : A} → x ≡ y → y ≡ x
sym refl = refl

-- Transitivity of equality
trans : {A : Set} {x y z : A} → x ≡ y → y ≡ z → x ≡ z
trans refl refl = refl

-- Inequality (non-equal)
_≢_ : {A : Set} → A → A → Set
x ≢ y = ¬ (x ≡ y)

-- ---------------------------------------------------------------------------
-- §A1.5 Dependent Pair (Sigma Type) — CANONICAL source of _,_ constructor
-- ---------------------------------------------------------------------------

-- Sigma type: the dependent pair. All product types are derived from this.
record Σ (A : Set) (B : A → Set) : Set where
  constructor _,_
  field
    fst : A
    snd : B fst

open Σ public

-- Existential syntax: ∃[ x ] P  means  Σ A (λ x → P)
∃ : {A : Set} → (A → Set) → Set
∃ = Σ _

syntax ∃ (λ x → B) = ∃[ x ] B

-- ---------------------------------------------------------------------------
-- §A1.6 Conjunction (Non-dependent Product)
-- ---------------------------------------------------------------------------

-- Product type defined as Σ with trivial (constant) dependency.
-- This ensures a SINGLE _,_ constructor across all pair/product types,
-- eliminating the SplitError.BlockedType ambiguity in with-clauses.
_×_ : Set → Set → Set
A × B = Σ A (λ _ → B)

infixr 4 _,_
infixr 2 _×_

-- Convenience: named projections for non-dependent products
proj₁ : {A B : Set} → A × B → A
proj₁ = fst

proj₂ : {A B : Set} → A × B → B
proj₂ = snd

-- ---------------------------------------------------------------------------
-- §A1.7 Disjunction (Sum)
-- ---------------------------------------------------------------------------

data _⊎_ (A B : Set) : Set where
  inj₁ : A → A ⊎ B
  inj₂ : B → A ⊎ B

infixr 1 _⊎_

-- ---------------------------------------------------------------------------
-- §A1.8 Vectors (Length-Indexed Lists)
-- ---------------------------------------------------------------------------

data Vec (A : Set) : ℕ → Set where
  []  : Vec A zero
  _∷_ : {n : ℕ} → A → Vec A n → Vec A (suc n)

infixr 5 _∷_

head : {A : Set} {n : ℕ} → Vec A (suc n) → A
head (x ∷ _) = x
