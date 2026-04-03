defmodule IndrajaalWeb.Prajna.Knowledge.ProductLiveTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.Prajna.Knowledge.ProductLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: Product knowledge management LiveView

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults
  - SC-KMS-001: SQLite+DuckDB only
  - SC-KMS-008: Feedback traceability mandatory

  ## TPS 5-Level RCA Context
  - L1 Symptom: Product knowledge screen not rendering
  - L5 Root Cause: Missing LiveView callback exports
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Prajna.Knowledge.ProductLive

  describe "ProductLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(ProductLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(ProductLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(ProductLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(ProductLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(ProductLive, :handle_info, 2)
    end

    test "status_color/1 is exported" do
      assert function_exported?(ProductLive, :status_color, 1)
    end

    test "priority_icon/1 is exported" do
      assert function_exported?(ProductLive, :priority_icon, 1)
    end
  end

  describe "status_color/1" do
    test "returns string for known status" do
      assert is_binary(ProductLive.status_color(:proposed))
      assert is_binary(ProductLive.status_color(:shipped))
      assert is_binary(ProductLive.status_color(:deprecated))
    end

    test "returns fallback string for unknown status" do
      assert is_binary(ProductLive.status_color(:unknown_status))
    end

    test "proposed status returns blue color class" do
      assert String.contains?(ProductLive.status_color(:proposed), "blue")
    end

    test "shipped status returns green color class" do
      assert String.contains?(ProductLive.status_color(:shipped), "green")
    end
  end

  describe "priority_icon/1" do
    test "returns string for known priority" do
      assert is_binary(ProductLive.priority_icon(:critical))
      assert is_binary(ProductLive.priority_icon(:high))
      assert is_binary(ProductLive.priority_icon(:medium))
      assert is_binary(ProductLive.priority_icon(:low))
    end

    test "returns fallback string for unknown priority" do
      assert is_binary(ProductLive.priority_icon(:unknown_priority))
    end
  end
end
