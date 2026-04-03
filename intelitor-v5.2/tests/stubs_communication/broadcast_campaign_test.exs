defmodule Intelitor.Communication.BroadcastCampaignTest do
  @moduledoc """
  Test suite for Intelitor.Communication.BroadcastCampaign.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/communication/broadcast_campaign.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Communication.BroadcastCampaign

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(BroadcastCampaign)
    end

    test "module has __info__/1 function" do
      assert function_exported?(BroadcastCampaign, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = BroadcastCampaign.__info__(:module)
      assert info == Intelitor.Communication.BroadcastCampaign
    end
  end
end
