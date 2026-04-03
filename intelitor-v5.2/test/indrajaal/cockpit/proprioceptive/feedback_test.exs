defmodule Indrajaal.Cockpit.Proprioceptive.FeedbackTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Proprioceptive.Feedback.

  ## STAMP Safety Integration
  - SC-PRAJNA-004: Feedback system rate limiting

  ## TPS 5-Level RCA Context
  - L1 Symptom: User feedback not displayed
  - L5 Root Cause: Rate limiting or channel misconfiguration
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Proprioceptive.Feedback

  describe "start_link/1" do
    test "starts GenServer successfully" do
      name = :"feedback_#{System.unique_integer()}"
      assert {:ok, pid} = start_supervised({Feedback, [name: name]})
      assert Process.alive?(pid)
    end
  end

  describe "function exports" do
    test "send/3 is exported" do
      assert function_exported?(Feedback, :send, 3)
    end

    test "confirm/1 is exported" do
      assert function_exported?(Feedback, :confirm, 1)
    end

    test "warn/1 is exported" do
      assert function_exported?(Feedback, :warn, 1)
    end

    test "error/1 is exported" do
      assert function_exported?(Feedback, :error, 1)
    end

    test "alert/1 is exported" do
      assert function_exported?(Feedback, :alert, 1)
    end

    test "progress/2 is exported" do
      assert function_exported?(Feedback, :progress, 2)
    end

    test "update_progress/2 is exported" do
      assert function_exported?(Feedback, :update_progress, 2)
    end

    test "dismiss/1 is exported" do
      assert function_exported?(Feedback, :dismiss, 1)
    end

    test "dismiss_all/0 is exported" do
      assert function_exported?(Feedback, :dismiss_all, 0)
    end

    test "active/0 is exported" do
      assert function_exported?(Feedback, :active, 0)
    end

    test "history/1 is exported" do
      assert function_exported?(Feedback, :history, 1)
    end

    test "render_json/0 is exported" do
      assert function_exported?(Feedback, :render_json, 0)
    end

    test "stats/0 is exported" do
      assert function_exported?(Feedback, :stats, 0)
    end
  end

  describe "GenServer behaviour" do
    test "implements GenServer" do
      behaviours = Feedback.__info__(:attributes)[:behaviour] || []
      assert GenServer in behaviours
    end
  end
end
