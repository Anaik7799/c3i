-- =============================================================================
-- TodolistAccessControl.agda
-- Formal Verification of PROJECT_TODOLIST.md Access Control
-- =============================================================================
-- STAMP: SC-TODO-001 to SC-TODO-008
-- AOR: AOR-TODO-001 to AOR-TODO-010
-- =============================================================================

module TodolistAccessControl where

open import Intelitor.Foundations

-- Note: String is replaced with ℕ for file identifiers to avoid
-- Agda.Builtin.String ↔ BUILTIN NATURAL conflict with Foundations.ℕ

-- =============================================================================
-- 1. ACCESS CONTROL TYPES
-- =============================================================================

-- Access method enumeration
data AccessMethod : Set where
  DirectRead    : AccessMethod  -- Read tool
  DirectWrite   : AccessMethod  -- Write/Edit tool
  ShellCat      : AccessMethod  -- cat command
  ShellGrep     : AccessMethod  -- grep/rg command
  ShellSed      : AccessMethod  -- sed command
  ShellEcho     : AccessMethod  -- echo >> command
  PlanningCLI   : AccessMethod  -- sa-plan command (F# Planning CLI)
  ChayaCLI      : AccessMethod  -- chaya command
  PlanningAPI   : AccessMethod  -- Programmatic F# API

-- Agent identity
data Agent : Set where
  ClaudeAgent   : Agent
  GeminiAgent   : Agent
  GrokAgent     : Agent
  HumanOperator : Agent
  SystemProcess : Agent

-- Access result
data AccessResult : Set where
  Allowed  : AccessResult
  Denied   : AccessResult
  Blocked  : AccessResult
  Alerted  : AccessResult

-- =============================================================================
-- 2. ACCESS CONTROL PREDICATES
-- =============================================================================

-- Is this method a direct access method?
isDirectAccess : AccessMethod → Bool
isDirectAccess DirectRead    = true
isDirectAccess DirectWrite   = true
isDirectAccess ShellCat      = true
isDirectAccess ShellGrep     = true
isDirectAccess ShellSed      = true
isDirectAccess ShellEcho     = true
isDirectAccess PlanningCLI   = false
isDirectAccess ChayaCLI      = false
isDirectAccess PlanningAPI   = false

-- Is this method authorized?
isAuthorizedMethod : AccessMethod → Bool
isAuthorizedMethod PlanningCLI   = true
isAuthorizedMethod ChayaCLI      = true
isAuthorizedMethod PlanningAPI   = true
isAuthorizedMethod _             = false

-- Is this an agent (not human)?
isAgent : Agent → Bool
isAgent ClaudeAgent   = true
isAgent GeminiAgent   = true
isAgent GrokAgent     = true
isAgent HumanOperator = false
isAgent SystemProcess = true

-- =============================================================================
-- 3. SC-TODO-001: AGENTS SHALL NOT READ DIRECTLY
-- =============================================================================

-- Access decision function
accessDecision : Agent → AccessMethod → AccessResult
accessDecision agent method with isAgent agent | isDirectAccess method
... | true  | true  = Blocked   -- Agent + Direct = BLOCKED (SC-TODO-001)
... | true  | false = Allowed   -- Agent + Authorized = OK
... | false | true  = Allowed   -- Human + Direct = OK (allowed for humans)
... | false | false = Allowed   -- Human + Authorized = OK

-- =============================================================================
-- 4. FORMAL PROOFS
-- =============================================================================

-- Proof: Direct access by agent is always blocked
direct-access-blocked : ∀ (agent : Agent) (method : AccessMethod) →
  isAgent agent ≡ true →
  isDirectAccess method ≡ true →
  accessDecision agent method ≡ Blocked
direct-access-blocked ClaudeAgent DirectRead refl refl = refl
direct-access-blocked ClaudeAgent DirectWrite refl refl = refl
direct-access-blocked ClaudeAgent ShellCat refl refl = refl
direct-access-blocked ClaudeAgent ShellGrep refl refl = refl
direct-access-blocked ClaudeAgent ShellSed refl refl = refl
direct-access-blocked ClaudeAgent ShellEcho refl refl = refl
direct-access-blocked GeminiAgent DirectRead refl refl = refl
direct-access-blocked GeminiAgent DirectWrite refl refl = refl
direct-access-blocked GeminiAgent ShellCat refl refl = refl
direct-access-blocked GeminiAgent ShellGrep refl refl = refl
direct-access-blocked GeminiAgent ShellSed refl refl = refl
direct-access-blocked GeminiAgent ShellEcho refl refl = refl
direct-access-blocked GrokAgent DirectRead refl refl = refl
direct-access-blocked GrokAgent DirectWrite refl refl = refl
direct-access-blocked GrokAgent ShellCat refl refl = refl
direct-access-blocked GrokAgent ShellGrep refl refl = refl
direct-access-blocked GrokAgent ShellSed refl refl = refl
direct-access-blocked GrokAgent ShellEcho refl refl = refl
direct-access-blocked SystemProcess DirectRead refl refl = refl
direct-access-blocked SystemProcess DirectWrite refl refl = refl
direct-access-blocked SystemProcess ShellCat refl refl = refl
direct-access-blocked SystemProcess ShellGrep refl refl = refl
direct-access-blocked SystemProcess ShellSed refl refl = refl
direct-access-blocked SystemProcess ShellEcho refl refl = refl

-- Proof: Authorized methods are always allowed for agents
authorized-access-allowed : ∀ (agent : Agent) (method : AccessMethod) →
  isAuthorizedMethod method ≡ true →
  accessDecision agent method ≡ Allowed
authorized-access-allowed ClaudeAgent PlanningCLI refl = refl
authorized-access-allowed ClaudeAgent ChayaCLI refl = refl
authorized-access-allowed ClaudeAgent PlanningAPI refl = refl
authorized-access-allowed GeminiAgent PlanningCLI refl = refl
authorized-access-allowed GeminiAgent ChayaCLI refl = refl
authorized-access-allowed GeminiAgent PlanningAPI refl = refl
authorized-access-allowed GrokAgent PlanningCLI refl = refl
authorized-access-allowed GrokAgent ChayaCLI refl = refl
authorized-access-allowed GrokAgent PlanningAPI refl = refl
authorized-access-allowed HumanOperator PlanningCLI refl = refl
authorized-access-allowed HumanOperator ChayaCLI refl = refl
authorized-access-allowed HumanOperator PlanningAPI refl = refl
authorized-access-allowed SystemProcess PlanningCLI refl = refl
authorized-access-allowed SystemProcess ChayaCLI refl = refl
authorized-access-allowed SystemProcess PlanningAPI refl = refl

-- =============================================================================
-- 5. INVARIANTS
-- =============================================================================

-- The todolist access invariant:
-- ∀ agent method . isAgent agent ∧ isDirectAccess method → accessDecision = Blocked
record TodolistInvariant : Set where
  field
    invariant-holds : ∀ (a : Agent) (m : AccessMethod) →
      isAgent a ≡ true → isDirectAccess m ≡ true → accessDecision a m ≡ Blocked

-- Proof that the invariant holds
todolist-invariant-proof : TodolistInvariant
todolist-invariant-proof = record { invariant-holds = direct-access-blocked }

-- =============================================================================
-- 6. STATE MACHINE MODEL
-- =============================================================================

data AccessState : Set where
  Idle      : AccessState
  Requested : AccessState
  Validated : AccessState
  Executed  : AccessState
  Logged    : AccessState

-- State transitions (only valid ones)
data ValidTransition : AccessState → AccessState → Set where
  idle→requested     : ValidTransition Idle Requested
  requested→validated : ValidTransition Requested Validated
  validated→executed : ValidTransition Validated Executed
  executed→logged    : ValidTransition Executed Logged
  logged→idle        : ValidTransition Logged Idle

-- Invalid transitions are blocked by the type system:
-- requested→executed is NOT a constructor, so it cannot be constructed.

-- =============================================================================
-- 7. GRAPH REPRESENTATION
-- =============================================================================

-- Nodes in the access control graph
data ACNode : Set where
  Agent_Node    : Agent → ACNode
  Method_Node   : AccessMethod → ACNode
  File_Node     : ℕ → ACNode
  Decision_Node : AccessResult → ACNode

-- Edges represent allowed transitions
data ACEdge : ACNode → ACNode → Set where
  agent-uses-method : ∀ (a : Agent) (m : AccessMethod) →
    isAuthorizedMethod m ≡ true →
    ACEdge (Agent_Node a) (Method_Node m)
  method-accesses-file : ∀ (m : AccessMethod) (f : ℕ) →
    isAuthorizedMethod m ≡ true →
    ACEdge (Method_Node m) (File_Node f)

-- No edge from DirectRead to File_Node (enforced by type system:
-- isAuthorizedMethod DirectRead ≡ true cannot be constructed)

-- =============================================================================
-- 8. THEOREM: SAFETY PROPERTY
-- =============================================================================

-- Helper: Blocked and Allowed are distinct constructors
Blocked≢Allowed : Blocked ≡ Allowed → ⊥
Blocked≢Allowed ()

-- No sequence of valid operations can lead to direct file access by an agent.
-- This is the MASTER SAFETY THEOREM for SC-TODO-001.
safety-theorem : ∀ (a : Agent) →
  isAgent a ≡ true →
  ¬ (∃ λ (m : AccessMethod) → isDirectAccess m ≡ true × accessDecision a m ≡ Allowed)
safety-theorem a is-agent (m , direct , allowed) =
  Blocked≢Allowed (trans (sym (direct-access-blocked a m is-agent direct)) allowed)

-- =============================================================================
-- END OF FORMAL SPECIFICATION
-- =============================================================================
