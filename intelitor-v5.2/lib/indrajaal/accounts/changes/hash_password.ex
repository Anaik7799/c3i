defmodule Indrajaal.Accounts.Changes.HashPassword do
  @moduledoc """
  Change that hashes a password using bcrypt.
  """

  use Ash.Resource.Change

  @spec change(term(), term(), term()) :: term()
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :password) do
      nil ->
        changeset

      password ->
        hashed = Bcrypt.hash_pwd_salt(password)
        Ash.Changeset.change_attribute(changeset, :hashed_password, hashed)
    end
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
