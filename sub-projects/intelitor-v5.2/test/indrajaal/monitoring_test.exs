defmodule Indrajaal.MonitoringTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Monitoring

  test "module exists" do
    assert Code.ensure_loaded?(Monitoring)
  end
end
