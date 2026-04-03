defmodule Indrajaal.ActorHelpers do
  @moduledoc """
  Standardized test actor creation helpers for consistent test patterns.
  Part of Phase 2: Update Test Patterns - SOPv5.1 Core Domain fixes.
  """

  @doc "Creates admin actor with full permissions"
  @spec admin_actor(any()) :: any()
  def admin_actor(tenant_id) do
    %{
      id: Ecto.UUID.generate(),
      tenant_id: tenant_id,
      role: :admin,
      is_system_admin: false
    }
  end

  @doc "Creates system admin actor with full permissions"
  @spec system_admin_actor(any()) :: any()
  def system_admin_actor(tenant_id \\ nil) do
    %{
      id: Ecto.UUID.generate(),
      tenant_id: tenant_id,
      role: :admin,
      is_system_admin: true
    }
  end

  @doc "Creates regular user actor"
  @spec user_actor(any(), any()) :: any()
  def user_actor(tenant_id, role \\ :user) do
    %{
      id: Ecto.UUID.generate(),
      tenant_id: tenant_id,
      role: role,
      is_system_admin: false
    }
  end

  @doc "Creates system actor for system-level operations"
  @spec system_actor() :: any()
  def system_actor do
    %{
      id: "system",
      tenant_id: nil,
      role: :system,
      is_system_admin: true
    }
  end
end
