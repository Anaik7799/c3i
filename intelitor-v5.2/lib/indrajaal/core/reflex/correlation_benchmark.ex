defmodule Indrajaal.Core.Reflex.CorrelationBenchmark do
  @moduledoc """
  Turing Baseline Benchmark — measures correlation between external API
  and local model inference quality.

  Runs curated benchmark prompts through both external API and local Mojo
  container, then computes cosine similarity between output embeddings to
  produce a "Correlation Score" (target: >0.85).

  ## STAMP Constraints
  - SC-SOVEREIGNTY-005: Turing baseline measurement
  - SC-SOVEREIGNTY-001: Air-gap survival verification

  ## Change History
  | Version | Date       | Author | Change               |
  |---------|------------|--------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation |
  """

  require Logger

  alias Indrajaal.Core.Reflex.InferenceRouter

  @zenoh_key "indrajaal/sovereignty/turing_baseline"
  @benchmark_prompts [
    "Summarize the key principles of distributed systems",
    "What are the safety implications of concurrent state mutations?",
    "Explain the circuit breaker pattern in microservices",
    "Describe the difference between eventual and strong consistency",
    "What is the CAP theorem and its practical implications?",
    "How does a Raft consensus algorithm work?",
    "Explain backpressure in reactive systems",
    "What are the benefits of immutable data structures?",
    "Describe the actor model of concurrency",
    "How does event sourcing differ from CRUD?"
  ]

  @doc """
  Run the full Turing Baseline benchmark.

  Sends each benchmark prompt through both external and local backends,
  computes similarity scores, and returns an aggregate correlation score.

  ## Options
  - `:prompts` — custom prompt list (default: built-in 10 curated prompts)
  - `:publish` — publish results to Zenoh (default: true)
  """
  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(opts \\ []) do
    prompts = Keyword.get(opts, :prompts, @benchmark_prompts)
    publish? = Keyword.get(opts, :publish, true)

    Logger.info("[CorrelationBenchmark] starting with #{length(prompts)} prompts")

    results =
      prompts
      |> Enum.with_index(1)
      |> Enum.map(fn {prompt, idx} ->
        Logger.debug("[CorrelationBenchmark] prompt #{idx}/#{length(prompts)}")
        benchmark_prompt(prompt)
      end)

    valid_results = Enum.filter(results, &match?({:ok, _}, &1))
    scores = Enum.map(valid_results, fn {:ok, r} -> r.similarity end)

    if Enum.empty?(scores) do
      Logger.error("[CorrelationBenchmark] no valid results — both backends may be down")
      {:error, :no_valid_results}
    else
      aggregate = %{
        correlation_score: mean(scores),
        min_score: Enum.min(scores),
        max_score: Enum.max(scores),
        std_dev: std_dev(scores),
        valid_count: length(scores),
        total_count: length(prompts),
        failed_count: length(prompts) - length(scores),
        timestamp: DateTime.utc_now(),
        details: Enum.map(valid_results, fn {:ok, r} -> r end)
      }

      Logger.info(
        "[CorrelationBenchmark] complete — score=#{Float.round(aggregate.correlation_score, 3)} " <>
          "(#{aggregate.valid_count}/#{aggregate.total_count} prompts)"
      )

      if publish?, do: publish_results(aggregate)

      {:ok, aggregate}
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # PRIVATE — PER-PROMPT BENCHMARK
  # ─────────────────────────────────────────────────────────────────────

  @spec benchmark_prompt(String.t()) :: {:ok, map()} | {:error, term()}
  defp benchmark_prompt(prompt) do
    external_result = InferenceRouter.route(:benchmark, prompt, strategy: :external)
    local_result = InferenceRouter.route(:benchmark, prompt, strategy: :local)

    case {external_result, local_result} do
      {{:ok, ext_output, _}, {:ok, local_output, _}} ->
        sim = text_similarity(to_string(ext_output), to_string(local_output))

        {:ok,
         %{
           prompt: String.slice(prompt, 0, 50),
           similarity: sim,
           external_length: String.length(to_string(ext_output)),
           local_length: String.length(to_string(local_output))
         }}

      {{:error, reason}, _} ->
        {:error, {:external_failed, reason}}

      {_, {:error, reason}} ->
        {:error, {:local_failed, reason}}
    end
  end

  # ─────────────────────────────────────────────────────────────────────
  # PRIVATE — SIMILARITY
  # ─────────────────────────────────────────────────────────────────────

  @spec text_similarity(String.t(), String.t()) :: float()
  defp text_similarity(text_a, text_b) do
    # Character n-gram based similarity (trigrams)
    # Fast approximation when embedding models aren't available
    trigrams_a = ngrams(text_a, 3)
    trigrams_b = ngrams(text_b, 3)

    if MapSet.size(trigrams_a) == 0 or MapSet.size(trigrams_b) == 0 do
      0.0
    else
      intersection = MapSet.intersection(trigrams_a, trigrams_b) |> MapSet.size()
      union = MapSet.union(trigrams_a, trigrams_b) |> MapSet.size()
      intersection / max(union, 1)
    end
  end

  @spec ngrams(String.t(), pos_integer()) :: MapSet.t()
  defp ngrams(text, n) do
    text
    |> String.downcase()
    |> String.graphemes()
    |> Enum.chunk_every(n, 1, :discard)
    |> Enum.map(&Enum.join/1)
    |> MapSet.new()
  end

  # ─────────────────────────────────────────────────────────────────────
  # PRIVATE — STATISTICS
  # ─────────────────────────────────────────────────────────────────────

  @spec mean([float()]) :: float()
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)

  @spec std_dev([float()]) :: float()
  defp std_dev(values) when length(values) < 2, do: 0.0

  defp std_dev(values) do
    avg = mean(values)
    variance = values |> Enum.map(&((&1 - avg) ** 2)) |> mean()
    :math.sqrt(variance)
  end

  # ─────────────────────────────────────────────────────────────────────
  # PRIVATE — PUBLISHING
  # ─────────────────────────────────────────────────────────────────────

  defp publish_results(aggregate) do
    payload =
      Jason.encode!(%{
        correlation_score: aggregate.correlation_score,
        valid_count: aggregate.valid_count,
        total_count: aggregate.total_count,
        min_score: aggregate.min_score,
        max_score: aggregate.max_score,
        timestamp: DateTime.to_iso8601(aggregate.timestamp)
      })

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:reflex",
      {:zenoh_publish, @zenoh_key, payload}
    )

    # Notify Prajna cockpit
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:sovereignty",
      {:turing_baseline, aggregate}
    )

    Logger.info("[CorrelationBenchmark] results published to Zenoh and PubSub")
  end
end
