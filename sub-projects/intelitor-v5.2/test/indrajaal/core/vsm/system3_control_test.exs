defmodule Indrajaal.Core.VSM.System3ControlTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Core.VSM.System3Control

  setup do
    {:ok, state: System3Control.new(cpu_limit: 100)}
  end

  describe "System3Control Priority Reservation" do
    test "allows normal reservation within budget", %{state: state} do
      assert {:ok, new_state} = System3Control.reserve(state, :cpu, 50, 3)
      assert System3Control.available(new_state, :cpu) == 50
    end

    test "denies normal reservation over budget", %{state: state} do
      {:ok, full_state} = System3Control.reserve(state, :cpu, 100, 3)
      assert {:error, :insufficient_budget} = System3Control.reserve(full_state, :cpu, 10, 3)
    end

    test "allows Priority 0 (Ω₀) pre-emption over budget", %{state: state} do
      # Fill the budget
      {:ok, full_state} = System3Control.reserve(state, :cpu, 100, 3)

      # Ω₀ requests more
      assert {:ok, supreme_state} = System3Control.reserve(full_state, :cpu, 50, 0)

      # Total reserved should be 150 (over budget)
      assert supreme_state.budget.cpu.reserved == 150
      assert supreme_state.over_budget == true
    end
  end
end
