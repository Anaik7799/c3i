// =============================================================================
// QUINT MODULE: Indrajaal Type Foundations
// Purpose: Executable type definitions for formal verification
// Coverage Gap: Mathematica types are static; Quint types enable model checking
// =============================================================================

module IndrajaalTypes {
  // ---------------------------------------------------------------------------
  // §Q1.1 Base Types (Executable Equivalents of §0.1)
  // ---------------------------------------------------------------------------

  type AgentRole = Executive | DomainSupervisor | FunctionalSupervisor | Worker
  type AgentState = Idle | Active | Blocked | Error | Recovering | Suspended | Terminated
  type ContainerName = IndrajaalApp | IndrajaalDB | IndrajaalObs
  type Phase = P1 | P2 | P3 | P4 | P5 | P6 | P7
  type TaskStatus = Pending | InProgress | Completed | BlockedStatus

  // Deontic modalities (executable)
  type Modality = Obligation | Permission | Prohibition

  // Severity levels
  type Severity = Critical | High | Medium | Low

  // Validation methods (FPPS)
  type ValidationMethod = Pattern | AST | Statistical | Binary | LineByLine

  // ---------------------------------------------------------------------------
  // §Q1.2 Composite Types (Records)
  // ---------------------------------------------------------------------------

  type Agent = {
    id: int,
    role: AgentRole,
    state: AgentState,
    supervisor: int,  // supervisor agent id (-1 for Executive)
    errorCount: int,
    currentTask: int  // task id (-1 for none)
  }

  type Container = {
    name: ContainerName,
    cpuCores: int,
    ramGB: int,
    healthy: bool,
    phicsLatencyMs: int
  }

  type ValidationResult = {
    method: ValidationMethod,
    errors: int,
    warnings: int,
    timestamp: int
  }

  type CompilationState = {
    files: int,
    errors: int,
    warnings: int,
    patientMode: bool,
    logPath: str,
    complete: bool
  }

  type SafetyConstraint = {
    id: str,
    category: str,
    satisfied: bool
  }
}
