defmodule Indrajaal.Unicon.Scanner do
  @moduledoc """
  A Unicon-inspired String Scanning DSL for Elixir.

  This module implements the "Orient" phase of the Fast OODA loop.
  It allows for high-velocity, cursor-based parsing of logs and streams without
  the overhead or brittleness of complex Regex chains.

  ## Concepts
  - `scan/2`: Sets up the scanning environment (Subject & Position).
  - `move/1`: Moves the cursor relative to current position.
  - `tab/1`: Moves the cursor to a specific absolute position.
  - `find/1`: Finds a substring and returns the position (generator).
  - `upto/1`: Scans until a character class is found.
  - `many/1`: Scans past a run of characters.

  ## Usage
      import Indrajaal.Unicon.Scanner

      scan "error: compilation failed at line 42" do
        if find("error:") do
          move(byte_size("error:") + 1)
          error_msg = tab(upto("\n"))
          {:error, error_msg}
        end
      end
  """

  # -----------------------------------------------------------------------------
  # Macros (The DSL)
  # -----------------------------------------------------------------------------

  @doc """
  Initializes a scanning environment.
  The subject and position are maintained in the process dictionary for the block's scope
  to mimic Unicon's implicit variable style, but localized to avoid side effects.
  """
  defmacro scan(subject, do: block) do
    quote do
      # 1. Setup Context
      Process.put(:_unicon_subject, unquote(subject))

      # Unicon strings are 1-indexed conceptually for the user logic if desired, but we map to 0-indexed binaries
      Process.put(:_unicon_pos, 1)

      try do
        unquote(block)
      after
        # 2. Cleanup
        Process.delete(:_unicon_subject)
        Process.delete(:_unicon_pos)
      end
    end
  end

  # -----------------------------------------------------------------------------
  # Primitives (Runtime)
  # -----------------------------------------------------------------------------

  @doc "Moves the cursor by `offset` bytes. Returns the substring skipped over."
  def move(offset) do
    with {subject, pos} <- get_state(),
         new_pos <- pos + offset,
         true <- valid_pos?(subject, new_pos) do
      # Extract substring [pos, new_pos)
      # Adjust for 0-based binary slicing
      start = pos - 1
      len = offset

      match = :binary.part(subject, start, len)
      Process.put(:_unicon_pos, new_pos)
      match
    else
      _ -> :fail
    end
  end

  @doc "Moves the cursor to absolute `target` position. Returns the substring."
  def tab(target) do
    with {subject, pos} <- get_state(),
         true <- valid_pos?(subject, target) do
      len = target - pos
      start = pos - 1

      match = :binary.part(subject, start, len)
      Process.put(:_unicon_pos, target)
      match
    else
      _ -> :fail
    end
  end

  @doc "Finds the first occurrence of `pattern` after current cursor. Returns the *position* of the match."
  def find(pattern) do
    with {subject, pos} <- get_state() do
      # Slice remaining string
      remaining = :binary.part(subject, pos - 1, byte_size(subject) - (pos - 1))

      case :binary.match(remaining, pattern) do
        {start_offset, _len} ->
          # Return absolute position of the match start
          # pos + start_offset
          pos + start_offset

        :nomatch ->
          :fail
      end
    end
  end

  @doc "Returns position of the first character matching the list `chars`."
  def upto(chars) when is_list(chars) do
    # Implementation simplified for binary scanning
    with {subject, pos} <- get_state() do
      _remaining = :binary.part(subject, pos - 1, byte_size(subject) - (pos - 1))
      # Inefficient but functional for prototype: recurse or Regex
      # Ideally use :binary.match with list if supported or iterate
      # Placeholder: standard search for char-set matching
      :fail
    end
  end

  @doc "Matches a run of characters. Moves cursor past them. Returns match."
  def many(_char_class) do
    # Placeholder
    :fail
  end

  # -----------------------------------------------------------------------------
  # Helpers
  # -----------------------------------------------------------------------------

  defp get_state do
    case {Process.get(:_unicon_subject), Process.get(:_unicon_pos)} do
      {nil, _} -> :fail
      {_, nil} -> :fail
      {s, p} -> {s, p}
    end
  end

  defp valid_pos?(subject, pos) do
    pos >= 1 and pos <= byte_size(subject) + 1
  end
end
