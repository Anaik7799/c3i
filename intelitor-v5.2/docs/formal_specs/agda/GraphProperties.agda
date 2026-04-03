module GraphProperties where

open import Agda.Builtin.Nat renaming (Nat to ℕ)
open import Agda.Builtin.Bool
open import Agda.Builtin.List
open import Agda.Builtin.Equality

-- A graph is a set of vertices (ℕ) with an adjacency predicate.
record Graph : Set₁ where
  field
    V : ℕ → Set
    E : ℕ → ℕ → Set

-- A path in a graph from u to v.
data Path (G : Graph) : ℕ → ℕ → Set where
  here  : ∀ {v} → Graph.V G v → Path G v v
  step  : ∀ {u w v} → Graph.E G u w → Path G w v → Path G u v

-- Reachability: there exists a path from u to v.
Reachable : Graph → ℕ → ℕ → Set
Reachable G u v = Path G u v

-- Theorem 1: Reachability is reflexive.
-- Every vertex is reachable from itself.
reachability-refl : ∀ (G : Graph) {v} → Graph.V G v → Reachable G v v
reachability-refl G vInG = here vInG

-- Theorem 2: Reachability is transitive.
-- If u reaches w and w reaches v, then u reaches v.
reachability-trans : ∀ (G : Graph) {u w v}
                   → Reachable G u w → Reachable G w v → Reachable G u v
reachability-trans G (here _)      wv = wv
reachability-trans G (step e rest) wv = step e (reachability-trans G rest wv)

-- Theorem 3: An edge implies reachability.
edge-implies-reachable : ∀ (G : Graph) {u v}
                       → Graph.V G v → Graph.E G u v → Reachable G u v
edge-implies-reachable G vInG e = step e (here vInG)

-- Theorem 4: Path composition.
-- Concatenation of two paths yields a path from start to end.
path-compose : ∀ (G : Graph) {u w v}
             → Path G u w → Path G w v → Path G u v
path-compose G (here _)      wv = wv
path-compose G (step e rest) wv = step e (path-compose G rest wv)

-- Connected graph: every pair of vertices is reachable.
Connected : Graph → Set
Connected G = ∀ {u v} → Graph.V G u → Graph.V G v → Reachable G u v

-- Strongly connected: reachable in both directions.
StronglyConnected : Graph → Set
StronglyConnected G = ∀ {u v} → Graph.V G u → Graph.V G v
                    → Reachable G u v → Reachable G v u
