namespace Cepaf.Phases

open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

module FormalVerification =

    let executeGate (logger: QuadplexLogger) (runner: IProcessRunner) gate cmd args est = asyncResult {
        let t = createTask gate (sprintf "Formal Proof Gate: %s" gate) "Spec files exist" "Constructive Proof Complete" "Hypothesis" "Proven" est
        
        do! runTask logger t (fun () -> asyncResult {
            let! result = runner.Run(cmd, args)
            if result.ExitCode = 0 then
                return ()
            else
                return! fromResult (Error (FormalVerificationError(gate, result.StandardError)))
        })
    }

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("PHASE: FORMAL_VERIFICATION (SIL-2 Mathematical Proofs)")
        logger.Emit(PhaseStart "FORMAL_VERIFICATION")
        
        let quintSpec = "docs/formal_specs/quint_specifications.qnt"
        let agdaSpec = "docs/formal_specs/agda_proofs.agda"

        do! executeGate logger runner "G1_QUINT_PARSE" "quint" ["parse"; quintSpec] 2000L
        do! executeGate logger runner "G2_QUINT_TYPECHECK" "quint" ["typecheck"; quintSpec] 3000L
        do! executeGate logger runner "G3_AGDA_PROOF" "agda" ["--safe"; agdaSpec] 5000L
        do! executeGate logger runner "G4_QUINT_VERIFY" "quint" ["verify"; "--invariant=masterInvariant"; quintSpec] 8000L

        logger.Emit(PhaseComplete("FORMAL_VERIFICATION", 0L, true))
        return ()
    }
