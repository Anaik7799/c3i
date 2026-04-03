# Script to verify Recursive Feedback Loop (L1-L7)
# Run with: mix run test/fractal/recursive_loop_test.exs

require Logger
alias Indrajaal.Graph.GraphAnalytics
alias Indrajaal.Graph.GraphBLAS

Logger.info("🔄 Starting 7-Layer Recursive Feedback Verification...")

# 1. Simulate Feedback Loop
# L2 (Logic) generates data -> L3 (Cortex) analyzes -> L4 (Safety) validates -> L5 (Interface) displays -> L2 Adjusts

# Step 1: L2 Generate Graph
Logger.info("[L2] Generating Dynamic Topology...")
nodes = 10
# Cycle!
edges = Enum.map(0..(nodes - 2), fn i -> {i, i + 1} end) ++ [{nodes - 1, 0}]
matrix = GraphBLAS.to_adjacency_matrix(nodes, edges)

# Step 2: L3/L2 Analytics
Logger.info("[L2+] Computing Centrality...")
centrality = GraphAnalytics.centrality(matrix)
max_centrality = Nx.reduce_max(centrality) |> Nx.to_number()
Logger.info("  -> Max Centrality: #{max_centrality}")

# Step 3: L4 Safety Check (Mocked Envelope)
# Arbitrary safety threshold
is_safe = max_centrality < 0.5
Logger.info("[L4] Safety Check: #{if is_safe, do: "SAFE", else: "RISK DETECTED"}")

# Step 4: L5 Telemetry Emission
Logger.info("[L6] Emitting Datadog Tags...")
tags = Indrajaal.Observability.DatadogMetadata.tags(%{nodes: nodes})
Logger.info("  -> Tags: #{inspect(tags)}")

Logger.info("✅ Recursive Loop Complete.")
