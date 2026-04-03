defmodule Indrajaal.GuardTour.TourExceptionTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.GuardTour.TourException.

  Sprint 54 — 100% module coverage.
  Ash resource — tests module loading and info queries only (no DB).

  ## STAMP Compliance
  - SC-COV-001: Module coverage
  - SC-DB-001: BaseResource usage
  - SC-DB-005: uuid_primary_key
  """

  use ExUnit.Case, async: true

  alias Indrajaal.GuardTour.TourException

  @moduletag :zenoh_nif

  describe "module existence" do
    test "TourException module is loaded" do
      assert Code.ensure_loaded?(TourException)
    end
  end

  describe "Ash resource info" do
    test "has expected attributes" do
      attrs = Ash.Resource.Info.attributes(TourException)
      attr_names = Enum.map(attrs, & &1.name)

      assert :id in attr_names
      assert :exception_type in attr_names
      assert :severity in attr_names
      assert :detected_at in attr_names
      assert :description in attr_names
      assert :resolved_at in attr_names
      assert :resolution_notes in attr_names
    end

    test "has expected relationships" do
      rels = Ash.Resource.Info.relationships(TourException)
      rel_names = Enum.map(rels, & &1.name)

      assert :execution in rel_names
      assert :checkpoint in rel_names
      assert :reported_by in rel_names
      assert :resolved_by in rel_names
    end

    test "has report_exception action" do
      actions = Ash.Resource.Info.actions(TourException)
      action_names = Enum.map(actions, & &1.name)
      assert :report_exception in action_names
    end

    test "has resolve_exception action" do
      actions = Ash.Resource.Info.actions(TourException)
      action_names = Enum.map(actions, & &1.name)
      assert :resolve_exception in action_names
    end
  end
end
