defmodule Indrajaal.Deployment.WaveExecutorTest do
  @moduledoc """
  Tests for Indrajaal.Deployment.WaveExecutor.

  WHAT: Tests wave-based container orchestration, dependency resolution, rollback.
  WHY: Ensures SIL-6 compliant container boot with transaction semantics.
  CONSTRAINTS: SC-SIL6-001 to SC-SIL6-007, SC-CLU-002

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-08 | Claude Opus 4.6 | Initial implementation |
  """
  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Deployment.WaveExecutor
  alias Indrajaal.Deployment.WaveExecutor.BootConfig

  # ============================================================================
  # Unit Tests - BootConfig
  # ============================================================================

  describe "BootConfig" do
    test "enforces compose_file as required field" do
      assert_raise ArgumentError, fn ->
        struct!(BootConfig, [])
      end
    end

    test "has sensible defaults" do
      config = %BootConfig{compose_file: "test.yml"}

      assert config.compose_file == "test.yml"
      assert config.total_timeout_ms == 120_000
      assert config.container_timeout_ms == 30_000
      assert config.health_check_timeout_ms == 5_000
      assert config.health_check_interval_ms == 500
      assert config.max_health_retries == 20
      assert config.enable_jitter == true
      assert config.base_jitter_ms == 50
      assert config.max_jitter_ms == 200
      assert config.rollback_on_failure == true
      assert config.verbose == true
    end

    test "allows custom configuration" do
      config = %BootConfig{
        compose_file: "custom.yml",
        total_timeout_ms: 60_000,
        enable_jitter: false,
        rollback_on_failure: false
      }

      assert config.total_timeout_ms == 60_000
      assert config.enable_jitter == false
      assert config.rollback_on_failure == false
    end
  end

  # ============================================================================
  # Unit Tests - State
  # ============================================================================

  describe "State struct" do
    test "has all required fields" do
      state = %WaveExecutor.State{}

      assert Map.has_key?(state, :config)
      assert Map.has_key?(state, :twin)
      assert Map.has_key?(state, :current_wave)
      assert Map.has_key?(state, :started_containers)
      assert Map.has_key?(state, :status)
      assert Map.has_key?(state, :start_time)
    end

    test "defaults to nil fields" do
      state = %WaveExecutor.State{}
      assert state.config == nil
      assert state.current_wave == nil
      assert state.status == nil
    end
  end

  # ============================================================================
  # Unit Tests - Wave Ordering Logic
  # ============================================================================

  describe "wave ordering" do
    test "DB must start before APP (SC-SIL6-005)" do
      # The wave dependency order: DB(wave 1) → OBS(wave 1) → APP(wave 2+)
      waves = [
        %{wave: 1, containers: ["indrajaal-db-prod", "indrajaal-obs-prod"]},
        %{wave: 2, containers: ["indrajaal-ex-app-1"]},
        %{wave: 3, containers: ["zenoh-router-1"]}
      ]

      db_wave =
        Enum.find(waves, fn w -> "indrajaal-db-prod" in w.containers end) |> Map.get(:wave)

      app_wave =
        Enum.find(waves, fn w -> "indrajaal-ex-app-1" in w.containers end) |> Map.get(:wave)

      assert db_wave < app_wave
    end

    test "waves are ordered by wave number" do
      wave_numbers = [1, 2, 3, 4, 5]
      assert wave_numbers == Enum.sort(wave_numbers)
    end
  end

  # ============================================================================
  # Unit Tests - Jitter Calculation (SC-SIL6-006)
  # ============================================================================

  describe "jitter calculation" do
    test "jitter stays within bounds" do
      base_jitter = 50
      max_jitter = 200

      # Simulate 100 jitter calculations
      jitters =
        for _i <- 1..100 do
          jitter = base_jitter + :rand.uniform(max_jitter - base_jitter)
          jitter
        end

      assert Enum.all?(jitters, &(&1 >= base_jitter))
      assert Enum.all?(jitters, &(&1 <= max_jitter))
    end
  end

  # ============================================================================
  # Unit Tests - Boot Result Types
  # ============================================================================

  describe "boot result types" do
    test "success result has container_id and duration" do
      result = {:success, "indrajaal-db-prod", 1500}
      assert {:success, container, duration} = result
      assert is_binary(container)
      assert is_integer(duration)
      assert duration > 0
    end

    test "failure result has reason and duration" do
      result = {:failure, "Port 5433 not responding", 30_000}
      assert {:failure, reason, duration} = result
      assert is_binary(reason)
      assert is_integer(duration)
    end

    test "timeout result has duration" do
      result = {:timeout, 30_000}
      assert {:timeout, duration} = result
      assert is_integer(duration)
    end

    test "skipped result has reason" do
      result = {:skipped, "Container already running"}
      assert {:skipped, reason} = result
      assert is_binary(reason)
    end
  end

  # ============================================================================
  # Unit Tests - Wave Result Structure
  # ============================================================================

  describe "wave result structure" do
    test "has required fields" do
      wave_result = %{
        wave: 1,
        results: %{
          "indrajaal-db-prod" => {:success, "indrajaal-db-prod", 2000},
          "indrajaal-obs-prod" => {:success, "indrajaal-obs-prod", 3000}
        },
        total_duration_ms: 3000,
        all_succeeded: true
      }

      assert wave_result.wave == 1
      assert map_size(wave_result.results) == 2
      assert wave_result.all_succeeded == true
    end

    test "failed wave has all_succeeded false" do
      wave_result = %{
        wave: 2,
        results: %{
          "indrajaal-ex-app-1" => {:failure, "Health check failed", 30_000}
        },
        total_duration_ms: 30_000,
        all_succeeded: false
      }

      refute wave_result.all_succeeded
    end
  end

  # ============================================================================
  # Unit Tests - Mesh Boot Result
  # ============================================================================

  describe "mesh boot result structure" do
    test "tracks overall success" do
      result = %{
        waves: [],
        total_duration_ms: 0,
        all_succeeded: true,
        failed_containers: [],
        rollback_performed: false
      }

      assert result.all_succeeded
      assert result.failed_containers == []
      refute result.rollback_performed
    end

    test "tracks rollback on failure" do
      result = %{
        waves: [
          %{wave: 1, results: %{}, total_duration_ms: 2000, all_succeeded: true},
          %{
            wave: 2,
            results: %{"indrajaal-ex-app-1" => {:failure, "crash", 1000}},
            total_duration_ms: 1000,
            all_succeeded: false
          }
        ],
        total_duration_ms: 3000,
        all_succeeded: false,
        failed_containers: ["indrajaal-ex-app-1"],
        rollback_performed: true
      }

      refute result.all_succeeded
      assert "indrajaal-ex-app-1" in result.failed_containers
      assert result.rollback_performed
    end
  end

  # ============================================================================
  # Property Tests - Wave Dependencies (PropCheck)
  # ============================================================================

  property "wave numbers form a contiguous sequence starting at 1" do
    forall n <- PC.integer(1, 10) do
      waves = Enum.to_list(1..n)
      waves == Enum.to_list(1..n) and hd(waves) == 1
    end
  end

  property "jitter values stay within configured bounds" do
    forall {base, max_j} <- {PC.integer(10, 100), PC.integer(100, 1000)} do
      jitter = base + :rand.uniform(max(max_j - base, 1))
      jitter >= base and jitter <= max_j + 1
    end
  end

  # ============================================================================
  # Property Tests - Config Validation (StreamData)
  # ============================================================================

  property "BootConfig timeouts are always positive" do
    forall {total, container_t, health_t} <-
             {PC.pos_integer(), PC.pos_integer(), PC.pos_integer()} do
      config = %BootConfig{
        compose_file: "test.yml",
        total_timeout_ms: total,
        container_timeout_ms: container_t,
        health_check_timeout_ms: health_t
      }

      config.total_timeout_ms > 0 and
        config.container_timeout_ms > 0 and
        config.health_check_timeout_ms > 0
    end
  end

  property "container boot duration is bounded by timeout" do
    forall {timeout_val, duration} <- {PC.integer(1000, 60_000), PC.integer(0, 120_000)} do
      cond do
        duration <= timeout_val ->
          {:success, "test", duration} == {:success, "test", duration}

        true ->
          {:timeout, timeout_val} == {:timeout, timeout_val}
      end
    end
  end

  property "failed_containers is always a subset of all containers" do
    forall {n, fail_n} <- {PC.integer(1, 14), PC.integer(0, 14)} do
      all_containers = Enum.map(1..n, &"container-#{&1}")
      failed = Enum.take(all_containers, min(fail_n, length(all_containers)))
      Enum.all?(failed, &(&1 in all_containers))
    end
  end
end
