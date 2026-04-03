defmodule Indrajaal.DomainApi do
  @moduledoc """
  Unified API functions for all domains to ensure consistent CRUD operations.
  """

  # Core domain
  @spec create_tenant(any(), any()) :: any()
  def create_tenant(attrs, opts \\ []) do
    try do
      Indrajaal.Core.Tenant
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @spec create_organization(any(), any()) :: any()
  def create_organization(attrs, opts \\ []) do
    try do
      Indrajaal.Core.Organization
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Accounts domain
  @spec create_user(any(), any()) :: any()
  def create_user(attrs, opts \\ []) do
    try do
      Indrajaal.Accounts.User
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Sites domain
  @spec create_site(any(), any()) :: any()
  def create_site(attrs, opts \\ []) do
    try do
      Indrajaal.Sites.Site
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @spec create_zone(any(), any()) :: any()
  def create_zone(attrs, opts \\ []) do
    try do
      Indrajaal.Sites.Zone
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Devices domain
  @spec create_device_type(any(), any()) :: any()
  def create_device_type(attrs, opts \\ []) do
    try do
      Indrajaal.Devices.DeviceType
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  @spec create_device(any(), any()) :: any()
  def create_device(attrs, opts \\ []) do
    try do
      Indrajaal.Devices.Device
      |> Ash.Changeset.for_create(:create, attrs, opts)
      |> Ash.create!()
      |> then(&{:ok, &1})
    rescue
      e -> {:error, e}
    end
  end

  # Alarms domain - Migrated to shared utility: Eliminates duplicate code (mass:
  @spec create_incident_type(any(), any()) :: any()
  def create_incident_type(attrs, opts \\ []) do
    Indrajaal.Shared.ApiPatterns.create_resource_function(Indrajaal.Alarms.IncidentType).(
      attrs,
      opts
    )
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
