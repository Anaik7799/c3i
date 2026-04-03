defmodule IndrajaalWeb.Api.Mobile.Mixins.ConfigurationMixinTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Mixins.ConfigurationMixin.

  WHAT: Verifies the configuration mixin macro is correctly defined.
  WHY: Ensures shared configuration validation helpers are available.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Mixins.ConfigurationMixin

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Mixins.ConfigurationMixin)
    end
  end

  describe "public functions" do
    test "validate_required_configuration_fields/2 function exists" do
      assert function_exported?(ConfigurationMixin, :validate_required_configuration_fields, 2)
    end
  end
end
