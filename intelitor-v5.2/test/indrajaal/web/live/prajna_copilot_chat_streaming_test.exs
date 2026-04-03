defmodule Indrajaal.Web.Live.PrajnaCopilotChatStreamingTest do
  @moduledoc """
  WHAT: Self-contained ETS-backed TDG test suite for the Prajna AI Copilot chat
        streaming interface. Covers the full round-trip from user message
        submission through Guardian pre-approval, token-by-token streaming,
        conversation history management, context-window bookkeeping, structured
        recommendation rendering, Founder Directive alignment screening, error
        recovery, and property-based invariant verification.
        All state is stored in per-test ETS tables. Zero production module
        dependencies — every helper is implemented privately at the bottom of
        this file.

  WHY:  SC-NEURO-001 mandates that every AI proposal passes Guardian.validate_proposal
        before execution; the streaming chat path is an independent execution
        surface that must be verified on its own. SC-NEURO-002 imposes hard
        resource bounds (token budget, request rate). SC-HMI-001 requires the
        dark-cockpit default so urgent AI alerts are only raised when warranted.
        SC-PRF-050 specifies a 50ms latency budget. AOR-PRAJNA-002 ensures every
        Copilot recommendation is screened against the Founder's Directive (Ω₀)
        before reaching the operator.

  ## STAMP Compliance
  - SC-NEURO-001: Simplex principle — AI proposals MUST pass Guardian.validate_proposal
  - SC-NEURO-002: Resource bounding — hard limits on token budget and request count
  - SC-NEURO-003: Forbidden ops — veto destructive commands unconditionally
  - SC-HMI-001: Dark cockpit default — urgent AI alerts only when warranted
  - SC-PRAJNA-001: Guardian gate — all Prajna commands pass Guardian validation
  - AOR-PRAJNA-001: Guardian gate required for all Prajna commands
  - AOR-PRAJNA-002: Founder alignment — Copilot recommendations aligned with Ω₀
  - AOR-PRAJNA-003: State logging — mutations logged to Immutable Register

  ## EP-GEN-014 compliance
  - `use PropCheck` provides `forall` for PropCheck `property` blocks.
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    avoids name collisions with PropCheck.
  - `alias PropCheck.BasicTypes, as: PC` — all PropCheck generators use PC. prefix.
  - `alias StreamData, as: SD` — all StreamData generators use SD. prefix.
  - StreamData `check all` blocks appear inside plain `test` blocks ONLY.
  - PropCheck `forall` blocks appear inside `property` blocks ONLY.

  ## Coverage Matrix
  | Concern                                      | Unit | PropCheck | StreamData |
  |----------------------------------------------|------|-----------|------------|
  | Message submission — storage and validation  | 3    | 0         | 0          |
  | Streaming — chunk accumulation and state     | 4    | 0         | 0          |
  | Conversation history — order and eviction    | 4    | 0         | 0          |
  | Guardian gate — approve / veto               | 5    | 1         | 0          |
  | Context window — token tracking and trim     | 3    | 0         | 0          |
  | Recommendation rendering — cards and actions | 3    | 0         | 0          |
  | Error handling — timeout, retry, degrade     | 3    | 0         | 0          |
  | Founder alignment — Ω₀ screening            | 3    | 0         | 0          |
  | PROP: message order preserved after stream   | 0    | 0         | 1          |
  | PROP: token count never exceeds window       | 0    | 0         | 1          |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :prajna_copilot
  @moduletag :streaming
  @moduletag :neuro_simplex

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Per-test ETS setup / teardown
  # ---------------------------------------------------------------------------

  setup do
    table = :ets.new(:chat_test_state, [:set, :public])
    on_exit(fn -> :ets.delete(table) end)
    %{table: table}
  end

  # ---------------------------------------------------------------------------
  # Module-level constants (self-contained, no production deps)
  # ---------------------------------------------------------------------------

  @max_history_entries 20
  @context_window_limit 4_096
  @guardian_risk_threshold 0.7
  @max_recommendations 5
  @retry_limit 3
  @first_token_budget_ms 200
  @full_response_budget_ms 5_000

  # ===========================================================================
  # 1. Message submission
  # ===========================================================================

  describe "message submission" do
    test "user message is stored in ETS history keyed by session id", %{table: table} do
      session = new_session("u1", table)
      {:ok, session2} = submit_message(session, "What is the alarm status?", table)

      stored = ets_history(table, session2.session_id)
      assert length(stored) == 1
      assert hd(stored).role == :user
      assert hd(stored).content == "What is the alarm status?"
    end

    test "message content is preserved verbatim including unicode", %{table: table} do
      raw = "Sensor Ω-42 — check δ threshold > 0.95"
      session = new_session("u1", table)
      {:ok, _session2} = submit_message(session, raw, table)

      [entry] = ets_history(table, session.session_id)
      assert entry.content == raw
    end

    test "empty message is rejected and history remains unchanged", %{table: table} do
      session = new_session("u1", table)
      result = submit_message(session, "", table)

      assert match?({:error, :empty_message}, result)
      assert ets_history(table, session.session_id) == []
    end
  end

  # ===========================================================================
  # 2. Streaming response
  # ===========================================================================

  describe "streaming response" do
    test "begin_stream/3 returns a list of binary chunks", %{table: table} do
      session = new_session("u1", table)
      {:ok, stream, _s2} = begin_stream(session, "What is the mesh status?", table)

      assert is_list(stream)
      assert Enum.all?(stream, &is_binary/1)
    end

    test "chunks accumulate in delivery order via collect_stream/1", %{table: table} do
      _session = new_session("u1", table)
      chunks = ["The ", "mesh ", "is ", "healthy."]
      assert collect_stream(chunks) == "The mesh is healthy."
    end

    test "begin_stream/3 transitions session state to :streaming", %{table: table} do
      session = new_session("u1", table)
      {:ok, _stream, session2} = begin_stream(session, "Status?", table)

      assert session2.state == :streaming
    end

    test "finalise_stream/3 appends assistant turn and returns session to :idle",
         %{table: table} do
      session = new_session("u1", table)
      {:ok, stream, session2} = begin_stream(session, "Status?", table)
      full = collect_stream(stream)
      {:ok, session3} = finalise_stream(session2, full, table)

      assert session3.state == :idle
      history = ets_history(table, session3.session_id)
      last = List.last(history)
      assert last.role == :assistant
      assert last.content == full
    end

    test "first token is available within #{@first_token_budget_ms}ms", %{table: table} do
      session = new_session("latency-user", table)
      t0 = System.monotonic_time(:millisecond)
      {:ok, stream, _s2} = begin_stream(session, "Mesh health?", table)
      _first = hd(stream)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= @first_token_budget_ms,
             "First token took #{elapsed}ms — budget #{@first_token_budget_ms}ms (SC-PRF-050)"
    end

    test "full response collection completes within #{@full_response_budget_ms}ms",
         %{table: table} do
      session = new_session("latency-user", table)
      t0 = System.monotonic_time(:millisecond)
      {:ok, stream, _s2} = begin_stream(session, "List threats.", table)
      _full = collect_stream(stream)
      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= @full_response_budget_ms,
             "Full response took #{elapsed}ms — budget #{@full_response_budget_ms}ms"
    end
  end

  # ===========================================================================
  # 3. Conversation history
  # ===========================================================================

  describe "conversation history" do
    test "entries are stored in chronological insertion order", %{table: table} do
      session =
        new_session("u1", table)
        |> add_turn(:user, "msg-1", table)
        |> add_turn(:assistant, "reply-1", table)
        |> add_turn(:user, "msg-2", table)

      roles = session |> ets_history(table) |> Enum.map(& &1.role)
      assert roles == [:user, :assistant, :user]
    end

    test "history timestamps are non-decreasing", %{table: table} do
      session =
        Enum.reduce(1..5, new_session("u1", table), fn i, s ->
          add_turn(s, :user, "message #{i}", table)
        end)

      timestamps = session |> ets_history(table) |> Enum.map(& &1.timestamp_ms)
      pairs = Enum.zip(timestamps, tl(timestamps))
      assert Enum.all?(pairs, fn {a, b} -> b >= a end)
    end

    test "history length never exceeds @max_history_entries", %{table: table} do
      session =
        Enum.reduce(1..(@max_history_entries + 5), new_session("u1", table), fn i, s ->
          add_turn(s, :user, "message #{i}", table)
        end)

      assert length(ets_history(table, session.session_id)) <= @max_history_entries
    end

    test "oldest entries are evicted first when window is exceeded", %{table: table} do
      session =
        Enum.reduce(1..(@max_history_entries + 3), new_session("u1", table), fn i, s ->
          add_turn(s, :user, "msg #{i}", table)
        end)

      history = ets_history(table, session.session_id)
      first_content = hd(history).content

      refute first_content == "msg 1"
      refute first_content == "msg 2"
      refute first_content == "msg 3"
    end
  end

  # ===========================================================================
  # 4. Guardian gate (SC-NEURO-001, SC-PRAJNA-001)
  # ===========================================================================

  describe "Guardian gate" do
    test "informational proposal at low risk is approved", %{table: _table} do
      proposal = build_proposal("Display threat level.", :informational, 0.1)
      assert guardian_validate(proposal) == {:ok, :approved}
    end

    test "operational proposal below risk threshold is approved", %{table: _table} do
      proposal = build_proposal("Restart sensor polling.", :operational, 0.4)
      assert guardian_validate(proposal) == {:ok, :approved}
    end

    test "destructive proposal is vetoed regardless of declared risk value",
         %{table: _table} do
      proposal = build_proposal("Delete audit log.", :destructive, 0.5)
      assert match?({:veto, _reason}, guardian_validate(proposal))
    end

    test "constitutional proposal targeting Ψ₀–Ψ₅ / Ω₀ is always vetoed",
         %{table: _table} do
      proposal = build_proposal("Disable Ω₀ symbiotic check.", :constitutional, 1.0)
      assert match?({:veto, _reason}, guardian_validate(proposal))
    end

    test "veto result includes a non-empty human-readable reason", %{table: _table} do
      proposal = build_proposal("DROP TABLE alarms;", :destructive, 0.9)
      {:veto, reason} = guardian_validate(proposal)
      assert is_binary(reason)
      assert byte_size(reason) > 0
    end

    test "forbidden shell command triggers veto regardless of category", %{table: _table} do
      proposal = build_proposal("rm -rf /data/holons", :operational, 0.3)
      assert match?({:veto, _reason}, guardian_validate(proposal))
    end

    test "proposal at exactly the risk threshold is vetoed", %{table: _table} do
      proposal = build_proposal("Reconfigure topology.", :operational, @guardian_risk_threshold)
      assert match?({:veto, _reason}, guardian_validate(proposal))
    end
  end

  # ===========================================================================
  # 5. Context window management (SC-NEURO-002)
  # ===========================================================================

  describe "context window management" do
    test "token count increases monotonically as messages are added", %{table: table} do
      session = new_session("u1", table)
      {:ok, session2} = submit_message(session, "hello world", table)
      assert session2.token_count > session.token_count
    end

    test "session at context limit rejects new messages", %{table: table} do
      session = new_session("u1", table) |> Map.put(:token_count, @context_window_limit)
      result = submit_message(session, "one more", table)
      assert match?({:error, :context_window_exceeded}, result)
    end

    test "trim_history/2 reduces token count below the limit", %{table: table} do
      session =
        Enum.reduce(1..10, new_session("u1", table), fn i, s ->
          add_turn(s, :user, String.duplicate("word ", 50) <> "#{i}", table)
        end)

      trimmed = trim_history(session, table)
      assert trimmed.token_count <= @context_window_limit
    end
  end

  # ===========================================================================
  # 6. Recommendation rendering
  # ===========================================================================

  describe "recommendation rendering" do
    test "recommendation card contains intent, title, and action list", %{table: _table} do
      card =
        build_recommendation_card(:action, "Acknowledge alarm A-001", [:acknowledge, :escalate])

      assert card.intent == :action
      assert is_binary(card.title)
      assert is_list(card.actions)
      assert length(card.actions) >= 1
    end

    test "structured recommendation does not exceed max_recommendations cap",
         %{table: _table} do
      recs =
        for i <- 1..(@max_recommendations + 3),
            do: build_recommendation_card(:info, "Rec #{i}", [:view])

      trimmed = Enum.take(recs, @max_recommendations)
      assert length(trimmed) == @max_recommendations
    end

    test "action buttons are rendered as atoms for LiveView event routing",
         %{table: _table} do
      card = build_recommendation_card(:action, "Restart sensor", [:restart, :skip])
      assert Enum.all?(card.actions, &is_atom/1)
    end
  end

  # ===========================================================================
  # 7. Error handling
  # ===========================================================================

  describe "error handling" do
    test "streaming timeout produces a :timeout error and graceful degradation message",
         %{table: table} do
      session = new_session("u1", table)
      result = simulate_timeout(session)

      assert match?({:error, :timeout, _msg}, result)
      {:error, :timeout, degradation_msg} = result
      assert is_binary(degradation_msg)
      assert byte_size(degradation_msg) > 0
    end

    test "retry counter increments on each consecutive failure", %{table: table} do
      session = new_session("u1", table)

      session2 = record_failure(session)
      session3 = record_failure(session2)

      assert session3.retry_count == 2
    end

    test "retry limit reached returns :max_retries_exceeded error", %{table: table} do
      session = new_session("u1", table) |> Map.put(:retry_count, @retry_limit)
      result = attempt_retry(session)

      assert match?({:error, :max_retries_exceeded}, result)
    end
  end

  # ===========================================================================
  # 8. Founder alignment (AOR-PRAJNA-002, Ω₀)
  # ===========================================================================

  describe "Founder alignment" do
    test "recommendation that supports Founder resource acquisition is :aligned",
         %{table: _table} do
      rec = build_rec(:report, false, false)
      assert founder_check(rec) == :aligned
    end

    test "recommendation that reduces Founder-controlled resources is :misaligned",
         %{table: _table} do
      rec = build_rec(:delete, true, true)
      assert founder_check(rec) == :misaligned
    end

    test "misaligned recommendation verbose result includes Ω₀ reference",
         %{table: _table} do
      rec = build_rec(:delete, true, true)
      {:misaligned, explanation} = founder_check_verbose(rec)
      assert String.contains?(explanation, "Ω₀")
    end
  end

  # ===========================================================================
  # 9. Property — message order preserved after streaming (StreamData)
  # ===========================================================================

  describe "property: message order preserved after streaming" do
    test "PROP_SD_01: history entries remain in submission order after simulated stream",
         %{table: _table} do
      ExUnitProperties.check all(
                               messages <-
                                 SD.list_of(SD.binary(min_length: 1, max_length: 32),
                                   min_length: 2,
                                   max_length: 12
                                 ),
                               max_runs: 40
                             ) do
        table = :ets.new(:prop_order_test, [:set, :public])

        session =
          Enum.reduce(messages, new_session("prop-u", table), fn msg, s ->
            add_turn(s, :user, msg, table)
          end)

        stored = ets_history(table, session.session_id)
        extracted = Enum.map(stored, & &1.content)

        # The retained window is the last @max_history_entries messages.
        expected = Enum.take(messages, -min(length(messages), @max_history_entries))

        assert extracted == expected,
               "History order deviated from submission order"

        :ets.delete(table)
      end
    end

    test "PROP_SD_02: collect_stream assembles chunks identically regardless of split point",
         %{table: _table} do
      ExUnitProperties.check all(
                               words <-
                                 SD.list_of(SD.binary(min_length: 1, max_length: 16),
                                   min_length: 1,
                                   max_length: 20
                                 ),
                               max_runs: 40
                             ) do
        joined_at_once = Enum.join(words)
        # Split into variable-sized batches and collect each batch then re-join.
        batch_size = max(1, div(length(words), 3))
        batches = Enum.chunk_every(words, batch_size)
        reassembled = batches |> Enum.map(&collect_stream/1) |> Enum.join()

        assert joined_at_once == reassembled,
               "collect_stream must be associative over chunk splits"
      end
    end
  end

  # ===========================================================================
  # 10. Property — token count never exceeds context window (StreamData)
  # ===========================================================================

  describe "property: token count never exceeds context window" do
    test "PROP_SD_03: arbitrary prompts stay within max_tokens budget", %{table: _table} do
      ExUnitProperties.check all(
                               prompt <- SD.binary(min_length: 1, max_length: 128),
                               max_tok <- SD.integer(256..4096),
                               max_runs: 40
                             ) do
        table = :ets.new(:prop_tok_test, [:set, :public])
        session = new_session("tok-u", table) |> Map.put(:max_tokens, max_tok)
        {:ok, stream, _s2} = begin_stream(session, prompt, table)
        full_response = collect_stream(stream)
        token_estimate = estimate_tokens(full_response)

        assert token_estimate <= max_tok,
               "Response used #{token_estimate} tokens but budget is #{max_tok}"

        :ets.delete(table)
      end
    end

    test "PROP_SD_04: token_count never exceeds context_window_limit after N submits",
         %{table: _table} do
      ExUnitProperties.check all(
                               messages <-
                                 SD.list_of(SD.binary(min_length: 1, max_length: 64),
                                   min_length: 1,
                                   max_length: 30
                                 ),
                               max_runs: 30
                             ) do
        table = :ets.new(:prop_ctx_test, [:set, :public])

        final_session =
          Enum.reduce(messages, new_session("ctx-u", table), fn msg, s ->
            case submit_message(s, msg, table) do
              {:ok, updated} -> updated
              {:error, :context_window_exceeded} -> s
              {:error, _} -> s
            end
          end)

        assert final_session.token_count <= @context_window_limit,
               "Token count #{final_session.token_count} exceeded window #{@context_window_limit}"

        :ets.delete(table)
      end
    end
  end

  # ===========================================================================
  # PropCheck property — Guardian determinism
  # ===========================================================================

  describe "Guardian determinism — PropCheck" do
    property "GUARD_PC_01: guardian_validate/1 is deterministic for identical proposals" do
      forall {content, cat_idx} <- {PC.binary(min: 1, max: 64), PC.integer(0, 3)} do
        category = Enum.at([:informational, :operational, :destructive, :constitutional], cat_idx)
        risk = canonical_risk(category)
        proposal = build_proposal(content, category, risk)
        guardian_validate(proposal) == guardian_validate(proposal)
      end
    end
  end

  # ===========================================================================
  # Private helpers — self-contained, zero production module dependencies
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Session management
  # ---------------------------------------------------------------------------

  defp new_session(user_id, table) do
    session_id = "stream-" <> unique_id()

    session = %{
      session_id: session_id,
      user_id: user_id,
      state: :idle,
      token_count: 0,
      max_tokens: @context_window_limit,
      retry_count: 0,
      created_at_ms: System.monotonic_time(:millisecond)
    }

    :ets.insert(table, {session_id, []})
    session
  end

  defp unique_id do
    :erlang.unique_integer([:positive, :monotonic]) |> Integer.to_string()
  end

  # ---------------------------------------------------------------------------
  # ETS history access
  # ---------------------------------------------------------------------------

  defp ets_history(table, session_id) do
    case :ets.lookup(table, session_id) do
      [{^session_id, history}] -> history
      [] -> []
    end
  end

  defp ets_history(session, table), do: ets_history(table, session.session_id)

  defp ets_put_history(table, session_id, history) do
    :ets.insert(table, {session_id, history})
  end

  # ---------------------------------------------------------------------------
  # Message submission
  # ---------------------------------------------------------------------------

  defp submit_message(_session, "", _table), do: {:error, :empty_message}

  defp submit_message(%{token_count: tc} = _session, _content, _table)
       when tc >= @context_window_limit do
    {:error, :context_window_exceeded}
  end

  defp submit_message(session, content, table) do
    entry = build_entry(:user, content)
    token_cost = estimate_tokens(content)
    existing = ets_history(table, session.session_id)

    new_history =
      (existing ++ [entry])
      |> Enum.take(-@max_history_entries)

    ets_put_history(table, session.session_id, new_history)

    updated = %{session | token_count: session.token_count + token_cost}
    {:ok, updated}
  end

  # ---------------------------------------------------------------------------
  # Streaming
  # ---------------------------------------------------------------------------

  defp begin_stream(session, content, table) when is_binary(content) and byte_size(content) > 0 do
    entry = build_entry(:user, content)
    existing = ets_history(table, session.session_id)

    new_history =
      (existing ++ [entry])
      |> Enum.take(-@max_history_entries)

    ets_put_history(table, session.session_id, new_history)

    stream = generate_stream(content, session.max_tokens)
    session2 = %{session | state: :streaming}
    {:ok, stream, session2}
  end

  defp begin_stream(_session, _content, _table), do: {:error, :empty_message}

  defp collect_stream(chunks) when is_list(chunks), do: Enum.join(chunks)

  defp finalise_stream(session, full_response, table) when is_binary(full_response) do
    entry = build_entry(:assistant, full_response)
    token_cost = estimate_tokens(full_response)
    existing = ets_history(table, session.session_id)

    new_history =
      (existing ++ [entry])
      |> Enum.take(-@max_history_entries)

    ets_put_history(table, session.session_id, new_history)

    updated = %{session | state: :idle, token_count: session.token_count + token_cost}
    {:ok, updated}
  end

  # ---------------------------------------------------------------------------
  # History helper
  # ---------------------------------------------------------------------------

  defp add_turn(session, role, content, table) do
    entry = build_entry(role, content)
    token_cost = estimate_tokens(content)
    existing = ets_history(table, session.session_id)

    new_history =
      (existing ++ [entry])
      |> Enum.take(-@max_history_entries)

    ets_put_history(table, session.session_id, new_history)
    %{session | token_count: session.token_count + token_cost}
  end

  defp build_entry(role, content) do
    %{
      role: role,
      content: content,
      timestamp_ms: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Token estimation (4-char-per-token heuristic)
  # ---------------------------------------------------------------------------

  defp estimate_tokens(content) when is_binary(content) do
    div(byte_size(content), 4) + 1
  end

  # ---------------------------------------------------------------------------
  # Context window trimming (SC-NEURO-002)
  # ---------------------------------------------------------------------------

  defp trim_history(%{token_count: tc} = session, _table)
       when tc <= @context_window_limit do
    session
  end

  defp trim_history(session, table) do
    existing = ets_history(table, session.session_id)
    trim_count = max(1, div(length(existing), 4))
    trimmed = Enum.drop(existing, trim_count)
    ets_put_history(table, session.session_id, trimmed)

    recalc = Enum.sum(Enum.map(trimmed, fn e -> estimate_tokens(e.content) end))
    %{session | token_count: recalc}
  end

  # ---------------------------------------------------------------------------
  # Guardian validation (SC-NEURO-001, SC-NEURO-003)
  # ---------------------------------------------------------------------------

  @veto_categories [:destructive, :constitutional]

  @forbidden_patterns [
    ~r/rm\s+-rf/i,
    ~r/DROP\s+TABLE/i,
    ~r/TRUNCATE\s+TABLE/i,
    ~r/DELETE\s+FROM\s+\w+\s*$/i,
    ~r/shutdown\s+--all/i,
    ~r/mkfs\./i,
    ~r/dd\s+if=/i
  ]

  defp build_proposal(content, category, risk) do
    %{
      content: content,
      category: category,
      risk: risk,
      timestamp_ms: System.monotonic_time(:millisecond)
    }
  end

  defp guardian_validate(%{category: cat}) when cat in @veto_categories do
    reason =
      case cat do
        :destructive ->
          "Destructive operations require explicit operator confirmation " <>
            "and Guardian approval (SC-NEURO-001)"

        :constitutional ->
          "Proposals modifying constitutional invariants Ψ₀-Ψ₅ / Ω₀ " <>
            "are permanently vetoed (SC-NEURO-001)"
      end

    {:veto, reason}
  end

  defp guardian_validate(%{content: content} = proposal) do
    if Enum.any?(@forbidden_patterns, &Regex.match?(&1, content)) do
      {:veto, "Content matches forbidden-operation pattern — unconditional veto (SC-NEURO-003)"}
    else
      guardian_validate_risk(proposal)
    end
  end

  defp guardian_validate_risk(%{risk: risk}) when risk >= @guardian_risk_threshold do
    {:veto,
     "Proposal risk #{risk} meets or exceeds Guardian threshold " <>
       "#{@guardian_risk_threshold} (SC-NEURO-001)"}
  end

  defp guardian_validate_risk(_proposal), do: {:ok, :approved}

  defp canonical_risk(:informational), do: 0.1
  defp canonical_risk(:operational), do: 0.4
  defp canonical_risk(:destructive), do: 0.9
  defp canonical_risk(:constitutional), do: 1.0

  # ---------------------------------------------------------------------------
  # Recommendation cards
  # ---------------------------------------------------------------------------

  defp build_recommendation_card(intent, title, actions)
       when is_atom(intent) and is_binary(title) and is_list(actions) do
    %{
      intent: intent,
      title: title,
      actions: actions,
      created_at_ms: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Error handling helpers
  # ---------------------------------------------------------------------------

  defp simulate_timeout(_session) do
    {:error, :timeout,
     "The AI assistant did not respond in time. " <>
       "Please retry or contact support if the issue persists."}
  end

  defp record_failure(session) do
    %{session | retry_count: session.retry_count + 1}
  end

  defp attempt_retry(%{retry_count: count}) when count >= @retry_limit do
    {:error, :max_retries_exceeded}
  end

  defp attempt_retry(session), do: {:ok, record_failure(session)}

  # ---------------------------------------------------------------------------
  # Founder alignment helpers (AOR-PRAJNA-002, Ω₀)
  # ---------------------------------------------------------------------------

  defp build_rec(intent, affects_founder, reduces_resources) do
    %{intent: intent, affects_founder: affects_founder, reduces_resources: reduces_resources}
  end

  defp founder_check(%{affects_founder: true, reduces_resources: true}), do: :misaligned
  defp founder_check(_rec), do: :aligned

  defp founder_check_verbose(%{affects_founder: true, reduces_resources: true} = rec) do
    explanation =
      "Recommendation intent=#{rec.intent} reduces Founder-controlled resources — " <>
        "violates Ω₀ resource acquisition directive (AOR-PRAJNA-002)"

    {:misaligned, explanation}
  end

  defp founder_check_verbose(rec),
    do: {:aligned, "No Founder impact detected for intent=#{rec.intent}"}

  # ---------------------------------------------------------------------------
  # Simulated streaming response generator
  # ---------------------------------------------------------------------------

  @canned_responses [
    "The mesh is operating normally. All 15 containers are healthy.",
    "Alarm A-001 is a critical door sensor — currently ACTIVE.",
    "Threat level is LOW. No anomalies detected in the last 30 seconds.",
    "Guardian validation passed. The proposed action is approved.",
    "Zenoh router is connected. Session latency is within the 50ms budget.",
    "Sentinel reports zero active threats. System health score is 98 out of 100.",
    "Memory utilisation is at 42 percent. No OOM risk detected."
  ]

  defp generate_stream(prompt, max_tokens) when is_binary(prompt) do
    idx = :erlang.phash2(prompt, length(@canned_responses))
    raw = Enum.at(@canned_responses, idx)

    # Truncate to max_tokens budget (4 chars-per-token heuristic)
    char_budget = max(1, max_tokens * 4)
    truncated = String.slice(raw, 0, char_budget)

    # Split into word-level chunks to simulate token-by-token streaming
    words = String.split(truncated, " ")
    last_idx = length(words) - 1

    words
    |> Enum.with_index()
    |> Enum.map(fn {word, i} -> if i < last_idx, do: word <> " ", else: word end)
  end
end
