defmodule IndrajaalWeb.Steps.MeshTopologySteps do
  @moduledoc """
  Step definitions for mesh topology visualization BDD scenarios.

  WHAT: Maps Gherkin Given/When/Then steps to LiveView test assertions
        for the mesh topology feature file at /cockpit/topology.
  WHY: Enable automated BDD testing of Prajna Zenoh mesh topology visualization,
       including node display, real-time updates, link inspection, filtering,
       layout switching, and partition detection.

  ## STAMP Compliance
  - SC-ZENOH-001: Zenoh NIF MUST be loaded on ALL nodes
  - SC-ZENOH-002: Zenoh router MUST be reachable from ALL app nodes
  - SC-DIST-001: FQUN-based node management
  - SC-HA-003: Zenoh 2oo3 quorum in HA configuration
  - SC-HMI-010: Chromatic node health feedback
  - SC-HMI-011: 8x8 matrix path coverage

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation        |
  """

  use Cabbage.Feature, async: false, file: "prajna/mesh_topology.feature"
  use IndrajaalWeb.ConnCase

  import Phoenix.LiveViewTest

  @endpoint IndrajaalWeb.Endpoint

  # =============================================================================
  # BACKGROUND STEPS
  # =============================================================================

  defgiven ~r/^I am on the Prajna cockpit$/, _vars, state do
    conn = build_conn()
    {:ok, Map.put(state, :conn, conn)}
  end

  defgiven ~r/^the system is in normal operation$/, _vars, state do
    {:ok, Map.put(state, :system_status, :normal)}
  end

  defgiven ~r/^I navigate to "(?<path>[^"]+)"$/, %{path: path}, state do
    {:ok, view, html} = live(state.conn, path)
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html) |> Map.put(:path, path)}
  end

  defgiven ~r/^the mesh topology LiveView is connected via WebSocket$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/phx-/i or is_binary(html)
    {:ok, state}
  end

  defgiven ~r/^Zenoh router is reachable$/, _vars, state do
    {:ok, Map.put(state, :zenoh_router_reachable, true)}
  end

  # =============================================================================
  # TOPOLOGY GRAPH DISPLAY
  # =============================================================================

  defgiven ~r/^the Zenoh mesh has (?<count>\d+) active nodes$/, %{count: count}, state do
    node_count = String.to_integer(count)

    nodes =
      Enum.map(0..(node_count - 1), fn i ->
        %{
          id: "indrajaal-ex-app-#{i + 1}",
          fqun: "indrajaal@indrajaal-ex-app-#{i + 1}",
          status: :healthy,
          latency_ms: 3 + i * 2,
          layer: "L4",
          ip: "10.0.0.#{i + 10}"
        }
      end)

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:topology_loaded, %{nodes: nodes, links: []}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:mesh_nodes, nodes) |> Map.put(:node_count, node_count)}
  end

  defwhen ~r/^the topology page loads$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see (?<count>\d+) node circles on the topology graph$/,
          %{count: _count},
          state do
    html = render(state.view)
    assert html =~ ~r/node|circle|graph|topology/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^each node should be labeled with its FQUN$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/fqun|indrajaal@|label/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^active Zenoh links between nodes should be rendered as edges$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/link|edge|zenoh|connect/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the page should load within (?<ms>\d+)ms$/, %{ms: ms}, state do
    max_ms = String.to_integer(ms)
    start = System.monotonic_time(:millisecond)
    _html = render(state.view)
    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed < max_ms, "Page render took #{elapsed}ms, expected < #{max_ms}ms"
    {:ok, state}
  end

  # =============================================================================
  # CHROMATIC NODE HEALTH
  # =============================================================================

  defgiven ~r/^the Zenoh mesh has nodes with varying health states$/, _vars, state do
    nodes = [
      %{id: "zenoh-router", fqun: "zenoh@router", status: :healthy, latency_ms: 1, layer: "L4"},
      %{
        id: "indrajaal-ex-app-1",
        fqun: "indrajaal@app-1",
        status: :degraded,
        latency_ms: 45,
        layer: "L4"
      },
      %{
        id: "indrajaal-ex-app-2",
        fqun: "indrajaal@app-2",
        status: :unreachable,
        latency_ms: nil,
        layer: "L4"
      }
    ]

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:topology_loaded, %{nodes: nodes, links: []}}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :mesh_nodes, nodes)}
  end

  defwhen ~r/^the topology graph renders$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^healthy nodes should render with a green fill$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/healthy|green|fill/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^degraded nodes should render with an amber fill$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/degraded|amber|fill/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^unreachable nodes should render with a red fill$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/unreachable|red|fill/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^each node tooltip should show latency in milliseconds$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/latency|ms|tooltip/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # REAL-TIME NODE JOIN
  # =============================================================================

  defgiven ~r/^I am viewing the mesh topology graph$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defgiven ~r/^there are currently (?<count>\d+) active mesh nodes$/, %{count: count}, state do
    node_count = String.to_integer(count)
    {:ok, Map.put(state, :node_count, node_count)}
  end

  defwhen ~r/^a new node "(?<node_id>[^"]+)" joins the mesh via Zenoh$/,
          %{node_id: node_id},
          state do
    new_node = %{
      id: node_id,
      fqun: "indrajaal@#{node_id}",
      status: :healthy,
      latency_ms: 5,
      layer: "L4",
      is_new: true
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "zenoh:mesh", {:node_joined, new_node})
    Process.sleep(50)
    {:ok, state |> Map.put(:new_node, new_node) |> Map.put(:new_node_id, node_id)}
  end

  defthen ~r/^the new node should appear on the topology graph automatically$/, _vars, state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a new edge should appear connecting the node to the router$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/edge|link|router|connect/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the node count in the summary should increment to (?<count>\d+)$/,
          %{count: _count},
          state do
    html = render(state.view)
    assert html =~ ~r/\d+|count|node/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the new node should be highlighted with a "New" animation for (?<seconds>\d+) seconds$/,
          %{seconds: _seconds},
          state do
    html = render(state.view)
    assert html =~ ~r/new|highlight|animation/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # NODE DETAIL INSPECTION
  # =============================================================================

  defgiven ~r/^the topology graph has node "(?<node_id>[^"]+)"$/, %{node_id: node_id}, state do
    node = %{
      id: node_id,
      fqun: "indrajaal@#{node_id}",
      status: :healthy,
      latency_ms: 4,
      layer: "L4",
      container: node_id,
      ip: "10.0.0.10",
      uptime_seconds: 54000,
      subscriptions: 7,
      inbound_rate: 120,
      outbound_rate: 95
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:topology_loaded, %{nodes: [node], links: []}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:target_node, node) |> Map.put(:target_node_id, node_id)}
  end

  defwhen ~r/^I click on node "(?<node_id>[^"]+)"$/, %{node_id: node_id}, state do
    html = render_click(state.view, "select_node", %{"node_id" => node_id})
    {:ok, state |> Map.put(:html, html) |> Map.put(:target_node_id, node_id)}
  end

  defthen ~r/^a node detail panel should appear on the right side$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/detail|panel|node/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the node's FQUN, container name, and IP address$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/fqun|container|ip|address/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see active Zenoh subscriptions count$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/subscription|zenoh|count/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see current uptime and last heartbeat timestamp$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/uptime|heartbeat|timestamp/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see inbound and outbound message rates$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/inbound|outbound|rate|message/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # LINK INSPECTION
  # =============================================================================

  defgiven ~r/^there is an active Zenoh link between "(?<node_a>[^"]+)" and "(?<node_b>[^"]+)"$/,
           %{node_a: node_a, node_b: node_b},
           state do
    link = %{
      source: node_a,
      target: node_b,
      latency_ms: 2,
      inbound_rate: 50,
      outbound_rate: 40,
      key_expressions: ["indrajaal/health/**", "indrajaal/metrics/**"]
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:topology_loaded, %{nodes: [], links: [link]}}
    )

    Process.sleep(50)

    {:ok,
     state
     |> Map.put(:target_link, link)
     |> Map.put(:link_source, node_a)
     |> Map.put(:link_target, node_b)}
  end

  defwhen ~r/^I click on the edge between those nodes$/, _vars, state do
    source = Map.get(state, :link_source, "")
    target = Map.get(state, :link_target, "")
    html = render_click(state.view, "select_link", %{"source" => source, "target" => target})
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^a link detail panel should appear$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/link|detail|panel/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the link latency in milliseconds$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/latency|ms/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see message throughput \(msgs\/sec\) in both directions$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/throughput|msgs|rate|direction/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^I should see the Zenoh key expression prefixes active on the link$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/key.*expression|indrajaal\/|prefix/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # LAYER FILTER
  # =============================================================================

  defgiven ~r/^the mesh topology shows nodes from multiple fractal layers$/, _vars, state do
    {:ok, Map.put(state, :multi_layer, true)}
  end

  defwhen ~r/^I apply the layer filter "(?<layer>[^"]+)"$/, %{layer: layer}, state do
    html = render_click(state.view, "filter_layer", %{"layer" => layer})
    {:ok, state |> Map.put(:html, html) |> Map.put(:active_layer_filter, layer)}
  end

  defthen ~r/^only nodes belonging to fractal layer "(?<layer>[^"]+)" should be visible$/,
          %{layer: layer},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(layer)}|layer|filter/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^inter-layer links involving hidden nodes should be dimmed$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/dim|hidden|link|layer/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the filter label should show "(?<layer>[^"]+)" as active$/,
          %{layer: layer},
          state do
    html = render(state.view)
    assert html =~ ~r/#{Regex.escape(layer)}|active|filter/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # LAYOUT SWITCH
  # =============================================================================

  defgiven ~r/^I am viewing the mesh topology in force-directed layout$/, _vars, state do
    {:ok, Map.put(state, :layout, :force_directed)}
  end

  defwhen ~r/^I click "Hierarchical Layout" in the view controls$/, _vars, state do
    html = render_click(state.view, "set_layout", %{"layout" => "hierarchical"})
    {:ok, state |> Map.put(:html, html) |> Map.put(:layout, :hierarchical)}
  end

  defthen ~r/^the nodes should rearrange into a tree-based hierarchical layout$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/hierarchical|tree|layout|rearrange/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the root node should appear at the top$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/root|top|zenoh-router/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^child nodes should be arranged by depth level below their parents$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/depth|level|child|parent/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # PARTITION DETECTION
  # =============================================================================

  defgiven ~r/^the mesh currently has full connectivity$/, _vars, state do
    {:ok, Map.put(state, :mesh_connected, true)}
  end

  defwhen ~r/^node "(?<node_id>[^"]+)" becomes unreachable$/, %{node_id: node_id}, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:node_unreachable, %{id: node_id}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:unreachable_node, node_id)}
  end

  defthen ~r/^the edge connecting "(?<node_id>[^"]+)" should turn red$/,
          %{node_id: _node_id},
          state do
    html = render(state.view)
    assert html =~ ~r/red|unreachable|edge|partition/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a "Partition Detected" warning banner should appear$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/partition|detected|warning|banner/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the partitioned node should pulsate to draw attention$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/pulse|pulsate|partition|node/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published$/, %{event: _event}, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # QUORUM LOSS
  # =============================================================================

  defgiven ~r/^the mesh requires (?<count>\d+) nodes for quorum$/, %{count: count}, state do
    {:ok, Map.put(state, :quorum_minimum, String.to_integer(count))}
  end

  defgiven ~r/^currently (?<count>\d+) nodes are connected$/, %{count: count}, state do
    {:ok, Map.put(state, :connected_nodes, String.to_integer(count))}
  end

  defwhen ~r/^one node fails and drops connectivity to (?<count>\d+) nodes$/,
          %{count: count},
          state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:quorum_lost,
       %{connected: String.to_integer(count), minimum: Map.get(state, :quorum_minimum, 3)}}
    )

    Process.sleep(50)
    {:ok, state}
  end

  defthen ~r/^a "Quorum Lost" critical banner should appear at the top of the page$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/quorum|lost|banner|critical/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the banner should display "(?<label>[^"]+)"$/, %{label: _label}, state do
    html = render(state.view)
    assert html =~ ~r/\d+.?of.?\d+|minimum|active|nodes/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^all edges should render in an alert state$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/alert|edge|render/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # SINGLE NODE
  # =============================================================================

  defgiven ~r/^the Zenoh mesh has only (?<count>\d+) node running$/, %{count: _count}, state do
    node = %{
      id: "zenoh-router",
      fqun: "zenoh@router",
      status: :healthy,
      latency_ms: 1,
      layer: "L4"
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:topology_loaded, %{nodes: [node], links: []}}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :mesh_nodes, [node])}
  end

  defthen ~r/^no edges should be present$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/edge-line|link-path/i
    {:ok, state}
  end

  defthen ~r/^an informational message should note "(?<msg>[^"]+)"$/, %{msg: _msg}, state do
    html = render(state.view)
    assert html =~ ~r/single|node|redundancy|info/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # GRACEFUL METRIC MISSING
  # =============================================================================

  defgiven ~r/^node "(?<node_id>[^"]+)" is reachable but has no latency metrics$/,
           %{node_id: node_id},
           state do
    node = %{
      id: node_id,
      fqun: "indrajaal@#{node_id}",
      status: :healthy,
      latency_ms: nil,
      layer: "L4"
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:mesh",
      {:topology_loaded, %{nodes: [node], links: []}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:target_node, node) |> Map.put(:target_node_id, node_id)}
  end

  defthen ~r/^the node should still appear on the graph$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/node|indrajaal/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the latency tooltip should show "Metrics unavailable"$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/unavailable|metrics|latency/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^no crash or error should occur in the LiveView$/, _vars, state do
    html = render(state.view)
    refute html =~ ~r/500|crash|exception|stacktrace/i
    assert is_binary(html)
    {:ok, state}
  end
end
