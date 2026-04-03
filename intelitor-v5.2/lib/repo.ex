defmodule Repo do
  @moduledoc """
  Repo delegation module.

  This module provides delegation to Indrajaal.Repo for backward compatibility.
  Created to resolve UNDEFINED_MODULE warnings during Phase 1.

  All functions delegate to Indrajaal.Repo.
  """

  @doc """
  Delete a record from the repository.

  ## Parameters
  - struct_or_changeset: The struct or changeset to delete

  ## Returns
  - {:ok, struct} on success
  - {:error, changeset} on failure
  """
  @spec delete(Ecto.Schema.t() | Ecto.Changeset.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete(struct_or_changeset) do
    Indrajaal.Repo.delete(struct_or_changeset)
  end

  @doc """
  Update a record in the repository.

  ## Parameters
  - changeset: The changeset with updates

  ## Returns
  - {:ok, struct} on success
  - {:error, changeset} on failure
  """
  @spec update(Ecto.Changeset.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def update(changeset) do
    Indrajaal.Repo.update(changeset)
  end

  @doc """
  Insert a record into the repository.

  ## Parameters
  - struct_or_changeset: The struct or changeset to insert

  ## Returns
  - {:ok, struct} on success
  - {:error, changeset} on failure
  """
  @spec insert(Ecto.Schema.t() | Ecto.Changeset.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert(struct_or_changeset) do
    Indrajaal.Repo.insert(struct_or_changeset)
  end

  @doc """
  Get a single record by query.

  ## Parameters
  - queryable: The queryable (schema or query)
  - clauses: The query clauses (e.g., [id: 1])

  ## Returns
  - The struct or nil
  """
  @spec get_by(Ecto.Queryable.t(), Keyword.t() | map()) :: Ecto.Schema.t() | nil
  def get_by(queryable, clauses) do
    Indrajaal.Repo.get_by(queryable, clauses)
  end

  @doc """
  Get a single record by primary key.

  ## Parameters
  - queryable: The queryable (schema or query)
  - id: The primary key value

  ## Returns
  - The struct or nil
  """
  @spec get(Ecto.Queryable.t(), term()) :: Ecto.Schema.t() | nil
  def get(queryable, id) do
    Indrajaal.Repo.get(queryable, id)
  end

  @doc """
  Get all records matching a query.

  ## Parameters
  - queryable: The queryable (schema or query)

  ## Returns
  - List of structs
  """
  @spec all(Ecto.Queryable.t()) :: [Ecto.Schema.t()]
  def all(queryable) do
    Indrajaal.Repo.all(queryable)
  end

  @doc """
  Get a single record, raising if none found.

  ## Parameters
  - queryable: The queryable (schema or query)
  - id: The primary key value

  ## Returns
  - The struct

  ## Raises
  - Ecto.NoResultsError if no record found
  """
  @spec get!(Ecto.Queryable.t(), term()) :: Ecto.Schema.t()
  def get!(queryable, id) do
    Indrajaal.Repo.get!(queryable, id)
  end

  @doc """
  Insert all records from a list.

  ## Parameters
  - schema_or_source: The schema or source name
  - entries: List of entries to insert

  ## Returns
  - {count, nil} or {count, [returned_records]}
  """
  @spec insert_all(Ecto.Schema.t() | binary(), [map() | Keyword.t()], Keyword.t()) ::
          {integer(), nil | [term()]}
  def insert_all(schema_or_source, entries, opts \\ []) do
    Indrajaal.Repo.insert_all(schema_or_source, entries, opts)
  end

  @doc """
  Reload a struct from the repository.

  ## Parameters
  - struct: The struct to reload

  ## Returns
  - The reloaded struct or nil
  """
  @spec reload(Ecto.Schema.t()) :: Ecto.Schema.t() | nil
  def reload(struct) do
    Indrajaal.Repo.reload(struct)
  end

  @doc """
  Execute a query and return one result.

  ## Parameters
  - queryable: The queryable

  ## Returns
  - The struct or nil
  """
  @spec one(Ecto.Queryable.t()) :: Ecto.Schema.t() | nil
  def one(queryable) do
    Indrajaal.Repo.one(queryable)
  end
end
