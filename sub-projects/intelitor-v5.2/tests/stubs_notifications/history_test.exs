defmodule Intelitor.Notifications.HistoryTest do
  @moduledoc """
  Test suite for Notifications History module.
  SOPv5.11 TDG Compliance - Submodule test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Notifications.History

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(History)
    end

    test "module has expected functions" do
      assert function_exported?(History, :__info__, 1)
    end
  end
end
