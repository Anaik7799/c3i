/// CEPAF Capability-Based Security Module
/// Provides capability tokens for fine-grained access control.
///
/// WHAT: Object-capability security model for secure resource access
/// WHY: Enables principle of least authority (POLA) and secure delegation
/// CONSTRAINTS:
///   - SC-FSH-100: Capabilities must be unforgeable
///   - SC-FSH-101: Capabilities must be revocable
///   - SC-FSH-102: Capability delegation must be auditable
///
/// STAMP Compliance: SC-FSH-100 to SC-FSH-102
/// Version: 1.0.0
namespace Cepaf.Core

open System
open System.Security.Cryptography
open System.Collections.Concurrent

// ============================================================================
// CAPABILITY TOKEN TYPES
// ============================================================================

/// Unique capability identifier
type CapabilityId = CapabilityId of Guid

/// Permission level
type Permission =
    | Read
    | Write
    | Execute
    | Admin
    | All

/// Resource type
type ResourceType =
    | File of path: string
    | Network of host: string * port: int
    | Database of connection: string
    | Memory of region: string
    | Process of pid: int
    | Custom of name: string

/// Capability constraints
type CapabilityConstraint =
    | TimeLimit of expiresAt: DateTime
    | RateLimit of maxCalls: int * windowMs: int
    | Attenuation of maxPermission: Permission
    | OneShot  // Can only be used once
    | Delegation of maxDepth: int

/// Audit entry for capability usage
type AuditEntry = {
    CapabilityId: CapabilityId
    Timestamp: DateTime
    Action: string
    Success: bool
    Details: string option
}

/// Revocation status
type RevocationStatus =
    | Active
    | Revoked of DateTime * reason: string
    | Expired

// ============================================================================
// CAPABILITY TOKEN
// ============================================================================

/// A capability token granting access to a resource
type Capability<'Resource> = private {
    Id: CapabilityId
    Resource: 'Resource
    Permissions: Permission Set
    Constraints: CapabilityConstraint list
    CreatedAt: DateTime
    ParentId: CapabilityId option
    DelegationDepth: int
    Secret: byte[]
}

module Capability =

    /// Generate secure random bytes
    let private generateSecret () =
        let bytes = Array.zeroCreate<byte> 32
        use rng = RandomNumberGenerator.Create()
        rng.GetBytes(bytes)
        bytes

    /// Create a new capability
    let create resource permissions constraints =
        {
            Id = CapabilityId (Guid.NewGuid())
            Resource = resource
            Permissions = permissions
            Constraints = constraints
            CreatedAt = DateTime.UtcNow
            ParentId = None
            DelegationDepth = 0
            Secret = generateSecret()
        }

    /// Get capability ID
    let id cap = cap.Id

    /// Get resource
    let resource cap = cap.Resource

    /// Get permissions
    let permissions cap = cap.Permissions

    /// Check if capability has specific permission
    let hasPermission perm cap =
        cap.Permissions.Contains(All) || cap.Permissions.Contains(perm)

    /// Check if capability is within constraints
    let checkConstraints now callCount cap =
        cap.Constraints
        |> List.forall (function
            | TimeLimit expiresAt -> now < expiresAt
            | RateLimit (maxCalls, _) -> callCount < maxCalls
            | OneShot -> callCount = 0
            | Delegation maxDepth -> cap.DelegationDepth <= maxDepth
            | Attenuation _ -> true)

    /// Attenuate (weaken) a capability
    let attenuate newPermissions newConstraints cap =
        // Can only remove permissions, not add
        let restrictedPerms = Set.intersect cap.Permissions newPermissions
        // Add new constraints
        let allConstraints = cap.Constraints @ newConstraints
        {
            Id = CapabilityId (Guid.NewGuid())
            Resource = cap.Resource
            Permissions = restrictedPerms
            Constraints = allConstraints
            CreatedAt = DateTime.UtcNow
            ParentId = Some cap.Id
            DelegationDepth = cap.DelegationDepth + 1
            Secret = generateSecret()
        }

    /// Create a time-limited delegation
    let delegateWithTimeout duration cap =
        attenuate cap.Permissions [TimeLimit (DateTime.UtcNow.Add(duration))] cap

    /// Create a read-only delegation
    let delegateReadOnly cap =
        attenuate (Set.singleton Read) [] cap

    /// Create a one-shot delegation
    let delegateOneShot cap =
        attenuate cap.Permissions [OneShot] cap

// ============================================================================
// CAPABILITY MANAGER
// ============================================================================

