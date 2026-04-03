// =============================================================================
// QUINT SPECIFICATION: Indrajaal.Ark Lytic Cycle
// Context: Level 6 (Biomorphic Layer)
// Objective: Verify state machine safety and liveness
// =============================================================================

module ArkLyticCycle {
  // The States of the Viral Life Cycle
  type State = 
    | Adsorbed    // Shell script running
    | Injected    // Binary extracted to /tmp
    | Scanning    // Verifying hashes
    | Healing     // Reed-Solomon reconstruction
    | Extracting  // Zstd decompression
    | Lysis       // Success: New system running
    | Failed      // Error state

  // State Variables
  var state: State
  var ram_usage: int
  var disk_usage: int
  var integrity: bool
  var shards_available: int

  // Constants (from Spec)
  pure val MAX_RAM = 1073741824 // 1GB
  pure val RECOVERY_BUFFER = 104857600 // 100MB
  pure val K_SHARDS = 100

  // Initial State
  action init = all {
    state' = Adsorbed,
    ram_usage' = 0,
    disk_usage' = 0,
    integrity' = false,
    shards_available' = 0
  }

  // Transition: Adsorption -> Injection
  action step_inject = all {
    state == Adsorbed,
    state' = Injected,
    ram_usage' = ram_usage,
    disk_usage' = disk_usage,
    integrity' = integrity,
    shards_available' = shards_available
  }

  // Transition: Injection -> Scanning
  action step_scan = all {
    state == Injected,
    state' = Scanning,
    // Simulate finding shards
    shards_available' = 100, // Best case
    ram_usage' = ram_usage + 1048576, // 1MB buffer
    disk_usage' = disk_usage,
    integrity' = integrity
  }

  // Transition: Scanning -> Healing (if needed)
  action step_heal = all {
    state == Scanning,
    shards_available >= K_SHARDS,
    // SC-ARK-002: Resource Bounding Check
    ram_usage + RECOVERY_BUFFER <= MAX_RAM,
    ram_usage' = ram_usage + RECOVERY_BUFFER,
    state' = Healing,
    integrity' = true, // Healing succeeds
    disk_usage' = disk_usage,
    shards_available' = shards_available
  }

  // Transition: Healing -> Extracting
  action step_extract = all {
    state == Healing,
    integrity == true,
    state' = Extracting,
    ram_usage' = ram_usage, // RAM holds steady or drops
    disk_usage' = disk_usage + 524288000, // 500MB extracted
    integrity' = integrity,
    shards_available' = shards_available
  }

  // Transition: Extracting -> Lysis
  action step_lysis = all {
    state == Extracting,
    state' = Lysis,
    ram_usage' = 0, // Process exit
    disk_usage' = disk_usage,
    integrity' = integrity,
    shards_available' = shards_available
  }

  // Transition: Failure (Generic)
  action step_fail = all {
    state != Lysis,
    state != Failed,
    state' = Failed,
    ram_usage' = 0,
    disk_usage' = disk_usage,
    integrity' = false,
    shards_available' = shards_available
  }

  // Next Step Function
  action step = any {
    step_inject,
    step_scan,
    step_heal,
    step_extract,
    step_lysis,
    step_fail
  }

  // ===========================================================================
  // Invariants & Temporal Properties
  // ===========================================================================

  // Safety: RAM usage never exceeds limit
  val inv_ram_safety = ram_usage <= MAX_RAM

  // Liveness: We eventually reach a terminal state
  temporal liveness = eventually(state == Lysis or state == Failed)
}
