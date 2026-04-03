defmodule Indrajaal.Compliance.HelpersTest do
  @moduledoc """
  Tests for Indrajaal.Compliance.Helpers utility module (Ash.Changeset helpers).
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance.Helpers

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Helpers)
    end

    test "generate_numbered_identifier/3 is exported" do
      assert function_exported?(Helpers, :generate_numbered_identifier, 3)
    end

    test "apply_conditional_attribute/3 is exported" do
      assert function_exported?(Helpers, :apply_conditional_attribute, 3)
    end
  end

  describe "apply_conditional_attribute/3 nil guard" do
    test "returns changeset unchanged when value is nil" do
      # When value is nil, returns the first argument unchanged
      result = Helpers.apply_conditional_attribute(:my_changeset, :field, nil)
      assert result == :my_changeset
    end

    test "returns changeset unchanged for falsy value" do
      result = Helpers.apply_conditional_attribute(:my_changeset, :field, false)
      assert result == :my_changeset
    end
  end
end
