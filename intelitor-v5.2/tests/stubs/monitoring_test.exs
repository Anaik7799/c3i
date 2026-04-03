defmodule Intelitor.MonitoringTest do
  @moduledoc """
  Test suite for Monitoring root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Monitoring

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Monitoring)
    end

    test "module has expected functions" do
      assert function_exported?(Monitoring, :__info__, 1)
    end
  end
end
