(* ::Package:: *)

(* ============================================================================= *)
(* INTELITOR MATHEMATICAL BLUEPRINT                                              *)
(* Purpose: Formal specification of system axioms and OODA loop parameters       *)
(* ============================================================================= *)

BeginPackage["Intelitor`Blueprint`"]

(* --- §1 Fundamental Axioms --- *)

Axiom1::usage = "Axiom1[config] is True if compilation settings are Patient Mode compliant.";
Axiom2::usage = "Axiom2[config] is True if container settings are Isolation compliant.";

(* --- §2 OODA Metrics --- *)

LoopSpeed::usage = "Latency thresholds for fast, standard, and deep loops.";
DataQualityThreshold::usage = "Minimum data quality for Observe-Orient transition.";

Begin["`Private`"]

(* Implementation *)

Axiom1[config_] := (
  config["noTimeout"] === True &&
  config["patientMode"] === True &&
  config["infinitePatience"] === True
)

Axiom2[config_] := (
  config["runtime"] === "Podman" &&
  config["rootless"] === True
)

LoopSpeed = <|
  "Fast" -> 100,     (* ms *)
  "Standard" -> 1000,
  "Deep" -> 5000
|>

DataQualityThreshold = 0.85

End[]

EndPackage[]
