defmodule Indrajaal.Observability.Fractal.ProfilerTest do
  use ExUnit.Case
  alias Indrajaal.Observability.Fractal.Profiler

  test "L1: traces execution time with nanosecond precision" do
    parent = self()

    :telemetry.attach(
      "test-profiler",
      [:indrajaal, :fractal, :profile],
      fn _name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, measurements, metadata})
      end,
      nil
    )

    Profiler.trace("test_func", %{custom: "meta"}, fn -> :ok end)

    assert_receive {:telemetry_event, measurements, metadata}
    assert measurements.duration_ns > 0
    assert metadata.name == "test_func"
    assert metadata.custom == "meta"
  end
end
