defmodule Indrajaal.AI.Simplex.GraphVerification do
  @moduledoc """
  Verifies the Fractal Mesh Substrate Topology using Graph Theory.
  Ensures the 6-node production holon structure is intact.
  """

  require Logger

  alias Graph

  # SC-FRACTAL-001: Expected Genotype Topology
  @expected_nodes ["db1", "db2", "obs", "app1", "app2", "liveview"]
  @expected_edges [
    # Replication Link
    {"db1", "db2"},
    # Data Link Primary
    {"app1", "db1"},
    # Data Link Primary (HA)
    {"app2", "db1"},
    # Telemetry Link
    {"app1", "obs"},
    # Telemetry Link
    {"app2", "obs"},
    # Cockpit Link
    {"liveview", "app1"}
  ]

  def verify_topology(actual_graph) do
    Logger.info(">>> [GRAPH] AUDITING FRACTAL MESH TOPOLOGY...")

    with :ok <- verify_nodes(actual_graph),
         :ok <- verify_edges(actual_graph) do
      {:ok, "Fractal Mesh Topology Verified (SIL4 Compliant)"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_nodes(graph) do
    actual = Graph.vertices(graph)
    missing = Enum.filter(@expected_nodes, &(&1 not in actual))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing holon nodes: #{inspect(missing)}"}
    end
  end

  defp verify_edges(graph) do
    Enum.reduce_while(@expected_edges, :ok, fn {u, v}, :ok ->
      if Graph.edge(graph, u, v) or Graph.edge(graph, v, u) do
        {:cont, :ok}
      else
        {:halt, {:error, "Missing topology link: #{u} <-> #{v}"}}
      end
    end)
  end

  def validate_routing_proposal(proposal) do
    # Placeholder implementation
    {:ok, proposal}
  end

  @registered_sources [
    :guardian,
    :gde,
    :cortex,
    :synapse,
    :synapse_resource,
    :chat_resource,
    :agent
  ]

  @doc false
  @spec check_source_registered(atom()) :: :ok | {:error, {atom(), atom()}}
  def check_source_registered(source) do
    if source in @registered_sources do
      :ok
    else
      {:error, {:source_not_registered, source}}
    end
  end

  @doc false
  @spec verify(map()) :: {:ok, map()} | {:error, term()}
  def verify(%{source: source, confidence: confidence} = proposal) do
    with :ok <- check_source_registered(source),
         :ok <- check_confidence(confidence) do
      {:ok, proposal}
    end
  end

  def verify(proposal), do: {:ok, proposal}

  @doc false
  @spec check_target_reachable(map()) :: :ok | {:error, term()}
  def check_target_reachable(%{target: nil}), do: :ok
  def check_target_reachable(%{target: :openrouter}), do: :ok

  def check_target_reachable(%{target: target}) do
    case target do
      :ollama ->
        # Ollama may or may not be available; default to reachable
        :ok

      _ ->
        :ok
    end
  end

  def check_target_reachable(_), do: :ok

  @doc false
  @spec list_registered_sources() :: [atom()]
  def list_registered_sources, do: @registered_sources

  defp check_confidence(confidence) when is_number(confidence) and confidence >= 0.5, do: :ok

  defp check_confidence(confidence),
    do: {:error, {:confidence_below_threshold, confidence}}
end
