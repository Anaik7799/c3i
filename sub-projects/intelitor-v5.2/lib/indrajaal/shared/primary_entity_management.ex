defmodule Indrajaal.Shared.PrimaryEntityManagement do
  @moduledoc """
  Shared utilities for managing primary entity patterns (one primary entity
    per tenant).

  This module extracts common primary entity functionality used by:
  - Core.Organization (mass: 68)
  - Other domains that need single primary entity per tenant

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  require Ash.Query

  @doc """
  Creates a primary entity management change function for creation.

  ## Parameters
    - `module` - The Ash resource module
    - `primary_field` - Field that indicates if entity is primary (default:
      :is_primary)
    - `tenant_field` - Field containing tenant ID (default: :tenant_id)

  ## Returns
  Function that ensures only one primary entity per tenant.

  ## Example
      change Indrajaal.Shared.PrimaryEntityManagement.create_primary_entity_change(__MODULE__)
  """
  def createprimary_entity_change(
        module,
        primary_field \\ :isprimary,
        tenant_field \\ :tenantid
      ) do
    fn changeset, __context ->
      if Ash.Changeset.get_attribute(changeset, primary_field) do
        tenant_id = Ash.Changeset.get_attribute(changeset, tenant_field)

        apply_primary_entity_before_action(changeset, module, tenant_id)
      else
        changeset
      end
    end
  end

  @doc """
  Creates a primary entity management change function for updates.

  ## Parameters
    - `module` - The Ash resource module
    - `primary_field` - Field that indicates if entity is primary (default:
      :is_primary)
    - `tenant_field` - Field containing tenant ID (default: :tenant_id)

  ## Returns
  Function that ensures only one primary entity per tenant during updates.
  """
  def updateprimary_entity_change(
        module,
        _primary_field \\ :isprimary,
        tenant_field \\ :tenantid
      ) do
    fn changeset, __context ->
      tenant_id = Ash.Changeset.get_attribute(changeset, tenant_field)

      apply_primary_entity_before_action(changeset, module, tenant_id, changeset.data.id)
    end
  end

  @doc """
  Creates a standard set_primary action definition.

  ## Parameters
    - `module` - The Ash resource module
    - `action_name` - Name of the action (default: :set_primary)
    - `primary_field` - Field that indicates if entity is primary (default:
      :is_primary)

  ## Returns
  Map with action configuration for setting entity as primary.
  """
  def setprimary_action(
        module,
        action_name \\ :setprimary,
        primary_field \\ :isprimary
      ) do
    %{
      name: action_name,
      accept: [],
      changes: [
        {:set_attribute, [primary_field, true]},
        {:change, updateprimary_entity_change(module, primary_field)}
      ]
    }
  end

  @doc """
  Gets the current primary entity for a tenant.

  ## Parameters
    - `module` - The Ash resource module
    - `tenant_id` - The tenant ID
    - `actor` - The actor __context
    - `primary_field` - Field that indicates if entity is primary (default:
      :is_primary)

  ## Returns
    - `{:ok, entity}` if primary entity found
    - `{:error, :not_found}` if no primary entity
    - `{:error, reason}` for other errors
  """
  @spec get_primary_entity(module(), any(), any(), atom()) :: {:ok, any()} | {:error, any()}
  def get_primary_entity(module, tenant_id, actor, _primary_field \\ :is_primary) do
    try do
      module
      |> Ash.Query.filter(tenant_id: tenant_id)
      |> Ash.Query.filter(is_primary: true)
      |> Ash.read_one!(actor: actor)
      |> case do
        nil -> {:error, :not_found}
        entity -> {:ok, entity}
      end
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Validates that exactly one primary entity exists per tenant.

  ## Parameters
    - `module` - The Ash resource module
    - `tenant_id` - The tenant ID to validate
    - `actor` - The actor __context

  ## Returns
    - `{:ok, primary_entity}` if exactly one primary exists
    - `{:error, :no_primary}` if no primary entity
    - `{:error, :multiple_primary}` if multiple primary entities
  """
  @spec validate_single_primary(module(), any(), any()) :: {:ok, any()} | {:error, atom()}
  def validate_single_primary(module, tenant_id, actor) do
    case list_primary_entities(module, tenant_id, actor) do
      {:ok, []} -> {:error, :no_primary}
      {:ok, [primary]} -> {:ok, primary}
      {:ok, _multiple} -> {:error, :multiple_primary}
      error -> error
    end
  end

  @doc """
  Ensures at least one entity is marked as primary for a tenant.

  ## Parameters
    - `module` - The Ash resource module
    - `tenant_id` - The tenant ID
    - `actor` - The actor __context
    - `primary_field` - Field that indicates if entity is primary (default:
      :is_primary)

  ## Returns
    - `{:ok, primary_entity}` if primary exists or was created
    - `{:error, reason}` if operation failed
  """
  @spec ensure_primary_exists(module(), any(), any(), atom()) :: {:ok, any()} | {:error, any()}
  def ensure_primary_exists(module, tenant_id, actor, primary_field \\ :is_primary) do
    case get_primary_entity(module, tenant_id, actor, primary_field) do
      {:ok, primary} ->
        {:ok, primary}

      {:error, :not_found} ->
        # Set first entity as primary
        case list_all_entities(module, tenant_id, actor) do
          {:ok, [first | _]} ->
            try do
              {:ok, module.update!(first, %{primary_field => true}, actor: actor)}
            rescue
              e -> {:error, e}
            end

          {:ok, []} ->
            {:error, :no_entities}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Lists all primary entities for a tenant (should be 0 or 1).

  ## Parameters
    - `module` - The Ash resource module
    - `tenant_id` - The tenant ID
    - `actor` - The actor __context
    - `primary_field` - Field that indicates if entity is primary (default:
      :is_primary)

  ## Returns
  List of primary entities.
  """
  @spec list_primary_entities(module(), any(), any(), atom()) :: {:ok, list()} | {:error, any()}
  def list_primary_entities(module, tenant_id, actor, _primary_field \\ :is_primary) do
    try do
      entities =
        module
        |> Ash.Query.filter(tenant_id: tenant_id)
        |> Ash.Query.filter(is_primary: true)
        |> Ash.read!(actor: actor)

      {:ok, entities}
    rescue
      e -> {:error, e}
    end
  end

  # Private helper functions

  # Extracted helper to eliminate duplicate before_action pattern in create/update.
  # Optional `exclude_id` filters out the entity being updated (for update actions).
  defp apply_primary_entity_before_action(changeset, module, tenant_id, exclude_id \\ nil) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case list_primary_entities(module, tenant_id, changeset.__context[:actor]) do
        {:ok, entities} ->
          entities_to_update =
            if exclude_id do
              Enum.reject(entities, &(&1.id == exclude_id))
            else
              entities
            end

          update_entities_to_non_primary(module, entities_to_update, changeset.__context[:actor])
          changeset

        _ ->
          changeset
      end
    end)
  end

  defp list_all_entities(module, tenant_id, actor) do
    try do
      entities =
        module
        |> Ash.Query.filter(tenant_id: tenant_id)
        |> Ash.read!(actor: actor)

      {:ok, entities}
    rescue
      e -> {:error, e}
    end
  end

  defp update_entities_to_non_primary(module, entities, actor) do
    Enum.each(
      entities,
      fn entity ->
        try do
          module.update!(
            entity,
            %{is_primary: false},
            actor: actor
          )
        rescue
          # Log error but continue with other entities
          _e -> :ok
        end
      end
    )
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
