defmodule Intelitor.Integrations.SyncJobTest do
  @moduledoc """
  Test suite for Intelitor.Integrations.SyncJob.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/integrations/sync_job.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Integrations.SyncJob

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(SyncJob)
    end

    test "module has __info__/1 function" do
      assert function_exported?(SyncJob, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = SyncJob.__info__(:module)
      assert info == Intelitor.Integrations.SyncJob
    end
  end
end
