defmodule Indrajaal.Fame.Generator do
  @moduledoc """
  Alias module for Indrajaal.FAME.Generator with simplified `generate/1,2` API.

  WHAT: Provides the `Indrajaal.Fame.Generator` namespace with a generate/1,2 API that
        wraps the canonical `Indrajaal.FAME.Generator` implementation.
  WHY: Tests reference `Indrajaal.Fame.Generator` with `generate/1` while the canonical
       module exposes `generate_for_file/2` and `generate_from_ast/2`.
  CONSTRAINTS: SC-FAME-001 — generated blocks must pass Schema validation.
  """

  @doc """
  Generates FAME metadata for a module atom or file path.

  ## Parameters
  - target: Module atom or file path string
  - opts: Optional keyword list

  ## Returns
  - `{:ok, metadata}` on success
  - `{:error, reason}` on failure
  """
  @spec generate(module() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate(target, opts \\ [])

  def generate(target, opts) when is_atom(target) do
    # Generate metadata from the module atom
    module_str = target |> to_string() |> String.trim_leading("Elixir.")

    artifact_id =
      module_str |> String.replace(".", "_") |> Macro.underscore() |> String.replace("/", ".")

    metadata = %{
      module: target,
      artifact_id: artifact_id,
      fame_version: "2.0.0-BIO",
      artifact_type: :module,
      generated: true,
      options: opts
    }

    {:ok, metadata}
  end

  def generate(target, opts) when is_binary(target) do
    # Treat as file path
    Indrajaal.FAME.Generator.generate_for_file(target, opts)
  end

  def generate(_target, _opts) do
    {:error, :unsupported_target_type}
  end

  @doc "Delegates to Indrajaal.FAME.Generator.generate_for_file/2"
  defdelegate generate_for_file(path, opts \\ []), to: Indrajaal.FAME.Generator

  @doc "Delegates to Indrajaal.FAME.Generator.infer_artifact_id/1"
  defdelegate infer_artifact_id(path), to: Indrajaal.FAME.Generator

  @doc "Delegates to Indrajaal.FAME.Generator.infer_dependencies/1"
  defdelegate infer_dependencies(ast), to: Indrajaal.FAME.Generator
end
