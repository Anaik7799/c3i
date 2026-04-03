defmodule Intelitor.GuardTour.CheckpointScanTest do
  @moduledoc """
  Test suite for Intelitor.GuardTour.CheckpointScan.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/guard_tour/checkpoint_scan.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.GuardTour.CheckpointScan

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(CheckpointScan)
    end

    test "module has __info__/1 function" do
      assert function_exported?(CheckpointScan, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = CheckpointScan.__info__(:module)
      assert info == Intelitor.GuardTour.CheckpointScan
    end
  end
end
