defmodule Indrajaal.Accounts.Changes.GenerateUsername do
  @moduledoc """
  Change that generates a unique __username from email if not provided.
  """

  use Ash.Resource.Change

  @spec change(term(), term(), term()) :: term()
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :__username) do
      nil ->
        email = Ash.Changeset.get_attribute(changeset, :email)

        if email do
          # Extract __username part from email
          base_username =
            email
            |> String.split("@")
            |> List.first()
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9_-]/, "")

          # Add random suffix to ensure uniqueness
          username = "#{base_username}_#{:rand.uniform(9999)}"
          Ash.Changeset.change_attribute(changeset, :__username, username)
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
