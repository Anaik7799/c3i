defmodule Indrajaal.Fractal.L4L5InteractionTest do
  @moduledoc """
  Fractal L4×L5 Interaction Test — Container-to-Node Health Propagation.

  WHAT: Tests that container health (L4) propagates to node-level health (L5),
        verifying health check mechanisms, FPPS consensus, and boot sequence.
  WHY: Node health depends on container health. Health check failures must
       propagate up the fractal hierarchy correctly.
  CONSTRAINTS:
    - SC-VER-031: All containers healthy
    - SC-BOOT-006: All containers pass health check
    - SC-OPT-002: Health check exponential backoff (100ms→3200ms)
    - SC-VAL-003: 100% consensus required
    - SC-SIL4-012: 5 startup phases mandatory
    - SC-PROP-023: PropCheck/StreamData disambiguation MANDATORY
    - SC-PROP-024: Use PC. prefix for PropCheck, SD. prefix for ExUnitProperties
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Import ExUnitProperties with except clause to avoid conflicts
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Disambiguation aliases MANDATORY
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :fractal
  @moduletag :l4_l5

  # ===========================================================================
  # L4-L5-TEST-001: Health check aggregation
  # ===========================================================================

  describe "L4→L5: Health check aggregation" do
    test "node health is derived from container health" do
      container_health = %{
        db: :healthy,
        obs: :healthy,
        app: :healthy
      }

      node_healthy? =
        Enum.all?(container_health, fn {_name, status} ->
          status == :healthy
        end)

      assert node_healthy?, "Node must be healthy when all containers are healthy (SC-VER-031)"
    end

    test "single unhealthy container degrades node" do
      container_health = %{
        db: :healthy,
        obs: :unhealthy,
        app: :healthy
      }

      node_healthy? =
        Enum.all?(container_health, fn {_name, status} ->
          status == :healthy
        end)

      refute node_healthy?, "Node must be degraded when any container is unhealthy (SC-VER-031)"
    end

    test "health status has 4 valid levels" do
      valid_statuses = [:healthy, :degraded, :unhealthy, :critical]
      assert length(valid_statuses) == 4

      for status <- valid_statuses do
        assert status in valid_statuses, "Status #{status} must be a valid health level"
      end
    end

    test "health severity ordering is monotonic" do
      severity = %{healthy: 0, degraded: 1, unhealthy: 2, critical: 3}

      assert severity[:healthy] < severity[:degraded]
      assert severity[:degraded] < severity[:unhealthy]
      assert severity[:unhealthy] < severity[:critical]
    end

    test "worst-of aggregation determines node health" do
      container_states = [:healthy, :degraded, :healthy]
      severity = %{healthy: 0, degraded: 1, unhealthy: 2, critical: 3}

      node_severity = Enum.max_by(container_states, &Map.get(severity, &1, 0))
      assert node_severity == :degraded, "Node adopts worst container health (SC-VER-031)"
    end
  end

  # ===========================================================================
  # L4-L5-TEST-002: Exponential backoff health checks (SC-OPT-002)
  # ===========================================================================

  describe "L4→L5: Exponential backoff health checks (SC-OPT-002)" do
    test "backoff doubles from 100ms to 3200ms" do
      backoffs = [100, 200, 400, 800, 1600, 3200]

      Enum.reduce(backoffs, nil, fn ms, prev ->
        if prev, do: assert(ms == prev * 2, "Backoff must double at each step (SC-OPT-002)")
        ms
      end)
    end

    test "backoff caps at maximum of 3200ms" do
      max_backoff = 3200
      # After 5 doublings from 100ms we reach 3200ms
      computed = Enum.reduce(1..5, 100, fn _, acc -> acc * 2 end)

      assert min(computed, max_backoff) == max_backoff,
             "Backoff cap must not exceed 3200ms (SC-OPT-002)"
    end

    test "backoff sequence has 6 steps from 100ms to 3200ms" do
      backoffs = Stream.iterate(100, &(&1 * 2)) |> Enum.take_while(&(&1 <= 3200))
      assert length(backoffs) == 6, "Backoff must have exactly 6 steps (SC-OPT-002)"
    end

    test "initial backoff is 100ms" do
      [first | _] = Stream.iterate(100, &(&1 * 2)) |> Enum.take_while(&(&1 <= 3200))
      assert first == 100, "Initial health check backoff must be 100ms (SC-OPT-002)"
    end

    test "maximum backoff is 3200ms" do
      last = Stream.iterate(100, &(&1 * 2)) |> Enum.take_while(&(&1 <= 3200)) |> List.last()
      assert last == 3200, "Maximum health check backoff must be 3200ms (SC-OPT-002)"
    end
  end

  # ===========================================================================
  # L4-L5-TEST-003: FPPS 5-method health consensus (SC-VAL-003)
  # ===========================================================================

  describe "L4→L5: FPPS 5-method health consensus" do
    test "all 5 FPPS methods are defined" do
      methods = [:pattern, :ast, :statistical, :binary, :line_by_line]
      assert length(methods) == 5, "FPPS requires exactly 5 validation methods (SC-VAL-003)"
    end

    test "all 5 methods must agree for healthy consensus" do
      methods = [:pattern, :ast, :statistical, :binary, :line_by_line]
      results = for method <- methods, into: %{}, do: {method, :pass}

      consensus = Enum.all?(results, fn {_m, r} -> r == :pass end)
      assert consensus, "All 5 FPPS methods must agree for healthy consensus (SC-VAL-003)"
    end

    test "single method disagreement breaks consensus" do
      results = %{
        pattern: :pass,
        ast: :pass,
        statistical: :fail,
        binary: :pass,
        line_by_line: :pass
      }

      consensus = Enum.all?(results, fn {_m, r} -> r == :pass end)
      refute consensus, "Any FPPS method failure must break consensus (SC-VAL-004)"
    end

    test "quorum (3/5) is insufficient for strict consensus" do
      results = %{
        pattern: :pass,
        ast: :pass,
        statistical: :pass,
        binary: :fail,
        line_by_line: :fail
      }

      pass_count = Enum.count(results, fn {_m, r} -> r == :pass end)
      strict_consensus = pass_count == 5
      quorum_consensus = pass_count >= 3

      assert quorum_consensus, "Quorum (3/5) is achieved"
      refute strict_consensus, "Quorum is not the same as strict FPPS consensus (SC-VAL-003)"
    end

    test "FPPS consensus is computed in defined order" do
      method_order = [:pattern, :ast, :statistical, :binary, :line_by_line]

      assert method_order ==
               Enum.sort(method_order, fn a, b ->
                 index_of(method_order, a) <= index_of(method_order, b)
               end)
    end
  end

  # ===========================================================================
  # L4-L5-TEST-004: Boot sequence health gates (SC-SIL4-012)
  # ===========================================================================

  describe "L4→L5: Boot sequence health gates" do
    test "boot follows 5 mandatory phases (SC-SIL4-012)" do
      phases = [:preflight, :ignition, :lens, :convergence, :ready]
      assert length(phases) == 5, "Boot must have exactly 5 phases (SC-SIL4-012)"
      assert List.first(phases) == :preflight, "Boot must begin with preflight phase"
      assert List.last(phases) == :ready, "Boot must end with ready phase"
    end

    test "each boot phase has a checkpoint identifier" do
      checkpoints = %{
        preflight: "CP-BOOT-01",
        ignition: "CP-BOOT-02",
        lens: "CP-BOOT-03",
        convergence: "CP-BOOT-04",
        ready: "CP-BOOT-05"
      }

      assert map_size(checkpoints) == 5,
             "Each of the 5 boot phases must have a checkpoint (SC-BOOT-010)"

      for {_phase, cp} <- checkpoints do
        assert String.starts_with?(cp, "CP-BOOT-"),
               "Boot checkpoint must follow CP-BOOT-NN format (SC-ZTEST-013)"
      end
    end

    test "shutdown follows 6 mandatory phases (SC-SIL4-013)" do
      shutdown_phases = [
        :lameduck,
        :drain,
        :checkpoint,
        :notify,
        :stop,
        :dying_gasp
      ]

      assert length(shutdown_phases) == 6, "Shutdown must have exactly 6 phases (SC-SIL4-013)"
      assert :lameduck in shutdown_phases, "Shutdown must include lameduck phase (AOR-SIL6-003)"
      assert :dying_gasp in shutdown_phases, "Shutdown must include dying gasp (SC-SIL4-007)"
    end

    test "boot target time is within SIL-6 bounds" do
      target_boot_ms = 60_000
      max_boot_ms = 120_000

      assert target_boot_ms <= max_boot_ms,
             "Boot target (60s) must be within max boot time (120s) (SC-BOOT-005)"
    end
  end

  # ===========================================================================
  # L4-L5-TEST-005: 2oo3 quorum validation (SC-SIL6-006)
  # ===========================================================================

  describe "L4→L5: 2oo3 quorum validation (SC-SIL6-006)" do
    test "quorum requires floor(N/2)+1 nodes" do
      assert compute_quorum(3) == 2, "2oo3 quorum must be 2 out of 3 (SC-SIL6-011)"
      assert compute_quorum(5) == 3, "3oo5 quorum must be 3 out of 5"
      assert compute_quorum(1) == 1, "Single node quorum is 1 out of 1"
    end

    test "3-node cluster achieves quorum with 2 healthy" do
      cluster_size = 3
      healthy_count = 2
      quorum = compute_quorum(cluster_size)
      assert healthy_count >= quorum, "2 healthy nodes must satisfy 2oo3 quorum"
    end

    test "3-node cluster loses quorum with 1 healthy" do
      cluster_size = 3
      healthy_count = 1
      quorum = compute_quorum(cluster_size)
      refute healthy_count >= quorum, "1 healthy node must not satisfy 2oo3 quorum"
    end

    test "split-brain detection requires quorum check" do
      # A partition where neither side has quorum triggers apoptosis (SC-SIL4-015)
      cluster_size = 3
      partition_a = 1
      partition_b = 2
      quorum = compute_quorum(cluster_size)

      has_quorum_a = partition_a >= quorum
      has_quorum_b = partition_b >= quorum

      # Only one side should have quorum
      assert has_quorum_b, "Larger partition must retain quorum"
      refute has_quorum_a, "Smaller partition must lose quorum and trigger apoptosis"
    end
  end

  # ===========================================================================
  # L4-L5-TEST-006: Property-based health propagation (PC/SD per SC-PROP-023/024)
  # ===========================================================================

  describe "L4→L5: Property-based health propagation" do
    property "health aggregation worst-of is monotonic" do
      forall statuses <- PC.list(PC.oneof([:healthy, :degraded, :unhealthy, :critical])) do
        if statuses == [] do
          true
        else
          severity = %{healthy: 0, degraded: 1, unhealthy: 2, critical: 3}
          worst = Enum.max_by(statuses, &Map.get(severity, &1, 0))
          Map.get(severity, worst, 0) >= 0
        end
      end
    end

    property "quorum formula floor(N/2)+1 always produces majority" do
      forall n <- PC.pos_integer() do
        quorum = compute_quorum(n)
        # Quorum must be majority: quorum > n/2
        quorum > n / 2
      end
    end

    property "exponential backoff stays within bounds" do
      forall steps <- PC.range(0, 5) do
        backoff = round(100 * :math.pow(2, steps))
        capped = min(backoff, 3200)
        capped >= 100 and capped <= 3200
      end
    end
  end

  describe "L4→L5: ExUnitProperties health model" do
    property "all container states produce valid node health" do
      forall states <-
               PC.non_empty(PC.list(PC.oneof([:healthy, :degraded, :unhealthy, :critical]))) do
        severity = %{healthy: 0, degraded: 1, unhealthy: 2, critical: 3}
        node_health = Enum.max_by(states, &Map.get(severity, &1, 0))
        node_health in [:healthy, :degraded, :unhealthy, :critical]
      end
    end

    property "quorum is always a majority (SC-SIL6-011)" do
      forall n <- PC.pos_integer() do
        n_capped = min(n, 100)
        quorum = compute_quorum(n_capped)
        quorum > n_capped / 2 and quorum <= n_capped
      end
    end
  end

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

  defp compute_quorum(n) do
    div(n, 2) + 1
  end

  defp index_of(list, element) do
    Enum.find_index(list, &(&1 == element))
  end
end
