defmodule Cabbage.Feature do
  @moduledoc """
  BDD Feature step definition macros.

  This is a stub module providing Cabbage-like BDD step definition macros.
  It enables step files using `use Cabbage.Feature` to compile and provides
  the defgiven/defwhen/defthen/defand macros for defining Gherkin step matchers.

  WHAT: Stub implementation of Cabbage BDD framework macros
  WHY: Enable BDD step files to compile without external dependency
  CONSTRAINTS: SC-BDD-002 (BDD scenarios MUST be executable)
  """

  defmacro __using__(_opts) do
    quote do
      import Cabbage.Feature, only: [defgiven: 4, defwhen: 4, defthen: 4, defand: 4]
      import ExUnit.Assertions

      Module.register_attribute(__MODULE__, :steps, accumulate: true)

      @before_compile Cabbage.Feature
    end
  end

  @doc """
  Defines a Given step matcher.

  ## Example
      defgiven ~r/^the API server is running$/, _params, state do
        {:ok, state}
      end
  """
  defmacro defgiven(regex, params, state, do: block) do
    step_name = extract_step_name(regex, "given")

    quote do
      @steps {:given, unquote(Macro.escape(regex)), unquote(step_name)}

      def unquote(step_name)(unquote(params), unquote(state)) do
        unquote(block)
      end
    end
  end

  @doc """
  Defines a When step matcher.

  ## Example
      defwhen ~r/^I request the health endpoint$/, _params, state do
        {:ok, state}
      end
  """
  defmacro defwhen(regex, params, state, do: block) do
    step_name = extract_step_name(regex, "when")

    quote do
      @steps {:when, unquote(Macro.escape(regex)), unquote(step_name)}

      def unquote(step_name)(unquote(params), unquote(state)) do
        unquote(block)
      end
    end
  end

  @doc """
  Defines a Then step matcher.

  ## Example
      defthen ~r/^I should receive a 200 status$/, _params, state do
        {:ok, state}
      end
  """
  defmacro defthen(regex, params, state, do: block) do
    step_name = extract_step_name(regex, "then")

    quote do
      @steps {:then, unquote(Macro.escape(regex)), unquote(step_name)}

      def unquote(step_name)(unquote(params), unquote(state)) do
        unquote(block)
      end
    end
  end

  @doc """
  Defines an And step matcher (alias for additional steps).

  ## Example
      defand ~r/^the response contains valid JSON$/, _params, state do
        {:ok, state}
      end
  """
  defmacro defand(regex, params, state, do: block) do
    step_name = extract_step_name(regex, "and")

    quote do
      @steps {:and, unquote(Macro.escape(regex)), unquote(step_name)}

      def unquote(step_name)(unquote(params), unquote(state)) do
        unquote(block)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Returns all registered step definitions for this module.
      """
      def __steps__ do
        @steps
      end

      @doc """
      Executes a step matching the given type and text.
      """
      def execute_step(type, text, state) when type in [:given, :when, :then, :and] do
        case find_matching_step(type, text) do
          {:ok, step_fn, captures} ->
            apply(__MODULE__, step_fn, [captures, state])

          :no_match ->
            {:error, {:step_not_found, type, text}}
        end
      end

      defp find_matching_step(type, text) do
        @steps
        |> Enum.filter(fn {step_type, _regex, _fn} -> step_type == type end)
        |> Enum.find_value(:no_match, fn {_type, regex, step_fn} ->
          case Regex.run(regex, text, capture: :all_but_first) do
            nil -> nil
            captures -> {:ok, step_fn, captures}
          end
        end)
      end
    end
  end

  # Helper to generate a unique step name from regex
  defp extract_step_name(regex, prefix) do
    # Generate a sanitized function name from the regex pattern
    case regex do
      {:sigil_r, _, [{:<<>>, _, [pattern]}, _]} when is_binary(pattern) ->
        sanitized =
          pattern
          |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
          |> String.replace(~r/_+/, "_")
          |> String.trim("_")
          |> String.downcase()
          |> String.slice(0, 40)

        String.to_atom("step_#{prefix}_#{sanitized}")

      _ ->
        # Fallback: generate unique name based on hash
        hash = :erlang.phash2(regex, 1_000_000)
        String.to_atom("step_#{prefix}_#{hash}")
    end
  end
end
