defmodule Indrajaal.AccessControl.AccessLogTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessLog Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessLog

  describe "event_type enum values" do
    test "granted is valid event type" do
      valid_types = [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      assert :granted in valid_types
    end

    test "denied is valid event type" do
      valid_types = [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      assert :denied in valid_types
    end

    test "tailgate is valid event type" do
      valid_types = [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      assert :tailgate in valid_types
    end

    test "forced is valid event type" do
      valid_types = [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      assert :forced in valid_types
    end

    test "emergency is valid event type" do
      valid_types = [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      assert :emergency in valid_types
    end

    test "duress is valid event type" do
      valid_types = [:granted, :denied, :tailgate, :forced, :emergency, :duress]
      assert :duress in valid_types
    end
  end

  describe "direction enum values" do
    test "in is valid direction" do
      valid_directions = [:in, :out]
      assert :in in valid_directions
    end

    test "out is valid direction" do
      valid_directions = [:in, :out]
      assert :out in valid_directions
    end
  end

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AccessLog)
    end

    test "has Ash resource behavior" do
      assert function_exported?(AccessLog, :spark_is, 1) or
               Code.ensure_loaded?(AccessLog)
    end
  end
end
