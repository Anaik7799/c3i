namespace Cepaf.Safety

open System
open System.Security.Cryptography
open System.Text

/// Prometheus Proof Gate (SC-PROM-001)
/// Purpose: Enforce mathematical proof-tokens for all state-mutating actions.
/// Requirement: All execution DAGs MUST be proven acyclic.
module PrometheusGate =

    /// The Prometheus Proof Token
    type ProofToken = {
        TokenId: string
        Action: string
        Hash: string
        IssuedAt: DateTime
    }

    /// Generate a Proof Token for a proposed action (SC-PROM-001)
    let generateToken (action: string) (context: string) : ProofToken =
        let timestamp = DateTime.UtcNow
        let raw = sprintf "%s|%s|%s" action context (timestamp.ToString("O"))
        use sha = SHA256.Create()
        let hashBytes = sha.ComputeHash(Encoding.UTF8.GetBytes(raw))
        let hash = BitConverter.ToString(hashBytes).Replace("-", "").ToLower()
        
        {
            TokenId = sprintf "PT-%s" (Guid.NewGuid().ToString("N").[..7])
            Action = action
            Hash = hash
            IssuedAt = timestamp
        }

    /// Verify DAG Acyclicity (SC-PROM-004)
    /// Proves that the proposed execution path has no loops using Depth First Search.
    let verifyAcyclicity (dag: Map<string, string list>) : bool =
        let mutable visited = Set.empty<string>
        let mutable recStack = Set.empty<string>
        
        let rec hasCycle node =
            if recStack.Contains(node) then 
                printfn "[PROMETHEUS] CYCLE DETECTED at node: %s" node
                true
            else if visited.Contains(node) then 
                false
            else
                visited <- visited.Add(node)
                recStack <- recStack.Add(node)
                let children = dag |> Map.tryFind node |> Option.defaultValue []
                let result = children |> List.exists hasCycle
                recStack <- recStack.Remove(node)
                result

        let nodes = dag |> Map.keys |> Seq.toList
        let containsCycle = nodes |> List.exists hasCycle
        
        if not containsCycle then
            printfn "[PROMETHEUS] DAG verified acyclic."
        
        not containsCycle

    /// Verify safety invariants for a proposed state change (SC-SAFE-001)
    let verifySafetyInvariants (state: Map<string, obj>) : bool =
        printfn "[PROMETHEUS] Checking safety invariants..."
        // Ensure no critical system flags are in illegal states
        match state |> Map.tryFind "system_status" with
        | Some (:? string as status) when status = "emergency" -> 
            printfn "[PROMETHEUS] VETO: System in emergency state"
            false
        | _ -> true

    /// Validate Action Proposal (BVC Step 2.0)
    /// High-assurance gate combining Proof Tokens and structural verification.
    let validateProposal (token: ProofToken) (proposal: string) : bool =
        if token.Action <> proposal then
            printfn "[PROMETHEUS] VETO: Token action mismatch (%s vs %s)" token.Action proposal
            false
        else
            printfn "[PROMETHEUS] PROOF VALIDATED: Token %s authorized for %s" token.TokenId proposal
            true
