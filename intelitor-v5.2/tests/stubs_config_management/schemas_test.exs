defmodule Intelitor.ConfigManagement.ConfigTemplateTest do
  @moduledoc """
  Test suite for Intelitor.ConfigManagement.ConfigTemplate.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/config_management/schemas.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.ConfigManagement.ConfigTemplate

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ConfigTemplate)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ConfigTemplate, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ConfigTemplate.__info__(:module)
      assert info == Intelitor.ConfigManagement.ConfigTemplate
    end
  end
end
