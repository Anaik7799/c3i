// =============================================================================
// QUINT MODULE: OODA Loop Verification
// Purpose: Model check OODA loop transitions and properties
// =============================================================================

module OODALoop {

  // ---------------------------------------------------------------------------
  // §Q12.1 OODA Phase Types
  // ---------------------------------------------------------------------------

  type OODAPhase = Observe | Orient | Decide | Act

  // ---------------------------------------------------------------------------
  // §Q12.2 State Variables
  // ---------------------------------------------------------------------------

  var currentPhase: OODAPhase
  var phaseStartTime: int
  var globalClock: int
  var observationData: int  // Quality metric 0-100
  var decisionConfidence: int
  var actionSuccess: bool
  var loopCount: int

  // ---------------------------------------------------------------------------
  // §Q12.3 Constants
  // ---------------------------------------------------------------------------

  pure val FAST_LOOP_MAX_MS = 100
  pure val STANDARD_LOOP_MAX_MS = 1000
  pure val MIN_DATA_QUALITY = 80
  pure val MIN_DECISION_CONFIDENCE = 70

  // ---------------------------------------------------------------------------
  // §Q12.4 Initialization
  // ---------------------------------------------------------------------------

  action init = all {
    currentPhase' = Observe,
    phaseStartTime' = 0,
    globalClock' = 0,
    observationData' = 0,
    decisionConfidence' = 0,
    actionSuccess' = false,
    loopCount' = 0
  }

  // ---------------------------------------------------------------------------
  // §Q12.5 Phase Transitions
  // ---------------------------------------------------------------------------

  action completeObserve(dataQuality: int): bool = all {
    currentPhase == Observe,
    dataQuality >= MIN_DATA_QUALITY,
    currentPhase' = Orient,
    observationData' = dataQuality,
    phaseStartTime' = globalClock,
    globalClock' = globalClock + 10
  }

  action completeOrient(analysisComplete: bool): bool = all {
    currentPhase == Orient,
    analysisComplete,
    currentPhase' = Decide,
    phaseStartTime' = globalClock,
    globalClock' = globalClock + 20
  }

  action completeDecide(confidence: int): bool = all {
    currentPhase == Decide,
    confidence >= MIN_DECISION_CONFIDENCE,
    currentPhase' = Act,
    decisionConfidence' = confidence,
    phaseStartTime' = globalClock,
    globalClock' = globalClock + 15
  }

  action completeAct(success: bool): bool = all {
    currentPhase == Act,
    currentPhase' = Observe,
    actionSuccess' = success,
    loopCount' = loopCount + 1,
    phaseStartTime' = globalClock,
    globalClock' = globalClock + 20
  }

  // Emergency fast loop
  action emergencyLoop: bool = all {
    currentPhase' = Observe,
    phaseStartTime' = globalClock,
    globalClock' = globalClock + 5
  }

  // ---------------------------------------------------------------------------
  // §Q12.6 Safety Invariants
  // ---------------------------------------------------------------------------

  // Data quality must be sufficient when leaving Observe
  val observeQualityInvariant: bool =
    currentPhase != Observe implies observationData >= MIN_DATA_QUALITY

  // Decisions must have sufficient confidence
  val decisionConfidenceInvariant: bool =
    currentPhase == Act implies decisionConfidence >= MIN_DECISION_CONFIDENCE

  // Loop always progresses
  val loopProgressInvariant: bool =
    currentPhase.in(Set(Observe, Orient, Decide, Act))

  val oodaInvariant: bool = all {
    observeQualityInvariant,
    decisionConfidenceInvariant,
    loopProgressInvariant
  }

  temporal alwaysOODASafe = always(oodaInvariant)

  // ---------------------------------------------------------------------------
  // §Q12.7 Liveness Properties
  // ---------------------------------------------------------------------------

  // Loop eventually completes
  temporal loopEventuallyCompletes = always(
    currentPhase == Observe implies eventually(loopCount > 0)
  )
}