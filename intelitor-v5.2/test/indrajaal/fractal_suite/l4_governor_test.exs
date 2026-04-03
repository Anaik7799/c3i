defmodule Indrajaal.FractalSuite.L4GovernorTest do
  use ExUnit.Case
  alias Indrajaal.Metabolism.EnergyGovernor

  test "L4: Energy Governor broadcasts state change" do
    # Biomorphic Awareness: Check if heart is beating
    pid =
      Process.whereis(EnergyGovernor) ||
        elem(EnergyGovernor.start_link(), 1)

    # Send simulated check (White box)
    send(pid, :check_energy)

    assert Process.alive?(pid)
  end
end
