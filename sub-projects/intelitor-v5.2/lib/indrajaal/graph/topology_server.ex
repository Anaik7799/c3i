defmodule Indrajaal.Graph.TopologyServer do
  @moduledoc """
  L2 State Holder for System Topology.
  Maintains the live graph and broadcasts updates to L5 (LiveView).
  """
  use GenServer
  require Logger
  alias Indrajaal.Graph.GraphBLAS
  alias Indrajaal.Graph.GraphAnalytics

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def update_graph(nodes, edges) do
    GenServer.cast(__MODULE__, {:update_graph, nodes, edges})
  end

  @impl true
  def init(_opts) do
    # Initial State (Mocked)
    nodes = ["Guardian", "Sentinel", "Cortex", "SagaManager", "Repo", "Web"]
    edges = [{0, 1}, {0, 2}, {3, 4}, {5, 0}, {1, 0}]

    state = calculate_state(nodes, edges)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_graph, nodes, edges}, _state) do
    new_state = calculate_state(nodes, edges)

    # Broadcast to L5
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "topology:updates",
      {:topology_update, new_state}
    )

    {:noreply, new_state}
  end

  defp calculate_state(nodes, edges) do
    matrix = GraphBLAS.to_adjacency_matrix(length(nodes), edges)
    has_cycle = GraphBLAS.has_cycle?(matrix)

    centrality_tensor = GraphAnalytics.centrality(matrix)
    centrality_list = Nx.to_flat_list(centrality_tensor)

    %{
      nodes: nodes,
      edges: edges,
      matrix: matrix,
      has_cycle: has_cycle,
      centrality: centrality_list
    }
  end
end
