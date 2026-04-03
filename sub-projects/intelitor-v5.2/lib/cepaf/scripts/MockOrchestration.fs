namespace Cepaf.Orchestration

open System.Collections.Concurrent

module Sil4Types =
    type MeshStatus = MeshReady | MeshSyncing | MeshOffline
    type MeshPheno = { Status: MeshStatus; Proof: string }
    type RegistryNode = { Pheno: MeshPheno; Diverge: float }

module MeshCortex =
    let globalRegistry = ConcurrentDictionary<string, Sil4Types.RegistryNode>()
