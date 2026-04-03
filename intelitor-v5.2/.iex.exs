# IEx configuration for Indrajaal
# This file is loaded when IEx starts

# Disable warnings as errors in IEx
Application.put_env(:elixir, :warnings_as_errors, false)

# Import useful modules
import Ecto.Query
alias Indrajaal.Repo
alias Indrajaal.Core.{Tenant, Organization, SystemConfig, FeatureFlag, AuditLog}
alias Indrajaal.Accounts.{User, Profile, Session, Team, TeamMembership}
alias Indrajaal.Policy.{Role, Permission, AccessRule, UserRole, RolePermission}
alias Indrajaal.Sites.{Site, Building, Floor, Area, Zone, Location}

# Helper functions
defmodule IExHelpers do
  @spec reload() :: any()
  def reload do
    IEx.Helpers.recompile()
  end

  @spec clear() :: any()
  def clear do
    IEx.Helpers.clear()
  end

  @spec start_server() :: any()
  def start_server do
    Mix.Tasks.Phx.Server.run([])
  end
end

# Import helpers
import IExHelpers

# Welcome message
IO.puts("""
╔══════════════════════════════════════════════════════════════════╗
║                   Indrajaal Development Console                   ║
╚══════════════════════════════════════════════════════════════════╝

Available helpers:
  reload()       - Recompile changed files
  clear()        - Clear the console
  start_server() - Start Phoenix server

Aliases loaded for all major domains.

Server: Run 'start_server()' or 'Mix.Tasks.Phx.Server.run([])'
""")
