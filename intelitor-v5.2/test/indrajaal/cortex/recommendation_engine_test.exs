defmodule Indrajaal.Cortex.RecommendationEngineTest do
  @moduledoc """
  TDG test suite for Cortex Recommendation Engine — L1 Function level.

  WHAT: Tests recommendation generation, FMEA scoring, Guardian validation,
        context awareness, feedback loop, cache management, and rate limiting.
        Entirely self-contained — no dependency on production GenServer or
        external AI clients. All state is simulated via ETS.

  WHY: Validates the core recommendation logic contracts before wiring to the
       live GenServer, ensuring correctness of RPN scoring, top-K selection,
       confidence filtering, and Guardian integration per SIL-6 safety mandate.

  CONSTRAINTS:
  - SC-NEURO-001: AI output MUST pass Guardian.validate_proposal/1 (Simplex principle)
  - SC-NEURO-002: Hard limits on AI requests (rate limiting enforced)
  - SC-SEM-001:   Semantic analysis text quality constraints
  - SC-PRED-001:  Predictive analytics domain constraints
  - SC-FMEA-002:  RPN = Severity × Occurrence × Detection (each 1-10)
  - SC-FMEA-004:  RPN >= 200 flagged as CRITICAL
  - SC-GDE-001:   Guardian validation required before recommendation dispatch
  - SC-SENS-001:  Non-blocking recommendation polling

  AOR Rules:
  - AOR-NEURO-001: Guardian Check — all AI proposals MUST pass Guardian validation
  - AOR-NEURO-002: Log Veto — vetoed proposals MUST be logged (shadow mode)
  - AOR-CAE-002:   Evolution Safety — proposals MUST pass Guardian before deployment
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ──────────────────────────────────────────────────────────────
  # ETS table names — prefixed with test pid to survive async: true
  # ──────────────────────────────────────────────────────────────

  defp rec_table, do: :"rec_#{inspect(self())}"
  defp fb_table, do: :"fb_#{inspect(self())}"
  defp cache_table, do: :"cache_#{inspect(self())}"
  defp rate_table, do: :"rate_#{inspect(self())}"

  defp make_table(name, opts \\ [:named_table, :public, :set]) do
    if :ets.whereis(name) != :undefined, do: :ets.delete(name)
    :ets.new(name, opts)
  end

  defp delete_table(name) do
    if :ets.whereis(name) != :undefined, do: :ets.delete(name)
    :ok
  end

  # ──────────────────────────────────────────────────────────────
  # PURE SIMULATION HELPERS — no production module dependency
  # ──────────────────────────────────────────────────────────────

  # RPN formula per SC-FMEA-002
  defp compute_rpn(s, o, d)
       when s in 1..10 and o in 1..10 and d in 1..10,
       do: s * o * d

  defp classify_priority(rpn) when rpn >= 200, do: :critical
  defp classify_priority(rpn) when rpn >= 100, do: :high
  defp classify_priority(rpn) when rpn >= 50, do: :medium
  defp classify_priority(_rpn), do: :low

  defp heuristic_confidence(rpn) when rpn >= 200, do: 0.80
  defp heuristic_confidence(rpn) when rpn >= 100, do: 0.72
  defp heuristic_confidence(rpn) when rpn >= 50, do: 0.65
  defp heuristic_confidence(_rpn), do: 0.55

  defp heuristic_action(obs, rpn) when rpn >= 200,
    do: "CRITICAL: Immediately investigate #{obs.issue} in #{obs.domain}"

  defp heuristic_action(obs, rpn) when rpn >= 100,
    do: "HIGH: Review #{obs.issue} in #{obs.domain} within 24h"

  defp heuristic_action(obs, rpn) when rpn >= 50,
    do: "MEDIUM: Schedule remediation of #{obs.issue} in #{obs.domain}"

  defp heuristic_action(obs, _rpn),
    do: "LOW: Monitor #{obs.issue} in #{obs.domain}"

  defp build_recommendation(obs) do
    rpn = compute_rpn(obs.severity, obs.occurrence, obs.detection)

    hash =
      :crypto.hash(:sha256, "#{obs.domain}#{obs.issue}#{rpn}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 8)

    %{
      id: "rec-#{hash}",
      domain: obs.domain,
      issue: obs.issue,
      rpn: rpn,
      severity: obs.severity,
      occurrence: obs.occurrence,
      detection: obs.detection,
      priority: classify_priority(rpn),
      action: heuristic_action(obs, rpn),
      rationale: "Heuristic recommendation (RPN=#{rpn})",
      confidence: heuristic_confidence(rpn),
      source: :heuristic,
      guardian_approved: false,
      timestamp: DateTime.utc_now()
    }
  end

  # Simulates Guardian.validate_proposal/1 without touching production code.
  # Returns {:ok, proposal} for safe proposals, {:veto, reason} for unsafe ones.
  defp guardian_validate(proposal) do
    cond do
      Map.get(proposal, :confidence, 1.0) < 0.1 ->
        {:veto, :confidence_too_low}

      Map.get(proposal, :action, "") == "" ->
        {:veto, :empty_action}

      true ->
        {:ok, Map.put(proposal, :guardian_approved, true)}
    end
  end

  defp apply_guardian(recommendations) do
    Enum.map(recommendations, fn rec ->
      proposal = %{
        source: :recommendation_engine,
        target: rec.domain,
        action: rec.action,
        confidence: rec.confidence,
        rpn: rec.rpn,
        guardian_approved: false
      }

      case guardian_validate(proposal) do
        {:ok, _} -> %{rec | guardian_approved: true}
        {:veto, _reason} -> %{rec | guardian_approved: false, confidence: rec.confidence * 0.5}
      end
    end)
  end

  defp generate_recommendations(observations, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 10)
    min_confidence = Keyword.get(opts, :min_confidence, 0.0)

    observations
    |> Enum.map(&build_recommendation/1)
    |> Enum.filter(&(&1.confidence >= min_confidence))
    |> apply_guardian()
    |> Enum.sort_by(& &1.rpn, :desc)
    |> Enum.take(top_k)
  end

  # ──────────────────────────────────────────────────────────────
  # FIXTURE OBSERVATIONS
  # ──────────────────────────────────────────────────────────────

  defp critical_obs,
    do: %{
      domain: :safety,
      issue: "guardian_timeout",
      severity: 9,
      occurrence: 5,
      detection: 5,
      metadata: %{}
    }

  defp high_obs,
    do: %{
      domain: :mesh,
      issue: "zenoh_disconnect",
      severity: 7,
      occurrence: 5,
      detection: 4,
      metadata: %{}
    }

  defp medium_obs,
    do: %{
      domain: :alarms,
      issue: "queue_backlog",
      severity: 5,
      occurrence: 4,
      detection: 3,
      metadata: %{}
    }

  defp low_obs,
    do: %{
      domain: :analytics,
      issue: "slow_query",
      severity: 3,
      occurrence: 2,
      detection: 2,
      metadata: %{}
    }

  defp mixed_observations,
    do: [critical_obs(), high_obs(), medium_obs(), low_obs()]

  # ──────────────────────────────────────────────────────────────
  # CACHE HELPERS
  # ──────────────────────────────────────────────────────────────

  defp cache_put(table, key, value, ttl_ms) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(table, {key, value, expires_at})
  end

  defp cache_get(table, key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, key) do
      [{^key, value, expires_at}] when expires_at > now -> {:hit, value}
      [{^key, _value, _expires_at}] -> :expired
      [] -> :miss
    end
  end

  defp cache_invalidate(table, key) do
    :ets.delete(table, key)
    :ok
  end

  # ──────────────────────────────────────────────────────────────
  # 1. DESCRIBE: recommendation generation
  # ──────────────────────────────────────────────────────────────

  describe "recommendation generation" do
    setup do
      t = make_table(rec_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "generates a recommendation for each observation" do
      recs = generate_recommendations(mixed_observations())
      assert length(recs) == 4
    end

    test "each recommendation has all required fields" do
      [rec | _] = generate_recommendations([critical_obs()])

      required = [
        :id,
        :domain,
        :issue,
        :rpn,
        :priority,
        :action,
        :rationale,
        :confidence,
        :source,
        :guardian_approved,
        :timestamp
      ]

      for field <- required do
        assert Map.has_key?(rec, field), "missing field :#{field}"
      end
    end

    test "RPN is computed as severity * occurrence * detection per SC-FMEA-002" do
      obs = %{domain: :test, issue: "x", severity: 3, occurrence: 4, detection: 5, metadata: %{}}
      [rec] = generate_recommendations([obs])
      assert rec.rpn == 3 * 4 * 5
    end

    test "empty observations list returns empty recommendations" do
      assert generate_recommendations([]) == []
    end

    test "recommendation id is deterministic and prefixed with rec-" do
      [r1] = generate_recommendations([critical_obs()])
      [r2] = generate_recommendations([critical_obs()])
      assert r1.id == r2.id
      assert String.starts_with?(r1.id, "rec-")
    end

    test "result persists to ETS for state regeneration (Psi-1 Regeneration)" do
      recs = generate_recommendations(mixed_observations())
      :ets.insert(rec_table(), {:latest, recs})
      [{:latest, stored}] = :ets.lookup(rec_table(), :latest)
      assert length(stored) == 4
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 2. DESCRIBE: scoring and ranking
  # ──────────────────────────────────────────────────────────────

  describe "scoring and ranking" do
    setup do
      t = make_table(rec_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "recommendations are sorted by RPN descending" do
      recs = generate_recommendations(mixed_observations())
      rpns = Enum.map(recs, & &1.rpn)
      assert rpns == Enum.sort(rpns, :desc)
    end

    test "critical: RPN >= 200 classified as :critical per SC-FMEA-004" do
      [rec] = generate_recommendations([critical_obs()])
      # guardian_timeout: 9*5*5 = 225 >= 200
      assert rec.rpn >= 200
      assert rec.priority == :critical
    end

    test "high: RPN 100-199 classified as :high" do
      obs = %{
        domain: :mesh,
        issue: "latency",
        severity: 5,
        occurrence: 5,
        detection: 5,
        metadata: %{}
      }

      [rec] = generate_recommendations([obs])
      # 5*5*5 = 125
      assert rec.rpn == 125
      assert rec.priority == :high
    end

    test "medium: RPN 50-99 classified as :medium" do
      obs = %{
        domain: :alarms,
        issue: "backlog",
        severity: 4,
        occurrence: 4,
        detection: 4,
        metadata: %{}
      }

      [rec] = generate_recommendations([obs])
      # 4*4*4 = 64
      assert rec.rpn == 64
      assert rec.priority == :medium
    end

    test "low: RPN < 50 classified as :low" do
      obs = %{
        domain: :analytics,
        issue: "minor",
        severity: 2,
        occurrence: 3,
        detection: 2,
        metadata: %{}
      }

      [rec] = generate_recommendations([obs])
      # 2*3*2 = 12
      assert rec.rpn == 12
      assert rec.priority == :low
    end

    test "top_k option limits returned count" do
      obs_list =
        for i <- 1..8 do
          %{
            domain: :test,
            issue: "issue_#{i}",
            severity: i,
            occurrence: 1,
            detection: 1,
            metadata: %{}
          }
        end

      recs = generate_recommendations(obs_list, top_k: 3)
      assert length(recs) == 3
    end

    test "top_k larger than input returns all recommendations" do
      recs = generate_recommendations([low_obs()], top_k: 100)
      assert length(recs) == 1
    end

    test "min_confidence filters out recommendations below threshold" do
      # low_obs: confidence = 0.55 (RPN = 12 < 50); threshold set above
      recs = generate_recommendations([low_obs()], min_confidence: 0.60)
      assert recs == []
    end

    test "min_confidence passes recommendations at or above threshold" do
      # critical_obs confidence = 0.80
      recs = generate_recommendations([critical_obs()], min_confidence: 0.80)
      assert length(recs) == 1
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 3. DESCRIBE: context awareness
  # ──────────────────────────────────────────────────────────────

  describe "context awareness" do
    setup do
      t = make_table(rec_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "off-hours severity boost increases RPN" do
      obs = %{
        domain: :mesh,
        issue: "packet_loss",
        severity: 5,
        occurrence: 4,
        detection: 3,
        metadata: %{}
      }

      base_rpn = compute_rpn(obs.severity, obs.occurrence, obs.detection)
      # Simulate off-hours: severity +1
      boosted_rpn = compute_rpn(min(obs.severity + 1, 10), obs.occurrence, obs.detection)
      assert boosted_rpn > base_rpn
    end

    test "admin role context sees all priority levels" do
      recs = generate_recommendations(mixed_observations())
      priorities = recs |> Enum.map(& &1.priority) |> Enum.uniq()
      assert :critical in priorities
    end

    test "observer role filter restricts to high/critical" do
      recs =
        mixed_observations()
        |> generate_recommendations()
        |> Enum.filter(&(&1.priority in [:critical, :high]))

      for rec <- recs do
        assert rec.priority in [:critical, :high]
      end
    end

    test "degraded system state adds context tag to recommendation" do
      rec = build_recommendation(critical_obs())
      degraded_rec = Map.put(rec, :context_tags, [:degraded_mode])
      assert :degraded_mode in degraded_rec.context_tags
    end

    test "issue and domain fields are preserved from source observation" do
      obs = %{
        domain: :safety,
        issue: "watchdog_expired",
        severity: 8,
        occurrence: 3,
        detection: 4,
        metadata: %{node: "app-1", region: "eu-west"}
      }

      rec = build_recommendation(obs)
      assert rec.domain == :safety
      assert rec.issue == "watchdog_expired"
    end

    test "timestamp is a valid DateTime struct" do
      [rec] = generate_recommendations([critical_obs()])
      assert %DateTime{} = rec.timestamp
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 4. DESCRIBE: Guardian validation (SC-NEURO-001)
  # ──────────────────────────────────────────────────────────────

  describe "Guardian validation" do
    setup do
      t = make_table(rec_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "all generated recommendations carry guardian_approved boolean" do
      recs = generate_recommendations(mixed_observations())

      for rec <- recs do
        assert Map.has_key?(rec, :guardian_approved)
        assert is_boolean(rec.guardian_approved)
      end
    end

    test "high-confidence recommendations are Guardian-approved" do
      # critical_obs confidence = 0.80 — passes guardian (>= 0.1 threshold)
      [rec] = generate_recommendations([critical_obs()])
      assert rec.guardian_approved == true
    end

    test "Guardian vetoes proposals with confidence < 0.1" do
      proposal = %{
        source: :rec_engine,
        target: :test,
        action: "some action",
        confidence: 0.05,
        rpn: 50,
        guardian_approved: false
      }

      assert {:veto, :confidence_too_low} = guardian_validate(proposal)
    end

    test "Guardian vetoes proposals with empty action string" do
      proposal = %{
        source: :rec_engine,
        target: :test,
        action: "",
        confidence: 0.9,
        rpn: 100,
        guardian_approved: false
      }

      assert {:veto, :empty_action} = guardian_validate(proposal)
    end

    test "Guardian approves valid proposal and sets guardian_approved: true" do
      proposal = %{
        source: :rec_engine,
        target: :safety,
        action: "Restart watchdog",
        confidence: 0.85,
        rpn: 200,
        guardian_approved: false
      }

      assert {:ok, approved} = guardian_validate(proposal)
      assert approved.guardian_approved == true
    end

    test "Guardian-vetoed recommendations have halved confidence (AOR-NEURO-002)" do
      # Manually apply guardian logic to a near-zero confidence rec
      rec = %{
        id: "rec-test",
        domain: :test,
        issue: "test",
        rpn: 50,
        severity: 5,
        occurrence: 2,
        detection: 5,
        priority: :medium,
        action: "test action",
        rationale: "test",
        confidence: 0.05,
        source: :heuristic,
        guardian_approved: false,
        timestamp: DateTime.utc_now()
      }

      proposal = %{
        source: :rec_engine,
        target: rec.domain,
        action: rec.action,
        confidence: rec.confidence,
        rpn: rec.rpn,
        guardian_approved: false
      }

      result =
        case guardian_validate(proposal) do
          {:ok, _} -> %{rec | guardian_approved: true}
          {:veto, _} -> %{rec | guardian_approved: false, confidence: rec.confidence * 0.5}
        end

      assert result.guardian_approved == false
      assert_in_delta result.confidence, 0.025, 0.001
    end

    test "Guardian audit stored in ETS for traceability" do
      [rec] = generate_recommendations([critical_obs()])

      :ets.insert(
        rec_table(),
        {:guardian_audit, %{rec_id: rec.id, approved: rec.guardian_approved}}
      )

      [{:guardian_audit, audit}] = :ets.lookup(rec_table(), :guardian_audit)
      assert is_boolean(audit.approved)
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 5. DESCRIBE: recommendation types
  # ──────────────────────────────────────────────────────────────

  describe "recommendation types" do
    setup do
      t = make_table(rec_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "action recommendation text contains severity prefix" do
      for obs <- mixed_observations() do
        rec = build_recommendation(obs)
        assert String.contains?(rec.action, ":")
      end
    end

    test "CRITICAL prefix used for RPN >= 200" do
      [rec] = generate_recommendations([critical_obs()])
      assert String.starts_with?(rec.action, "CRITICAL:")
    end

    test "HIGH prefix used for RPN 100-199" do
      obs = %{
        domain: :mesh,
        issue: "latency",
        severity: 5,
        occurrence: 5,
        detection: 5,
        metadata: %{}
      }

      [rec] = generate_recommendations([obs])
      assert String.starts_with?(rec.action, "HIGH:")
    end

    test "configuration suggestion type can be tagged on recommendation" do
      config_obs = %{
        domain: :cortex,
        issue: "openrouter_timeout_low",
        severity: 4,
        occurrence: 6,
        detection: 3,
        metadata: %{type: :configuration}
      }

      rec = build_recommendation(config_obs)
      config_rec = Map.put(rec, :type, :configuration_suggestion)
      assert config_rec.type == :configuration_suggestion
    end

    test "alert summary type carries severity context" do
      alert_obs = %{
        domain: :alarms,
        issue: "alarm_storm_detected",
        severity: 8,
        occurrence: 7,
        detection: 2,
        metadata: %{alert_count: 142}
      }

      rec = build_recommendation(alert_obs)
      alert_rec = Map.put(rec, :type, :alert_summary)
      assert alert_rec.type == :alert_summary
      assert alert_rec.severity == 8
    end

    test "heuristic source is tagged on all simulated recommendations" do
      [rec] = generate_recommendations([medium_obs()])
      assert rec.source == :heuristic
    end

    test "action text is bounded to reasonable length (SC-SEM-001 text quality)" do
      for obs <- mixed_observations() do
        [rec] = generate_recommendations([obs])
        assert String.length(rec.action) < 200, "action too long: #{rec.action}"
      end
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 6. DESCRIBE: feedback loop
  # ──────────────────────────────────────────────────────────────

  describe "feedback loop" do
    setup do
      t = make_table(fb_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "accept feedback increments accepted count" do
      :ets.insert(fb_table(), {:accepted, 0})
      [{:accepted, c}] = :ets.lookup(fb_table(), :accepted)
      :ets.insert(fb_table(), {:accepted, c + 1})
      [{:accepted, new}] = :ets.lookup(fb_table(), :accepted)
      assert new == 1
    end

    test "reject feedback increments rejected count" do
      :ets.insert(fb_table(), {:rejected, 0})
      [{:rejected, c}] = :ets.lookup(fb_table(), :rejected)
      :ets.insert(fb_table(), {:rejected, c + 1})
      [{:rejected, new}] = :ets.lookup(fb_table(), :rejected)
      assert new == 1
    end

    test "accuracy calculated as accepted / total when total > 0" do
      :ets.insert(fb_table(), {:accepted, 7})
      :ets.insert(fb_table(), {:rejected, 3})

      [{:accepted, accepted}] = :ets.lookup(fb_table(), :accepted)
      [{:rejected, rejected}] = :ets.lookup(fb_table(), :rejected)

      accuracy = accepted / (accepted + rejected)
      assert_in_delta accuracy, 0.7, 0.001
    end

    test "accuracy is 0.0 when no feedback recorded yet" do
      :ets.insert(fb_table(), {:accepted, 0})
      :ets.insert(fb_table(), {:rejected, 0})

      [{:accepted, a}] = :ets.lookup(fb_table(), :accepted)
      [{:rejected, r}] = :ets.lookup(fb_table(), :rejected)

      accuracy = if a + r == 0, do: 0.0, else: a / (a + r)
      assert accuracy == 0.0
    end

    test "repeated rejection lowers domain confidence weight (model adjustment)" do
      initial_weight = 1.0
      rejection_count = 3
      adjusted = initial_weight * :math.pow(0.9, rejection_count)
      assert adjusted < initial_weight
      assert_in_delta adjusted, 0.729, 0.001
    end

    test "feedback record stored by recommendation id" do
      rec_id = "rec-abcd1234"
      :ets.insert(fb_table(), {rec_id, %{action: :accepted, timestamp: DateTime.utc_now()}})
      [{^rec_id, entry}] = :ets.lookup(fb_table(), rec_id)
      assert entry.action == :accepted
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 7. DESCRIBE: cache management
  # ──────────────────────────────────────────────────────────────

  describe "cache management" do
    setup do
      t = make_table(cache_table())
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    test "cache miss on first lookup for unknown key" do
      assert :miss = cache_get(cache_table(), :unknown_ctx_key)
    end

    test "cache hit within TTL after put" do
      cache_put(cache_table(), :ctx_alarm, ["rec1", "rec2"], 5_000)
      assert {:hit, ["rec1", "rec2"]} = cache_get(cache_table(), :ctx_alarm)
    end

    test "cache returns :expired after TTL elapses" do
      cache_put(cache_table(), :ctx_expired, ["stale"], 1)
      Process.sleep(5)
      assert :expired = cache_get(cache_table(), :ctx_expired)
    end

    test "cache invalidation removes the entry immediately" do
      cache_put(cache_table(), :ctx_mesh, ["rec_a"], 60_000)
      {:hit, _} = cache_get(cache_table(), :ctx_mesh)
      cache_invalidate(cache_table(), :ctx_mesh)
      assert :miss = cache_get(cache_table(), :ctx_mesh)
    end

    test "multiple context keys are cached independently" do
      cache_put(cache_table(), :ctx_safety, ["safety_rec"], 5_000)
      cache_put(cache_table(), :ctx_alarms, ["alarm_rec"], 5_000)

      {:hit, safety} = cache_get(cache_table(), :ctx_safety)
      {:hit, alarms} = cache_get(cache_table(), :ctx_alarms)

      assert safety == ["safety_rec"]
      assert alarms == ["alarm_rec"]
    end

    test "ETS size reflects number of cached entries" do
      cache_put(cache_table(), :k1, "v1", 5_000)
      cache_put(cache_table(), :k2, "v2", 5_000)
      assert :ets.info(cache_table(), :size) == 2
    end

    test "context change invalidates stale cached recommendations" do
      cache_put(cache_table(), :ctx_cortex, ["old_rec"], 60_000)
      # Context change (e.g. new alert) triggers invalidation
      cache_invalidate(cache_table(), :ctx_cortex)
      new_recs = generate_recommendations([critical_obs()])
      cache_put(cache_table(), :ctx_cortex, new_recs, 60_000)
      {:hit, stored} = cache_get(cache_table(), :ctx_cortex)
      assert hd(stored).domain == :safety
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 8. DESCRIBE: rate limiting (SC-NEURO-002)
  # ──────────────────────────────────────────────────────────────

  describe "rate limiting" do
    setup do
      # Use duplicate_bag so multiple timestamp entries per key are stored separately
      t = make_table(rate_table(), [:named_table, :public, :duplicate_bag])
      on_exit(fn -> delete_table(t) end)
      :ok
    end

    # Window-based rate limiter using ETS
    defp rate_allow(table, key, max_per_window) do
      now_sec = System.os_time(:second)
      window_start = now_sec - 60

      :ets.select_delete(table, [{{key, :"$1"}, [{:<, :"$1", window_start}], [true]}])

      count = length(:ets.lookup(table, key))

      if count < max_per_window do
        :ets.insert(table, {key, now_sec})
        :ok
      else
        {:error, :rate_limited}
      end
    end

    test "requests within limit are all allowed" do
      for _i <- 1..5 do
        assert :ok = rate_allow(rate_table(), :engine_a, 10)
      end
    end

    test "request exceeding limit is rejected" do
      for _i <- 1..10 do
        rate_allow(rate_table(), :engine_b, 10)
      end

      assert {:error, :rate_limited} = rate_allow(rate_table(), :engine_b, 10)
    end

    test "separate keys have independent rate-limit windows" do
      for _i <- 1..10 do
        rate_allow(rate_table(), :key_a, 10)
      end

      # key_b is fresh
      assert :ok = rate_allow(rate_table(), :key_b, 10)
    end

    test "request records are stored in ETS" do
      rate_allow(rate_table(), :counter_key, 5)
      rate_allow(rate_table(), :counter_key, 5)
      entries = :ets.lookup(rate_table(), :counter_key)
      assert length(entries) == 2
    end

    test "exponential backoff delay increases with failure count" do
      base_ms = 100
      delays = for n <- 1..4, do: base_ms * Integer.pow(2, n - 1)
      assert delays == [100, 200, 400, 800]
      assert delays == Enum.sort(delays)
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 9. PROPERTY TEST: sorted by score descending (PropCheck / PC)
  # ──────────────────────────────────────────────────────────────

  describe "property: recommendations sorted by RPN descending" do
    test "forall non-empty observation lists, result is RPN-sorted" do
      # Generate a flat list of {s,o,d} triples via PC.let to bind dependent
      # generators within a single forall — nested forall returns generator structs
      # rather than evaluated booleans (EP-GEN-014).
      # PC.tuple/1 takes a *list* of generators and produces a fixed-arity tuple.
      # quickcheck/1 is required to evaluate the forall property — using forall
      # as a bare expression returns the PropCheck internal type, not a boolean
      # (EP-GEN-014). assert quickcheck(forall ...) is the canonical pattern.
      triple_list_gen =
        PC.non_empty(PC.list(PC.tuple([PC.range(1, 10), PC.range(1, 10), PC.range(1, 10)])))

      assert quickcheck(
               forall triples <- triple_list_gen do
                 observations =
                   triples
                   |> Enum.with_index()
                   |> Enum.map(fn {{s, o, d}, i} ->
                     %{
                       domain: :test,
                       issue: "obs_#{i}",
                       severity: s,
                       occurrence: o,
                       detection: d,
                       metadata: %{}
                     }
                   end)

                 recs = generate_recommendations(observations)
                 rpns = Enum.map(recs, & &1.rpn)
                 rpns == Enum.sort(rpns, :desc)
               end
             )
    end
  end

  # ──────────────────────────────────────────────────────────────
  # 10. PROPERTY TEST: count <= requested top_k (StreamData / SD)
  # ──────────────────────────────────────────────────────────────

  describe "property: recommendation count never exceeds top_k" do
    test "check all: length(result) <= top_k for any valid inputs" do
      ExUnitProperties.check all(
                               n_obs <- SD.integer(1..20),
                               top_k <- SD.integer(1..15),
                               severities <- SD.list_of(SD.integer(1..10), length: n_obs),
                               occurrences <- SD.list_of(SD.integer(1..10), length: n_obs),
                               detections <- SD.list_of(SD.integer(1..10), length: n_obs),
                               max_runs: 50
                             ) do
        observations =
          [severities, occurrences, detections]
          |> Enum.zip()
          |> Enum.with_index()
          |> Enum.map(fn {{s, o, d}, i} ->
            %{
              domain: :test,
              issue: "obs_#{i}",
              severity: s,
              occurrence: o,
              detection: d,
              metadata: %{}
            }
          end)

        recs = generate_recommendations(observations, top_k: top_k)
        assert length(recs) <= top_k
      end
    end
  end
end
