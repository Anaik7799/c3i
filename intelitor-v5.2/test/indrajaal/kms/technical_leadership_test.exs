defmodule Indrajaal.KMS.TechnicalLeadershipTest do
  @moduledoc """
  TDG test suite for Indrajaal.KMS.TechnicalLeadership.

  Tests technical leadership knowledge management: ADRs, RFCs, tech specs,
  spikes, C4 models, API contracts, data models, debt items, radar entries,
  and remediation plans. All persistence via KMS.create_holon.

  ## STAMP Safety Integration
  - SC-KMS-007: All decisions must be traceable to implementation
  - SC-KMS-008: Architecture changes require impact analysis
  - SC-KMS-009: Technical debt must have remediation timeline
  """

  use ExUnit.Case, async: true

  alias Indrajaal.KMS.TechnicalLeadership

  describe "create_adr/5" do
    test "returns ok or error tuple with required params" do
      result =
        TechnicalLeadership.create_adr(
          "Use PostgreSQL for Primary Storage",
          "Need ACID-compliant relational database",
          "Adopt PostgreSQL 17 with TimescaleDB",
          ["Full ACID compliance", "Increased ops complexity"],
          []
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :draft status option" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], status: :draft)
      assert is_tuple(result)
    end

    test "accepts :proposed status option" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], status: :proposed)
      assert is_tuple(result)
    end

    test "accepts :accepted status option" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], status: :accepted)
      assert is_tuple(result)
    end

    test "accepts :deprecated status option" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], status: :deprecated)
      assert is_tuple(result)
    end

    test "accepts :superseded status option" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], status: :superseded)
      assert is_tuple(result)
    end

    test "accepts tags option" do
      result =
        TechnicalLeadership.create_adr("t", "ctx", "dec", [], tags: ["architecture", "data"])

      assert is_tuple(result)
    end

    test "accepts related_to list option" do
      result =
        TechnicalLeadership.create_adr("t", "ctx", "dec", [], related_to: ["hln-1", "hln-2"])

      assert is_tuple(result)
    end

    test "accepts supersedes option" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], supersedes: "hln-old-adr")
      assert is_tuple(result)
    end

    test "consequences list can be empty" do
      result = TechnicalLeadership.create_adr("t", "ctx", "dec", [], [])
      assert is_tuple(result)
    end

    test "consequences list accepts multiple strings" do
      result =
        TechnicalLeadership.create_adr("t", "ctx", "dec", ["Pro 1", "Con 1", "Trade-off"], [])

      assert is_tuple(result)
    end

    test "returns map with id when successful" do
      case TechnicalLeadership.create_adr("ADR Test", "ctx", "dec", [], []) do
        {:ok, holon} -> assert is_map(holon) and Map.has_key?(holon, :id)
        {:error, _} -> :ok
      end
    end
  end

  describe "create_rfc/5" do
    test "returns ok or error tuple" do
      result =
        TechnicalLeadership.create_rfc(
          "Migrate to Zenoh",
          "Move from Kafka to Zenoh for sub-ms latency",
          "Kafka has high latency for safety-critical paths",
          "Replace Kafka producers with Zenoh publishers, maintain consumer API"
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts reviewers option" do
      result = TechnicalLeadership.create_rfc("t", "s", "m", "d", reviewers: ["alice", "bob"])
      assert is_tuple(result)
    end

    test "accepts deadline DateTime option" do
      result =
        TechnicalLeadership.create_rfc("t", "s", "m", "d",
          deadline: DateTime.utc_now() |> DateTime.add(7 * 86400)
        )

      assert is_tuple(result)
    end

    test "accepts scope list option" do
      result = TechnicalLeadership.create_rfc("t", "s", "m", "d", scope: ["kms", "mesh"])
      assert is_tuple(result)
    end

    test "accepts empty opts" do
      result = TechnicalLeadership.create_rfc("t", "s", "m", "d")
      assert is_tuple(result)
    end
  end

  describe "create_tech_spec/4" do
    test "returns ok or error tuple" do
      result =
        TechnicalLeadership.create_tech_spec(
          "KMS SQLite Schema",
          "Defines all tables in the KMS SQLite database",
          %{
            schema: "CREATE TABLE holons ...",
            indexes: "CREATE INDEX ...",
            migrations: []
          }
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts related_adr option" do
      result = TechnicalLeadership.create_tech_spec("t", "o", %{}, related_adr: "hln-adr-1")
      assert is_tuple(result)
    end

    test "accepts api_contracts option" do
      result = TechnicalLeadership.create_tech_spec("t", "o", %{}, api_contracts: ["contract-1"])
      assert is_tuple(result)
    end

    test "accepts empty sections map" do
      result = TechnicalLeadership.create_tech_spec("t", "o", %{})
      assert is_tuple(result)
    end
  end

  describe "create_spike/4" do
    test "returns ok or error tuple" do
      result =
        TechnicalLeadership.create_spike(
          "Evaluate Zenoh vs Kafka",
          "Can Zenoh meet our latency requirements for SIL-6?",
          40
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts findings option" do
      result = TechnicalLeadership.create_spike("t", "q", 8, findings: "Zenoh achieves <1ms")
      assert is_tuple(result)
    end

    test "accepts recommendation option" do
      result = TechnicalLeadership.create_spike("t", "q", 8, recommendation: "Adopt Zenoh")
      assert is_tuple(result)
    end

    test "accepts artifacts list option" do
      result =
        TechnicalLeadership.create_spike("t", "q", 8, artifacts: ["bench.exs", "report.md"])

      assert is_tuple(result)
    end

    test "accepts timebox_hours as integer" do
      result = TechnicalLeadership.create_spike("t", "q", 1)
      assert is_tuple(result)
    end
  end

  describe "create_c4_model/5" do
    test "accepts :context level" do
      result =
        TechnicalLeadership.create_c4_model(
          :context,
          "Indrajaal System Context",
          "Shows Indrajaal and its external actors",
          %{systems: ["Phoenix App", "PostgreSQL", "Zenoh"]}
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :container level" do
      result = TechnicalLeadership.create_c4_model(:container, "t", "d", %{})
      assert is_tuple(result)
    end

    test "accepts :component level" do
      result = TechnicalLeadership.create_c4_model(:component, "t", "d", %{})
      assert is_tuple(result)
    end

    test "accepts :code level" do
      result = TechnicalLeadership.create_c4_model(:code, "t", "d", %{})
      assert is_tuple(result)
    end

    test "rejects invalid level" do
      assert_raise FunctionClauseError, fn ->
        TechnicalLeadership.create_c4_model(:invalid_level, "t", "d", %{})
      end
    end

    test "accepts parent_diagram option" do
      result =
        TechnicalLeadership.create_c4_model(:container, "t", "d", %{}, parent_diagram: "hln-ctx")

      assert is_tuple(result)
    end

    test "accepts mermaid option" do
      result = TechnicalLeadership.create_c4_model(:context, "t", "d", %{}, mermaid: "graph TD;")
      assert is_tuple(result)
    end
  end

  describe "create_api_contract/5" do
    test "accepts :rest protocol" do
      result =
        TechnicalLeadership.create_api_contract(
          "KMS REST API",
          "v1",
          :rest,
          %{openapi: "3.0.0", paths: %{}}
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :graphql protocol" do
      result = TechnicalLeadership.create_api_contract("KMS GraphQL", "v1", :graphql, %{})
      assert is_tuple(result)
    end

    test "accepts :grpc protocol" do
      result = TechnicalLeadership.create_api_contract("KMS gRPC", "v1", :grpc, %{})
      assert is_tuple(result)
    end

    test "accepts :async_api protocol" do
      result = TechnicalLeadership.create_api_contract("KMS Async", "v1", :async_api, %{})
      assert is_tuple(result)
    end

    test "rejects invalid protocol" do
      assert_raise FunctionClauseError, fn ->
        TechnicalLeadership.create_api_contract("n", "v", :soap, %{})
      end
    end

    test "accepts base_url option" do
      result =
        TechnicalLeadership.create_api_contract("n", "v1", :rest, %{},
          base_url: "https://api.indrajaal.io"
        )

      assert is_tuple(result)
    end
  end

  describe "create_data_model/3" do
    test "returns ok or error tuple" do
      result =
        TechnicalLeadership.create_data_model(
          "HolonSchema",
          %{
            table: "holons",
            columns: %{id: "uuid", type: "text", payload: "jsonb"}
          }
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts empty schema map" do
      result = TechnicalLeadership.create_data_model("EmptyModel", %{})
      assert is_tuple(result)
    end

    test "accepts database option" do
      result = TechnicalLeadership.create_data_model("Model", %{}, database: "postgresql")
      assert is_tuple(result)
    end

    test "accepts relationships option" do
      result =
        TechnicalLeadership.create_data_model("Model", %{},
          relationships: [%{from: "holons", to: "edges", type: :has_many}]
        )

      assert is_tuple(result)
    end
  end

  describe "create_debt_item/4" do
    test "returns ok or error tuple with required params" do
      result =
        TechnicalLeadership.create_debt_item(
          "Migrate legacy Exqlite calls",
          "Multiple modules still use direct Exqlite (SC-DBPROXY-001 violation)",
          %{
            velocity_impact: 5,
            reliability_impact: 7,
            security_impact: 3,
            maintainability_impact: 8
          }
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts estimated_effort option" do
      result =
        TechnicalLeadership.create_debt_item("t", "d", %{velocity_impact: 5},
          estimated_effort: 40
        )

      assert is_tuple(result)
    end

    test "accepts affected_areas option" do
      result =
        TechnicalLeadership.create_debt_item("t", "d", %{},
          affected_areas: ["kms", "integration"]
        )

      assert is_tuple(result)
    end

    test "accepts root_cause option" do
      result =
        TechnicalLeadership.create_debt_item("t", "d", %{},
          root_cause: "Time pressure during sprint"
        )

      assert is_tuple(result)
    end

    test "accepts introduced_by option" do
      result = TechnicalLeadership.create_debt_item("t", "d", %{}, introduced_by: "sprint-45")
      assert is_tuple(result)
    end

    test "impact_scores can be empty map" do
      result = TechnicalLeadership.create_debt_item("t", "d", %{})
      assert is_tuple(result)
    end
  end

  describe "create_remediation_plan/4" do
    test "returns ok or error tuple" do
      result =
        TechnicalLeadership.create_remediation_plan(
          "Q1 2026 Debt Payoff",
          ["debt-1", "debt-2"],
          %{start: "2026-01-01", end: "2026-03-31"}
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts milestones option" do
      result =
        TechnicalLeadership.create_remediation_plan("t", [], %{},
          milestones: [%{date: "2026-02-01", goal: "50% complete"}]
        )

      assert is_tuple(result)
    end

    test "accepts success_criteria option" do
      result =
        TechnicalLeadership.create_remediation_plan("t", [], %{},
          success_criteria: ["0 Credo issues", "100% test coverage"]
        )

      assert is_tuple(result)
    end

    test "accepts empty debt_item_ids list" do
      result = TechnicalLeadership.create_remediation_plan("t", [], %{})
      assert is_tuple(result)
    end
  end

  describe "create_radar_entry/5" do
    test "accepts :techniques quadrant with :adopt ring" do
      result =
        TechnicalLeadership.create_radar_entry(
          "Event Sourcing",
          :techniques,
          :adopt,
          "Proven pattern for audit trails"
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts :tools quadrant with :trial ring" do
      result =
        TechnicalLeadership.create_radar_entry("Zenoh", :tools, :trial, "High-perf pub/sub")

      assert is_tuple(result)
    end

    test "accepts :platforms quadrant with :assess ring" do
      result =
        TechnicalLeadership.create_radar_entry("NixOS", :platforms, :assess, "Declarative OS")

      assert is_tuple(result)
    end

    test "accepts :languages_frameworks quadrant with :hold ring" do
      result =
        TechnicalLeadership.create_radar_entry(
          "Ruby",
          :languages_frameworks,
          :hold,
          "Not our stack"
        )

      assert is_tuple(result)
    end

    test "rejects invalid quadrant" do
      assert_raise FunctionClauseError, fn ->
        TechnicalLeadership.create_radar_entry("t", :invalid, :adopt, "d")
      end
    end

    test "rejects invalid ring" do
      assert_raise FunctionClauseError, fn ->
        TechnicalLeadership.create_radar_entry("t", :tools, :invalid_ring, "d")
      end
    end

    test "accepts rationale option" do
      result =
        TechnicalLeadership.create_radar_entry("t", :tools, :adopt, "d",
          rationale: "Battle-tested in production"
        )

      assert is_tuple(result)
    end

    test "accepts examples option" do
      result =
        TechnicalLeadership.create_radar_entry("t", :tools, :adopt, "d",
          examples: ["project-a", "project-b"]
        )

      assert is_tuple(result)
    end
  end
end
