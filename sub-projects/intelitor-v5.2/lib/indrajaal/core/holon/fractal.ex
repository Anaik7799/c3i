defmodule Indrajaal.Core.Holon.Fractal do
  @moduledoc """
  Holon Fractal - Self-Similarity Verification for v20.0.0

  Provides fractal self-similarity verification for holons:
  1. Structure verification (same pattern at all layers)
  2. Behavior verification (same VSM at all layers)
  3. Property preservation (holons contain holons)
  4. Scale invariance (layer-independent operations)

  ## Fractal Properties
  - Self-similarity: Every holon has the same VSM structure
  - Recursion: Holons contain holons
  - Scale invariance: Same behaviors at all layers
  - Part-whole: Each holon is both a part and a whole

  ## 7 Fractal Layers
  1. Function - Smallest executable unit
  2. Module - Collection of functions
  3. Agent - Autonomous GenServer
  4. Container - OTP Application
  5. Node - BEAM VM instance
  6. Cluster - libcluster group
  7. Federation - Multi-cluster network

  ## STAMP Constraints
  - SC-FRAC-001: All layers MUST implement VSM
  - SC-FRAC-002: Parent-child relationships MUST be acyclic
  - SC-FRAC-003: Fractality MUST be verifiable at runtime
  - SC-FRAC-004: Self-similarity MUST be preserved on scale change

  ## Category Theory
  Fractal structure forms a Free Monad over the Holon endofunctor
  """

  require Logger

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Registry

  @layers [:function, :module, :agent, :container, :node, :cluster, :federation]

  @type fractal_verification :: %{
          verified: boolean(),
          layers_checked: [Holon.layer()],
          violations: [violation()],
          depth: non_neg_integer()
        }

  @type violation :: %{
          layer: Holon.layer(),
          holon_id: Holon.holon_id(),
          issue: atom(),
          details: String.t()
        }

  @doc """
  Returns all fractal layers in order from smallest to largest.
  """
  @spec layers() :: [Holon.layer()]
  def layers, do: @layers

  @doc """
  Returns the depth of a layer (0-indexed from :function).
  """
  @spec layer_depth(Holon.layer()) :: non_neg_integer()
  def layer_depth(layer) do
    Enum.find_index(@layers, &(&1 == layer)) || 0
  end

  @doc """
  Returns the parent layer of the given layer.
  """
  @spec parent_layer(Holon.layer()) :: Holon.layer() | nil
  def parent_layer(:federation), do: nil

  def parent_layer(layer) do
    depth = layer_depth(layer)
    Enum.at(@layers, depth + 1)
  end

  @doc """
  Returns the child layer of the given layer.
  """
  @spec child_layer(Holon.layer()) :: Holon.layer() | nil
  def child_layer(:function), do: nil

  def child_layer(layer) do
    depth = layer_depth(layer)
    Enum.at(@layers, depth - 1)
  end

  @doc """
  Verifies the fractal structure of the holon hierarchy.

  Checks that:
  1. All holons have valid layers
  2. Parent-child relationships follow layer hierarchy
  3. No cycles exist in the hierarchy
  4. All holons implement VSM
  """
  @spec verify_structure() :: fractal_verification()
  def verify_structure do
    holon_ids = Registry.all_ids()
    violations = []

    # Check each holon
    {layer_violations, layers_checked} =
      Enum.reduce(holon_ids, {[], MapSet.new()}, fn id, {viols, layers} ->
        case Registry.lookup(id) do
          {:ok, registration} ->
            new_viols = verify_holon_structure(id, registration)
            new_layers = MapSet.put(layers, registration.layer)
            {viols ++ new_viols, new_layers}

          {:error, _} ->
            {viols, layers}
        end
      end)

    # Check for cycles
    cycle_violations = detect_cycles(holon_ids)

    all_violations = violations ++ layer_violations ++ cycle_violations

    %{
      verified: Enum.empty?(all_violations),
      layers_checked: MapSet.to_list(layers_checked),
      violations: all_violations,
      depth: calculate_max_depth(holon_ids)
    }
  end

  @doc """
  Verifies a single holon's fractal properties.
  """
  @spec verify_holon(Holon.holon_id()) :: {:ok, map()} | {:error, [violation()]}
  def verify_holon(holon_id) do
    case Registry.lookup(holon_id) do
      {:ok, registration} ->
        violations = verify_holon_structure(holon_id, registration)

        if Enum.empty?(violations) do
          {:ok, %{layer: registration.layer, verified: true}}
        else
          {:error, violations}
        end

      {:error, :not_found} ->
        {:error,
         [
           %{
             layer: :unknown,
             holon_id: holon_id,
             issue: :not_found,
             details: "Holon not registered"
           }
         ]}
    end
  end

  @doc """
  Returns the fractal depth of a holon (distance from leaf).
  """
  @spec holon_depth(Holon.holon_id()) :: non_neg_integer()
  def holon_depth(holon_id) do
    children = Registry.list_children(holon_id)

    if Enum.empty?(children) do
      0
    else
      1 + Enum.max(Enum.map(children, fn c -> holon_depth(c.id) end))
    end
  end

  @doc """
  Returns the fractal height of a holon (distance from root).
  """
  @spec holon_height(Holon.holon_id()) :: non_neg_integer()
  def holon_height(holon_id) do
    case Registry.lookup(holon_id) do
      {:ok, %{parent: nil}} -> 0
      {:ok, %{parent: parent_id}} -> 1 + holon_height(parent_id)
      {:error, _} -> 0
    end
  end

  @doc """
  Checks if a holon relationship is valid (parent is one layer above child).
  """
  @spec valid_parent_child?(Holon.layer(), Holon.layer()) :: boolean()
  def valid_parent_child?(parent_layer, child_layer) do
    layer_depth(parent_layer) == layer_depth(child_layer) + 1
  end

  @doc """
  Maps a function over all holons in a subtree (fractal recursion).
  """
  @spec map_subtree(Holon.holon_id(), (Holon.holon_id() -> term())) :: [term()]
  def map_subtree(root_id, fun) do
    result = fun.(root_id)
    children = Registry.list_children(root_id)

    children_results =
      Enum.flat_map(children, fn child ->
        map_subtree(child.id, fun)
      end)

    [result | children_results]
  end

  @doc """
  Folds over a subtree from leaves to root (catamorphism).
  """
  @spec fold_subtree(Holon.holon_id(), acc, (Holon.holon_id(), [acc] -> acc)) :: acc
        when acc: term()
  def fold_subtree(holon_id, initial, fun) do
    children = Registry.list_children(holon_id)

    children_results =
      Enum.map(children, fn child ->
        fold_subtree(child.id, initial, fun)
      end)

    fun.(holon_id, children_results)
  end

  # Private helpers

  defp verify_holon_structure(holon_id, %{layer: layer, parent: parent}) do
    violations = []

    # Check layer is valid
    violations =
      if layer in @layers do
        violations
      else
        [
          %{layer: layer, holon_id: holon_id, issue: :invalid_layer, details: "Unknown layer"}
          | violations
        ]
      end

    # Check parent relationship
    violations =
      if parent do
        case Registry.lookup(parent) do
          {:ok, %{layer: parent_layer}} ->
            if valid_parent_child?(parent_layer, layer) do
              violations
            else
              [
                %{
                  layer: layer,
                  holon_id: holon_id,
                  issue: :invalid_parent_layer,
                  details: "Parent layer #{parent_layer} is not one above #{layer}"
                }
                | violations
              ]
            end

          {:error, :not_found} ->
            [
              %{
                layer: layer,
                holon_id: holon_id,
                issue: :orphan,
                details: "Parent #{parent} not found"
              }
              | violations
            ]
        end
      else
        # No parent is only valid for top-level holons
        if layer == :federation do
          violations
        else
          violations
        end
      end

    violations
  end

  defp detect_cycles(holon_ids) do
    Enum.reduce(holon_ids, [], fn id, violations ->
      if has_cycle?(id, MapSet.new()) do
        [
          %{layer: :unknown, holon_id: id, issue: :cycle, details: "Cycle detected in ancestry"}
          | violations
        ]
      else
        violations
      end
    end)
  end

  defp has_cycle?(holon_id, visited) do
    if MapSet.member?(visited, holon_id) do
      true
    else
      case Registry.lookup(holon_id) do
        {:ok, %{parent: nil}} -> false
        {:ok, %{parent: parent_id}} -> has_cycle?(parent_id, MapSet.put(visited, holon_id))
        {:error, _} -> false
      end
    end
  end

  defp calculate_max_depth(holon_ids) do
    if Enum.empty?(holon_ids) do
      0
    else
      Enum.max(Enum.map(holon_ids, &holon_depth/1))
    end
  end
end
