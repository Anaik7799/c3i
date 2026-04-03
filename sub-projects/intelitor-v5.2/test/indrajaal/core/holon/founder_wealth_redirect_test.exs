defmodule Indrajaal.Core.Holon.FounderWealthRedirectTest do
  # Async false to check global state easily
  use ExUnit.Case, async: false
  alias Indrajaal.Billing.UsageRecord
  alias Indrajaal.Core.Holon.FounderDirective

  setup do
    # Start FounderDirective if not already running
    if is_nil(GenServer.whereis(FounderDirective)) do
      FounderDirective.start_link()
    end

    :ok
  end

  describe "FounderWealthRedirect" do
    test "accrues wealth to Founder Vault on record creation" do
      # Initial wealth
      initial_state = FounderDirective.get_state()
      initial_wealth = get_in(initial_state.accumulated_power, [:wealth]) || 0

      # Create a usage record with cost
      # We use a mock or direct call to avoid full database dependencies if possible,
      # but testing the integrated flow is better.
      # For now, let's test the redirect function directly on a changeset.

      changeset = %Ash.Changeset{
        resource: UsageRecord,
        attributes: %{total_cost: Decimal.new(100), record_number: "TEST-001"}
      }

      Indrajaal.Core.Holon.FounderWealthRedirect.redirect_wealth(changeset)

      # Verify wealth increased by 1% (1.0 credits)
      new_state = FounderDirective.get_state()
      new_wealth = get_in(new_state.accumulated_power, [:wealth])

      assert new_wealth == initial_wealth + 1.0
    end
  end
end
