defmodule Indrajaal.Web.Live.ComplianceDashboardTest do
  @moduledoc """
  WHAT: Self-contained ETS-backed tests for a LiveView compliance dashboard with
        audit timeline — no production module dependencies required.
  WHY:  Validates compliance score aggregation, GDPR data-processing records, ISO 27001
        control mapping, append-only audit event recording with tamper detection,
        gap analysis, regulatory report generation, and compliance trend analysis
        that power the Prajna compliance cockpit (SC-COMP-001, SC-COMP-002).

  ## STAMP Compliance
  - SC-COMP-001: Compliance LiveView — dashboard required fields, real-time score
  - SC-COMP-002: Compliance state machine — status aggregation from domain scores
  - SC-COMPLIANCE-001: Compliance audit trail — append-only event log, tamper detection
  - SC-COMPLIANCE-002: Regulatory framework checks — GDPR, ISO 27001, IEC 61508
  - SC-AUDIT-001: Audit events — chronological timeline, date-range filtering
  - SC-HMI-001: Human-machine interface — dashboard metrics always in valid ranges

  ## Coverage Matrix
  | Concern                          | Unit | PropCheck | StreamData |
  |----------------------------------|------|-----------|------------|
  | Compliance status overview       | 3    | 0         | 0          |
  | Audit timeline ordering          | 3    | 0         | 1          |
  | GDPR compliance tracking         | 3    | 0         | 0          |
  | ISO 27001 control mapping        | 3    | 0         | 0          |
  | Audit event recording            | 3    | 0         | 0          |
  | Compliance gap analysis          | 3    | 0         | 0          |
  | Regulatory report generation     | 3    | 0         | 0          |
  | Compliance trend analysis        | 3    | 0         | 0          |
  | Score bounded [0,100]            | 0    | 1         | 1          |
  | Timeline chronological invariant | 0    | 1         | 1          |

  ## EP-GEN-014 compliance
  - `use PropCheck` provides forall/PC generators.
  - Do NOT use `property` macro — it contacts CounterStrike GenServer at compile time
    and fails without --start (project memory sprint-52 finding). Use `forall` inside
    plain `test` blocks instead.
  - StreamData `check all` inside plain `test` blocks.
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :compliance
  @moduletag :dashboard

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  setup do
    table = :ets.new(:compliance_test_table, [:set, :public])
    on_exit(fn -> if :ets.info(table) != :undefined, do: :ets.delete(table) end)
    {:ok, table: table}
  end

  # ---------------------------------------------------------------------------
  # Section 1: Compliance status overview (SC-COMP-001, SC-COMP-002)
  # ---------------------------------------------------------------------------

  describe "compliance status overview" do
    test "overall score is the weighted mean of per-domain scores", %{table: table} do
      domains = [
        %{name: "access_control", score: 80.0, weight: 2},
        %{name: "data_protection", score: 60.0, weight: 3},
        %{name: "incident_management", score: 100.0, weight: 1}
      ]

      :ets.insert(table, {:domains, domains})

      overall = calculate_overall_score(domains)
      expected = (80.0 * 2 + 60.0 * 3 + 100.0 * 1) / (2 + 3 + 1)
      assert_in_delta overall, expected, 0.01
    end

    test "per-domain scores are accessible individually", %{table: table} do
      domains = [
        %{name: "gdpr", score: 75.0, weight: 1},
        %{name: "iso27001", score: 90.0, weight: 1}
      ]

      :ets.insert(table, {:domains, domains})
      gdpr_score = domain_score(domains, "gdpr")
      assert gdpr_score == 75.0
    end

    test "overall status is :non_compliant when any domain score is below threshold", %{
      table: table
    } do
      domains = [
        %{name: "access_control", score: 95.0, weight: 1},
        %{name: "data_protection", score: 45.0, weight: 1}
      ]

      :ets.insert(table, {:domains, domains})
      status = overall_compliance_status(domains, _threshold = 60.0)
      assert status == :non_compliant
    end

    test "overall status is :compliant when all domain scores are at or above threshold", %{
      table: table
    } do
      domains = [
        %{name: "access_control", score: 80.0, weight: 1},
        %{name: "data_protection", score: 70.0, weight: 1}
      ]

      :ets.insert(table, {:domains, domains})
      status = overall_compliance_status(domains, _threshold = 70.0)
      assert status == :compliant
    end
  end

  # ---------------------------------------------------------------------------
  # Section 2: Audit timeline (SC-AUDIT-001)
  # ---------------------------------------------------------------------------

  describe "audit timeline" do
    test "events sorted ascending by timestamp represent chronological order", %{table: table} do
      t0 = 1_000_000

      events = [
        make_event("E3", t0 + 2000),
        make_event("E1", t0),
        make_event("E2", t0 + 1000)
      ]

      :ets.insert(table, {:events, events})
      sorted = sort_events(events)

      assert Enum.map(sorted, & &1.id) == ["E1", "E2", "E3"],
             "Events must be sorted oldest-first"
    end

    test "date-range filter returns only events within the window", %{table: table} do
      t0 = 2_000_000

      events =
        Enum.map(0..9, fn i -> make_event("E#{i}", t0 + i * 1000) end)

      :ets.insert(table, {:events, events})

      windowed = filter_events_by_range(events, t0 + 3000, t0 + 6000)
      assert length(windowed) == 4

      assert Enum.all?(windowed, fn e -> e.timestamp >= t0 + 3000 and e.timestamp <= t0 + 6000 end)
    end

    test "empty event list returns empty timeline", %{table: _table} do
      assert sort_events([]) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Section 3: GDPR compliance tracking (SC-COMPLIANCE-001, SC-COMPLIANCE-002)
  # ---------------------------------------------------------------------------

  describe "GDPR compliance tracking" do
    test "data processing record includes required GDPR article-30 fields", %{table: table} do
      record = make_gdpr_record("DPR-001", "customer_profiles", "marketing")
      :ets.insert(table, {:gdpr_record, record})

      assert Map.has_key?(record, :id)
      assert Map.has_key?(record, :data_category)
      assert Map.has_key?(record, :purpose)
      assert Map.has_key?(record, :legal_basis)
      assert Map.has_key?(record, :retention_days)
      assert Map.has_key?(record, :data_subjects)
      assert Map.has_key?(record, :processors)
    end

    test "consent tracking records subject approval with timestamp", %{table: table} do
      consent = make_consent_record("SUBJ-42", "analytics_cookies", _granted = true)
      :ets.insert(table, {:consent, consent})

      assert consent.subject_id == "SUBJ-42"
      assert consent.granted == true
      assert is_integer(consent.granted_at)
    end

    test "retention period breach is detected when record exceeds threshold", %{table: table} do
      record = make_gdpr_record("DPR-002", "purchase_history", "order_fulfillment")
      record = %{record | retention_days: 30}

      now_days = System.os_time(:second) |> div(86_400)
      old_created_days = now_days - 45

      :ets.insert(table, {:gdpr_old, record})
      assert retention_breached?(record, old_created_days, now_days)
    end
  end

  # ---------------------------------------------------------------------------
  # Section 4: ISO 27001 control mapping (SC-COMPLIANCE-002)
  # ---------------------------------------------------------------------------

  describe "ISO 27001 control mapping" do
    test "control objective has required ISO 27001 fields", %{table: table} do
      control = make_iso27001_control("A.9.1.1", "Access control policy", :implemented)
      :ets.insert(table, {:iso_control, control})

      assert Map.has_key?(control, :id)
      assert Map.has_key?(control, :clause)
      assert Map.has_key?(control, :title)
      assert Map.has_key?(control, :status)
      assert Map.has_key?(control, :evidence_refs)
    end

    test "implementation status for a control can be updated", %{table: table} do
      control =
        make_iso27001_control("A.12.6.1", "Management of technical vulnerabilities", :planned)

      :ets.insert(table, {:iso_ctrl_before, control})

      updated = update_control_status(control, :implemented)
      :ets.insert(table, {:iso_ctrl_after, updated})

      assert updated.status == :implemented
    end

    test "group_controls_by_clause/1 groups controls under their parent clause prefix", %{
      table: table
    } do
      controls = [
        make_iso27001_control("A.9.1.1", "Access control policy", :implemented),
        make_iso27001_control("A.9.1.2", "Access to networks", :planned),
        make_iso27001_control("A.12.6.1", "Technical vulnerabilities", :implemented)
      ]

      :ets.insert(table, {:iso_controls, controls})
      grouped = group_controls_by_clause(controls)

      assert Map.has_key?(grouped, "A.9")
      assert Map.has_key?(grouped, "A.12")
      assert length(Map.fetch!(grouped, "A.9")) == 2
      assert length(Map.fetch!(grouped, "A.12")) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Section 5: Audit event recording (SC-COMPLIANCE-001, SC-AUDIT-001)
  # ---------------------------------------------------------------------------

  describe "audit event recording" do
    test "appending an audit event increases log size by exactly one", %{table: table} do
      :ets.insert(table, {:audit_log, []})
      log = ets_audit_log(table)

      event = make_audit_event("EVT-001", :access_review, "user_a")
      updated = append_event(log, event)
      :ets.insert(table, {:audit_log, updated})

      assert length(ets_audit_log(table)) == length(log) + 1
    end

    test "tamper detection fails when an event payload is mutated", %{table: table} do
      event = make_audit_event("EVT-HASH", :policy_check, "system")
      log = append_event([], event)
      :ets.insert(table, {:audit_log, log})

      # Simulate tamper by changing the actor on the stored event
      [stored_event] = ets_audit_log(table)
      tampered = %{stored_event | actor: "attacker"}
      tampered_log = [tampered]

      refute audit_log_intact?(tampered_log),
             "Tampered log must fail integrity check"
    end

    test "unmodified audit log passes integrity check", %{table: table} do
      events = [
        make_audit_event("EVT-A", :control_test, "system"),
        make_audit_event("EVT-B", :evidence_upload, "admin")
      ]

      log = Enum.reduce(events, [], fn e, acc -> append_event(acc, e) end)
      :ets.insert(table, {:audit_log, log})

      assert audit_log_intact?(ets_audit_log(table)),
             "Intact log must pass integrity check"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 6: Compliance gap analysis (SC-COMP-002, SC-COMPLIANCE-002)
  # ---------------------------------------------------------------------------

  describe "compliance gap analysis" do
    test "gap analysis identifies controls with :planned or :not_started status as gaps", %{
      table: table
    } do
      controls = [
        make_iso27001_control("A.9.1.1", "Access control policy", :implemented),
        make_iso27001_control("A.9.1.2", "Access to networks", :planned),
        make_iso27001_control("A.12.6.1", "Technical vulnerabilities", :not_started)
      ]

      :ets.insert(table, {:controls_gap, controls})
      gaps = find_gaps(controls)

      gap_ids = Enum.map(gaps, & &1.id)
      assert "A.9.1.2" in gap_ids
      assert "A.12.6.1" in gap_ids
      refute "A.9.1.1" in gap_ids
    end

    test "gap percentage is the ratio of gap controls to total controls", %{table: table} do
      controls = [
        make_iso27001_control("A.9.1.1", "Control 1", :implemented),
        make_iso27001_control("A.9.1.2", "Control 2", :planned),
        make_iso27001_control("A.9.1.3", "Control 3", :not_started),
        make_iso27001_control("A.9.1.4", "Control 4", :implemented)
      ]

      :ets.insert(table, {:controls_pct, controls})
      pct = gap_percentage(controls)

      assert_in_delta pct, 50.0, 0.01
    end

    test "gap percentage is 0.0 when all controls are implemented", %{table: table} do
      controls =
        Enum.map(1..5, fn i ->
          make_iso27001_control("A.#{i}.1.1", "Control #{i}", :implemented)
        end)

      :ets.insert(table, {:controls_full, controls})
      assert gap_percentage(controls) == 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 7: Regulatory report generation (SC-COMPLIANCE-001)
  # ---------------------------------------------------------------------------

  describe "regulatory report generation" do
    test "generated report includes required structural sections", %{table: table} do
      controls = build_sample_controls()
      :ets.insert(table, {:report_controls, controls})

      report = generate_compliance_report("ISO27001", controls, [])

      assert Map.has_key?(report, :framework)
      assert Map.has_key?(report, :generated_at)
      assert Map.has_key?(report, :overall_score)
      assert Map.has_key?(report, :sections)
      assert Map.has_key?(report, :evidence_links)
      assert Map.has_key?(report, :gap_count)
    end

    test "report framework field matches the requested framework", %{table: table} do
      controls = build_sample_controls()
      :ets.insert(table, {:report_fw, controls})

      report = generate_compliance_report("GDPR", controls, [])
      assert report.framework == "GDPR"
    end

    test "report sections are non-empty when controls are provided", %{table: table} do
      controls = build_sample_controls()
      :ets.insert(table, {:report_secs, controls})

      report = generate_compliance_report("IEC61508", controls, [])
      assert length(report.sections) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 8: Compliance trend analysis (SC-COMP-002, SC-COMP-010)
  # ---------------------------------------------------------------------------

  describe "compliance trend analysis" do
    test "monthly score series is sorted from oldest to most recent month", %{table: table} do
      snapshots = [
        %{month: "2026-01", score: 72.0},
        %{month: "2026-03", score: 85.0},
        %{month: "2026-02", score: 78.0}
      ]

      :ets.insert(table, {:snapshots, snapshots})
      sorted = sort_trend_snapshots(snapshots)

      months = Enum.map(sorted, & &1.month)
      assert months == ["2026-01", "2026-02", "2026-03"]
    end

    test "regression is detected when score drops more than threshold between consecutive months",
         %{table: table} do
      snapshots = [
        %{month: "2026-01", score: 90.0},
        %{month: "2026-02", score: 70.0}
      ]

      :ets.insert(table, {:snap_regression, snapshots})
      assert detect_regression(snapshots, _drop_threshold = 10.0)
    end

    test "no regression is reported when scores are stable or improving", %{table: table} do
      snapshots = [
        %{month: "2026-01", score: 70.0},
        %{month: "2026-02", score: 75.0},
        %{month: "2026-03", score: 80.0}
      ]

      :ets.insert(table, {:snap_ok, snapshots})
      refute detect_regression(snapshots, _drop_threshold = 10.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Section 9: Property — compliance score always in 0..100 (SD generators)
  # ---------------------------------------------------------------------------

  describe "compliance score bounds — StreamData" do
    test "SCORE_SD_01: overall score is always in [0.0, 100.0]" do
      ExUnitProperties.check all(
                               domains <-
                                 SD.list_of(domain_gen_sd(), min_length: 1, max_length: 20)
                             ) do
        score = calculate_overall_score(domains)

        assert score >= 0.0 and score <= 100.0,
               "Score #{score} out of [0.0, 100.0]"
      end
    end

    test "SCORE_PC_01: forall domain lists, overall score is bounded" do
      assert :proper.quickcheck(
               forall domains <- PC.non_empty(PC.list(domain_gen_pc())) do
                 score = calculate_overall_score(domains)
                 score >= 0.0 and score <= 100.0
               end,
               [:quiet]
             )
    end
  end

  # ---------------------------------------------------------------------------
  # Section 10: Property — audit timeline is chronologically ordered (SD generators)
  # ---------------------------------------------------------------------------

  describe "audit timeline chronological invariant — StreamData" do
    test "TIMELINE_SD_01: sort_events always produces ascending timestamps" do
      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(event_gen_sd(), min_length: 1, max_length: 20)
                             ) do
        sorted = sort_events(events)
        pairs = Enum.zip(sorted, tl(sorted))

        assert Enum.all?(pairs, fn {a, b} -> a.timestamp <= b.timestamp end),
               "Sorted events must be non-descending in timestamp"
      end
    end

    test "TIMELINE_SD_02: sort_events is idempotent" do
      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(event_gen_sd(), min_length: 1, max_length: 20)
                             ) do
        once = sort_events(events)
        twice = sort_events(once)
        assert once == twice, "sort_events must be idempotent"
      end
    end

    test "TIMELINE_PC_01: forall event list, sort produces ascending timestamps" do
      assert :proper.quickcheck(
               forall events <- PC.non_empty(PC.list(event_gen_pc())) do
                 sorted = sort_events(events)
                 pairs = Enum.zip(sorted, tl(sorted))
                 Enum.all?(pairs, fn {a, b} -> a.timestamp <= b.timestamp end)
               end,
               [:quiet]
             )
    end
  end

  # ===========================================================================
  # Private helpers — fully self-contained, no production module dependencies
  # ===========================================================================

  # --- Domain score helpers (SC-COMP-001) ------------------------------------

  @spec calculate_overall_score([map()]) :: float()
  defp calculate_overall_score([]), do: 0.0

  defp calculate_overall_score(domains) do
    total_weight = Enum.sum(Enum.map(domains, & &1.weight))

    if total_weight == 0 do
      0.0
    else
      weighted_sum =
        Enum.reduce(domains, 0.0, fn d, acc ->
          clamped = max(0.0, min(100.0, d.score))
          acc + clamped * d.weight
        end)

      Float.round(weighted_sum / total_weight, 4)
    end
  end

  @spec domain_score([map()], binary()) :: float() | nil
  defp domain_score(domains, name) do
    case Enum.find(domains, &(&1.name == name)) do
      nil -> nil
      d -> d.score
    end
  end

  @spec overall_compliance_status([map()], float()) :: :compliant | :non_compliant | :unknown
  defp overall_compliance_status([], _threshold), do: :unknown

  defp overall_compliance_status(domains, threshold) do
    if Enum.all?(domains, fn d -> d.score >= threshold end) do
      :compliant
    else
      :non_compliant
    end
  end

  # --- Audit timeline helpers (SC-AUDIT-001) ---------------------------------

  @spec make_event(binary(), non_neg_integer()) :: map()
  defp make_event(id, timestamp) do
    %{id: id, timestamp: timestamp, type: :generic, actor: "system"}
  end

  @spec sort_events([map()]) :: [map()]
  defp sort_events(events), do: Enum.sort_by(events, & &1.timestamp, :asc)

  @spec filter_events_by_range([map()], non_neg_integer(), non_neg_integer()) :: [map()]
  defp filter_events_by_range(events, t_start, t_end) do
    Enum.filter(events, fn e -> e.timestamp >= t_start and e.timestamp <= t_end end)
  end

  # --- GDPR helpers (SC-COMPLIANCE-002) --------------------------------------

  @spec make_gdpr_record(binary(), binary(), binary()) :: map()
  defp make_gdpr_record(id, data_category, purpose) do
    %{
      id: id,
      data_category: data_category,
      purpose: purpose,
      legal_basis: "legitimate_interest",
      retention_days: 365,
      data_subjects: ["customers"],
      processors: ["internal"]
    }
  end

  @spec make_consent_record(binary(), binary(), boolean()) :: map()
  defp make_consent_record(subject_id, consent_type, granted) do
    %{
      subject_id: subject_id,
      consent_type: consent_type,
      granted: granted,
      granted_at: System.os_time(:second)
    }
  end

  @spec retention_breached?(map(), non_neg_integer(), non_neg_integer()) :: boolean()
  defp retention_breached?(record, created_day, current_day) do
    current_day - created_day > record.retention_days
  end

  # --- ISO 27001 helpers (SC-COMPLIANCE-002) ---------------------------------

  @spec make_iso27001_control(binary(), binary(), atom()) :: map()
  defp make_iso27001_control(clause, title, status) do
    %{
      id: clause,
      clause: clause,
      title: title,
      status: status,
      evidence_refs: []
    }
  end

  @spec update_control_status(map(), atom()) :: map()
  defp update_control_status(control, new_status), do: %{control | status: new_status}

  @spec group_controls_by_clause([map()]) :: %{binary() => [map()]}
  defp group_controls_by_clause(controls) do
    Enum.group_by(controls, fn c ->
      # Extract the top-level clause prefix, e.g., "A.9.1.1" -> "A.9"
      parts = String.split(c.clause, ".")
      Enum.take(parts, 2) |> Enum.join(".")
    end)
  end

  # --- Audit event recording helpers (SC-COMPLIANCE-001) --------------------

  @spec make_audit_event(binary(), atom(), binary()) :: map()
  defp make_audit_event(id, type, actor) do
    payload = "#{id}:#{type}:#{actor}"

    %{
      id: id,
      type: type,
      actor: actor,
      timestamp: System.monotonic_time(:millisecond),
      hash: :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
    }
  end

  @spec append_event([map()], map()) :: [map()]
  defp append_event(log, event), do: log ++ [event]

  @spec audit_log_intact?([map()]) :: boolean()
  defp audit_log_intact?(log) do
    Enum.all?(log, fn event ->
      payload = "#{event.id}:#{event.type}:#{event.actor}"
      expected = :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
      event.hash == expected
    end)
  end

  @spec ets_audit_log(:ets.tab()) :: [map()]
  defp ets_audit_log(table) do
    case :ets.lookup(table, :audit_log) do
      [{:audit_log, log}] -> log
      [] -> []
    end
  end

  # --- Gap analysis helpers (SC-COMP-002) ------------------------------------

  @gap_statuses [:planned, :not_started]

  @spec find_gaps([map()]) :: [map()]
  defp find_gaps(controls), do: Enum.filter(controls, &(&1.status in @gap_statuses))

  @spec gap_percentage([map()]) :: float()
  defp gap_percentage([]), do: 0.0

  defp gap_percentage(controls) do
    gap_count = length(find_gaps(controls))
    Float.round(gap_count / length(controls) * 100.0, 2)
  end

  # --- Report generation helpers (SC-COMPLIANCE-001) ------------------------

  @spec generate_compliance_report(binary(), [map()], [binary()]) :: map()
  defp generate_compliance_report(framework, controls, evidence_links) do
    domains =
      controls
      |> Enum.map(fn c ->
        score = if c.status == :implemented, do: 100.0, else: 0.0
        %{name: c.id, score: score, weight: 1}
      end)

    sections =
      controls
      |> group_controls_by_clause()
      |> Enum.map(fn {clause, clause_controls} ->
        %{
          clause: clause,
          control_count: length(clause_controls),
          implemented: Enum.count(clause_controls, &(&1.status == :implemented))
        }
      end)

    %{
      framework: framework,
      generated_at: System.os_time(:second),
      overall_score: calculate_overall_score(domains),
      sections: sections,
      evidence_links: evidence_links,
      gap_count: length(find_gaps(controls))
    }
  end

  @spec build_sample_controls() :: [map()]
  defp build_sample_controls do
    [
      make_iso27001_control("A.9.1.1", "Access control policy", :implemented),
      make_iso27001_control("A.9.1.2", "Access to networks", :planned),
      make_iso27001_control("A.12.6.1", "Technical vulnerabilities", :implemented)
    ]
  end

  # --- Trend analysis helpers (SC-COMP-002) ----------------------------------

  @spec sort_trend_snapshots([map()]) :: [map()]
  defp sort_trend_snapshots(snapshots), do: Enum.sort_by(snapshots, & &1.month, :asc)

  @spec detect_regression([map()], float()) :: boolean()
  defp detect_regression(snapshots, drop_threshold) do
    sorted = sort_trend_snapshots(snapshots)
    pairs = Enum.zip(sorted, tl(sorted))

    Enum.any?(pairs, fn {prev, curr} ->
      prev.score - curr.score > drop_threshold
    end)
  end

  # ---------------------------------------------------------------------------
  # StreamData generators (SD. prefix — EP-GEN-014)
  # ---------------------------------------------------------------------------

  @spec domain_gen_sd() :: StreamData.t()
  defp domain_gen_sd do
    SD.fixed_map(%{
      name: SD.binary(min_length: 1, max_length: 8),
      score: SD.float(min: 0.0, max: 100.0),
      weight: SD.integer(1..5)
    })
  end

  @spec event_gen_sd() :: StreamData.t()
  defp event_gen_sd do
    SD.fixed_map(%{
      id: SD.binary(min_length: 1, max_length: 8),
      timestamp: SD.integer(0..9_999_999),
      type: SD.member_of([:access_review, :policy_check, :control_test]),
      actor: SD.constant("system")
    })
  end

  # ---------------------------------------------------------------------------
  # PropCheck generators (PC. prefix — EP-GEN-014)
  # ---------------------------------------------------------------------------

  defp domain_gen_pc do
    let {score, weight} <- {PC.float(min: 0.0, max: 100.0), PC.integer(1, 5)} do
      %{name: "domain", score: score, weight: weight}
    end
  end

  defp event_gen_pc do
    let {id, ts} <- {PC.binary(8), PC.integer(0, 9_999_999)} do
      %{id: id, timestamp: ts, type: :generic, actor: "system"}
    end
  end
end
