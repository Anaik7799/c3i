defmodule Indrajaal.Cockpit.Prajna.Guardian.ResilienceTest do
  use ExUnit.Case
  alias Indrajaal.Cockpit.Prajna.Guardian.Resilience

  test "with_timeout completes successfully" do
    assert Resilience.with_timeout(fn -> 1 + 1 end) == 2
  end

  test "with_timeout handles timeout" do
    assert Resilience.with_timeout(fn -> Process.sleep(100) end, 10) == {:error, :timeout}
  end
end
