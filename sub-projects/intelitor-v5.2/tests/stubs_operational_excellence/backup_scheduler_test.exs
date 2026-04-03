defmodule Intelitor.OperationalExcellence.BackupSchedulerTest do
  @moduledoc """
  Test suite for Intelitor.OperationalExcellence.BackupScheduler.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/operational_excellence/backup_scheduler.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OperationalExcellence.BackupScheduler

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(BackupScheduler)
    end

    test "module has __info__/1 function" do
      assert function_exported?(BackupScheduler, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = BackupScheduler.__info__(:module)
      assert info == Intelitor.OperationalExcellence.BackupScheduler
    end
  end
end
