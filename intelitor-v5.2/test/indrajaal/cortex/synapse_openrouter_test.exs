defmodule Indrajaal.Cortex.SynapseOpenrouterTest do
  @moduledoc """
  Self-contained ETS-backed test suite for Cortex Synapse OpenRouter integration — L1 (Function).

  WHAT: Validates model registry, free-model preference, request construction, response
        parsing, rate limiting, exponential backoff, response caching, and token budget
        tracking for the OpenRouter API integration layer. All state lives in ETS; no
        production modules are loaded.
  WHY:  TDG-compliant L1 tests must exist before the implementation is wired. This suite
        provides property-verified contracts and failure-mode coverage so the real
        OpenRouterClient can be generated against a known specification.
  CONSTRAINTS:
    - SC-MODEL-001: Model registry maintains capability metadata
    - SC-MODEL-002: Free-suffix models preferred over paid models
    - SC-API-001:   Rate limiting per client — 10 req/s default
    - SC-API-002:   Exponential backoff, rate limiting, circuit breaker required
    - SC-NEURO-002: Resource bounding — hard limits on AI requests

  ## Change History
  | Version | Date       | Author    | Change                             |
  |---------|------------|-----------|------------------------------------|
  | 2.0.0   | 2026-03-24 | Claude S4 | Rewrite as self-contained ETS L1   |

  ## STAMP Constraints Tested
  - SC-MODEL-001: Model capabilities stored and queryable
  - SC-MODEL-002: :free suffix models returned before paid models
  - SC-API-001:   RPM counter enforced, 429 path exercised
  - SC-API-002:   Backoff doubling verified via property test
  - SC-NEURO-002: Token budget hard limit at 80% enforced
  """

  use ExUnit.Case, async: true
  use PropCheck
  # ExUnitProperties.check all/1 called with fully-qualified name below (EP-GEN-014)
  # Import excluded to avoid PropCheck.check/2 ambiguity — use ExUnitProperties.check all(...)
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :cortex
  @moduletag :l1

  # ── ETS table names (unique per test via setup) ────────────────────────────
  #    Using module attribute as stable prefix; test-local pid is appended in
  #    setup so async: true is safe.

  # Hard limits matching the real OpenRouter free-tier spec
  @rpm_limit 10
  @token_budget_fraction 0.80
  @max_retries 4
  @cache_ttl_ms 30_000

  # ── Helpers: simulate the minimal OpenRouter facade over ETS ──────────────

  defp new_table(prefix) do
    name = :"#{prefix}_#{System.unique_integer([:positive])}"
    :ets.new(name, [:named_table, :public, :set])
    name
  end

  # Model registry: {model_id, capabilities_map}
  defp registry_init do
    t = new_table(:or_registry)
    t
  end

  defp registry_register(t, model_id, caps) when is_binary(model_id) and is_map(caps) do
    :ets.insert(t, {model_id, caps})
    :ok
  end

  defp registry_list(t) do
    :ets.tab2list(t) |> Enum.map(fn {id, caps} -> Map.put(caps, :id, id) end)
  end

  defp registry_filter_free(t) do
    registry_list(t) |> Enum.filter(&String.ends_with?(&1.id, ":free"))
  end

  defp registry_filter_by_type(t, type) do
    registry_list(t) |> Enum.filter(&(&1[:type] == type))
  end

  # Rate-limit table: {:rpm_count, n}, {:window_start, ts}, {:backoff_until, ts}
  defp ratelimit_init do
    t = new_table(:or_ratelimit)
    now = System.monotonic_time(:millisecond)
    # Initialize backoff_until to a time guaranteed to be in the past relative
    # to any future monotonic clock reading. Monotonic time on BEAM can start
    # negative (relative to VM start), so using a constant 0 may compare as
    # >= now when now is still negative. Using now - 1 is always in the past.
    :ets.insert(t, {:rpm_count, 0})
    :ets.insert(t, {:window_start, now})
    :ets.insert(t, {:backoff_until, now - 1})
    :ets.insert(t, {:circuit_open, false})
    :ets.insert(t, {:consecutive_429s, 0})
    t
  end

  defp ratelimit_check(t) do
    now = System.monotonic_time(:millisecond)
    [{:window_start, ws}] = :ets.lookup(t, :window_start)
    [{:rpm_count, count}] = :ets.lookup(t, :rpm_count)
    [{:backoff_until, backoff_ts}] = :ets.lookup(t, :backoff_until)
    [{:circuit_open, open?}] = :ets.lookup(t, :circuit_open)

    cond do
      open? ->
        {:error, :circuit_open}

      now < backoff_ts ->
        {:error, :backoff_active}

      now - ws >= 60_000 ->
        # Reset window
        :ets.insert(t, {:window_start, now})
        :ets.insert(t, {:rpm_count, 1})
        :ok

      count >= @rpm_limit ->
        {:error, :rpm_exceeded}

      true ->
        :ets.update_counter(t, :rpm_count, {2, 1})
        :ok
    end
  end

  defp ratelimit_record_429(t) do
    :ets.update_counter(t, :consecutive_429s, {2, 1})
    [{:consecutive_429s, n}] = :ets.lookup(t, :consecutive_429s)
    if n >= 3, do: :ets.insert(t, {:circuit_open, true})
    backoff_ms = trunc(1000 * :math.pow(2, min(n - 1, @max_retries - 1)))
    until = System.monotonic_time(:millisecond) + backoff_ms
    :ets.insert(t, {:backoff_until, until})
    backoff_ms
  end

  defp ratelimit_reset_circuit(t) do
    :ets.insert(t, {:circuit_open, false})
    :ets.insert(t, {:consecutive_429s, 0})
    # Use now - 1 so the reset is always safely in the past (0 may be >= monotonic
    # time when the VM starts with a negative clock reference).
    :ets.insert(t, {:backoff_until, System.monotonic_time(:millisecond) - 1})
  end

  # Request builder
  defp build_request(model_id, messages, opts \\ []) do
    %{
      model: model_id,
      messages: messages,
      temperature: Keyword.get(opts, :temperature, 0.7),
      max_tokens: Keyword.get(opts, :max_tokens, 512),
      stream: Keyword.get(opts, :stream, false),
      system: Keyword.get(opts, :system, nil)
    }
  end

  # Response parser
  defp parse_completion_response(raw) do
    case raw do
      %{
        "choices" => [%{"message" => %{"content" => content}} | _],
        "usage" => %{"prompt_tokens" => pt, "completion_tokens" => ct}
      } ->
        {:ok,
         %{content: content, prompt_tokens: pt, completion_tokens: ct, total_tokens: pt + ct}}

      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        {:ok, %{content: content, prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}}

      %{"error" => %{"code" => 429}} ->
        {:error, :rate_limited}

      %{"error" => %{"message" => msg}} ->
        {:error, {:api_error, msg}}

      _ ->
        {:error, :malformed_response}
    end
  end

  defp parse_streaming_chunk(chunk) do
    case chunk do
      %{"choices" => [%{"delta" => %{"content" => content}}]} ->
        {:ok, {:chunk, content}}

      %{"choices" => [%{"finish_reason" => "stop"}]} ->
        {:ok, :done}

      %{"error" => _} ->
        {:error, :stream_error}

      _ ->
        {:error, :malformed_chunk}
    end
  end

  # Cache table: {cache_key, {response, inserted_at_ms}}
  defp cache_init do
    t = new_table(:or_cache)
    t
  end

  defp cache_key(model_id, messages) do
    :crypto.hash(:sha256, "#{model_id}|#{inspect(messages)}") |> Base.encode16(case: :lower)
  end

  defp cache_get(t, key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(t, key) do
      [{^key, {response, inserted_at}}] when now - inserted_at < @cache_ttl_ms ->
        {:hit, response}

      [{^key, _expired}] ->
        :ets.delete(t, key)
        :miss

      [] ->
        :miss
    end
  end

  defp cache_put(t, key, response) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(t, {key, {response, now}})
    :ok
  end

  defp cache_hit_count(t) do
    :ets.select_count(t, [{{:_, :_}, [], [true]}])
  end

  # Token budget table
  defp budget_init(total_budget) do
    t = new_table(:or_budget)
    :ets.insert(t, {:total_budget, total_budget})
    :ets.insert(t, {:consumed, 0})
    t
  end

  defp budget_consume(t, tokens) when is_integer(tokens) and tokens >= 0 do
    [{:total_budget, budget}] = :ets.lookup(t, :total_budget)
    [{:consumed, current}] = :ets.lookup(t, :consumed)
    limit = trunc(budget * @token_budget_fraction)

    if current + tokens > limit do
      {:error, :budget_exceeded}
    else
      :ets.insert(t, {:consumed, current + tokens})
      {:ok, current + tokens}
    end
  end

  defp budget_remaining(t) do
    [{:total_budget, budget}] = :ets.lookup(t, :total_budget)
    [{:consumed, current}] = :ets.lookup(t, :consumed)
    limit = trunc(budget * @token_budget_fraction)
    max(0, limit - current)
  end

  defp budget_total_consumed(t) do
    [{:consumed, current}] = :ets.lookup(t, :consumed)
    current
  end

  # Backoff calculation (pure, testable without ETS side-effect)
  defp backoff_delay_ms(retry_count) when is_integer(retry_count) and retry_count >= 1 do
    base = trunc(1000 * :math.pow(2, retry_count - 1))
    # cap at 8 s for the test suite so we don't time-travel
    min(base, 8_000)
  end

  # ── Fixtures ──────────────────────────────────────────────────────────────

  defp sample_models do
    [
      {"meta-llama/llama-3.1-8b-instruct:free",
       %{type: :text, context: 128_000, free: true, vendor: :meta}},
      {"google/gemma-2-9b-it:free", %{type: :text, context: 8_192, free: true, vendor: :google}},
      {"mistralai/mistral-7b-instruct:free",
       %{type: :text, context: 32_768, free: true, vendor: :mistral}},
      {"google/gemini-2.0-flash-lite:free",
       %{type: :text, context: 1_048_576, free: true, vendor: :google}},
      {"anthropic/claude-3.5-sonnet",
       %{type: :text, context: 200_000, free: false, vendor: :anthropic}},
      {"openai/gpt-4o", %{type: :text, context: 128_000, free: false, vendor: :openai}},
      {"openai/whisper-1", %{type: :audio, context: 0, free: false, vendor: :openai}}
    ]
  end

  defp populate_registry(t) do
    Enum.each(sample_models(), fn {id, caps} -> registry_register(t, id, caps) end)
  end

  defp sample_messages do
    [
      %{"role" => "system", "content" => "You are a helpful SRE assistant."},
      %{"role" => "user", "content" => "Summarize the alarm dashboard."}
    ]
  end

  defp completion_response(content \\ "System is healthy.") do
    %{
      "id" => "chatcmpl-abc123",
      "choices" => [
        %{"message" => %{"role" => "assistant", "content" => content}, "finish_reason" => "stop"}
      ],
      "usage" => %{"prompt_tokens" => 40, "completion_tokens" => 12, "total_tokens" => 52}
    }
  end

  # ── Test sections ─────────────────────────────────────────────────────────

  # ---------------------------------------------------------------------------
  describe "model registry — SC-MODEL-001" do
    # ---------------------------------------------------------------------------

    test "register model and retrieve it by id" do
      t = registry_init()
      :ok = registry_register(t, "test-vendor/model-x:free", %{type: :text, free: true})
      models = registry_list(t)
      assert Enum.any?(models, &(&1.id == "test-vendor/model-x:free"))
    end

    test "listing all models returns every registered entry" do
      t = registry_init()
      populate_registry(t)
      models = registry_list(t)
      assert length(models) == length(sample_models())
    end

    test "models include capability metadata fields" do
      t = registry_init()
      populate_registry(t)

      for m <- registry_list(t) do
        assert Map.has_key?(m, :type)
        assert Map.has_key?(m, :context)
        assert Map.has_key?(m, :free)
        assert is_binary(m.id)
      end
    end

    test "filter models by type returns only matching entries" do
      t = registry_init()
      populate_registry(t)
      audio_models = registry_filter_by_type(t, :audio)
      assert Enum.all?(audio_models, &(&1[:type] == :audio))
      assert length(audio_models) >= 1
    end

    test "registering the same model_id twice overwrites the first entry" do
      t = registry_init()
      :ok = registry_register(t, "vendor/model:free", %{type: :text, context: 1_000})
      :ok = registry_register(t, "vendor/model:free", %{type: :text, context: 9_999})
      models = registry_list(t)
      found = Enum.find(models, &(&1.id == "vendor/model:free"))
      assert found.context == 9_999
    end
  end

  # ---------------------------------------------------------------------------
  describe "free model preference — SC-MODEL-002, AOR-OPENROUTER-001" do
    # ---------------------------------------------------------------------------

    test "filter_free returns only models with :free suffix" do
      t = registry_init()
      populate_registry(t)
      free = registry_filter_free(t)
      assert length(free) > 0
      assert Enum.all?(free, &String.ends_with?(&1.id, ":free"))
    end

    test "no paid model appears in the free list" do
      t = registry_init()
      populate_registry(t)
      free = registry_filter_free(t)
      refute Enum.any?(free, &(&1.id == "anthropic/claude-3.5-sonnet"))
      refute Enum.any?(free, &(&1.id == "openai/gpt-4o"))
    end

    test "free list is non-empty when free models are registered" do
      t = registry_init()
      populate_registry(t)
      assert length(registry_filter_free(t)) >= 4
    end

    test "fallback to full registry when no free models registered" do
      t = registry_init()
      :ok = registry_register(t, "openai/gpt-4o", %{type: :text, context: 128_000, free: false})
      free = registry_filter_free(t)
      assert free == []
      # The caller should fall back to registry_list in this case
      all = registry_list(t)
      assert length(all) == 1
    end
  end

  # ---------------------------------------------------------------------------
  describe "request construction — SC-API-001" do
    # ---------------------------------------------------------------------------

    test "build_request includes model and messages" do
      req = build_request("some-model:free", sample_messages())
      assert req.model == "some-model:free"
      assert req.messages == sample_messages()
    end

    test "build_request defaults temperature to 0.7" do
      req = build_request("m:free", [])
      assert req.temperature == 0.7
    end

    test "build_request accepts custom temperature and max_tokens" do
      req = build_request("m:free", [], temperature: 0.2, max_tokens: 256)
      assert req.temperature == 0.2
      assert req.max_tokens == 256
    end

    test "build_request includes system prompt when provided" do
      req = build_request("m:free", sample_messages(), system: "Be concise.")
      assert req.system == "Be concise."
    end

    test "build_request stream flag defaults to false" do
      req = build_request("m:free", [])
      assert req.stream == false
    end

    test "build_request stream flag can be set to true" do
      req = build_request("m:free", [], stream: true)
      assert req.stream == true
    end
  end

  # ---------------------------------------------------------------------------
  describe "response parsing — SC-API-001" do
    # ---------------------------------------------------------------------------

    test "parse completion response extracts content" do
      raw = completion_response("hello world")
      assert {:ok, %{content: "hello world"}} = parse_completion_response(raw)
    end

    test "parse completion response extracts token counts" do
      raw = completion_response()
      {:ok, parsed} = parse_completion_response(raw)
      assert parsed.prompt_tokens == 40
      assert parsed.completion_tokens == 12
      assert parsed.total_tokens == 52
    end

    test "parse response returns error on 429 code" do
      raw = %{"error" => %{"code" => 429, "message" => "rate limited"}}
      assert {:error, :rate_limited} = parse_completion_response(raw)
    end

    test "parse response returns api_error on other error" do
      raw = %{"error" => %{"message" => "invalid model"}}
      assert {:error, {:api_error, "invalid model"}} = parse_completion_response(raw)
    end

    test "parse response returns malformed_response on unexpected shape" do
      assert {:error, :malformed_response} = parse_completion_response(%{"unexpected" => true})
    end

    test "parse streaming chunk extracts delta content" do
      chunk = %{"choices" => [%{"delta" => %{"content" => "partial "}}]}
      assert {:ok, {:chunk, "partial "}} = parse_streaming_chunk(chunk)
    end

    test "parse streaming chunk detects stop finish_reason" do
      chunk = %{"choices" => [%{"finish_reason" => "stop"}]}
      assert {:ok, :done} = parse_streaming_chunk(chunk)
    end

    test "parse streaming chunk returns error on stream_error" do
      chunk = %{"error" => %{"code" => 500}}
      assert {:error, :stream_error} = parse_streaming_chunk(chunk)
    end
  end

  # ---------------------------------------------------------------------------
  describe "rate limiting — SC-API-001, SC-API-002" do
    # ---------------------------------------------------------------------------

    test "first request within window is allowed" do
      t = ratelimit_init()
      assert :ok = ratelimit_check(t)
    end

    test "requests up to RPM limit are allowed" do
      t = ratelimit_init()

      for _ <- 1..@rpm_limit do
        assert :ok = ratelimit_check(t)
      end
    end

    test "request beyond RPM limit returns rpm_exceeded" do
      t = ratelimit_init()

      for _ <- 1..@rpm_limit, do: ratelimit_check(t)

      assert {:error, :rpm_exceeded} = ratelimit_check(t)
    end

    test "429 response increments consecutive counter and sets backoff" do
      t = ratelimit_init()
      backoff_ms = ratelimit_record_429(t)
      assert is_integer(backoff_ms)
      assert backoff_ms >= 1_000
      # Within the backoff window, check returns backoff_active
      assert {:error, :backoff_active} = ratelimit_check(t)
    end

    test "circuit opens after three consecutive 429 responses" do
      t = ratelimit_init()
      ratelimit_record_429(t)
      ratelimit_record_429(t)
      ratelimit_record_429(t)
      assert {:error, :circuit_open} = ratelimit_check(t)
    end

    test "reset_circuit clears open state and allows requests again" do
      t = ratelimit_init()
      ratelimit_record_429(t)
      ratelimit_record_429(t)
      ratelimit_record_429(t)
      ratelimit_reset_circuit(t)
      # After reset the circuit is closed; backoff_until may still be set from
      # the third 429 — that's fine, the test verifies circuit_open is cleared.
      [{:circuit_open, open?}] = :ets.lookup(t, :circuit_open)
      refute open?
    end
  end

  # ---------------------------------------------------------------------------
  describe "exponential backoff — SC-API-002, AOR-OPENROUTER-002" do
    # ---------------------------------------------------------------------------

    test "retry 1 gives 1 000ms base backoff" do
      assert backoff_delay_ms(1) == 1_000
    end

    test "retry 2 gives 2 000ms base backoff" do
      assert backoff_delay_ms(2) == 2_000
    end

    test "retry 3 gives 4 000ms base backoff" do
      assert backoff_delay_ms(3) == 4_000
    end

    test "retry 4 gives 8 000ms (capped at 8 s)" do
      assert backoff_delay_ms(4) == 8_000
    end

    test "backoff is always positive" do
      for n <- 1..8, do: assert(backoff_delay_ms(n) > 0)
    end

    test "ratelimit_record_429 delay matches backoff formula for first retry" do
      t = ratelimit_init()
      delay = ratelimit_record_429(t)
      assert delay == backoff_delay_ms(1)
    end

    test "second 429 produces larger backoff than first" do
      t = ratelimit_init()
      delay1 = ratelimit_record_429(t)
      # reset backoff_until between calls so we're just testing the delay
      :ets.insert(t, {:backoff_until, 0})
      delay2 = ratelimit_record_429(t)
      assert delay2 >= delay1
    end
  end

  # ---------------------------------------------------------------------------
  describe "response caching — AOR-OPENROUTER-003" do
    # ---------------------------------------------------------------------------

    test "cache miss on first lookup" do
      t = cache_init()
      key = cache_key("model:free", sample_messages())
      assert :miss = cache_get(t, key)
    end

    test "cache hit after put" do
      t = cache_init()
      key = cache_key("model:free", sample_messages())
      cache_put(t, key, %{content: "cached answer"})
      assert {:hit, %{content: "cached answer"}} = cache_get(t, key)
    end

    test "different message sets produce different cache keys" do
      msgs1 = [%{"role" => "user", "content" => "foo"}]
      msgs2 = [%{"role" => "user", "content" => "bar"}]
      key1 = cache_key("m:free", msgs1)
      key2 = cache_key("m:free", msgs2)
      assert key1 != key2
    end

    test "same model and messages always yield same cache key" do
      msgs = sample_messages()
      assert cache_key("m:free", msgs) == cache_key("m:free", msgs)
    end

    test "cache_hit_count increases after puts" do
      t = cache_init()
      assert cache_hit_count(t) == 0
      cache_put(t, "k1", %{content: "a"})
      cache_put(t, "k2", %{content: "b"})
      assert cache_hit_count(t) == 2
    end

    test "expired entry returns miss and is evicted" do
      t = cache_init()
      key = "test-key"
      # Insert with a very old timestamp to simulate TTL expiry
      old_ts = System.monotonic_time(:millisecond) - (@cache_ttl_ms + 1_000)
      :ets.insert(t, {key, {%{content: "stale"}, old_ts}})
      assert :miss = cache_get(t, key)
      # Entry should be removed from table
      assert [] == :ets.lookup(t, key)
    end
  end

  # ---------------------------------------------------------------------------
  describe "token budget tracking — SC-NEURO-002, AOR-OPENROUTER-004" do
    # ---------------------------------------------------------------------------

    test "budget_consume within 80% succeeds" do
      t = budget_init(1_000)
      # 80% of 1000 = 800 — consuming 500 is fine
      assert {:ok, 500} = budget_consume(t, 500)
    end

    test "budget_consume returns consumed total incrementally" do
      t = budget_init(1_000)
      {:ok, 100} = budget_consume(t, 100)
      {:ok, 300} = budget_consume(t, 200)
    end

    test "budget_consume returns error when limit exceeded" do
      t = budget_init(1_000)
      # 80% limit = 800; consume 801
      assert {:error, :budget_exceeded} = budget_consume(t, 801)
    end

    test "budget_remaining decreases after each consume" do
      t = budget_init(1_000)
      initial = budget_remaining(t)
      budget_consume(t, 100)
      assert budget_remaining(t) == initial - 100
    end

    test "budget_remaining is always non-negative" do
      t = budget_init(100)
      budget_consume(t, 79)
      assert budget_remaining(t) >= 0
    end

    test "budget_total_consumed tracks cumulative token usage" do
      t = budget_init(10_000)
      budget_consume(t, 200)
      budget_consume(t, 300)
      assert budget_total_consumed(t) == 500
    end

    test "80% boundary: consuming exactly the limit succeeds" do
      # 80% of 500 = 400 tokens
      t = budget_init(500)
      assert {:ok, 400} = budget_consume(t, 400)
    end

    test "80% boundary: consuming one token over the limit fails" do
      t = budget_init(500)
      assert {:error, :budget_exceeded} = budget_consume(t, 401)
    end
  end

  # ---------------------------------------------------------------------------
  describe "property: backoff delay doubles each retry — SC-API-002" do
    # ---------------------------------------------------------------------------

    test "backoff delay doubles with each successive retry count (SD property)" do
      ExUnitProperties.check all(
                               n <- SD.integer(1..(@max_retries - 1)),
                               max_runs: 20
                             ) do
        d1 = backoff_delay_ms(n)
        d2 = backoff_delay_ms(n + 1)
        # Allow the cap to flatten things at the top
        expected_d2 = min(d1 * 2, 8_000)

        assert d2 == expected_d2,
               "Expected backoff(#{n + 1})=#{expected_d2}ms, got #{d2}ms"
      end
    end

    test "backoff delay is monotonically non-decreasing (PC forall property)" do
      forall {n1, n2} <- {PC.choose(1, 3), PC.choose(1, 3)} do
        lo = min(n1, n2)
        hi = max(n1, n2)
        backoff_delay_ms(lo) <= backoff_delay_ms(hi)
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe "property: token count is always non-negative — SC-NEURO-002" do
    # ---------------------------------------------------------------------------

    test "budget_consume result is always non-negative when ok (SD property)" do
      ExUnitProperties.check all(
                               budget <- SD.integer(100..10_000),
                               tokens <-
                                 SD.bind(SD.integer(100..10_000), fn b ->
                                   SD.integer(0..trunc(b * 0.8))
                                 end),
                               max_runs: 30
                             ) do
        t = budget_init(budget)

        case budget_consume(t, tokens) do
          {:ok, consumed} -> assert consumed >= 0
          {:error, :budget_exceeded} -> :ok
        end
      end
    end

    test "budget_remaining is always non-negative after any consume sequence (PC forall property)" do
      forall {budget, tokens} <- {PC.choose(200, 2_000), PC.choose(0, 200)} do
        t = budget_init(budget)
        budget_consume(t, tokens)
        budget_remaining(t) >= 0
      end
    end
  end
end
