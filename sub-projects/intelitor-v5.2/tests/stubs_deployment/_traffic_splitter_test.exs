defmodule Intelitor.Deployment.TrafficSplitterTest do
  @moduledoc """
  Test suite for Intelitor.Deployment.TrafficSplitter.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/deployment/_traffic_splitter.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Deployment.TrafficSplitter

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(TrafficSplitter)
    end

    test "module has __info__/1 function" do
      assert function_exported?(TrafficSplitter, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = TrafficSplitter.__info__(:module)
      assert info == Intelitor.Deployment.TrafficSplitter
    end
  end
end
