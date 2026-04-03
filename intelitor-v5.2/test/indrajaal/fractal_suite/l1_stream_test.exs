defmodule Indrajaal.FractalSuite.L1StreamTest do
  use ExUnit.Case

  test "L1: Lazy Stream processing prevents OOM" do
    # Simulate infinite telemetry stream
    infinite_stream = Stream.cycle([%{status: :ok}])

    # Process partial stream
    result =
      infinite_stream
      |> Stream.take(1000)
      |> Stream.map(fn _ -> :processed end)
      |> Enum.to_list()

    assert length(result) == 1000
    # Implicit pass: If we didn't crash, streams are working.
  end
end
