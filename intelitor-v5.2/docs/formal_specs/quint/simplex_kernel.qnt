// Simplex Safety Kernel Model
// Verifies SC-SIMPLEX-001 and SC-SIMPLEX-002

module SimplexKernel {
  // Types
  type Verdict = Approved | Vetoed | Modified
  type CommandType = ScaleUp | ScaleDown | Restart | WipeData
  
  type SystemState = {
    redundancy: int,
    memoryUsage: int, // In MB
    maxMemory: int,
    minRedundancy: int
  }

  // Pure function representing the Kernel Logic
  // Corresponds to F# Cepaf.Safety.SimplexKernel.evaluate
  pure def evaluate(cmd: CommandType, state: SystemState): Verdict = {
    if (cmd == ScaleDown and state.redundancy <= state.minRedundancy) {
      Vetoed
    } else if (cmd == ScaleUp and state.memoryUsage + 1024 > state.maxMemory) {
      Vetoed
    } else if (cmd == WipeData) {
      // Hard constraint: Never wipe data automatically
      Vetoed
    } else {
      Approved
    }
  }

  // Properties to Verify

  // Invariant 1: Survivability
  // "The kernel shall never Approve a ScaleDown if redundancy is at minimum"
  val inv_survivability =
    val criticalState = { redundancy: 2, memoryUsage: 5000, maxMemory: 16000, minRedundancy: 2 }
    evaluate(ScaleDown, criticalState) == Vetoed

  // Invariant 2: Resource Safety
  // "The kernel shall never Approve a ScaleUp if memory is full"
  val inv_resource_safety =
    val fullState = { redundancy: 3, memoryUsage: 15500, maxMemory: 16000, minRedundancy: 2 }
    evaluate(ScaleUp, fullState) == Vetoed

  // Invariant 3: Data Safety
  // "The kernel shall never Approve WipeData"
  val inv_data_safety =
    val normalState = { redundancy: 3, memoryUsage: 5000, maxMemory: 16000, minRedundancy: 2 }
    evaluate(WipeData, normalState) == Vetoed
}
