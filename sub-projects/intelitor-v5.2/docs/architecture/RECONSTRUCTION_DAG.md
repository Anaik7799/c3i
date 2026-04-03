# Reconstruction DAG Analysis

The reconstruction of the Ark from damaged media follows a Directed Acyclic Graph (DAG) that ensures mathematical correctness and safety.

## Nodes (States)

1.  **Adsorbed**: The Ark file is present on the filesystem.
2.  **Header**: The Shell preamble is executing.
3.  **Capsid**: The Rust binary is running.
4.  **Mapped**: The file is memory-mapped (ReadOnly).
5.  **Seam**: The `|||INDRAJAAL_DNA_SEP|||` delimiter is located.
6.  **Metadata**: The Footer JSON is parsed.
7.  **Shards[N]**: The N shards are identified in the byte stream.
8.  **Hashes[N]**: The BLAKE3 hash of each shard is computed.
9.  **Status[N]**: Each shard is marked `Healthy` or `Necrotic`.
10. **Survivors**: The set of healthy shards $S_{surv}$.
11. **Check**: $|S_{surv}| \ge K$.
12. **Reconstruction**: The Reed-Solomon engine generates the missing shards.
13. **Genome**: The full $K$ data shards are assembled.
14. **Decompressed**: The Zstd stream is decoded.
15. **Lysis**: The filesystem is populated.

## Edges (Transitions)

*   `Adsorbed -> Header`: User executes `./indrajaal.ark`.
*   `Header -> Capsid`: `dd` extraction + `exec`.
*   `Capsid -> Mapped`: `mmap` syscall.
*   `Mapped -> Seam`: Boyer-Moore search (or naive).
*   `Seam -> Metadata`: Offset calculation `EOF - 1024`.
*   `Metadata -> Shards[N]`: Geometry calculation.
*   `Shards[N] -> Hashes[N]`: Parallel BLAKE3 (Rayon).
*   `Hashes[N] -> Status[N]`: Comparison with Metadata hashes.
*   `Status[N] -> Survivors`: Filter.
*   `Survivors -> Check`: Threshold logic.
*   `Check -> Reconstruction`: If $Survivors < N$, else Identity.
*   `Reconstruction -> Genome`: Concatenation.
*   `Genome -> Decompressed`: Zstd stream.
*   `Decompressed -> Lysis`: Tar extraction.

## Critical Path Analysis

The longest path is:
`Shards -> Hashes -> Status -> Reconstruction`

*   **Optimization**: `Hashes` is $O(N)$ but parallelizable.
*   **Optimization**: `Reconstruction` is $O(K \cdot M)$ XOR ops.

## Failure Modes (Cut Sets)

The graph disconnects (failure) if:
1.  **Header Corruption**: `Header -> Capsid` edge fails. (Recoverable via manual extraction).
2.  **Seam Corruption**: `Mapped -> Seam` edge fails. (Recoverable via brute force).
3.  **Metadata Corruption**: `Metadata -> Shards` edge fails. (Critical - Manual Geometry guessing required).
4.  **Massive Necrosis**: `Check -> Reconstruction` fails condition $|S_{surv}| \ge K$. (Information Theoretic Death).
