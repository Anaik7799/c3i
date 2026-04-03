defmodule Intelitor.EctoMigrationDefaultsTest do
  @moduledoc """
  Test suite for Intelitor.EctoMigrationDefaults.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/ecto_migration_defaults.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.EctoMigrationDefaults

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(EctoMigrationDefaults)
    end

    test "module has __info__/1 function" do
      assert function_exported?(EctoMigrationDefaults, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = EctoMigrationDefaults.__info__(:module)
      assert info == Intelitor.EctoMigrationDefaults
    end
  end
end
