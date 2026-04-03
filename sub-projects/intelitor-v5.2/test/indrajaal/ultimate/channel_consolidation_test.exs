defmodule Indrajaal.Ultimate.ChannelConsolidationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.ChannelConsolidation

  test "module is loaded" do
    assert Code.ensure_loaded?(ChannelConsolidation)
  end

  test "universal_join/2 macro is defined" do
    assert macro_exported?(ChannelConsolidation, :universal_join, 2)
  end

  test "handle_universal_event/2 macro is defined" do
    assert macro_exported?(ChannelConsolidation, :handle_universal_event, 2)
  end
end
