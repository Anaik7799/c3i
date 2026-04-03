defmodule Indrajaal.Accounts.Changes.SendConfirmationEmail do
  @moduledoc """
  Change that sends a confirmation email after user registration.
  """

  use Ash.Resource.Change

  @spec change(term(), term(), term()) :: term()
  def change(changeset, _opts, __context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      # TODO: Send actual email when email service is configured
      # For now, just log
      require Logger
      Logger.info("Would send confirmation email to #{user.email}")

      {:ok, user}
    end)
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
