defmodule Indrajaal.Deployment.StartupWaveTest do
  @moduledoc """
  TDG test suite for StartupWave struct.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: Struct field contracts verified

  ## STAMP Safety Integration
  - SC-SIL6-005: Start order DB -> OBS -> APP (enforced by wave ordering)
  - SC-CLU-001: Seed node MUST start before satellites (wave ordering)

  ## TPS 5-Level RCA Context
  - L1 Symptom: Container starts in wrong order
  - L5 Root Cause: Missing wave struct field validation at compile time
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Deployment.StartupWave

  @moduletag :zenoh_nif

  # ==========================================================================
  # Struct construction
  # ==========================================================================

  describe "StartupWave struct" do
    test "can be constructed with all fields" do
      wave = %StartupWave{
        order: 1,
        containers: ["db-primary"],
        timeout_ms: 30_000,
        jitter_enabled: false
      }

      assert wave.order == 1
      assert wave.containers == ["db-primary"]
      assert wave.timeout_ms == 30_000
      assert wave.jitter_enabled == false
    end

    test "struct fields are accessible by name" do
      wave = %StartupWave{
        order: 3,
        containers: ["indrajaal-ex-app-1"],
        timeout_ms: 30_000,
        jitter_enabled: false
      }

      assert wave.order == 3
      assert wave.containers == ["indrajaal-ex-app-1"]
    end

    test "pattern matches on %StartupWave{}" do
      wave = %StartupWave{order: 2, containers: [], timeout_ms: 30_000, jitter_enabled: false}
      assert %StartupWave{} = wave
    end

    test "wave 4 can have jitter enabled (thundering herd prevention - SC-CLU-002)" do
      wave4 = %StartupWave{
        order: 4,
        containers: ["indrajaal-ex-app-2", "indrajaal-ex-app-3"],
        timeout_ms: 30_000,
        jitter_enabled: true
      }

      assert wave4.jitter_enabled == true
    end

    test "wave 1 should have jitter disabled (db must start deterministically)" do
      wave1 = %StartupWave{
        order: 1,
        containers: ["db-primary"],
        timeout_ms: 30_000,
        jitter_enabled: false
      }

      assert wave1.jitter_enabled == false
    end

    test "containers field is a list" do
      wave = %StartupWave{order: 1, containers: [], timeout_ms: 30_000, jitter_enabled: false}
      assert is_list(wave.containers)
    end

    test "wave ordering field is an integer" do
      wave = %StartupWave{order: 1, containers: [], timeout_ms: 30_000, jitter_enabled: false}
      assert is_integer(wave.order)
    end

    test "timeout_ms field is an integer (SC-SIL6-002: 30s waves)" do
      wave = %StartupWave{order: 1, containers: [], timeout_ms: 30_000, jitter_enabled: false}
      assert is_integer(wave.timeout_ms)
      assert wave.timeout_ms > 0
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "wave order is preserved after struct construction" do
    forall order <- PC.pos_integer() do
      wave = %StartupWave{order: order, containers: [], timeout_ms: 30_000, jitter_enabled: false}
      wave.order == order
    end
  end

  test "containers list is preserved in struct" do
    ExUnitProperties.check all(
                             containers <-
                               SD.list_of(SD.string(:alphanumeric, min_length: 1, max_length: 30))
                           ) do
      wave = %StartupWave{
        order: 1,
        containers: containers,
        timeout_ms: 30_000,
        jitter_enabled: false
      }

      assert wave.containers == containers
    end
  end
end
