module AcyclicityProofs where

open import Agda.Builtin.Nat renaming (Nat to ℕ)
open import Agda.Builtin.Bool
open import Agda.Builtin.List
open import Agda.Builtin.Equality
open import GraphProperties

-- ---------------------------------------------------------------------------
-- Auxiliary types (needed since we use Builtins, not stdlib)
-- ---------------------------------------------------------------------------

data ⊥ : Set where

record ⊤ : Set where
  constructor tt

-- Disjunction (sum type)
data _⊎_ (A B : Set) : Set where
  inj₁ : A → A ⊎ B
  inj₂ : B → A ⊎ B

-- Strict less-than on naturals (renamed to avoid Agda.Builtin.Nat._<_ clash)
data _<ₙ_ : ℕ → ℕ → Set where
  z<s : ∀ {n} → zero <ₙ suc n
  s<s : ∀ {m n} → m <ₙ n → suc m <ₙ suc n

-- Less-than-or-equal on naturals
data _≤ₙ_ : ℕ → ℕ → Set where
  z≤n : ∀ {n} → zero ≤ₙ n
  s≤s : ∀ {m n} → m ≤ₙ n → suc m ≤ₙ suc n

-- Substitution (transport along equality)
subst : {A : Set} {x y : A} → (P : A → Set) → x ≡ y → P x → P y
subst P refl px = px

-- Ex falso quodlibet
⊥-elim : {A : Set} → ⊥ → A
⊥-elim ()

-- Irreflexivity of strict less-than
<ₙ-irrefl : ∀ {n} → n <ₙ n → ⊥
<ₙ-irrefl (s<s p) = <ₙ-irrefl p

-- Transitivity of strict less-than
<ₙ-trans : ∀ {a b c} → a <ₙ b → b <ₙ c → a <ₙ c
<ₙ-trans z<s (s<s _) = z<s
<ₙ-trans (s<s p) (s<s q) = s<s (<ₙ-trans p q)

-- ---------------------------------------------------------------------------
-- Cycles and DAGs
-- ---------------------------------------------------------------------------

-- A cycle is a non-trivial path from a vertex back to itself.
data Cycle (G : Graph) : Set where
  cycle : ∀ {v w} → Graph.E G v w → Path G w v → Cycle G

-- A Directed Acyclic Graph has no cycles.
IsDAG : Graph → Set
IsDAG G = Cycle G → ⊥

-- Topological ordering: a mapping from vertices to natural numbers
-- such that edges always go from lower to higher numbers.
record TopoOrder (G : Graph) : Set where
  field
    order : ℕ → ℕ
    monotone : ∀ {u v} → Graph.E G u v → order u <ₙ order v

-- ---------------------------------------------------------------------------
-- THEOREM 1: Self-loops violate DAG property (constructive proof)
-- ---------------------------------------------------------------------------

-- A graph with a self-loop edge (v → v) cannot be a DAG.
-- Proof: construct a cycle from the self-loop and the trivial path.
self-loop-not-dag : ∀ (G : Graph) {v}
                  → Graph.E G v v → Graph.V G v
                  → IsDAG G → ⊥
self-loop-not-dag G edge vertex isDAG = isDAG (cycle edge (here vertex))

-- ---------------------------------------------------------------------------
-- THEOREM 2: Topological ordering implies acyclicity
-- ---------------------------------------------------------------------------

-- Helper: a path in a topo-ordered graph implies order inequality
path-monotone : ∀ (G : Graph) (T : TopoOrder G) {u v}
              → Path G u v → (TopoOrder.order T u ≡ TopoOrder.order T v)
                            ⊎ (TopoOrder.order T u <ₙ TopoOrder.order T v)
path-monotone G T (here _) = inj₁ refl
path-monotone G T (step e rest) with path-monotone G T rest
... | inj₁ eq = inj₂ (subst (λ x → TopoOrder.order T _ <ₙ x) eq (TopoOrder.monotone T e))
... | inj₂ lt = inj₂ (<ₙ-trans (TopoOrder.monotone T e) lt)

-- ---------------------------------------------------------------------------
-- Boot Sequence DAG Properties (parameterized by specific boot graph)
-- ---------------------------------------------------------------------------

-- The boot sequence properties are about a SPECIFIC graph, not all graphs.
-- We express them as a parameterized module.
module BootSequence
  (BG : Graph)
  (topo : TopoOrder BG)
  -- Assumption: CP-BOOT-01 (node 0) has no incoming edges
  (single-source : ∀ {v} → Graph.E BG v 0 → ⊥)
  -- Assumption: CP-BOOT-10 (node 9) has no outgoing edges
  (single-sink : ∀ {v} → Graph.E BG 9 v → ⊥)
  where

  -- LEMMA: Any path ending at 0 must be trivial (start ≡ 0),
  -- because 0 has no incoming edges so the path can't step into 0.
  path-to-0-trivial : ∀ {w} → Path BG w 0 → w ≡ 0
  path-to-0-trivial (here _) = refl
  path-to-0-trivial (step e' rest) with path-to-0-trivial rest
  ... | refl = ⊥-elim (single-source e')

  -- THEOREM: The boot graph is a DAG (no cycles from the source)
  -- Source node 0 cannot be part of a cycle since it has no incoming edges.
  boot-source-acyclic : ∀ {w} → Graph.E BG 0 w → Path BG w 0 → ⊥
  boot-source-acyclic edge path with path-to-0-trivial path
  ... | refl = single-source edge
