-- =============================================================================
-- AGDA MODULE: Core Axiom Proofs for Intelitor
-- Purpose: Formal proofs for Axiom 1 (Patient Mode) and Axiom 2 (Container)
-- =============================================================================

module Intelitor.Axioms where

open import Intelitor.Foundations

-- ---------------------------------------------------------------------------
-- §A4.1 Compilation Configuration (Axiom 1)
-- ---------------------------------------------------------------------------

record CompilationConfig : Set where
  constructor mkConfig
  field
    noTimeout        : Bool
    patientMode      : Bool
    infinitePatience : Bool

-- Axiom 1 Predicate
Axiom1 : CompilationConfig → Set
Axiom1 cfg =
  (CompilationConfig.noTimeout cfg ≡ true) ×
  (CompilationConfig.patientMode cfg ≡ true) ×
  (CompilationConfig.infinitePatience cfg ≡ true)

-- ---------------------------------------------------------------------------
-- §A5.1 Container Configuration (Axiom 2)
-- ---------------------------------------------------------------------------

data Runtime : Set where
  Podman : Runtime
  Docker : Runtime

record ContainerConfig : Set where
  constructor mkContainer
  field
    runtime  : Runtime
    rootless : Bool

-- Axiom 2 Predicate
Axiom2 : ContainerConfig → Set
Axiom2 cfg =
  (ContainerConfig.runtime cfg ≡ Podman) ×
  (ContainerConfig.rootless cfg ≡ true)

-- ---------------------------------------------------------------------------
-- §A5.2 THEOREM: Docker is Forbidden
-- ---------------------------------------------------------------------------

-- Proving that if a config uses Docker, it CANNOT satisfy Axiom 2.
docker-is-forbidden : (cfg : ContainerConfig) →
                      (ContainerConfig.runtime cfg ≡ Docker) →
                      ¬ Axiom2 cfg
docker-is-forbidden (mkContainer Docker rootless) refl (runtime-is-podman , _) =
  absurd-podman runtime-is-podman
  where
    absurd-podman : Docker ≡ Podman → ⊥
    absurd-podman ()

-- ---------------------------------------------------------------------------
-- §A6.1 THEOREM: Compliant Configs are Provably Safe
-- ---------------------------------------------------------------------------

record SafeSystem : Set where
  field
    compConfig : CompilationConfig
    contConfig : ContainerConfig
    proof1     : Axiom1 compConfig
    proof2     : Axiom2 contConfig

-- Example of a certified system construction
certifiedSystem : SafeSystem
certifiedSystem = record
  { compConfig = mkConfig true true true
  ; contConfig = mkContainer Podman true
  ; proof1     = (refl , refl , refl)
  ; proof2     = (refl , refl)
  }
