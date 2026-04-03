defmodule Indrajaal.Observability.Fractal.OtelTraceCorrelator do
  @moduledoc """
  OTEL Trace Correlator — Full L1–L7 Fractal Layer Trace Correlation

  WHAT: Extends OtelIntegration (L1–L5) to complete L6 (Cluster) and L7
        (Federation) trace correlation. Provides cross-node and cross-holon
        trace context propagation via Phoenix.PubSub (L6) and Zenoh topics
        (L7), enabling end-to-end distributed tracing across the SIL-6
        biomorphic fractal mesh.
  WHY: SC-OBS-071 (4 OTEL modules), SC-LOG-004 (TraceID propagation), and
       the 2f294e44 task requirement mandate that all 7 fractal layers expose
       traceable, correlated spans. Cluster-level consensus operations (L6)
       and federation-level cross-holon exchanges (L7) must carry W3C
       traceparent and Indrajaal fractal baggage for end-to-end observability.

  ## Layer Coverage
  | Layer | Scope           | Correlation Mechanism                    |
  |-------|-----------------|------------------------------------------|
  | L1    | Function        | OtelIntegration.start_fractal_span/3     |
  | L2    | Module/Component| OtelIntegration.start_fractal_span/3     |
  | L3    | Holon/Domain    | OtelIntegration.start_fractal_span/3     |
  | L4    | Container       | OtelIntegration.start_fractal_span/3     |
  | L5    | Node            | OtelIntegration.start_fractal_span/3     |
  | L6    | Cluster         | start_l6_span/3 + PubSub propagation     |
  | L7    | Federation      | start_l7_span/3 + Zenoh topic forwarding |

  ## L6 Cluster Correlation
  L6 spans carry cluster-specific attributes:
  - `cluster.node` — Current BEAM node name
  - `cluster.quorum` — Quorum membership snapshot (2oo3 voting context)
  - `cluster.consensus_id` — Tricameral consensus operation ID (if any)
  - `cluster.mesh_score` — Mesh health score at span start (0.0–1.0)

  ## L7 Federation Correlation
  L7 spans carry federation-specific attributes:
  - `federation.holon_id` — Source holon identifier (UHI format)
  - `federation.peer` — Target federation peer node
  - `federation.protocol_version` — Negotiated federation protocol version
  - `federation.attestation_id` — Ed25519 attestation ID for cross-holon call

  ## Baggage Headers (L6/L7 Extensions)
  - `ot-baggage-fractal-cluster-node` — BEAM node name
  - `ot-baggage-fractal-cluster-consensus` — Consensus operation ID
  - `ot-baggage-fractal-federation-holon` — UHI of originating holon
  - `ot-baggage-fractal-federation-peer` — Target federation peer
  - `ot-baggage-fractal-federation-proto` — Protocol version negotiated

  ## Zenoh Topics (L7 Trace Forwarding)
  - `indrajaal/otel/federation/trace` — Cross-holon trace context
  - `indrajaal/otel/cluster/trace` — Cluster-level trace events

  ## STAMP Compliance
  - SC-OBS-071: 4 OTEL modules (this is the 4th, covering L6/L7)
  - SC-LOG-004: TraceID auto-propagated across all 7 layers
  - SC-LOG-006: HLC timestamps for L3+ (enforced at L6/L7)
  - SC-FRAC-001: Cluster-level AI quorum consensus observable
  - SC-FED-006: Federation attestation Ed25519-verified (attribute in span)
  - SC-ZEN-001: Zenoh IPC for L7 federation trace forwarding
  - SC-VER-041: OODA cycle < 100ms — span correlation completes async
  """

  require Logger

  alias Indrajaal.Observability.Fractal.{OtelIntegration, HLC}

  @pubsub Indrajaal.PubSub
  @cluster_trace_topic "otel:cluster:trace"
  @federation_trace_topic "otel:federation:trace"

  @zenoh_cluster_topic "indrajaal/otel/cluster/trace"
  @zenoh_federation_topic "indrajaal/otel/federation/trace"

  # Federation protocol version this node speaks
  @federation_protocol_version "1.0.0"

  # ============================================================================
  # Types
  # ============================================================================

  @type fractal_level :: :l1 | :l2 | :l3 | :l4 | :l5 | :l6 | :l7

  @type span_context :: %{
          span_name: String.t(),
          span_ctx: term(),
          parent_ctx: term(),
          level: fractal_level(),
          module: atom(),
          function: atom(),
          hlc: term() | nil,
          start_time: integer(),
          layer_attrs: map()
        }

  @type l6_opts :: [
          consensus_id: String.t() | nil,
          quorum_members: [atom()] | nil,
          mesh_score: float() | nil
        ]

  @type l7_opts :: [
          holon_id: String.t() | nil,
          peer: String.t() | nil,
          attestation_id: String.t() | nil
        ]

  # ============================================================================
  # L1–L5 pass-through (backward compatibility shim)
  # ============================================================================

  @doc """
  Unified span entry point for all fractal layers L1–L7.

  For L1–L5, delegates to `OtelIntegration.start_fractal_span/3`.
  For L6, adds cluster correlation attributes and PubSub broadcast.
  For L7, adds federation attributes and Zenoh trace forwarding.
  """
  @spec start_span(atom(), atom(), fractal_level()) :: span_context()
  def start_span(module, function, level)
      when level in [:l1, :l2, :l3, :l4, :l5] do
    OtelIntegration.start_fractal_span(module, function, level)
  end

  def start_span(module, function, :l6) do
    start_l6_span(module, function, [])
  end

  def start_span(module, function, :l7) do
    start_l7_span(module, function, [])
  end

  @doc """
  End a span created by `start_span/3`, `start_l6_span/3`, or `start_l7_span/3`.
  """
  @spec end_span(span_context(), :ok | {:error, term()}) :: :ok
  def end_span(nil, _result), do: :ok

  def end_span(%{level: level} = span_context, result)
      when level in [:l1, :l2, :l3, :l4, :l5] do
    OtelIntegration.end_fractal_span(span_context, result)
  end

  def end_span(%{level: :l6} = span_context, result) do
    end_l6_span(span_context, result)
  end

  def end_span(%{level: :l7} = span_context, result) do
    end_l7_span(span_context, result)
  end

  # ============================================================================
  # L6: Cluster Span
  # ============================================================================

  @doc """
  Start an L6 (Cluster) fractal span with cluster-aware attributes.

  Adds cluster membership, quorum context, and mesh health score to the span.
  Broadcasts the trace context via Phoenix.PubSub to all cluster nodes so that
  the trace can be correlated across the Erlang distributed cluster.

  ## Options
  - `:consensus_id` — ID of the tricameral consensus operation in progress
  - `:quorum_members` — List of node atoms participating in quorum
  - `:mesh_score` — Mesh health score (0.0–1.0) at span creation time

  ## STAMP
  - SC-FRAC-001: Cluster-level quorum correlation
  - SC-VER-041: Async PubSub broadcast (does not block span creation)
  """
  @spec start_l6_span(atom(), atom(), l6_opts()) :: span_context()
  def start_l6_span(module, function, opts \\ []) do
    consensus_id = Keyword.get(opts, :consensus_id)
    quorum_members = Keyword.get(opts, :quorum_members, Node.list())
    mesh_score = Keyword.get(opts, :mesh_score, 0.0)

    span_name = build_l6_span_name(module, function)
    hlc = HLC.now()
    now_us = System.monotonic_time(:microsecond)

    layer_attrs = build_l6_attributes(module, function, consensus_id, quorum_members, mesh_score)

    # Try to create OTel span with L6 attributes
    span_ctx = try_create_extended_span(span_name, layer_attrs)

    # Set L6-specific baggage for cross-cluster propagation
    set_l6_baggage(consensus_id, quorum_members)

    # Broadcast trace context to cluster (non-blocking)
    broadcast_cluster_trace(span_name, layer_attrs, hlc)

    %{
      span_name: span_name,
      span_ctx: span_ctx,
      parent_ctx: OtelIntegration.get_fractal_baggage(:trace_id),
      level: :l6,
      module: module,
      function: function,
      hlc: hlc,
      start_time: now_us,
      layer_attrs: layer_attrs
    }
  end

  @doc """
  End an L6 cluster span, recording final duration and broadcasting completion.
  """
  @spec end_l6_span(span_context(), :ok | {:error, term()}) :: :ok
  def end_l6_span(nil, _result), do: :ok

  def end_l6_span(span_context, result) do
    duration_us = System.monotonic_time(:microsecond) - span_context.start_time

    status =
      case result do
        :ok -> "ok"
        {:error, reason} -> "error:#{inspect(reason)}"
      end

    # Emit telemetry for cluster-level observability
    :telemetry.execute(
      [:fractal, :l6, :span, :stop],
      %{duration_us: duration_us},
      %{
        span_name: span_context.span_name,
        module: span_context.module,
        function: span_context.function,
        status: status,
        node: Node.self()
      }
    )

    # End the underlying OTel span if any
    try_end_extended_span(span_context.span_ctx, result)

    # Clear L6 baggage
    clear_l6_baggage()

    :ok
  end

  # ============================================================================
  # L7: Federation Span
  # ============================================================================

  @doc """
  Start an L7 (Federation) fractal span with cross-holon correlation attributes.

  Sets federation baggage headers and publishes the trace context to the Zenoh
  federation topic so that receiving holons can continue the distributed trace.

  ## Options
  - `:holon_id` — UHI of the originating holon (auto-detected if nil)
  - `:peer` — Target federation peer node name or URI
  - `:attestation_id` — Ed25519 attestation ID for the cross-holon call

  ## STAMP
  - SC-FED-006: Attestation Ed25519-verified (recorded as span attribute)
  - SC-ZEN-001: ALL F#↔Elixir communication via Zenoh backplane
  - SC-XHOLON-003: Cross-holon access via Zenoh ONLY
  """
  @spec start_l7_span(atom(), atom(), l7_opts()) :: span_context()
  def start_l7_span(module, function, opts \\ []) do
    holon_id = Keyword.get(opts, :holon_id) || detect_holon_id()
    peer = Keyword.get(opts, :peer, "unknown")
    attestation_id = Keyword.get(opts, :attestation_id)

    span_name = build_l7_span_name(module, function, peer)
    hlc = HLC.now()
    now_us = System.monotonic_time(:microsecond)

    layer_attrs = build_l7_attributes(module, function, holon_id, peer, attestation_id)

    # Try to create OTel span with L7 attributes
    span_ctx = try_create_extended_span(span_name, layer_attrs)

    # Set L7 federation baggage for W3C traceparent propagation
    set_l7_baggage(holon_id, peer)

    # Forward trace context to federation peer via Zenoh (non-blocking)
    forward_federation_trace(span_name, layer_attrs, hlc, peer)

    %{
      span_name: span_name,
      span_ctx: span_ctx,
      parent_ctx: OtelIntegration.get_fractal_baggage(:trace_id),
      level: :l7,
      module: module,
      function: function,
      hlc: hlc,
      start_time: now_us,
      layer_attrs: layer_attrs
    }
  end

  @doc """
  End an L7 federation span, recording final metrics and signalling completion
  to the federation peer via Zenoh.
  """
  @spec end_l7_span(span_context(), :ok | {:error, term()}) :: :ok
  def end_l7_span(nil, _result), do: :ok

  def end_l7_span(span_context, result) do
    duration_us = System.monotonic_time(:microsecond) - span_context.start_time
    peer = Map.get(span_context.layer_attrs, "federation.peer", "unknown")

    status =
      case result do
        :ok -> "ok"
        {:error, reason} -> "error:#{inspect(reason)}"
      end

    # Emit telemetry for federation-level observability
    :telemetry.execute(
      [:fractal, :l7, :span, :stop],
      %{duration_us: duration_us},
      %{
        span_name: span_context.span_name,
        module: span_context.module,
        function: span_context.function,
        status: status,
        peer: peer,
        holon: Map.get(span_context.layer_attrs, "federation.holon_id", "unknown")
      }
    )

    # End the underlying OTel span if any
    try_end_extended_span(span_context.span_ctx, result)

    # Clear L7 baggage
    clear_l7_baggage()

    :ok
  end

  # ============================================================================
  # Cross-Layer Correlation Utilities
  # ============================================================================

  @doc """
  Inject all fractal baggage (L1–L7) into HTTP headers for outbound requests.

  Extends `OtelIntegration.inject_baggage_headers/1` with L6/L7 cluster and
  federation headers, enabling full end-to-end trace propagation through REST
  and gRPC calls that cross holon boundaries.
  """
  @spec inject_all_baggage_headers(list()) :: list()
  def inject_all_baggage_headers(headers) when is_list(headers) do
    # Start with L1–L5 baggage from base module
    headers = OtelIntegration.inject_baggage_headers(headers)

    # Add L6 cluster baggage
    l6_headers = build_l6_headers()

    # Add L7 federation baggage
    l7_headers = build_l7_headers()

    headers ++ l6_headers ++ l7_headers
  end

  @doc """
  Extract fractal baggage from inbound HTTP headers (L1–L7).

  Extends `OtelIntegration.extract_baggage_headers/1` to restore L6/L7 context
  when a request arrives from another holon or cluster node.
  """
  @spec extract_all_baggage_headers(list() | map()) :: map()
  def extract_all_baggage_headers(headers) do
    base = OtelIntegration.extract_baggage_headers(headers)
    l6 = extract_l6_headers(headers)
    l7 = extract_l7_headers(headers)

    Map.merge(Map.merge(base, l6), l7)
  end

  @doc """
  Restore federation trace context from an incoming Zenoh message payload.

  When a federation peer forwards trace context via the
  `indrajaal/otel/federation/trace` Zenoh topic, this function restores
  the distributed trace into the current process's OTel context so that
  subsequent L7 spans correctly link back to the originating holon's trace.
  """
  @spec restore_federation_trace_context(map()) :: :ok
  def restore_federation_trace_context(payload) when is_map(payload) do
    trace_id = Map.get(payload, "trace_id")
    holon_id = Map.get(payload, "holon_id")
    peer = Map.get(payload, "peer")
    proto = Map.get(payload, "protocol_version", @federation_protocol_version)

    if trace_id do
      Process.put(:fractal_trace_id, trace_id)
    end

    if holon_id do
      Process.put(:federation_holon_id, holon_id)
    end

    if peer do
      Process.put(:federation_peer, peer)
    end

    Process.put(:federation_protocol_version, proto)

    :ok
  end

  @doc """
  Get the current end-to-end trace ID spanning all fractal layers.

  Returns the W3C trace ID from OTel if available, falling back to the
  process dictionary. This ID is stable across L1–L7 for a given
  distributed request.
  """
  @spec get_e2e_trace_id() :: String.t() | nil
  def get_e2e_trace_id do
    OtelIntegration.get_l3_trace_id()
    |> case do
      nil -> Process.get(:fractal_trace_id)
      id -> id
    end
  end

  @doc """
  Build a full fractal correlation map covering all 7 layers.

  Useful for attaching to log entries or telemetry events to provide
  complete observability context.
  """
  @spec build_full_correlation_map() :: map()
  def build_full_correlation_map do
    base_baggage = OtelIntegration.get_fractal_baggage()

    %{
      # L1–L5 context (from base OtelIntegration)
      fractal_level: Map.get(base_baggage, "ot-baggage-fractal-level"),
      fractal_module: Map.get(base_baggage, "ot-baggage-fractal-module"),
      fractal_function: Map.get(base_baggage, "ot-baggage-fractal-function"),
      trace_id: get_e2e_trace_id(),
      # L6 context
      cluster_node: Node.self(),
      cluster_consensus_id: Process.get(:l6_consensus_id),
      cluster_quorum_size: length(Process.get(:l6_quorum_members, [])),
      # L7 context
      federation_holon_id: Process.get(:federation_holon_id) || detect_holon_id(),
      federation_peer: Process.get(:federation_peer),
      federation_protocol: Process.get(:federation_protocol_version, @federation_protocol_version)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Private: L6 Helpers
  # ============================================================================

  defp build_l6_span_name(module, function) do
    module_str = String.replace(to_string(module), "Elixir.", "")
    "fractal:L6:cluster:#{module_str}.#{function}"
  end

  defp build_l6_attributes(module, function, consensus_id, quorum_members, mesh_score) do
    node_str = to_string(Node.self())
    quorum_str = quorum_members |> Enum.map(&to_string/1) |> Enum.join(",")

    base = %{
      "fractal.level" => "L6",
      "fractal.module" => String.replace(to_string(module), "Elixir.", ""),
      "fractal.function" => to_string(function),
      "fractal.enabled" => true,
      "cluster.node" => node_str,
      "cluster.quorum_members" => quorum_str,
      "cluster.quorum_size" => length(quorum_members),
      "cluster.mesh_score" => mesh_score
    }

    if consensus_id do
      Map.put(base, "cluster.consensus_id", consensus_id)
    else
      base
    end
  end

  defp set_l6_baggage(consensus_id, quorum_members) do
    baggage = %{
      "ot-baggage-fractal-cluster-node" => to_string(Node.self()),
      "ot-baggage-fractal-cluster-quorum" =>
        quorum_members |> Enum.map(&to_string/1) |> Enum.join(",")
    }

    baggage =
      if consensus_id do
        Map.put(baggage, "ot-baggage-fractal-cluster-consensus", consensus_id)
      else
        baggage
      end

    # Store in process dictionary for intra-process propagation
    existing = Process.get(:fractal_baggage, %{})
    Process.put(:fractal_baggage, Map.merge(existing, baggage))

    # Remember key values for build_full_correlation_map
    Process.put(:l6_consensus_id, consensus_id)
    Process.put(:l6_quorum_members, quorum_members)

    :ok
  end

  defp clear_l6_baggage do
    existing = Process.get(:fractal_baggage, %{})

    cleaned =
      Map.drop(existing, [
        "ot-baggage-fractal-cluster-node",
        "ot-baggage-fractal-cluster-quorum",
        "ot-baggage-fractal-cluster-consensus"
      ])

    Process.put(:fractal_baggage, cleaned)
    Process.delete(:l6_consensus_id)
    Process.delete(:l6_quorum_members)

    :ok
  end

  defp broadcast_cluster_trace(span_name, attrs, hlc) do
    message = %{
      event: :l6_span_start,
      span_name: span_name,
      trace_id: get_e2e_trace_id(),
      node: Node.self(),
      attrs: attrs,
      hlc_physical: if(hlc, do: hlc.physical, else: nil),
      timestamp: DateTime.utc_now()
    }

    # Non-blocking PubSub broadcast to cluster (SC-VER-041: async)
    Task.start(fn ->
      try do
        Phoenix.PubSub.broadcast(@pubsub, @cluster_trace_topic, {:cluster_trace, message})
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end)

    # Also emit telemetry for cluster-level metrics
    :telemetry.execute(
      [:fractal, :l6, :span, :start],
      %{count: 1},
      %{span_name: span_name, node: Node.self(), zenoh_topic: @zenoh_cluster_topic}
    )

    :ok
  end

  defp build_l6_headers do
    node_str = to_string(Node.self())
    consensus_id = Process.get(:l6_consensus_id)

    base = [{"ot-baggage-fractal-cluster-node", node_str}]

    if consensus_id do
      [{"ot-baggage-fractal-cluster-consensus", consensus_id} | base]
    else
      base
    end
  end

  defp extract_l6_headers(headers) when is_list(headers) do
    headers
    |> Enum.filter(fn {k, _v} ->
      String.starts_with?(to_string(k), "ot-baggage-fractal-cluster-")
    end)
    |> Enum.into(%{})
  end

  defp extract_l6_headers(headers) when is_map(headers) do
    headers
    |> Enum.filter(fn {k, _v} ->
      String.starts_with?(to_string(k), "ot-baggage-fractal-cluster-")
    end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Private: L7 Helpers
  # ============================================================================

  defp build_l7_span_name(module, function, peer) do
    module_str = String.replace(to_string(module), "Elixir.", "")
    "fractal:L7:federation:#{module_str}.#{function}->#{peer}"
  end

  defp build_l7_attributes(module, function, holon_id, peer, attestation_id) do
    base = %{
      "fractal.level" => "L7",
      "fractal.module" => String.replace(to_string(module), "Elixir.", ""),
      "fractal.function" => to_string(function),
      "fractal.enabled" => true,
      "federation.holon_id" => holon_id,
      "federation.peer" => peer,
      "federation.protocol_version" => @federation_protocol_version
    }

    if attestation_id do
      Map.put(base, "federation.attestation_id", attestation_id)
    else
      base
    end
  end

  defp set_l7_baggage(holon_id, peer) do
    baggage = %{
      "ot-baggage-fractal-federation-holon" => holon_id,
      "ot-baggage-fractal-federation-peer" => peer,
      "ot-baggage-fractal-federation-proto" => @federation_protocol_version
    }

    existing = Process.get(:fractal_baggage, %{})
    Process.put(:fractal_baggage, Map.merge(existing, baggage))

    # Remember for build_full_correlation_map
    Process.put(:federation_holon_id, holon_id)
    Process.put(:federation_peer, peer)
    Process.put(:federation_protocol_version, @federation_protocol_version)

    :ok
  end

  defp clear_l7_baggage do
    existing = Process.get(:fractal_baggage, %{})

    cleaned =
      Map.drop(existing, [
        "ot-baggage-fractal-federation-holon",
        "ot-baggage-fractal-federation-peer",
        "ot-baggage-fractal-federation-proto"
      ])

    Process.put(:fractal_baggage, cleaned)
    Process.delete(:federation_holon_id)
    Process.delete(:federation_peer)
    Process.delete(:federation_protocol_version)

    :ok
  end

  defp forward_federation_trace(span_name, attrs, hlc, peer) do
    trace_id = get_e2e_trace_id()
    holon_id = detect_holon_id()

    payload = %{
      event: "l7_span_start",
      span_name: span_name,
      trace_id: trace_id,
      holon_id: holon_id,
      peer: peer,
      attrs: attrs,
      protocol_version: @federation_protocol_version,
      hlc_physical: if(hlc, do: hlc.physical, else: nil),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Non-blocking Task: forward via PubSub (L7 bridge) and telemetry
    Task.start(fn ->
      try do
        # Publish to PubSub for local Zenoh bridge to pick up
        Phoenix.PubSub.broadcast(
          @pubsub,
          @federation_trace_topic,
          {:federation_trace, payload}
        )
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end

      # Emit telemetry; the ZenohPublisher will forward to Zenoh topic
      :telemetry.execute(
        [:fractal, :l7, :span, :start],
        %{count: 1},
        %{
          span_name: span_name,
          peer: peer,
          holon: holon_id,
          zenoh_topic: @zenoh_federation_topic
        }
      )
    end)

    :ok
  end

  defp build_l7_headers do
    holon_id = Process.get(:federation_holon_id) || detect_holon_id()
    peer = Process.get(:federation_peer, "unknown")

    [
      {"ot-baggage-fractal-federation-holon", holon_id},
      {"ot-baggage-fractal-federation-peer", peer},
      {"ot-baggage-fractal-federation-proto", @federation_protocol_version}
    ]
  end

  defp extract_l7_headers(headers) when is_list(headers) do
    headers
    |> Enum.filter(fn {k, _v} ->
      String.starts_with?(to_string(k), "ot-baggage-fractal-federation-")
    end)
    |> Enum.into(%{})
  end

  defp extract_l7_headers(headers) when is_map(headers) do
    headers
    |> Enum.filter(fn {k, _v} ->
      String.starts_with?(to_string(k), "ot-baggage-fractal-federation-")
    end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Private: Shared OTel Helpers
  # ============================================================================

  defp try_create_extended_span(span_name, attributes) do
    if otel_available?() do
      try do
        tracer = :opentelemetry.get_application_tracer(:indrajaal)

        span_opts = %{
          kind: :internal,
          attributes: attributes |> Enum.into([])
        }

        :otel_tracer.start_span(tracer, span_name, span_opts)
      rescue
        _ -> nil
      catch
        _, _ -> nil
      end
    else
      nil
    end
  end

  defp try_end_extended_span(nil, _result), do: :ok

  defp try_end_extended_span(span_ctx, result) do
    if otel_available?() do
      try do
        case result do
          :ok ->
            :otel_span.set_status(span_ctx, :ok, "")

          {:error, reason} ->
            :otel_span.set_status(span_ctx, :error, inspect(reason))
        end

        :otel_span.end_span(span_ctx)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    else
      :ok
    end
  end

  defp otel_available? do
    Code.ensure_loaded?(:opentelemetry) and Code.ensure_loaded?(:otel_tracer)
  end

  # ============================================================================
  # Private: Holon Identity
  # ============================================================================

  defp detect_holon_id do
    # Derive UHI from app config if set, else fall back to node name
    case Application.get_env(:indrajaal, :holon_id) do
      nil -> "holon://#{Node.self()}"
      id -> id
    end
  end
end
