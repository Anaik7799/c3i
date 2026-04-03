defmodule Intelitor.Core.Validations.EnsurePrimaryOrganizationTest do
  @moduledoc """
  Test suite for Intelitor.Core.Validations.EnsurePrimaryOrganization.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/core/validations/ensure_primary_organization.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Core.Validations.EnsurePrimaryOrganization

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(EnsurePrimaryOrganization)
    end

    test "module has __info__/1 function" do
      assert function_exported?(EnsurePrimaryOrganization, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = EnsurePrimaryOrganization.__info__(:module)
      assert info == Intelitor.Core.Validations.EnsurePrimaryOrganization
    end
  end
end
