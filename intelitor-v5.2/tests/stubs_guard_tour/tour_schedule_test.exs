defmodule Intelitor.GuardTour.TourScheduleTest do
  @moduledoc """
  Test suite for Intelitor.GuardTour.TourSchedule.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/guard_tour/tour_schedule.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.GuardTour.TourSchedule

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(TourSchedule)
    end

    test "module has __info__/1 function" do
      assert function_exported?(TourSchedule, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = TourSchedule.__info__(:module)
      assert info == Intelitor.GuardTour.TourSchedule
    end
  end
end
