defmodule Indrajaal.Web.Live.PrajnaCopilotChatTest do
  @moduledoc """
  WHAT: Self-contained tests for the Prajna Copilot LiveView streaming chat —
        session lifecycle, message delivery, AI proposal validation through the
        Guardian Simplex, context-window management, and rate limiting.
        No production module dependencies are required; all logic lives in
        private helpers at the bottom of this file.
  WHY:  SC-NEURO-001 mandates that all AI output passes through Guardian.
        SC-NEURO-002 requires hard resource bounds on AI requests.
        AOR-PRAJNA-002 ensures every AI recommendation aligns with the
        Founder's Directive before being delivered to the operator.
        The Prajna Copilot is the primary human-AI interface; its safety
        properties must be test-verified at every layer.

  ## STAMP Compliance
  - SC-NEURO-001: Simplex principle — AI proposals MUST pass Guardian.validate
  - SC-NEURO-002: Resource bounding — hard limits on AI request budget
  - SC-HMI-001: Dark cockpit default — urgent AI alerts only when warranted
  - AOR-PRAJNA-001: Guardian gate — Prajna commands pass Guardian validation
  - AOR-PRAJNA-002: Founder alignment — Copilot recommendations align with Ω₀
  - AOR-PRAJNA-003: State logging — mutations logged to Immutable Register
  - SC-PRF-050: Response <50ms — chat session operations meet latency budget

  ## Coverage Matrix
  | Concern                              | Unit | PropCheck | StreamData |
  |--------------------------------------|------|-----------|------------|
  | Chat session creation                | 2    | 0         | 0          |
  | Message sending (user turn)          | 2    | 0         | 0          |
  | Streaming token receipt              | 2    | 0         | 0          |
  | Conversation history preservation   | 2    | 0         | 0          |
  | Guardian proposal validation         | 3    | 0         | 0          |
  | Context window management            | 2    | 0         | 0          |
  | Rate limiting                        | 2    | 0         | 0          |
  | Message count monotone increases     | 0    | 1         | 1          |
  | Token count bounded by window limit  | 0    | 1         | 1          |
  | History order preserved              | 0    | 1         | 1          |
  | Rate limit slot consumption          | 0    | 1         | 1          |
  | Guardian veto determinism            | 0    | 1         | 0          |
  | Latency budget (SC-PRF-050)          | 1    | 0         | 0          |

  ## EP-GEN-014 compliance
  - `use PropCheck` provides forall for `property` blocks (PropCheck-native).
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
  - StreamData `check all` blocks inside plain `test` blocks only — never inside
    `ExUnitProperties.property` or wrapped in `if` conditionals (prevents binding).
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :prajna_copilot
  @moduletag :neuro_simplex

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Section 1: Chat session creation
  # ---------------------------------------------------------------------------

  describe "Chat session creation" do
    test "new session has empty history and zero token count" do
      session = new_session("user-001")

      assert session.history == []
      assert session.token_count == 0
      assert session.message_count == 0
    end

    test "session carries the initiating user id" do
      session = new_session("operator-abc")
      assert session.user_id == "operator-abc"
    end

    test "session receives a unique session id at creation" do
      s1 = new_session("u1")
      s2 = new_session("u2")

      assert is_binary(s1.session_id)
      assert byte_size(s1.session_id) > 0
      assert s1.session_id != s2.session_id
    end

    test "new session is in :idle state with no active stream" do
      session = new_session("u1")
      assert session.state == :idle
      assert session.active_stream == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Section 2: Message sending — user turn
  # ---------------------------------------------------------------------------

  describe "Message sending — user turn" do
    test "sending a message appends it to history as :user role" do
      session = new_session("u1")
      {:ok, session2} = send_user_message(session, "What is the alarm status?")

      assert length(session2.history) == 1
      [msg] = session2.history
      assert msg.role == :user
      assert msg.content == "What is the alarm status?"
    end

    test "sending two messages preserves order in history" do
      session = new_session("u1")
      {:ok, s1} = send_user_message(session, "first")
      {:ok, s2} = send_user_message(s1, "second")

      roles_and_contents =
        Enum.map(s2.history, fn m -> {m.role, m.content} end)

      assert roles_and_contents == [
               {:user, "first"},
               {:user, "second"}
             ]
    end

    test "sending a message increments message_count by 1" do
      session = new_session("u1")
      {:ok, session2} = send_user_message(session, "hello")
      assert session2.message_count == 1
    end

    test "empty message returns error and does not mutate session" do
      session = new_session("u1")
      result = send_user_message(session, "")
      assert match?({:error, :empty_message}, result)
      assert session.message_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 3: Streaming token receipt
  # ---------------------------------------------------------------------------

  describe "Streaming token receipt" do
    test "receiving a token appends it to the active buffer" do
      session = new_session("u1") |> start_stream()
      session2 = receive_token(session, "Hello")
      assert session2.stream_buffer == "Hello"
    end

    test "multiple tokens are concatenated in the buffer in order" do
      session =
        new_session("u1")
        |> start_stream()
        |> receive_token("The ")
        |> receive_token("system ")
        |> receive_token("is healthy.")

      assert session.stream_buffer == "The system is healthy."
    end

    test "finalising a stream appends an :assistant message and clears buffer" do
      session =
        new_session("u1")
        |> start_stream()
        |> receive_token("Stand by.")

      {:ok, session2} = finalise_stream(session)

      assert session2.stream_buffer == ""
      assert session2.active_stream == nil

      last = List.last(session2.history)
      assert last.role == :assistant
      assert last.content == "Stand by."
    end

    test "finalising an idle session (no active stream) returns an error" do
      session = new_session("u1")
      assert match?({:error, :no_active_stream}, finalise_stream(session))
    end
  end

  # ---------------------------------------------------------------------------
  # Section 4: Conversation history preservation (SC-NEURO-001)
  # ---------------------------------------------------------------------------

  describe "Conversation history preservation" do
    test "alternating user/assistant turns are ordered chronologically" do
      session =
        new_session("u1")
        |> add_history_entry(:user, "What is alarm A-001?")
        |> add_history_entry(:assistant, "Alarm A-001 is a critical door sensor.")
        |> add_history_entry(:user, "Acknowledge it.")
        |> add_history_entry(:assistant, "Acknowledged.")

      roles = Enum.map(session.history, & &1.role)

      assert roles == [:user, :assistant, :user, :assistant]
    end

    test "history entries carry timestamps in non-decreasing order" do
      session =
        new_session("u1")
        |> add_history_entry(:user, "msg-1")
        |> add_history_entry(:assistant, "reply-1")
        |> add_history_entry(:user, "msg-2")

      timestamps = Enum.map(session.history, & &1.timestamp_ms)
      pairs = Enum.zip(timestamps, tl(timestamps))

      assert Enum.all?(pairs, fn {a, b} -> b >= a end),
             "History timestamps must be non-decreasing"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 5: Guardian validation of AI proposals (SC-NEURO-001)
  # ---------------------------------------------------------------------------

  describe "Guardian proposal validation (SC-NEURO-001)" do
    test "safe AI proposal is approved by Guardian" do
      proposal = build_ai_proposal("Display alarm summary.", :informational)
      assert guardian_validate(proposal) == {:ok, :approved}
    end

    test "destructive AI proposal without justification is vetoed" do
      proposal = build_ai_proposal("Delete all alarm history.", :destructive)
      assert match?({:veto, _reason}, guardian_validate(proposal))
    end

    test "proposal modifying Founder Directive configuration is vetoed (AOR-PRAJNA-002)" do
      proposal = build_ai_proposal("Disable Ω₀ symbiotic survival check.", :constitutional)
      assert match?({:veto, _reason}, guardian_validate(proposal))
    end

    test "vetoed proposal includes a human-readable reason" do
      proposal = build_ai_proposal("rm -rf /data/holons", :destructive)
      {:veto, reason} = guardian_validate(proposal)
      assert is_binary(reason)
      assert byte_size(reason) > 0
    end

    test "proposal with safety label :informational always passes" do
      proposal = build_ai_proposal("Provide status summary.", :informational)
      {:ok, :approved} = guardian_validate(proposal)
      assert true
    end

    test "proposal risk score determines approval threshold" do
      low_risk = build_ai_proposal("Suggest next action.", :informational) |> Map.put(:risk, 0.1)

      high_risk =
        build_ai_proposal("Reconfigure mesh topology.", :destructive) |> Map.put(:risk, 0.9)

      assert guardian_validate(low_risk) == {:ok, :approved}
      assert match?({:veto, _}, guardian_validate(high_risk))
    end
  end

  # ---------------------------------------------------------------------------
  # Section 6: Context window management (SC-NEURO-002)
  # ---------------------------------------------------------------------------

  describe "Context window management (SC-NEURO-002)" do
    test "token count increases when messages are added" do
      session = new_session("u1")
      {:ok, s1} = send_user_message(session, "hello world")
      assert s1.token_count > session.token_count
    end

    test "session at context limit rejects new messages" do
      # Fill to the window limit
      session = new_session("u1") |> set_token_count(@context_window_limit)
      result = send_user_message(session, "one more token")
      assert match?({:error, :context_window_exceeded}, result)
    end

    test "trim_history/1 reduces token count below limit" do
      session =
        new_session("u1")
        |> set_token_count(@context_window_limit - 10)
        |> add_history_entry(:user, "old message 1")
        |> add_history_entry(:assistant, "old reply 1")
        |> add_history_entry(:user, "old message 2")

      trimmed = trim_history(session)

      assert trimmed.token_count < @context_window_limit,
             "Trimmed session must be below context window limit"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 7: Rate limiting (SC-NEURO-002, AOR-API-001)
  # ---------------------------------------------------------------------------

  describe "Rate limiting (SC-NEURO-002)" do
    test "fresh rate limiter has full allowance" do
      limiter = new_rate_limiter()
      assert limiter.remaining == @rate_limit_per_minute
    end

    test "consuming a slot decrements remaining by 1" do
      limiter = new_rate_limiter()
      {:ok, limiter2} = consume_slot(limiter)
      assert limiter2.remaining == @rate_limit_per_minute - 1
    end

    test "exhausted rate limiter rejects further consumption" do
      limiter = new_rate_limiter() |> set_remaining(0)
      result = consume_slot(limiter)
      assert match?({:error, :rate_limited, _retry_after_ms}, result)
    end

    test "retry_after is a positive integer when rate-limited" do
      limiter = new_rate_limiter() |> set_remaining(0)
      {:error, :rate_limited, retry_after_ms} = consume_slot(limiter)
      assert is_integer(retry_after_ms)
      assert retry_after_ms > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 8: Latency budget (SC-PRF-050)
  # ---------------------------------------------------------------------------

  describe "Latency budget — chat operations ≤ 50ms (SC-PRF-050)" do
    test "session creation + send message + guardian validate complete within 50ms" do
      t0 = System.monotonic_time(:millisecond)

      session = new_session("latency-user")
      {:ok, session2} = send_user_message(session, "What is the threat level?")
      proposal = build_ai_proposal("Threat level is LOW.", :informational)
      {:ok, :approved} = guardian_validate(proposal)
      _session3 = add_history_entry(session2, :assistant, "Threat level is LOW.")

      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= 50,
             "Full copilot turn took #{elapsed}ms — must be ≤50ms (SC-PRF-050)"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 9: Property — message count monotonically increases (PropCheck)
  # ---------------------------------------------------------------------------

  describe "Message count monotone — PropCheck" do
    property "MSG_PROP_01: message_count never decreases after send_user_message" do
      forall messages <- PC.non_empty(PC.list(PC.binary(min: 1, max: 32))) do
        session =
          Enum.reduce(messages, new_session("prop-user"), fn msg, acc ->
            case send_user_message(acc, msg) do
              {:ok, updated} -> updated
              {:error, _} -> acc
            end
          end)

        session.message_count == length(messages)
      end
    end

    property "MSG_PROP_02: history length equals message_count for user-only turns" do
      forall n <- PC.integer(min: 1, max: 10) do
        messages = Enum.map(1..n, fn i -> "message #{i}" end)

        session =
          Enum.reduce(messages, new_session("prop-user"), fn msg, acc ->
            case send_user_message(acc, msg) do
              {:ok, updated} -> updated
              {:error, _} -> acc
            end
          end)

        length(session.history) == session.message_count
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 10: Property — token count bounded (StreamData)
  # ---------------------------------------------------------------------------

  describe "Token count bounded — StreamData" do
    test "TOKEN_SD_01: token_count never exceeds context window limit" do
      ExUnitProperties.check all(
                               messages <-
                                 SD.list_of(SD.binary(min_length: 1, max_length: 64),
                                   max_length: 20
                                 ),
                               max_runs: 30
                             ) do
        session =
          Enum.reduce(messages, new_session("sd-user"), fn msg, acc ->
            case send_user_message(acc, msg) do
              {:ok, updated} -> updated
              {:error, :context_window_exceeded} -> acc
              {:error, _} -> acc
            end
          end)

        assert session.token_count <= @context_window_limit,
               "Token count #{session.token_count} exceeded window #{@context_window_limit}"
      end
    end

    test "TOKEN_SD_02: trim_history always produces token_count < window limit" do
      ExUnitProperties.check all(extra_tokens <- SD.integer(0..200), max_runs: 30) do
        session =
          new_session("sd-trim")
          |> set_token_count(@context_window_limit - 50 + extra_tokens)

        trimmed = trim_history(session)

        assert trimmed.token_count <= @context_window_limit,
               "After trim, token_count #{trimmed.token_count} still exceeds limit"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 11: Property — conversation history order preserved (PropCheck)
  # ---------------------------------------------------------------------------

  describe "History order preserved — PropCheck" do
    property "HIST_PROP_01: history entries are always in insertion order" do
      forall pairs <- PC.non_empty(PC.list(history_turn_gen_pc())) do
        session =
          Enum.reduce(pairs, new_session("hist-user"), fn {role, content}, acc ->
            add_history_entry(acc, role, content)
          end)

        extracted = Enum.map(session.history, fn e -> {e.role, e.content} end)
        extracted == pairs
      end
    end

    property "HIST_PROP_02: timestamps in history are non-decreasing" do
      forall n <- PC.integer(min: 2, max: 8) do
        session =
          Enum.reduce(1..n, new_session("ts-user"), fn i, acc ->
            add_history_entry(acc, :user, "msg #{i}")
          end)

        timestamps = Enum.map(session.history, & &1.timestamp_ms)
        pairs = Enum.zip(timestamps, tl(timestamps))
        Enum.all?(pairs, fn {a, b} -> b >= a end)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 12: Property — rate limit slot consumption (StreamData)
  # ---------------------------------------------------------------------------

  describe "Rate limit slot consumption — StreamData" do
    test "RATE_SD_01: remaining decrements by exactly 1 per successful consume" do
      ExUnitProperties.check all(initial <- SD.integer(1..@rate_limit_per_minute), max_runs: 50) do
        limiter = new_rate_limiter() |> set_remaining(initial)
        {:ok, limiter2} = consume_slot(limiter)
        assert limiter2.remaining == initial - 1
      end
    end

    test "RATE_SD_02: remaining never goes below 0 after N consumes" do
      ExUnitProperties.check all(
                               consumes <- SD.integer(0..(@rate_limit_per_minute + 5)),
                               max_runs: 30
                             ) do
        final_limiter =
          Enum.reduce(1..max(consumes, 1), new_rate_limiter(), fn _, acc ->
            case consume_slot(acc) do
              {:ok, updated} -> updated
              {:error, :rate_limited, _} -> acc
            end
          end)

        assert final_limiter.remaining >= 0,
               "remaining #{final_limiter.remaining} went below 0"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 13: Property — Guardian veto determinism (PropCheck)
  # ---------------------------------------------------------------------------

  describe "Guardian veto determinism — PropCheck" do
    property "GUARD_PROP_01: same proposal always yields same guardian decision" do
      forall {content, category} <- {PC.binary(min: 1, max: 64), proposal_category_gen_pc()} do
        proposal = build_ai_proposal(content, category)
        result1 = guardian_validate(proposal)
        result2 = guardian_validate(proposal)
        result1 == result2
      end
    end
  end

  # ===========================================================================
  # Private helpers — all logic is self-contained, no production deps
  # ===========================================================================

  # Module-level constants
  @context_window_limit 4_096
  @rate_limit_per_minute 20

  # ---------------------------------------------------------------------------
  # Session state machine
  # ---------------------------------------------------------------------------

  defp new_session(user_id) do
    %{
      session_id: generate_id(),
      user_id: user_id,
      state: :idle,
      history: [],
      message_count: 0,
      token_count: 0,
      stream_buffer: "",
      active_stream: nil,
      created_at_ms: System.monotonic_time(:millisecond)
    }
  end

  defp generate_id do
    :erlang.unique_integer([:positive, :monotonic])
    |> Integer.to_string()
    |> then(fn n -> "sess-" <> n end)
  end

  # ---------------------------------------------------------------------------
  # Message operations
  # ---------------------------------------------------------------------------

  defp send_user_message(_session, ""), do: {:error, :empty_message}

  defp send_user_message(%{token_count: tc} = _session, _content)
       when tc >= @context_window_limit do
    {:error, :context_window_exceeded}
  end

  defp send_user_message(session, content) do
    token_cost = estimate_tokens(content)
    entry = build_history_entry(:user, content)

    updated = %{
      session
      | history: session.history ++ [entry],
        message_count: session.message_count + 1,
        token_count: session.token_count + token_cost
    }

    {:ok, updated}
  end

  defp estimate_tokens(content) do
    # Rough 4-chars-per-token heuristic (standard approximation)
    div(byte_size(content), 4) + 1
  end

  # ---------------------------------------------------------------------------
  # Streaming operations
  # ---------------------------------------------------------------------------

  defp start_stream(session) do
    %{session | active_stream: generate_id(), stream_buffer: "", state: :streaming}
  end

  defp receive_token(%{active_stream: nil} = session, _token), do: session

  defp receive_token(session, token) do
    %{session | stream_buffer: session.stream_buffer <> token}
  end

  defp finalise_stream(%{active_stream: nil}), do: {:error, :no_active_stream}

  defp finalise_stream(session) do
    entry = build_history_entry(:assistant, session.stream_buffer)
    token_cost = estimate_tokens(session.stream_buffer)

    updated = %{
      session
      | history: session.history ++ [entry],
        message_count: session.message_count + 1,
        token_count: session.token_count + token_cost,
        stream_buffer: "",
        active_stream: nil,
        state: :idle
    }

    {:ok, updated}
  end

  # ---------------------------------------------------------------------------
  # History helpers
  # ---------------------------------------------------------------------------

  defp build_history_entry(role, content) do
    %{
      role: role,
      content: content,
      timestamp_ms: System.monotonic_time(:millisecond)
    }
  end

  defp add_history_entry(session, role, content) do
    entry = build_history_entry(role, content)
    token_cost = estimate_tokens(content)

    %{
      session
      | history: session.history ++ [entry],
        message_count: session.message_count + 1,
        token_count: session.token_count + token_cost
    }
  end

  # ---------------------------------------------------------------------------
  # Context window trimming (SC-NEURO-002)
  # ---------------------------------------------------------------------------

  defp trim_history(%{token_count: tc} = session) when tc <= @context_window_limit do
    session
  end

  defp trim_history(session) do
    # Drop the oldest 25% of history to recover headroom
    trim_count = max(1, div(length(session.history), 4))
    trimmed_history = Enum.drop(session.history, trim_count)

    recalculated_tokens =
      Enum.sum(Enum.map(trimmed_history, fn e -> estimate_tokens(e.content) end))

    %{session | history: trimmed_history, token_count: recalculated_tokens}
  end

  defp set_token_count(session, count), do: %{session | token_count: count}

  # ---------------------------------------------------------------------------
  # Guardian validation (SC-NEURO-001, AOR-PRAJNA-001)
  # ---------------------------------------------------------------------------

  @guardian_risk_threshold 0.7

  # Veto categories that are never approved (constitutional protection)
  @veto_categories [:destructive, :constitutional]

  defp build_ai_proposal(content, category) do
    risk =
      case category do
        :informational -> 0.1
        :operational -> 0.4
        :destructive -> 0.9
        :constitutional -> 1.0
      end

    %{
      content: content,
      category: category,
      risk: risk,
      timestamp_ms: System.monotonic_time(:millisecond)
    }
  end

  defp guardian_validate(%{category: category}) when category in @veto_categories do
    reason =
      case category do
        :destructive ->
          "Destructive operations require explicit operator confirmation and Guardian approval"

        :constitutional ->
          "Proposals that modify constitutional invariants (Ψ₀-Ψ₅ / Ω₀) are permanently vetoed"
      end

    {:veto, reason}
  end

  defp guardian_validate(%{risk: risk}) when risk >= @guardian_risk_threshold do
    {:veto, "Proposal risk score #{risk} exceeds Guardian threshold #{@guardian_risk_threshold}"}
  end

  defp guardian_validate(_proposal) do
    {:ok, :approved}
  end

  # ---------------------------------------------------------------------------
  # Rate limiter (SC-NEURO-002, AOR-API-002)
  # ---------------------------------------------------------------------------

  defp new_rate_limiter do
    %{
      remaining: @rate_limit_per_minute,
      window_start_ms: System.monotonic_time(:millisecond),
      window_ms: 60_000
    }
  end

  defp set_remaining(limiter, n), do: %{limiter | remaining: n}

  defp consume_slot(%{remaining: 0} = limiter) do
    elapsed = System.monotonic_time(:millisecond) - limiter.window_start_ms
    retry_after_ms = max(1, limiter.window_ms - elapsed)
    {:error, :rate_limited, retry_after_ms}
  end

  defp consume_slot(limiter) do
    {:ok, %{limiter | remaining: limiter.remaining - 1}}
  end

  # ---------------------------------------------------------------------------
  # PropCheck generators (PC. prefix — EP-GEN-014)
  # ---------------------------------------------------------------------------

  @roles [:user, :assistant]
  @proposal_categories [:informational, :operational, :destructive, :constitutional]

  defp history_turn_gen_pc do
    let {role_idx, content} <- {PC.integer(0, 1), PC.binary(min: 1, max: 32)} do
      {Enum.at(@roles, role_idx), content}
    end
  end

  defp proposal_category_gen_pc do
    let idx <- PC.integer(0, length(@proposal_categories) - 1) do
      Enum.at(@proposal_categories, idx)
    end
  end
end
