defmodule Indrajaal.Core.CliEnvelopeJsonOutputTest do
  @moduledoc """
  TDG test suite for CLI envelope --json output for machine consumption (L5).

  WHAT: Validates that the simulated envelope CLI JSON output is structurally correct,
        machine-parseable, contains required fields, respects latency budgets, and
        behaves correctly under various section filters and edge cases. ETS-backed
        simulation — no production module dependencies.

  WHY: The `envelope` command is the primary machine-readable interface for external
       tooling, CI/CD pipelines, and Zenoh consumers to inspect system capability.
       Incorrect JSON structure or schema breaks downstream automation and violates
       SIL-6 observability mandates.

  CONSTRAINTS:
  - SC-CMD-027: envelope SHALL display capability dashboard
  - SC-PRF-050: Response < 50ms
  - SC-OBS-069: Dual log (Term+SigNoz)
  - SC-BRIDGE-001: Message buffer FIFO
  - SC-OPT-001: Boot time < 60s (envelope must not block boot)
  - Ω₃ Zero-Defect: 0 errors, 0 warnings, 0 test failures

  ## Constitutional Verification
  - Ψ₃ (Verification): JSON output is deterministic and reproducible
  - Ψ₅ (Truthfulness): Metrics reflect actual ETS state, no hallucinated data

  ## Change History
  | Version | Date       | Author | Change                                           |
  |---------|------------|--------|--------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave — CLI envelope JSON output suite  |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :cli
  @moduletag :envelope
  @moduletag :json
  @moduletag :sprint_88

  @latency_budget_ms 50
  @valid_sections ~w(health agents containers metrics all)
  @required_top_level_keys ~w(version health agents containers metrics timestamp)

  # ---------------------------------------------------------------------------
  # ETS-backed state engine
  # ---------------------------------------------------------------------------

  defp table_name do
    :"envelope_json_test_#{:erlang.unique_integer([:positive])}"
  end

  defp create_table(name) do
    :ets.new(name, [:set, :public, :named_table])
  end

  defp seed_state(table, opts \\ []) do
    health_score = Keyword.get(opts, :health_score, 0.91)
    agent_count = Keyword.get(opts, :agent_count, 12)
    containers = Keyword.get(opts, :containers, default_containers())
    metrics = Keyword.get(opts, :metrics, default_metrics())

    :ets.insert(table, {:health_score, health_score})
    :ets.insert(table, {:agent_count, agent_count})
    :ets.insert(table, {:containers, containers})
    :ets.insert(table, {:metrics, metrics})
    table
  end

  defp default_containers do
    [
      %{name: "indrajaal-db-prod", status: "healthy", port: 5433},
      %{name: "indrajaal-obs-prod", status: "healthy", port: 4317},
      %{name: "indrajaal-ex-app-1", status: "healthy", port: 4000},
      %{name: "zenoh-router", status: "healthy", port: 7447}
    ]
  end

  defp default_metrics do
    %{
      cpu: 34.2,
      memory: 61.5,
      uptime: 86_400
    }
  end

  defp fetch(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Envelope JSON engine (simulated)
  # ---------------------------------------------------------------------------

  defp build_envelope(table) do
    %{
      "version" => "21.3.0-SIL6",
      "timestamp" => iso8601_now(),
      "health" => build_health_section(table),
      "agents" => build_agents_section(table),
      "containers" => build_containers_section(table),
      "metrics" => build_metrics_section(table)
    }
  end

  defp build_health_section(table) do
    score = fetch(table, :health_score) || 1.0

    %{
      "score" => score,
      "status" => health_status(score),
      "sentinel" => "active",
      "guardian" => "active"
    }
  end

  defp build_agents_section(table) do
    count = fetch(table, :agent_count) || 0

    %{
      "count" => count,
      "active" => count,
      "idle" => 0
    }
  end

  defp build_containers_section(table) do
    containers = fetch(table, :containers) || []

    Enum.map(containers, fn c ->
      %{
        "name" => c.name,
        "status" => c.status,
        "port" => c.port
      }
    end)
  end

  defp build_metrics_section(table) do
    m = fetch(table, :metrics) || default_metrics()

    %{
      "cpu" => m.cpu,
      "memory" => m.memory,
      "uptime" => m.uptime
    }
  end

  defp health_status(score) when score >= 0.9, do: "healthy"
  defp health_status(score) when score >= 0.7, do: "degraded"
  defp health_status(_), do: "critical"

  defp iso8601_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  # Render modes
  defp render_json(envelope, :pretty) do
    Jason.encode!(envelope, pretty: true)
  end

  defp render_json(envelope, :compact) do
    Jason.encode!(envelope)
  end

  defp render_section(envelope, section) when section in @valid_sections do
    section_data =
      case section do
        "all" -> envelope
        key -> Map.get(envelope, key, :not_found)
      end

    case section_data do
      :not_found ->
        Jason.encode!(%{"error" => "unknown section: #{section}"})

      data ->
        Jason.encode!(data)
    end
  end

  defp render_section(_envelope, unknown_section) do
    Jason.encode!(%{"error" => "unknown section: #{unknown_section}"})
  end

  defp generate_envelope(table) do
    t0 = System.monotonic_time(:millisecond)
    envelope = build_envelope(table)
    json = render_json(envelope, :compact)
    elapsed = System.monotonic_time(:millisecond) - t0
    {json, elapsed}
  end

  # ---------------------------------------------------------------------------
  # Test setup helpers
  # ---------------------------------------------------------------------------

  defp setup_table(opts \\ []) do
    t = table_name()
    create_table(t)
    seed_state(t, opts)
    t
  end

  defp cleanup(table) do
    :ets.delete(table)
  rescue
    _ -> :ok
  end

  # ---------------------------------------------------------------------------
  # Test group 1: JSON validity
  # ---------------------------------------------------------------------------

  describe "JSON output validity" do
    test "JSON output is parseable by Jason" do
      table = setup_table()

      try do
        {json, _} = generate_envelope(table)
        assert {:ok, _decoded} = Jason.decode(json)
      after
        cleanup(table)
      end
    end

    test "JSON output contains all required top-level keys" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        json = render_json(envelope, :compact)
        {:ok, decoded} = Jason.decode(json)

        for key <- @required_top_level_keys do
          assert Map.has_key?(decoded, key),
                 "Missing required key: #{key}. Got: #{inspect(Map.keys(decoded))}"
        end
      after
        cleanup(table)
      end
    end

    test "version field is a non-empty string" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert is_binary(decoded["version"])
        assert String.length(decoded["version"]) > 0
      after
        cleanup(table)
      end
    end

    test "timestamp field is ISO 8601 format" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        ts = decoded["timestamp"]
        assert is_binary(ts), "timestamp must be a string"

        assert {:ok, _dt, _offset} = DateTime.from_iso8601(ts),
               "timestamp must parse as ISO 8601: #{ts}"
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 2: Health section
  # ---------------------------------------------------------------------------

  describe "health section" do
    test "health score is a float between 0.0 and 1.0" do
      table = setup_table(health_score: 0.75)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        score = decoded["health"]["score"]
        assert is_float(score) or is_integer(score)
        assert score >= 0.0
        assert score <= 1.0
      after
        cleanup(table)
      end
    end

    test "health score 0.91 → status healthy" do
      table = setup_table(health_score: 0.91)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["health"]["status"] == "healthy"
      after
        cleanup(table)
      end
    end

    test "health score 0.75 → status degraded" do
      table = setup_table(health_score: 0.75)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["health"]["status"] == "degraded"
      after
        cleanup(table)
      end
    end

    test "health score 0.5 → status critical" do
      table = setup_table(health_score: 0.5)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["health"]["status"] == "critical"
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 3: Agent and container sections
  # ---------------------------------------------------------------------------

  describe "agents section" do
    test "agent count is a non-negative integer" do
      table = setup_table(agent_count: 7)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        count = decoded["agents"]["count"]
        assert is_integer(count)
        assert count >= 0
      after
        cleanup(table)
      end
    end

    test "agent count matches seeded value" do
      table = setup_table(agent_count: 25)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["agents"]["count"] == 25
      after
        cleanup(table)
      end
    end
  end

  describe "containers section" do
    test "containers is a JSON array" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert is_list(decoded["containers"])
      after
        cleanup(table)
      end
    end

    test "each container object has name, status, and port fields" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))

        for c <- decoded["containers"] do
          assert Map.has_key?(c, "name"), "Container missing 'name'"
          assert Map.has_key?(c, "status"), "Container missing 'status'"
          assert Map.has_key?(c, "port"), "Container missing 'port'"
        end
      after
        cleanup(table)
      end
    end

    test "empty container list produces valid JSON with empty array" do
      table = setup_table(containers: [])

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["containers"] == []
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 4: Metrics section
  # ---------------------------------------------------------------------------

  describe "metrics section" do
    test "metrics includes cpu, memory, and uptime fields" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        m = decoded["metrics"]
        assert Map.has_key?(m, "cpu"), "Missing 'cpu' in metrics"
        assert Map.has_key?(m, "memory"), "Missing 'memory' in metrics"
        assert Map.has_key?(m, "uptime"), "Missing 'uptime' in metrics"
      after
        cleanup(table)
      end
    end

    test "cpu and memory are numeric" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert is_number(decoded["metrics"]["cpu"])
        assert is_number(decoded["metrics"]["memory"])
      after
        cleanup(table)
      end
    end

    test "uptime is a non-negative integer" do
      table = setup_table()

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        uptime = decoded["metrics"]["uptime"]
        assert is_integer(uptime)
        assert uptime >= 0
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 5: Render modes
  # ---------------------------------------------------------------------------

  describe "render modes" do
    test "pretty-print mode produces indented JSON" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        pretty = render_json(envelope, :pretty)
        assert String.contains?(pretty, "\n"), "Pretty JSON must contain newlines"
        # Jason pretty uses 2-space indent by default
        assert String.contains?(pretty, "  "), "Pretty JSON must contain indentation"
      after
        cleanup(table)
      end
    end

    test "compact mode produces single-line JSON (no internal newlines)" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        compact = render_json(envelope, :compact)
        refute String.contains?(compact, "\n"), "Compact JSON must not contain newlines"
      after
        cleanup(table)
      end
    end

    test "both pretty and compact modes produce identical decoded structures" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        {:ok, from_pretty} = Jason.decode(render_json(envelope, :pretty))
        {:ok, from_compact} = Jason.decode(render_json(envelope, :compact))
        assert from_pretty == from_compact
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 6: Section filtering
  # ---------------------------------------------------------------------------

  describe "section filtering" do
    test "--section health returns only health data as valid JSON" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        json = render_section(envelope, "health")
        {:ok, decoded} = Jason.decode(json)
        assert Map.has_key?(decoded, "score")
        assert Map.has_key?(decoded, "status")
        refute Map.has_key?(decoded, "containers"), "Should not contain containers section"
      after
        cleanup(table)
      end
    end

    test "--section agents returns only agents data as valid JSON" do
      table = setup_table(agent_count: 5)

      try do
        envelope = build_envelope(table)
        json = render_section(envelope, "agents")
        {:ok, decoded} = Jason.decode(json)
        assert Map.has_key?(decoded, "count")
        assert decoded["count"] == 5
      after
        cleanup(table)
      end
    end

    test "--section all returns the full envelope" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        json = render_section(envelope, "all")
        {:ok, decoded} = Jason.decode(json)

        for key <- @required_top_level_keys do
          assert Map.has_key?(decoded, key), "Missing key #{key} in 'all' section"
        end
      after
        cleanup(table)
      end
    end

    test "invalid section returns JSON error object with 'error' key" do
      table = setup_table()

      try do
        envelope = build_envelope(table)
        json = render_section(envelope, "nonexistent_section_xyz")
        {:ok, decoded} = Jason.decode(json)
        assert Map.has_key?(decoded, "error"), "Error response must have 'error' key"
        assert is_binary(decoded["error"])
        assert String.length(decoded["error"]) > 0
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 7: Performance and determinism
  # ---------------------------------------------------------------------------

  describe "performance and determinism" do
    test "JSON generation completes in < #{@latency_budget_ms}ms (SC-PRF-050)" do
      table = setup_table()

      try do
        {_json, elapsed_ms} = generate_envelope(table)

        assert elapsed_ms < @latency_budget_ms,
               "JSON generation took #{elapsed_ms}ms, exceeds #{@latency_budget_ms}ms budget"
      after
        cleanup(table)
      end
    end

    test "same ETS state produces identical JSON output (deterministic)" do
      table = setup_table(health_score: 0.88, agent_count: 10)

      try do
        # Build twice from same state — only timestamp will differ
        e1 = build_envelope(table)
        e2 = build_envelope(table)

        # All sections except timestamp must be identical
        assert e1["version"] == e2["version"]
        assert e1["health"] == e2["health"]
        assert e1["agents"] == e2["agents"]
        assert e1["containers"] == e2["containers"]
        assert e1["metrics"] == e2["metrics"]
      after
        cleanup(table)
      end
    end

    test "repeated JSON generation is consistently fast" do
      table = setup_table()

      try do
        times =
          for _ <- 1..10 do
            {_, elapsed} = generate_envelope(table)
            elapsed
          end

        max_ms = Enum.max(times)

        assert max_ms < @latency_budget_ms,
               "Worst case latency #{max_ms}ms exceeded #{@latency_budget_ms}ms budget"
      after
        cleanup(table)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Property-based tests (ExUnitProperties / StreamData)
  # ---------------------------------------------------------------------------

  describe "property-based: envelope validity" do
    test "property: random health/agent/container counts always produce valid JSON" do
      check all(
              health_score <- SD.float(min: 0.0, max: 1.0),
              agent_count <- SD.integer(0..200),
              container_count <- SD.integer(0..20)
            ) do
        table = table_name()
        create_table(table)

        containers =
          if container_count > 0 do
            for i <- 1..container_count do
              %{name: "container-#{i}", status: "healthy", port: 4000 + i}
            end
          else
            []
          end

        seed_state(table,
          health_score: health_score,
          agent_count: agent_count,
          containers: containers
        )

        try do
          {json, _} = generate_envelope(table)
          assert {:ok, decoded} = Jason.decode(json)
          assert is_map(decoded)

          for key <- @required_top_level_keys do
            assert Map.has_key?(decoded, key)
          end

          assert decoded["agents"]["count"] == agent_count
          assert length(decoded["containers"]) == container_count
          score = decoded["health"]["score"]
          assert score >= 0.0 and score <= 1.0
        after
          :ets.delete(table)
        end
      end
    end

    test "property: random section filters always return valid JSON or structured error" do
      valid_section_gen =
        SD.one_of([
          SD.constant("health"),
          SD.constant("agents"),
          SD.constant("containers"),
          SD.constant("metrics"),
          SD.constant("all"),
          SD.string(:alphanumeric, min_length: 1, max_length: 20)
        ])

      check all(section <- valid_section_gen) do
        table = table_name()
        create_table(table)
        seed_state(table)

        try do
          envelope = build_envelope(table)
          json = render_section(envelope, section)

          assert {:ok, decoded} = Jason.decode(json),
                 "Section #{inspect(section)} produced invalid JSON: #{json}"

          assert is_map(decoded) or is_list(decoded),
                 "Section output must be a map or list, got: #{inspect(decoded)}"
        after
          :ets.delete(table)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test group 8: Edge cases
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    test "system with no containers produces valid JSON with empty array" do
      table = setup_table(containers: [])

      try do
        {json, _} = generate_envelope(table)
        {:ok, decoded} = Jason.decode(json)
        assert decoded["containers"] == []
        assert is_list(decoded["containers"])
      after
        cleanup(table)
      end
    end

    test "zero agent count is valid and serialises correctly" do
      table = setup_table(agent_count: 0)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["agents"]["count"] == 0
      after
        cleanup(table)
      end
    end

    test "boundary health score 0.0 serialises as healthy:critical" do
      table = setup_table(health_score: 0.0)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["health"]["score"] == 0.0
        assert decoded["health"]["status"] == "critical"
      after
        cleanup(table)
      end
    end

    test "boundary health score 1.0 serialises as healthy:healthy" do
      table = setup_table(health_score: 1.0)

      try do
        {:ok, decoded} = Jason.decode(render_json(build_envelope(table), :compact))
        assert decoded["health"]["score"] == 1.0
        assert decoded["health"]["status"] == "healthy"
      after
        cleanup(table)
      end
    end
  end
end
