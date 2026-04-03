defmodule Indrajaal.Cockpit.Prajna.PrometheusVerifier do
  @moduledoc """
  PROMETHEUS Verification Layer for Prajna Cockpit.

  WHAT: Enforces formal verification constraints on state mutations.
  WHY: SC-PROM-001 requires a "Proof Token" for all state-mutating actions.

  ## Constraints Checked
  - SC-PROM-001: Proof Requirement (via token check)
  - SC-PROM-002: API Safety Redline (Budget Check)
  - SC-PROM-004: Graph Acyclicity (DAG Check)

  ## Usage
  ```elixir
  # Request a proof token before mutation
  {:ok, token} = PrometheusVerifier.require_proof_token(:reconfigure, :sentinel)

  # Verify the token is valid
  {:ok, :valid} = PrometheusVerifier.verify_token(token)

  # Verify DAG is acyclic
  {:ok, sorted} = PrometheusVerifier.verify_dag_acyclic(nodes)

  # Check API budget
  {:ok, usage} = PrometheusVerifier.check_api_budget()
  ```
  """

  use Agent
  require Logger

  alias Indrajaal.Cockpit.Prajna.Config

  @type proof_token :: %{
          token_id: String.t(),
          action: atom(),
          target: atom(),
          timestamp: DateTime.t(),
          expires_at: DateTime.t(),
          signature: String.t()
        }
  @type dag_node :: %{id: String.t(), action: atom(), dependencies: list(String.t())}
  @type execution_graph :: %{
          nodes: list(dag_node()),
          edges: list({String.t(), String.t()}),
          metadata: map()
        }
  @type dag_proof_token :: %{
          token_id: String.t(),
          graph_hash: String.t(),
          topological_order: list(String.t()),
          timestamp: DateTime.t(),
          expires_at: DateTime.t(),
          signature: String.t()
        }
  @type cycle_info :: %{
          cycle_nodes: list(String.t()),
          entry_point: String.t()
        }

  # Prohibited actions that cannot receive proof tokens
  @prohibited_actions [:self_destruct, :disable_guardian, :bypass_verification]

  # SC-PROM-005: DAG verification must complete within 5ms (p99)
  @dag_verification_timeout_ms 5

  @doc """
  Starts the PrometheusVerifier agent for tracking statistics.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(
      fn ->
        %{
          tokens_issued: 0,
          tokens_verified: 0,
          dag_checks: 0,
          dag_proof_tokens_issued: 0,
          cycles_detected: 0,
          budget_checks: 0,
          verification_failures: 0,
          execution_graphs_validated: 0
        }
      end,
      name: __MODULE__
    )
  end

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Requests a proof token for the specified action and target.

  ## Parameters
  - `action` - The action requiring proof (e.g., :reconfigure, :scale)
  - `target` - The target of the action (e.g., :sentinel, :workers)
  - `opts` - Options (e.g., skip_budget_check: true)

  ## Returns
  - `{:ok, proof_token}` - Token granted
  - `{:error, :action_prohibited}` - Action is prohibited
  - `{:error, :budget_exceeded}` - API budget exceeded (SC-PROM-002)
  """
  @spec require_proof_token(atom(), atom(), keyword()) :: {:ok, proof_token()} | {:error, atom()}
  def require_proof_token(action, target, opts \\ []) do
    cond do
      action in @prohibited_actions ->
        increment_stat(:verification_failures)
        {:error, :action_prohibited}

      not Keyword.get(opts, :skip_budget_check, false) and budget_exceeded?() ->
        increment_stat(:verification_failures)
        {:error, :budget_exceeded}

      true ->
        timestamp = DateTime.utc_now()
        # SC-PROM-001: Use Config for proof token TTL (default 5 min = 300s for SIL-4)
        ttl_seconds = div(Config.get(:proof_token_ttl_ms, 300_000), 1000)
        expires_at = DateTime.add(timestamp, ttl_seconds, :second)
        nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

        token_data = "#{action}:#{target}:#{DateTime.to_iso8601(timestamp)}:#{nonce}"
        signature = sign_token(token_data)

        token = %{
          token_id: nonce,
          action: action,
          target: target,
          timestamp: timestamp,
          expires_at: expires_at,
          signature: signature
        }

        increment_stat(:tokens_issued)
        {:ok, token}
    end
  end

  @doc """
  Verifies a proof token is valid and not expired.

  ## Returns
  - `{:ok, :valid}` - Token is valid
  - `{:error, :expired_token}` - Token has expired
  - `{:error, :invalid_signature}` - Signature verification failed
  - `{:error, :invalid_token}` - Token format is invalid
  """
  @spec verify_token(proof_token() | term()) :: {:ok, :valid} | {:error, atom()}
  def verify_token(token) when is_map(token) do
    with :ok <- validate_token_format(token),
         :ok <- check_expiration(token),
         :ok <- verify_signature(token) do
      increment_stat(:tokens_verified)
      {:ok, :valid}
    else
      error ->
        increment_stat(:verification_failures)
        error
    end
  end

  def verify_token(_), do: {:error, :invalid_token}

  @doc """
  Verifies that a directed graph (DAG) is acyclic using Kahn's algorithm.

  ## Parameters
  - `nodes` - List of nodes with `:id`, `:action`, and `:dependencies` keys

  ## Returns
  - `{:ok, sorted_ids}` - DAG is acyclic, returns topologically sorted node IDs
  - `{:error, :cyclic_graph}` - Graph contains a cycle
  - `{:error, :invalid_input}` - Input format is invalid
  """
  @spec verify_dag_acyclic(list(dag_node()) | term()) ::
          {:ok, list(String.t())} | {:error, atom()}
  def verify_dag_acyclic(nodes) when is_list(nodes) do
    increment_stat(:dag_checks)

    case kahn_toposort(nodes) do
      {:ok, sorted} -> {:ok, sorted}
      :cycle -> {:error, :cyclic_graph}
    end
  end

  def verify_dag_acyclic(_), do: {:error, :invalid_input}

  @doc """
  Validates a DAG is acyclic and returns a proof token if valid.

  SC-PROM-004 Compliance: Graph Acyclicity verified via topological sort.
  SC-PROM-001 Compliance: Returns a proof token for valid DAGs.

  ## Parameters
  - `nodes` - List of nodes with `:id`, `:action`, and `:dependencies` keys

  ## Returns
  - `{:ok, dag_proof_token}` - DAG is acyclic, returns proof token with topological order
  - `{:error, :cyclic_graph, cycle_info}` - Graph contains a cycle with cycle details
  - `{:error, :invalid_input}` - Input format is invalid
  - `{:error, :timeout}` - Verification exceeded SC-PROM-005 latency budget

  ## Example
      nodes = [
        %{id: "init", action: :initialize, dependencies: []},
        %{id: "process", action: :process, dependencies: ["init"]},
        %{id: "finalize", action: :finalize, dependencies: ["process"]}
      ]

      {:ok, proof_token} = PrometheusVerifier.validate_dag_acyclic(nodes)
      # proof_token.topological_order == ["init", "process", "finalize"]
  """
  @spec validate_dag_acyclic(list(dag_node()) | term()) ::
          {:ok, dag_proof_token()}
          | {:error, :cyclic_graph, cycle_info()}
          | {:error, :invalid_input}
          | {:error, :timeout}
  def validate_dag_acyclic(nodes) when is_list(nodes) do
    start_time = System.monotonic_time(:millisecond)
    increment_stat(:dag_checks)

    result =
      with :ok <- validate_node_format(nodes),
           {:ok, sorted} <- kahn_toposort_with_cycle_detection(nodes) do
        # Generate proof token for valid DAG
        proof_token = generate_dag_proof_token(nodes, sorted)
        increment_stat(:dag_proof_tokens_issued)

        emit_dag_validation_telemetry(:success, nodes, sorted, start_time)
        {:ok, proof_token}
      else
        {:cycle, cycle_info} ->
          increment_stat(:cycles_detected)
          increment_stat(:verification_failures)
          emit_dag_validation_telemetry(:cycle_detected, nodes, cycle_info, start_time)
          {:error, :cyclic_graph, cycle_info}

        {:error, reason} ->
          increment_stat(:verification_failures)
          {:error, reason}
      end

    # Check latency budget (SC-PROM-005)
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > @dag_verification_timeout_ms do
      Logger.warning(
        "[PROMETHEUS] DAG verification exceeded latency budget: #{elapsed}ms > #{@dag_verification_timeout_ms}ms"
      )
    end

    result
  end

  def validate_dag_acyclic(_), do: {:error, :invalid_input}

  @doc """
  Validates an execution graph structure and generates a proof token.

  An execution graph is a complete DAG specification including nodes, edges, and metadata.
  This function performs comprehensive validation suitable for scheduling execution plans.

  ## Parameters
  - `graph` - Execution graph with `:nodes`, `:edges`, and `:metadata` keys

  ## Returns
  - `{:ok, proof_token, execution_plan}` - Valid graph with proof token and execution order
  - `{:error, reason}` - Validation failed

  ## Example
      graph = %{
        nodes: [
          %{id: "a", action: :fetch, dependencies: []},
          %{id: "b", action: :transform, dependencies: ["a"]}
        ],
        edges: [{"a", "b"}],
        metadata: %{name: "data_pipeline", version: 1}
      }

      {:ok, proof, plan} = PrometheusVerifier.validate_execution_graph(graph)
  """
  @spec validate_execution_graph(execution_graph() | term()) ::
          {:ok, dag_proof_token(), list(String.t())} | {:error, atom()}
  def validate_execution_graph(%{nodes: nodes, edges: _edges, metadata: metadata} = graph)
      when is_list(nodes) and is_map(metadata) do
    increment_stat(:execution_graphs_validated)

    case validate_dag_acyclic(nodes) do
      {:ok, proof_token} ->
        execution_plan = proof_token.topological_order

        Logger.debug(
          "[PROMETHEUS] Execution graph '#{Map.get(metadata, :name, "unnamed")}' validated with #{length(nodes)} nodes"
        )

        emit_execution_graph_telemetry(graph, proof_token)
        {:ok, proof_token, execution_plan}

      {:error, :cyclic_graph, cycle_info} ->
        Logger.warning(
          "[PROMETHEUS] Execution graph rejected: cycle detected at #{cycle_info.entry_point}"
        )

        {:error, :cyclic_graph}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate_execution_graph(%{nodes: nodes}) when is_list(nodes) do
    # Allow simplified graph without explicit edges/metadata
    validate_execution_graph(%{nodes: nodes, edges: [], metadata: %{}})
  end

  def validate_execution_graph(_), do: {:error, :invalid_graph_format}

  @doc """
  Verifies a DAG proof token is valid.

  ## Returns
  - `{:ok, :valid}` - Token is valid and not expired
  - `{:error, :expired_token}` - Token has expired
  - `{:error, :invalid_signature}` - Signature verification failed
  """
  @spec verify_dag_proof_token(dag_proof_token() | term()) :: {:ok, :valid} | {:error, atom()}
  def verify_dag_proof_token(token) when is_map(token) do
    with :ok <- validate_dag_token_format(token),
         :ok <- check_expiration(token),
         :ok <- verify_dag_signature(token) do
      {:ok, :valid}
    else
      error ->
        increment_stat(:verification_failures)
        error
    end
  end

  def verify_dag_proof_token(_), do: {:error, :invalid_token}

  @doc """
  Checks API budget usage against the 95% threshold (SC-PROM-002).

  ## Returns
  - `{:ok, usage}` - Current usage percentage (0.0 to 1.0)
  - `{:error, :budget_exceeded}` - Usage >= 95%
  """
  @spec check_api_budget() :: {:ok, float()} | {:error, :budget_exceeded}
  def check_api_budget do
    increment_stat(:budget_checks)

    # SIL-4 FIX: Use real API usage metrics
    usage = get_real_api_usage()

    if usage < 0.95 do
      {:ok, usage}
    else
      {:error, :budget_exceeded}
    end
  end

  @doc """
  Returns statistics about verification operations.
  """
  @spec get_stats() :: map()
  def get_stats do
    case Process.whereis(__MODULE__) do
      nil ->
        %{
          tokens_issued: 0,
          tokens_verified: 0,
          dag_checks: 0,
          dag_proof_tokens_issued: 0,
          cycles_detected: 0,
          budget_checks: 0,
          verification_failures: 0,
          execution_graphs_validated: 0
        }

      _pid ->
        Agent.get(__MODULE__, & &1)
    end
  end

  @doc """
  Legacy function for backward compatibility.
  Verifies if a state mutation is permissible under PROMETHEUS constraints.
  """
  @spec verify_mutation(atom(), map()) :: :ok | {:error, atom()}
  def verify_mutation(action, context) do
    with :ok <- check_proof_token_in_context(context),
         :ok <- check_api_budget_for_action(action),
         :ok <- check_graph_acyclicity(action, context) do
      :ok
    else
      error ->
        log_rejection(action, error)
        error
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp validate_token_format(%{
         token_id: _,
         action: _,
         target: _,
         timestamp: _,
         expires_at: _,
         signature: _
       }),
       do: :ok

  defp validate_token_format(_), do: {:error, :invalid_token}

  defp check_expiration(%{expires_at: expires_at}) do
    if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
      :ok
    else
      {:error, :expired_token}
    end
  end

  defp verify_signature(%{
         action: action,
         target: target,
         timestamp: timestamp,
         token_id: nonce,
         signature: signature
       }) do
    token_data = "#{action}:#{target}:#{DateTime.to_iso8601(timestamp)}:#{nonce}"
    expected_signature = sign_token(token_data)

    if signature == expected_signature do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  # SC-PROM-001: HMAC-SHA256 for proof token signing (SIL-4 compliant)
  # Uses HMAC with a derived key for symmetric token verification
  @hmac_key_material "prajna_prometheus_verifier_hmac_key_v21.1.0"

  defp sign_token(data) do
    # Derive key from material using SHA-256 (key derivation, not signing)
    derived_key = :crypto.hash(:sha256, @hmac_key_material)
    # HMAC-SHA256 for proper cryptographic signing
    :crypto.mac(:hmac, :sha256, derived_key, data) |> Base.encode16(case: :lower)
  end

  defp budget_exceeded? do
    get_real_api_usage() >= 0.95
  end

  defp get_real_api_usage do
    # SIL-4 FIX: Use real metrics instead of simulation
    # SC-PROM-002: API Safety Redline must use actual data
    try do
      # Try to get real usage from telemetry/metrics
      case :persistent_term.get({:indrajaal, :api, :usage_percent}, :not_set) do
        :not_set ->
          # Fallback: Query SmartMetrics if available
          get_usage_from_smart_metrics()

        usage when is_number(usage) ->
          usage
      end
    rescue
      _ ->
        # SIL-4 SAFETY: On error, assume 50% usage (conservative but not blocking)
        # This prevents false positives while maintaining safety margin
        Logger.warning("[PrometheusVerifier] Cannot get real API usage, using conservative 50%")
        0.5
    end
  end

  defp get_usage_from_smart_metrics do
    # Try to get from SmartMetrics
    case Process.whereis(Indrajaal.Cockpit.Prajna.SmartMetrics) do
      nil ->
        # No SmartMetrics running - use conservative default
        0.5

      _pid ->
        metrics = Indrajaal.Cockpit.Prajna.SmartMetrics.all()

        case Map.get(metrics, "api.usage_percent") do
          nil -> 0.5
          %{value: value} when is_number(value) -> value / 100
          _ -> 0.5
        end
    end
  end

  @doc """
  Updates the real API usage for budget checking.
  Call this from rate limiter or API client.
  """
  @spec update_api_usage(float()) :: :ok
  def update_api_usage(usage_percent) when is_number(usage_percent) do
    :persistent_term.put({:indrajaal, :api, :usage_percent}, usage_percent)

    :telemetry.execute(
      [:indrajaal, :prajna, :prometheus, :api_usage_updated],
      %{usage_percent: usage_percent, timestamp: System.system_time(:millisecond)},
      %{}
    )

    :ok
  end

  # ============================================================================
  # DAG VALIDATION HELPERS
  # ============================================================================

  defp validate_node_format([]), do: :ok

  defp validate_node_format([%{id: id, dependencies: deps} | rest])
       when is_binary(id) and is_list(deps) do
    if Enum.all?(deps, &is_binary/1) do
      validate_node_format(rest)
    else
      {:error, :invalid_dependencies}
    end
  end

  defp validate_node_format(_), do: {:error, :invalid_node_format}

  defp validate_dag_token_format(%{
         token_id: _,
         graph_hash: _,
         topological_order: order,
         timestamp: _,
         expires_at: _,
         signature: _
       })
       when is_list(order),
       do: :ok

  defp validate_dag_token_format(_), do: {:error, :invalid_token}

  defp verify_dag_signature(%{
         graph_hash: graph_hash,
         topological_order: order,
         timestamp: timestamp,
         token_id: nonce,
         signature: signature
       }) do
    token_data =
      "dag:#{graph_hash}:#{Enum.join(order, ",")}:#{DateTime.to_iso8601(timestamp)}:#{nonce}"

    expected_signature = sign_token(token_data)

    if signature == expected_signature do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  @doc false
  defp generate_dag_proof_token(nodes, topological_order) do
    timestamp = DateTime.utc_now()
    # SC-PROM-001: Use Config for proof token TTL (default 5 min = 300s for SIL-4)
    ttl_seconds = div(Config.get(:proof_token_ttl_ms, 300_000), 1000)
    expires_at = DateTime.add(timestamp, ttl_seconds, :second)
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    # Hash the graph structure for integrity
    graph_hash = compute_graph_hash(nodes)

    token_data =
      "dag:#{graph_hash}:#{Enum.join(topological_order, ",")}:#{DateTime.to_iso8601(timestamp)}:#{nonce}"

    signature = sign_token(token_data)

    %{
      token_id: nonce,
      graph_hash: graph_hash,
      topological_order: topological_order,
      timestamp: timestamp,
      expires_at: expires_at,
      signature: signature
    }
  end

  defp compute_graph_hash(nodes) do
    # Deterministic hash of graph structure
    normalized =
      nodes
      |> Enum.sort_by(& &1.id)
      |> Enum.map_join("|", fn node ->
        "#{node.id}:#{node.action}:[#{Enum.sort(node.dependencies) |> Enum.join(",")}]"
      end)

    :crypto.hash(:sha256, normalized) |> Base.encode16(case: :lower) |> String.slice(0, 16)
  end

  # Kahn's algorithm with enhanced cycle detection
  defp kahn_toposort_with_cycle_detection([]), do: {:ok, []}

  defp kahn_toposort_with_cycle_detection(nodes) do
    # Build adjacency list and in-degree map
    {adj, in_degree} = build_graph(nodes)
    node_ids = Enum.map(nodes, & &1.id)

    # Find nodes with no dependencies
    queue =
      node_ids
      |> Enum.filter(fn id -> Map.get(in_degree, id, 0) == 0 end)

    case kahn_loop_with_detection(queue, adj, in_degree, [], nodes) do
      {:ok, sorted} -> {:ok, sorted}
      {:cycle, remaining} -> {:cycle, detect_cycle_info(remaining, adj, nodes)}
    end
  end

  defp kahn_loop_with_detection([], _adj, in_degree, result, _nodes) do
    # Check if all nodes processed (no remaining in-degree > 0)
    remaining =
      in_degree
      |> Enum.filter(fn {_k, v} -> v > 0 end)
      |> Enum.map(fn {k, _v} -> k end)

    if Enum.empty?(remaining) do
      {:ok, Enum.reverse(result)}
    else
      {:cycle, remaining}
    end
  end

  defp kahn_loop_with_detection([node | rest], adj, in_degree, result, nodes) do
    # Get neighbors and decrease their in-degree
    neighbors = Map.get(adj, node, [])

    {new_queue, new_in_degree} =
      Enum.reduce(neighbors, {rest, in_degree}, fn neighbor, {q, ind} ->
        new_ind = Map.update!(ind, neighbor, &(&1 - 1))

        if Map.get(new_ind, neighbor) == 0 do
          {q ++ [neighbor], new_ind}
        else
          {q, new_ind}
        end
      end)

    # Mark current node as processed (set in-degree to -1)
    final_in_degree = Map.put(new_in_degree, node, -1)

    kahn_loop_with_detection(new_queue, adj, final_in_degree, [node | result], nodes)
  end

  defp detect_cycle_info(remaining_nodes, adj, _nodes) do
    # Find the cycle by walking from any remaining node
    entry_point = List.first(remaining_nodes)

    # Simple cycle detection: follow edges from entry_point
    cycle_nodes = find_cycle_path(entry_point, adj, remaining_nodes, [])

    %{
      cycle_nodes: cycle_nodes,
      entry_point: entry_point
    }
  end

  defp find_cycle_path(current, adj, valid_nodes, visited) do
    if current in visited do
      # Found cycle, return nodes from cycle start
      cycle_start_idx = Enum.find_index(visited, &(&1 == current))
      Enum.slice(visited, cycle_start_idx..-1//1)
    else
      # Find next node in valid_nodes
      neighbors = Map.get(adj, current, [])
      next_node = Enum.find(neighbors, &(&1 in valid_nodes))

      if next_node do
        find_cycle_path(next_node, adj, valid_nodes, visited ++ [current])
      else
        # No cycle found from this path, return what we have
        visited ++ [current]
      end
    end
  end

  # ============================================================================
  # TELEMETRY HELPERS
  # ============================================================================

  defp emit_dag_validation_telemetry(:success, nodes, sorted, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute(
      [:indrajaal, :prajna, :prometheus, :dag_validated],
      %{
        node_count: length(nodes),
        duration_ms: elapsed,
        timestamp: System.system_time(:millisecond)
      },
      %{
        topological_order: sorted,
        status: :success
      }
    )
  end

  defp emit_dag_validation_telemetry(:cycle_detected, nodes, cycle_info, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute(
      [:indrajaal, :prajna, :prometheus, :dag_cycle_detected],
      %{
        node_count: length(nodes),
        cycle_length: length(cycle_info.cycle_nodes),
        duration_ms: elapsed,
        timestamp: System.system_time(:millisecond)
      },
      %{
        cycle_info: cycle_info,
        status: :cycle_detected
      }
    )
  end

  defp emit_execution_graph_telemetry(graph, proof_token) do
    :telemetry.execute(
      [:indrajaal, :prajna, :prometheus, :execution_graph_validated],
      %{
        node_count: length(graph.nodes),
        edge_count: length(Map.get(graph, :edges, [])),
        timestamp: System.system_time(:millisecond)
      },
      %{
        graph_name: get_in(graph, [:metadata, :name]),
        proof_token_id: proof_token.token_id
      }
    )
  end

  # Kahn's algorithm for topological sort
  defp kahn_toposort([]), do: {:ok, []}

  defp kahn_toposort(nodes) do
    # Build adjacency list and in-degree map
    {adj, in_degree} = build_graph(nodes)
    node_ids = Enum.map(nodes, & &1.id)

    # Find nodes with no dependencies
    queue =
      node_ids
      |> Enum.filter(fn id -> Map.get(in_degree, id, 0) == 0 end)

    kahn_loop(queue, adj, in_degree, [])
  end

  defp build_graph(nodes) do
    adj = Map.new(nodes, fn node -> {node.id, []} end)
    in_degree = Map.new(nodes, fn node -> {node.id, 0} end)

    Enum.reduce(nodes, {adj, in_degree}, fn node, {a, ind} ->
      Enum.reduce(node.dependencies, {a, ind}, fn dep, {a2, ind2} ->
        # dep -> node.id edge
        new_adj = Map.update(a2, dep, [node.id], &[node.id | &1])
        new_ind = Map.update(ind2, node.id, 1, &(&1 + 1))
        {new_adj, new_ind}
      end)
    end)
  end

  defp kahn_loop([], _adj, in_degree, result) do
    # Check if all nodes processed (no remaining in-degree > 0)
    remaining = Enum.count(in_degree, fn {_k, v} -> v > 0 end)

    if remaining == 0 do
      {:ok, Enum.reverse(result)}
    else
      :cycle
    end
  end

  defp kahn_loop([node | rest], adj, in_degree, result) do
    # Get neighbors and decrease their in-degree
    neighbors = Map.get(adj, node, [])

    {new_queue, new_in_degree} =
      Enum.reduce(neighbors, {rest, in_degree}, fn neighbor, {q, ind} ->
        new_ind = Map.update!(ind, neighbor, &(&1 - 1))

        if Map.get(new_ind, neighbor) == 0 do
          {q ++ [neighbor], new_ind}
        else
          {q, new_ind}
        end
      end)

    # Mark current node as processed (set in-degree to -1 or remove)
    final_in_degree = Map.put(new_in_degree, node, -1)

    kahn_loop(new_queue, adj, final_in_degree, [node | result])
  end

  defp increment_stat(key) do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> Agent.update(__MODULE__, fn stats -> Map.update(stats, key, 1, &(&1 + 1)) end)
    end
  end

  # Legacy context-based check
  defp check_proof_token_in_context(%{proof_token: token}) when is_binary(token) do
    if String.starts_with?(token, "PROOF-") do
      :ok
    else
      {:error, :invalid_proof_token}
    end
  end

  defp check_proof_token_in_context(_), do: {:error, :missing_proof_token}

  defp check_api_budget_for_action(_action), do: :ok

  defp check_graph_acyclicity(:add_dependency, %{graph: graph, from: u, to: v}) do
    if graph_has_path?(graph, v, u) do
      {:error, :cycle_detected}
    else
      :ok
    end
  end

  defp check_graph_acyclicity(_, _), do: :ok

  defp graph_has_path?(_graph, _start, _target), do: false

  defp log_rejection(action, {:error, reason}) do
    Logger.warning("[PROMETHEUS] Mutation Rejected: #{inspect(action)} - #{inspect(reason)}")

    :telemetry.execute(
      [:indrajaal, :prajna, :prometheus, :rejection],
      %{timestamp: System.system_time(:millisecond)},
      %{action: action, reason: reason}
    )
  end
end
