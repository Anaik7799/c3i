// Cybernetic Invariants Verification
// SC-CTX-003 Compliance

module CyberneticInvariants {
  type SystemState = Stable | Expanded | Contracted

  var state: SystemState
  var stressScore: int // 0-100 (mapped from 0.0-1.0)
  var poolSize: int

  pure val HIGH_WATER = 80
  pure val LOW_WATER = 30

  action init = all {
    state' = Stable,
    stressScore' = 50,
    poolSize' = 10
  }

  action step = {
    nondet newStress = oneOf(0.to(100));
    // Apply Control Logic (Homeostasis)
    if (newStress > HIGH_WATER) all {
      state' = Expanded,
      stressScore' = newStress,
      poolSize' = poolSize + 1
    } else if (newStress < LOW_WATER) all {
      state' = Contracted,
      stressScore' = newStress,
      poolSize' = if (poolSize > 1) poolSize - 1 else 1
    } else all {
      state' = Stable,
      stressScore' = newStress,
      poolSize' = poolSize
    }
  }

  // Safety: Pool size never goes below minimum
  val minPoolSize = poolSize >= 1

  // Stability: We don't expand if stress is low
  val properExpansion =
    state == Expanded implies stressScore > HIGH_WATER
}
