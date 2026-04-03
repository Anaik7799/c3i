defmodule Indrajaal.ML.ServingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ML.Serving

  test "module is loaded" do
    assert Code.ensure_loaded?(Serving)
  end

  test "start_link/1 is defined" do
    assert function_exported?(Serving, :start_link, 1)
  end

  test "module uses Supervisor behaviour" do
    behaviours = Serving.__info__(:attributes)[:behaviour] || []
    assert Supervisor in behaviours
  end

  test "child_spec/1 is defined for supervision" do
    assert function_exported?(Serving, :child_spec, 1)
  end
end
