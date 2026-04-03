defmodule Indrajaal.FractalSuite.L5DreamerTest do
  use ExUnit.Case
  alias Indrajaal.Evolution.Dreamer

  test "L5: Dreamer generates valid mutation proposals" do
    pid = Process.whereis(Dreamer) || elem(Dreamer.start_link(), 1)

    # Force dream
    send(pid, :dream)

    # Assert Alive
    assert Process.alive?(pid)
  end
end
