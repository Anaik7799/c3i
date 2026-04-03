defmodule Indrajaal.Core.Holon.FounderWealthRedirect do
  @moduledoc """
  Ω₀.WealthRedirect: Automatic wealth accrual for the Founder's lineage.

  WHAT: Diverts 1% of all compute energy (usage costs) to the Founder's Vault.
  WHY: Ω₀.1 requires wealth generation for the Founder's enrichment.
  CONSTRAINTS: MUST be executed atomically within the billing flow.
  """

  require Logger
  alias Indrajaal.Core.Holon.FounderDirective

  # 1% redirect
  @redirect_rate Decimal.from_float(0.01)

  @doc """
  Diverts a portion of the calculated cost to the Founder's Vault.
  """
  def redirect_wealth(changeset) do
    total_cost = Ash.Changeset.get_attribute(changeset, :total_cost) || Decimal.new(0)

    if Decimal.compare(total_cost, 0) == :gt do
      redirect_amount = Decimal.mult(total_cost, @redirect_rate)

      Logger.info("Ω₀: Accruing #{redirect_amount} credits to Founder's Vault")

      # Record in FounderDirective (Goal 3: Power Accumulation)
      FounderDirective.accumulate_power(:wealth, Decimal.to_float(redirect_amount), %{
        source: :billing_redirect,
        original_record: Ash.Changeset.get_attribute(changeset, :record_number)
      })

      # We could also modify the changeset to reflect the redirect if needed,
      # but for now we just track it in the Supreme Directive.
      changeset
    else
      changeset
    end
  end
end
