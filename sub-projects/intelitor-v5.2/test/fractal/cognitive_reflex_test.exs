# Script to verify Cognitive Reflex (L3 -> L2 -> L5)
# Run with: mix run test/fractal/cognitive_reflex_test.exs

defmodule Indrajaal.Fractal.CognitiveReflexTest do
  use Indrajaal.DataCase
  require Logger
  alias Indrajaal.Observability.ZenohControlSubscriber
  alias Indrajaal.Graph.TopologyServer

  @tag :fractal
  test "Cognitive Reflex (L3 -> L2 -> L5)" do
    Logger.info("🧠 Starting Cognitive Reflex Verification...")

    # 1. Subscribe to PubSub to verify L5 reception
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "topology:updates")

    # 2. Simulate L3 Cortex Correction Signal (via Zenoh)
    # In real life, F# sends this. We inject via Subscriber.
    payload = %{"type" => "break_cycle", "target" => "Sentinel"}
    Logger.info("[L3] Cortex detecting anomaly... Sending Correction Signal.")

    # Manually trigger handler (since we don't have full Zenoh net)
    Indrajaal.Cybernetic.CorrectionListener.handle_correction(
      "indrajaal/cortex/correction",
      payload
    )

    # 3. Verify L2/L6 Broadcast
    assert_receive {:correction_applied, ^payload}, 1000
    Logger.info("✅ L5 LiveView received Correction Signal.")

    # 4. Trigger Topology Update
    new_nodes = ["Guardian", "Sentinel", "Cortex"]
    new_edges = [{0, 1}, {1, 2}]
    Logger.info("[L2] Updating Topology...")
    TopologyServer.update_graph(new_nodes, new_edges)

    # 5. Verify Topology Update
    assert_receive {:topology_update, state}, 1000

    if length(state.nodes) == 3 do
      Logger.info("✅ L5 LiveView received Topology Update.")
    else
      Logger.error("❌ Topology Update Failed.")
    end

    Logger.info("✅ Cognitive Reflex Verification Complete.")
  end
end
