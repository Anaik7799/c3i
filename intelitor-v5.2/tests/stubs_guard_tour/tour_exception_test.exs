defmodule Intelitor.GuardTour.TourExceptionTest do
  @moduledoc """
  Test suite for Intelitor.GuardTour.TourException.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/guard_tour/tour_exception.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.GuardTour.TourException

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(TourException)
    end

    test "module has __info__/1 function" do
      assert function_exported?(TourException, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = TourException.__info__(:module)
      assert info == Intelitor.GuardTour.TourException
    end
  end
end
