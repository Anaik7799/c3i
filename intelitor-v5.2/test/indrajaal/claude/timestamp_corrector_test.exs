defmodule Indrajaal.Claude.TimestampCorrectorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Claude.TimestampCorrector

  test "module exists" do
    assert Code.ensure_loaded?(TimestampCorrector)
  end

  test "start_link/1 is exported" do
    assert function_exported?(TimestampCorrector, :start_link, 1)
  end
end
