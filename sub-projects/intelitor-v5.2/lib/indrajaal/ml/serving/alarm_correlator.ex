defmodule Indrajaal.ML.Serving.AlarmCorrelator do
  @moduledoc """
  Nx.Serving-based alarm correlation using NLP and embedding similarity.

  Correlates alarms based on:
  - Text similarity (alarm descriptions, messages)
  - Temporal proximity
  - Spatial/logical grouping
  - Causal relationship inference

  STAMP Compliance:
  - SC-ML-001: Model serving isolation
  - SC-OBS-068: Intelligent alarm correlation

  Integration:
  - Works with Indrajaal.Observability.AlertIntegration
  - FLAME for batch correlation on large alarm sets
  """

  use GenServer

  require Logger

  @default_batch_size 20
  @default_batch_timeout 100

  # Correlation thresholds
  @text_similarity_threshold 0.65
  # 5 minutes
  @temporal_window_ms 300_000
  @min_correlation_score 0.5

  # Keyword embeddings (simplified TF-IDF style)
  @keyword_weights %{
    # Security
    "intrusion" => %{category: :security, weight: 1.0, related: ["breach", "unauthorized"]},
    "tamper" => %{category: :security, weight: 0.9, related: ["alarm", "sensor"]},
    "access" => %{category: :access, weight: 0.8, related: ["denied", "granted", "control"]},
    "motion" => %{category: :detection, weight: 0.7, related: ["detected", "sensor", "pir"]},

    # System
    "offline" => %{category: :system, weight: 0.9, related: ["down", "disconnected"]},
    "failure" => %{category: :system, weight: 0.95, related: ["error", "fault"]},
    "timeout" => %{category: :system, weight: 0.7, related: ["connection", "response"]},
    "battery" => %{category: :power, weight: 0.8, related: ["low", "backup", "fail"]},

    # Environmental
    "fire" => %{category: :safety, weight: 1.0, related: ["smoke", "heat", "alarm"]},
    "smoke" => %{category: :safety, weight: 0.95, related: ["fire", "detector"]},
    "temperature" => %{category: :environmental, weight: 0.6, related: ["high", "low", "sensor"]},
    "water" => %{category: :environmental, weight: 0.7, related: ["leak", "flood", "sensor"]}
  }

  ## Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Find correlations for a new alarm against recent alarms.

  ## Parameters
  - `alarm` - The new alarm to correlate
  - `recent_alarms` - List of recent alarms to compare against

  ## Returns
  - `{:ok, %{correlations: list, groups: list}}`
  """
  def correlate(alarm, recent_alarms, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    GenServer.call(__MODULE__, {:correlate, alarm, recent_alarms, opts}, timeout)
  end

  @doc """
  Group a batch of alarms into correlated clusters.
  """
  def cluster_alarms(alarms, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    GenServer.call(__MODULE__, {:cluster, alarms, opts}, timeout)
  end

  @doc """
  Correlate via FLAME for large alarm sets.
  """
  def correlate_via_flame(alarms) do
    alias Indrajaal.FLAME.SafeRunner

    FLAME.call(Indrajaal.FLAME.IntelligencePool, fn ->
      SafeRunner.guard_state()
      do_cluster(alarms, [])
    end)
  end

  @doc """
  Compute text similarity between two alarm descriptions.
  """
  def text_similarity(text1, text2) do
    emb1 = compute_embedding(String.downcase(text1))
    emb2 = compute_embedding(String.downcase(text2))
    cosine_similarity(emb1, emb2)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    batch_timeout = Keyword.get(opts, :batch_timeout, @default_batch_timeout)

    Logger.info("🔗 AlarmCorrelator: Starting (batch_size: #{batch_size})")

    state = %{
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      model_version: "1.0.0",
      stats: %{
        correlations_found: 0,
        clusters_created: 0,
        alarms_processed: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:correlate, alarm, recent_alarms, opts}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result = do_correlate(alarm, recent_alarms, opts)

    latency_us = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:correlate, latency_us, length(result.correlations))

    new_stats = %{
      state.stats
      | correlations_found: state.stats.correlations_found + length(result.correlations),
        alarms_processed: state.stats.alarms_processed + 1
    }

    {:reply, {:ok, result}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:cluster, alarms, opts}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result = do_cluster(alarms, opts)

    latency_us = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:cluster, latency_us, length(result.clusters))

    new_stats = %{
      state.stats
      | clusters_created: state.stats.clusters_created + length(result.clusters),
        alarms_processed: state.stats.alarms_processed + length(alarms)
    }

    {:reply, {:ok, result}, %{state | stats: new_stats}}
  end

  ## Private Functions

  defp do_correlate(alarm, recent_alarms, _opts) do
    alarm_text = extract_text(alarm)
    alarm_embedding = compute_embedding(alarm_text)
    alarm_time = extract_timestamp(alarm)

    correlations =
      recent_alarms
      |> Enum.map(fn recent ->
        recent_text = extract_text(recent)
        recent_embedding = compute_embedding(recent_text)
        recent_time = extract_timestamp(recent)

        # Compute correlation scores
        text_sim = cosine_similarity(alarm_embedding, recent_embedding)
        temporal_sim = temporal_similarity(alarm_time, recent_time)
        category_sim = category_similarity(alarm, recent)

        # Weighted combination
        total_score =
          text_sim * 0.4 +
            temporal_sim * 0.3 +
            category_sim * 0.3

        %{
          alarm: recent,
          scores: %{
            text: Float.round(text_sim, 3),
            temporal: Float.round(temporal_sim, 3),
            category: Float.round(category_sim, 3),
            total: Float.round(total_score, 3)
          },
          correlation_type: infer_correlation_type(text_sim, temporal_sim, category_sim)
        }
      end)
      |> Enum.filter(&(&1.scores.total >= @min_correlation_score))
      |> Enum.sort_by(& &1.scores.total, :desc)

    # Group correlations by type
    groups = group_correlations(correlations)

    %{
      correlations: correlations,
      groups: groups,
      alarm_analyzed: alarm,
      correlated_at: DateTime.utc_now()
    }
  end

  defp do_cluster(alarms, _opts) when length(alarms) < 2 do
    %{
      clusters: [%{id: 1, alarms: alarms, centroid: nil}],
      unclustered: [],
      clustered_at: DateTime.utc_now()
    }
  end

  defp do_cluster(alarms, _opts) do
    # Build similarity matrix
    embeddings =
      alarms
      |> Enum.map(fn alarm ->
        text = extract_text(alarm)
        {alarm, compute_embedding(text)}
      end)

    # Simple agglomerative clustering
    clusters = agglomerative_cluster(embeddings, @text_similarity_threshold)

    # Label clusters
    labeled_clusters =
      clusters
      |> Enum.with_index(1)
      |> Enum.map(fn {cluster_alarms, idx} ->
        %{
          id: idx,
          alarms: cluster_alarms,
          size: length(cluster_alarms),
          dominant_category: find_dominant_category(cluster_alarms),
          time_span: compute_time_span(cluster_alarms)
        }
      end)

    %{
      clusters: labeled_clusters,
      total_alarms: length(alarms),
      cluster_count: length(labeled_clusters),
      clustered_at: DateTime.utc_now()
    }
  end

  # Text extraction
  defp extract_text(alarm) do
    message = Map.get(alarm, :message, "")
    description = Map.get(alarm, :description, "")
    type = to_string(Map.get(alarm, :type, ""))
    source = to_string(Map.get(alarm, :source, ""))

    "#{message} #{description} #{type} #{source}"
    |> String.downcase()
    |> String.trim()
  end

  # Simple TF-IDF style embedding
  defp compute_embedding(text) do
    words =
      text
      |> String.split(~r/\W+/, trim: true)
      |> Enum.uniq()

    # Create sparse embedding based on keyword weights
    embedding =
      @keyword_weights
      |> Enum.map(fn {keyword, info} ->
        if keyword in words or Enum.any?(info.related, &(&1 in words)) do
          info.weight
        else
          0.0
        end
      end)

    # Add category presence indicators
    categories = [:security, :access, :detection, :system, :power, :safety, :environmental]

    category_features =
      categories
      |> Enum.map(fn cat ->
        if Enum.any?(@keyword_weights, fn {k, v} ->
             v.category == cat and (k in words or Enum.any?(v.related, &(&1 in words)))
           end) do
          1.0
        else
          0.0
        end
      end)

    embedding ++ category_features
  end

  # Cosine similarity between embeddings
  defp cosine_similarity(emb1, emb2) when length(emb1) != length(emb2), do: 0.0

  defp cosine_similarity(emb1, emb2) do
    zipped = Enum.zip(emb1, emb2)

    dot_product =
      zipped
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.sum(Enum.map(emb1, &(&1 * &1))))
    magnitude2 = :math.sqrt(Enum.sum(Enum.map(emb2, &(&1 * &1))))

    if magnitude1 == 0 or magnitude2 == 0 do
      0.0
    else
      dot_product / (magnitude1 * magnitude2)
    end
  end

  # Temporal similarity (closer in time = higher score)
  defp temporal_similarity(time1, time2) do
    diff_ms = abs(DateTime.diff(time1, time2, :millisecond))

    if diff_ms > @temporal_window_ms do
      0.0
    else
      1.0 - diff_ms / @temporal_window_ms
    end
  end

  # Category similarity
  defp category_similarity(alarm1, alarm2) do
    cat1 = infer_category(alarm1)
    cat2 = infer_category(alarm2)

    if cat1 == cat2 and cat1 != :unknown do
      1.0
    else
      # Related categories get partial score
      related_categories = %{
        security: [:access, :detection],
        safety: [:environmental, :power],
        system: [:power]
      }

      related1 = Map.get(related_categories, cat1, [])
      related2 = Map.get(related_categories, cat2, [])

      if cat2 in related1 or cat1 in related2 do
        0.5
      else
        0.0
      end
    end
  end

  defp infer_category(alarm) do
    extracted = extract_text(alarm)
    text = extracted |> String.downcase()

    @keyword_weights
    |> Enum.find_value(:unknown, fn {keyword, info} ->
      if String.contains?(text, keyword) do
        info.category
      else
        nil
      end
    end)
  end

  defp infer_correlation_type(text_sim, temporal_sim, _category_sim) do
    cond do
      text_sim > 0.8 and temporal_sim > 0.8 -> :duplicate
      text_sim > 0.6 and temporal_sim > 0.6 -> :related
      temporal_sim > 0.9 -> :cascade
      text_sim > 0.7 -> :similar
      true -> :loose
    end
  end

  defp group_correlations(correlations) do
    correlations
    |> Enum.group_by(& &1.correlation_type)
    |> Enum.map(fn {type, corrs} ->
      %{type: type, count: length(corrs), avg_score: avg_score(corrs)}
    end)
  end

  defp avg_score(correlations) do
    if correlations == [] do
      0.0
    else
      total = Enum.sum(Enum.map(correlations, & &1.scores.total))
      Float.round(total / Enum.count(correlations), 3)
    end
  end

  # Simple agglomerative clustering
  defp agglomerative_cluster(alarm_embeddings, threshold) do
    # Start with each alarm in its own cluster
    initial_clusters =
      alarm_embeddings
      |> Enum.map(fn {alarm, _emb} -> [alarm] end)

    merge_clusters(initial_clusters, alarm_embeddings, threshold)
  end

  defp merge_clusters(clusters, _alarm_embeddings, _threshold) when length(clusters) <= 1 do
    clusters
  end

  defp merge_clusters(clusters, alarm_embeddings, threshold) do
    # Find closest cluster pair
    embeddings_map =
      alarm_embeddings
      |> Enum.into(%{}, fn {alarm, emb} -> {alarm, emb} end)

    cluster_pairs =
      for {c1, i} <- Enum.with_index(clusters),
          {c2, j} <- Enum.with_index(clusters),
          i < j do
        sim = cluster_similarity(c1, c2, embeddings_map)
        {i, j, sim}
      end

    case Enum.max_by(cluster_pairs, fn {_, _, sim} -> sim end, fn -> nil end) do
      nil ->
        clusters

      {i, j, sim} when sim >= threshold ->
        # Merge clusters i and j
        merged = Enum.at(clusters, i) ++ Enum.at(clusters, j)

        new_clusters =
          clusters
          |> Enum.with_index()
          |> Enum.reject(fn {_, idx} -> idx == i or idx == j end)
          |> Enum.map(fn {c, _} -> c end)
          |> Kernel.++([merged])

        merge_clusters(new_clusters, alarm_embeddings, threshold)

      _ ->
        clusters
    end
  end

  defp cluster_similarity(cluster1, cluster2, embeddings_map) do
    similarities =
      for a1 <- cluster1, a2 <- cluster2 do
        emb1 = Map.get(embeddings_map, a1, [])
        emb2 = Map.get(embeddings_map, a2, [])
        cosine_similarity(emb1, emb2)
      end

    if similarities == [], do: 0.0, else: Enum.sum(similarities) / Enum.count(similarities)
  end

  defp find_dominant_category(alarms) do
    alarms
    |> Enum.map(&infer_category/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_cat, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end

  defp compute_time_span(alarms) do
    timestamps = Enum.map(alarms, &extract_timestamp/1)

    if length(timestamps) < 2 do
      0
    else
      min_time = Enum.min(timestamps, DateTime)
      max_time = Enum.max(timestamps, DateTime)
      DateTime.diff(max_time, min_time, :second)
    end
  end

  defp extract_timestamp(alarm) do
    Map.get(alarm, :timestamp, DateTime.utc_now())
  end

  defp emit_telemetry(operation, latency_us, result_count) do
    :telemetry.execute(
      [:indrajaal, :ml, :alarm_correlator, operation],
      %{latency_us: latency_us, result_count: result_count},
      %{model: "alarm_correlator", version: "1.0.0"}
    )
  end
end