/// Manages capability lifecycle and auditing
type CapabilityManager() =
    let capabilities = ConcurrentDictionary<CapabilityId, obj>()
    let revocations = ConcurrentDictionary<CapabilityId, RevocationStatus>()
    let usageCounts = ConcurrentDictionary<CapabilityId, int>()
    let auditLog = ConcurrentQueue<AuditEntry>()

    /// Register a capability
    member _.Register(cap: Capability<'R>) =
        capabilities.TryAdd(cap.Id, box cap) |> ignore
        usageCounts.TryAdd(cap.Id, 0) |> ignore

    /// Revoke a capability
    member _.Revoke(capId: CapabilityId, reason: string) =
        revocations.AddOrUpdate(
            capId,
            Revoked (DateTime.UtcNow, reason),
            fun _ _ -> Revoked (DateTime.UtcNow, reason)) |> ignore

    /// Check if capability is valid
    member _.IsValid(cap: Capability<'R>) =
        match revocations.TryGetValue(cap.Id) with
        | true, Revoked _ -> false
        | _ ->
            let callCount = usageCounts.GetOrAdd(cap.Id, 0)
            Capability.checkConstraints DateTime.UtcNow callCount cap

    /// Use capability (increments counter, logs audit)
    member this.Use(cap: Capability<'R>, action: string) =
        if not (this.IsValid(cap)) then
            auditLog.Enqueue({
                CapabilityId = cap.Id
                Timestamp = DateTime.UtcNow
                Action = action
                Success = false
                Details = Some "Invalid or revoked capability"
            })
            Error "Capability is invalid or revoked"
        else
            usageCounts.AddOrUpdate(cap.Id, 1, fun _ c -> c + 1) |> ignore
            auditLog.Enqueue({
                CapabilityId = cap.Id
                Timestamp = DateTime.UtcNow
                Action = action
                Success = true
                Details = None
            })
            Ok ()

    /// Get audit log
    member _.GetAuditLog() = auditLog.ToArray() |> Array.toList

    /// Get usage count
    member _.GetUsageCount(capId: CapabilityId) =
        match usageCounts.TryGetValue(capId) with
        | true, count -> count
        | false, _ -> 0

// ============================================================================
// CAPABILITY-BASED RESOURCES
// ============================================================================

/// Capability-protected resource wrapper
type CapabilityResource<'R, 'V> = private {
    Capability: Capability<'R>
    Manager: CapabilityManager
    Value: unit -> 'V
}

module CapabilityResource =

    /// Create a protected resource
    let create (manager: CapabilityManager) (cap: Capability<'R>) (getValue: unit -> 'V) : CapabilityResource<'R, 'V> =
        manager.Register(cap)
        {
            Capability = cap
            Manager = manager
            Value = getValue
        }

    /// Access resource with permission check
    let access perm action resource =
        if not (Capability.hasPermission perm resource.Capability) then
            Error (sprintf "Missing permission: %A" perm)
        else
            match resource.Manager.Use(resource.Capability, action) with
            | Ok () -> Ok (resource.Value())
            | Error e -> Error e

    /// Access for read
    let read resource = access Read "read" resource

    /// Access for write
    let write resource = access Write "write" resource

    /// Access for execute
    let execute resource = access Execute "execute" resource

// ============================================================================
// CAPABILITY DSL
// ============================================================================

/// DSL for creating capabilities
module CapabilityDsl =

    type CapabilityBuilder() =
        let mutable permissions = Set.empty
        let mutable constraints = []

        member _.Yield(_) = ()

        [<CustomOperation("permission")>]
        member _.Permission(_, perm) =
            permissions <- permissions.Add(perm)

        [<CustomOperation("timeout")>]
        member _.Timeout(_, duration: TimeSpan) =
            constraints <- TimeLimit (DateTime.UtcNow.Add(duration)) :: constraints

        [<CustomOperation("rateLimit")>]
        member _.RateLimit(_, maxCalls, windowMs) =
            constraints <- RateLimit (maxCalls, windowMs) :: constraints

        [<CustomOperation("oneShot")>]
        member _.OneShot(_) =
            constraints <- OneShot :: constraints

        [<CustomOperation("maxDelegation")>]
        member _.MaxDelegation(_, depth) =
            constraints <- Delegation depth :: constraints

        member _.Run(_) =
            let perms = permissions
            let cons = constraints
            permissions <- Set.empty
            constraints <- []
            (perms, cons)

    let capability = CapabilityBuilder()

    /// Create capability with builder result
    let forResource resource (perms, constraints) =
        Capability.create resource perms constraints

// ============================================================================
// SEALER/UNSEALER PATTERN
// ============================================================================

/// Sealer creates sealed values that only the matching unsealer can open
module Sealer =

    /// Sealed value (opaque to outside)
    type Sealed<'T> = private Sealed of Guid * obj

    /// Sealer/Unsealer pair
    type SealerPair<'T> = {
        Seal: 'T -> Sealed<'T>
        Unseal: Sealed<'T> -> 'T option
    }

    /// Create a new sealer/unsealer pair
    let create<'T>() =
        let key = Guid.NewGuid()
        {
            Seal = fun value -> Sealed (key, box value)
            Unseal = fun (Sealed (k, v)) ->
                if k = key then Some (unbox v)
                else None
        }

    /// Brand pattern - type-safe tagging
    type Brand<'Tag, 'T> = private Brand of 'T

    module Brand =
        /// Create a brander for a specific tag type
        let create<'Tag>() =
            let wrap (x: 'T) : Brand<'Tag, 'T> = Brand x
            let unwrap (Brand x) : 'T = x
            (wrap, unwrap)

// ============================================================================
// MEMBRANE PATTERN
// ============================================================================

/// Membrane for revocable access to object graphs
module Membrane =

    /// Membrane wraps access to a target, allowing revocation
    type Membrane<'T> = {
        Target: 'T
        mutable IsRevoked: bool
        OnAccess: 'T -> unit
    }

    /// Create a membrane around a target
    let create onAccess target = {
        Target = target
        IsRevoked = false
        OnAccess = onAccess
    }

    /// Access through membrane
    let access membrane =
        if membrane.IsRevoked then
            Error "Membrane has been revoked"
        else
            membrane.OnAccess membrane.Target
            Ok membrane.Target

    /// Revoke the membrane
    let revoke membrane =
        membrane.IsRevoked <- true

    /// Wrap function through membrane
    let wrap f membrane =
        access membrane |> Result.map f

// ============================================================================
// CARETAKER PATTERN
// ============================================================================

/// Caretaker holds reference to facets for revocation
module Caretaker =

    /// Facet - wrapped capability with revocation
    type Facet<'T> = {
        mutable Value: 'T option
        mutable IsRevoked: bool
    }

    /// Create a facet
    let createFacet value = {
        Value = Some value
        IsRevoked = false
    }

    /// Get value from facet
    let get facet =
        if facet.IsRevoked then None
        else facet.Value

    /// Revoke facet
    let revoke facet =
        facet.IsRevoked <- true
        facet.Value <- None

    /// Caretaker manages multiple facets
    type Caretaker() =
        let facets = ResizeArray<obj>()

        member _.Register(facet: Facet<'T>) =
            facets.Add(box facet)

        member _.RevokeAll() =
            for f in facets do
                let facet = unbox<Facet<obj>> f
                facet.IsRevoked <- true
                facet.Value <- None

// ============================================================================
// POWERBOX PATTERN
// ============================================================================

/// Powerbox provides controlled capability granting
module Powerbox =

    type CapabilityRequest<'R> = {
        RequestedResource: 'R
        RequestedPermissions: Permission Set
        Justification: string
    }

    type CapabilityGrant<'R> =
        | Granted of Capability<'R>
        | Denied of reason: string
        | NeedsApproval

    /// Powerbox interface
    type IPowerbox<'R> =
        abstract Request: CapabilityRequest<'R> -> CapabilityGrant<'R>
        abstract GetAvailable: unit -> 'R list

    /// Simple policy-based powerbox
    type PolicyPowerbox<'R>(policy: CapabilityRequest<'R> -> bool) =
        let granted = ConcurrentBag<Capability<'R>>()

        interface IPowerbox<'R> with
            member _.Request(request) =
                if policy request then
                    let cap = Capability.create request.RequestedResource request.RequestedPermissions []
                    granted.Add(cap)
                    Granted cap
                else
                    Denied "Policy violation"

            member _.GetAvailable() =
                granted.ToArray() |> Array.map Capability.resource |> Array.toList

    /// Interactive powerbox that logs requests
    type AuditingPowerbox<'R>(inner: IPowerbox<'R>) =
        let log = ConcurrentQueue<CapabilityRequest<'R> * CapabilityGrant<'R>>()

        interface IPowerbox<'R> with
            member _.Request(request) =
                let result = inner.Request(request)
                log.Enqueue((request, result))
                result

            member _.GetAvailable() = inner.GetAvailable()

        member _.GetAuditLog() = log.ToArray() |> Array.toList
