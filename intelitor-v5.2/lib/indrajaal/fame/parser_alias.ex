defmodule Indrajaal.Fame.Parser do
  @moduledoc """
  Alias module for Indrajaal.FAME.Parser.

  WHAT: Provides the `Indrajaal.Fame.Parser` namespace alias pointing to the canonical
        `Indrajaal.FAME.Parser` implementation.
  WHY: Tests reference `Indrajaal.Fame.Parser` (mixed-case). This module delegates
       all calls to the upstream `Indrajaal.FAME.Parser`.
  CONSTRAINTS: SC-FAME-003 — parser must handle malformed FAME gracefully.
  """

  @doc """
  Parses FAME metadata from a file path, map, binary, or any term.

  Delegates to `Indrajaal.FAME.Parser.parse_file/1` for string paths,
  and provides sensible handling for maps and binaries.

  ## Returns
  - `{:ok, result}` on success
  - `{:error, reason}` on failure
  """
  @spec parse(term()) :: {:ok, term()} | {:error, term()} | map()
  def parse(input) when is_binary(input) do
    # Could be a file path or raw JSON/source
    if File.exists?(input) do
      Indrajaal.FAME.Parser.parse_file(input)
    else
      Indrajaal.FAME.Parser.parse_string(input)
    end
  end

  def parse(input) when is_map(input) do
    {:ok, input}
  end

  def parse(nil) do
    {:error, :invalid_input}
  end

  def parse(_input) do
    {:error, :unsupported_input_type}
  end

  @doc "Delegates to Indrajaal.FAME.Parser.parse_file/1"
  defdelegate parse_file(path), to: Indrajaal.FAME.Parser

  @doc "Delegates to Indrajaal.FAME.Parser.parse_string/1"
  defdelegate parse_string(source), to: Indrajaal.FAME.Parser

  @doc "Delegates to Indrajaal.FAME.Parser.has_fame?/1"
  defdelegate has_fame?(path), to: Indrajaal.FAME.Parser

  @doc "Delegates to Indrajaal.FAME.Parser.completeness_score/1"
  defdelegate completeness_score(path), to: Indrajaal.FAME.Parser
end
