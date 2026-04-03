defmodule Indrajaal.GuardTour.TourRouteIntrospectionTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Ash resource introspection tests for TourRoute without DB connections.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-DB-001: BaseResource usage verified
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.GuardTour.TourRoute

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TourRoute)
    end
  end

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(TourRoute)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(TourRoute)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "activate is a create action" do
      actions = Ash.Resource.Info.actions(TourRoute)
      activate = Enum.find(actions, &(&1.name == :activate))
      assert activate.type == :create
    end

    test "deactivate is an update action" do
      actions = Ash.Resource.Info.actions(TourRoute)
      deactivate = Enum.find(actions, &(&1.name == :deactivate))
      assert deactivate.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(TourRoute)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :route_type in attr_names
      assert :estimated_duration in attr_names
      assert :is_active in attr_names
      assert :priority_level in attr_names
    end

    test "domain is GuardTour" do
      assert Ash.Resource.Info.domain(TourRoute) == Indrajaal.GuardTour
    end
  end
end
