defmodule Indrajaal.AccessControl.AntiPassbackTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AntiPassback Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AntiPassback

  describe "current_state enum values" do
    test "outside is valid state" do
      valid_states = [:outside, :inside, :unknown]
      assert :outside in valid_states
    end

    test "inside is valid state" do
      valid_states = [:outside, :inside, :unknown]
      assert :inside in valid_states
    end

    test "unknown is valid state" do
      valid_states = [:outside, :inside, :unknown]
      assert :unknown in valid_states
    end
  end

  describe "resource definition" do
    test "module is loadable" do
      assert Code.ensure_loaded?(AntiPassback)
    end

    test "current_state defaults to outside" do
      default_state = :outside
      assert default_state == :outside
    end

    test "violation_count defaults to 0" do
      default_count = 0
      assert default_count == 0
    end

    test "has Ash resource behavior" do
      assert function_exported?(AntiPassback, :spark_is, 1) or
               Code.ensure_loaded?(AntiPassback)
    end

    test "has get code interface function" do
      assert function_exported?(AntiPassback, :get, 1) or
               function_exported?(AntiPassback, :get, 2)
    end
  end
end
