defmodule Indrajaal.KMS.AnalyticsTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Analytics.
  Tests module existence and public API surface.
  Functions take explicit db path args — no running DB needed for surface tests.
  STAMP: SC-KMS-001 (SQLite/DuckDB only), SC-COG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Analytics

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Analytics)
    end
  end

  describe "public API surface" do
    test "exports init/2" do
      assert function_exported?(Analytics, :init, 2)
    end

    test "exports health_report/2" do
      assert function_exported?(Analytics, :health_report, 2)
    end

    test "exports event_stats/3" do
      assert function_exported?(Analytics, :event_stats, 3)
    end

    test "exports entropy_report/3" do
      assert function_exported?(Analytics, :entropy_report, 3)
    end

    test "exports activity_summary/2" do
      assert function_exported?(Analytics, :activity_summary, 2)
    end

    test "exports archive_events/4" do
      assert function_exported?(Analytics, :archive_events, 4)
    end

    test "exports query_archives/2" do
      assert function_exported?(Analytics, :query_archives, 2)
    end

    test "exports tree_stats/2" do
      assert function_exported?(Analytics, :tree_stats, 2)
    end
  end
end
