defmodule Indrajaal.CEPAF.Bridge.Grammar do
  @moduledoc """
  CEPAF Grammar - DSL for F# Orchestration Commands for v20.0.0

  Implements a grammar for describing orchestration patterns:
  - Workflow definitions
  - Resource constraints
  - Temporal patterns
  - Error handling strategies

  ## Grammar Structure

  ```
  workflow := name '{' step+ '}'
  step := action | parallel | choice | loop
  action := 'do' name '(' args ')' constraints?
  parallel := 'fork' '{' step+ '}'
  choice := 'when' condition '{' step+ '}' ('else' '{' step+ '}')?
  loop := 'while' condition '{' step+ '}'
  constraints := 'with' '{' constraint+ '}'
  constraint := 'timeout' duration | 'retry' count | 'fallback' action
  ```

  ## STAMP Constraints
  - SC-GRM-001: Grammar MUST be unambiguous
  - SC-GRM-002: Parsing MUST be deterministic
  - SC-GRM-003: Invalid grammar MUST fail fast
  - SC-GRM-004: AST MUST be serializable
  """

  require Logger

  @type workflow_name :: atom()
  @type step_type :: :action | :parallel | :choice | :loop | :sequence

  @type constraint :: %{
          type: :timeout | :retry | :fallback | :resource,
          value: term()
        }

  @type step :: %{
          type: step_type(),
          name: atom() | nil,
          body: term(),
          constraints: [constraint()],
          metadata: map()
        }

  @type workflow :: %{
          name: workflow_name(),
          steps: [step()],
          inputs: [atom()],
          outputs: [atom()],
          metadata: map()
        }

  @doc """
  Parses a workflow definition string.
  """
  @spec parse(String.t()) :: {:ok, workflow()} | {:error, term()}
  def parse(source) do
    source
    |> tokenize()
    |> parse_workflow()
  end

  @doc """
  Compiles a workflow to F# orchestrator code.
  """
  @spec compile(workflow()) :: {:ok, String.t()} | {:error, term()}
  def compile(workflow) do
    try do
      code = generate_fsharp(workflow)
      {:ok, code}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Validates a workflow definition.
  """
  @spec validate(workflow()) :: :ok | {:error, [term()]}
  def validate(workflow) do
    errors =
      []
      |> validate_name(workflow)
      |> validate_steps(workflow)
      |> validate_constraints(workflow)
      |> validate_inputs_outputs(workflow)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end
  end

  @doc """
  Creates an action step.
  """
  @spec action(atom(), term(), Keyword.t()) :: step()
  def action(name, args, opts \\ []) do
    %{
      type: :action,
      name: name,
      body: args,
      constraints: Keyword.get(opts, :constraints, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a parallel step.
  """
  @spec parallel([step()], Keyword.t()) :: step()
  def parallel(steps, opts \\ []) do
    %{
      type: :parallel,
      name: Keyword.get(opts, :name),
      body: steps,
      constraints: Keyword.get(opts, :constraints, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a choice step.
  """
  @spec choice(term(), [step()], [step()], Keyword.t()) :: step()
  def choice(condition, then_branch, else_branch \\ [], opts \\ []) do
    %{
      type: :choice,
      name: Keyword.get(opts, :name),
      body: %{condition: condition, then: then_branch, else: else_branch},
      constraints: Keyword.get(opts, :constraints, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a loop step.
  """
  @spec loop(term(), [step()], Keyword.t()) :: step()
  def loop(condition, body, opts \\ []) do
    %{
      type: :loop,
      name: Keyword.get(opts, :name),
      body: %{condition: condition, body: body},
      constraints: Keyword.get(opts, :constraints, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a sequence of steps.
  """
  @spec sequence([step()], Keyword.t()) :: step()
  def sequence(steps, opts \\ []) do
    %{
      type: :sequence,
      name: Keyword.get(opts, :name),
      body: steps,
      constraints: Keyword.get(opts, :constraints, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a timeout constraint.
  """
  @spec timeout(non_neg_integer()) :: constraint()
  def timeout(ms) when is_integer(ms) and ms > 0 do
    %{type: :timeout, value: ms}
  end

  @doc """
  Creates a retry constraint.
  """
  @spec retry(non_neg_integer(), Keyword.t()) :: constraint()
  def retry(count, opts \\ []) when is_integer(count) and count > 0 do
    %{
      type: :retry,
      value: %{
        count: count,
        delay: Keyword.get(opts, :delay, 1000),
        backoff: Keyword.get(opts, :backoff, :exponential)
      }
    }
  end

  @doc """
  Creates a fallback constraint.
  """
  @spec fallback(step()) :: constraint()
  def fallback(step) do
    %{type: :fallback, value: step}
  end

  @doc """
  Creates a resource constraint.
  """
  @spec resource(atom(), term()) :: constraint()
  def resource(type, requirement) do
    %{type: :resource, value: %{type: type, requirement: requirement}}
  end

  @doc """
  Builds a workflow definition.
  """
  @spec workflow(atom(), Keyword.t()) :: workflow()
  def workflow(name, opts \\ []) do
    %{
      name: name,
      steps: Keyword.get(opts, :steps, []),
      inputs: Keyword.get(opts, :inputs, []),
      outputs: Keyword.get(opts, :outputs, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  # Private: Tokenizer

  defp tokenize(source) do
    source
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> tokenize_stream([])
  end

  defp tokenize_stream([], tokens), do: Enum.reverse(tokens)

  defp tokenize_stream([word | rest], tokens) do
    token =
      case word do
        "workflow" -> {:keyword, :workflow}
        "do" -> {:keyword, :do}
        "fork" -> {:keyword, :fork}
        "when" -> {:keyword, :when}
        "else" -> {:keyword, :else}
        "while" -> {:keyword, :while}
        "with" -> {:keyword, :with}
        "timeout" -> {:keyword, :timeout}
        "retry" -> {:keyword, :retry}
        "fallback" -> {:keyword, :fallback}
        "{" -> {:symbol, :lbrace}
        "}" -> {:symbol, :rbrace}
        "(" -> {:symbol, :lparen}
        ")" -> {:symbol, :rparen}
        "," -> {:symbol, :comma}
        "->" -> {:symbol, :arrow}
        other -> parse_literal(other)
      end

    tokenize_stream(rest, [token | tokens])
  end

  defp parse_literal(str) do
    cond do
      Regex.match?(~r/^\d+$/, str) -> {:number, String.to_integer(str)}
      Regex.match?(~r/^:\w+$/, str) -> {:atom, String.to_atom(String.slice(str, 1..-1//1))}
      Regex.match?(~r/^".*"$/, str) -> {:string, String.slice(str, 1..-2//1)}
      true -> {:identifier, String.to_atom(str)}
    end
  end

  # Private: Parser

  defp parse_workflow(tokens) do
    try do
      {workflow, []} = do_parse_workflow(tokens)
      {:ok, workflow}
    rescue
      e -> {:error, e}
    end
  end

  defp do_parse_workflow([{:keyword, :workflow}, {:identifier, name}, {:symbol, :lbrace} | rest]) do
    {steps, [{:symbol, :rbrace} | remaining]} = parse_steps(rest, [])

    workflow = %{
      name: name,
      steps: steps,
      inputs: [],
      outputs: [],
      metadata: %{}
    }

    {workflow, remaining}
  end

  defp parse_steps([{:symbol, :rbrace} | _] = tokens, acc) do
    {Enum.reverse(acc), tokens}
  end

  defp parse_steps(tokens, acc) do
    {step, rest} = parse_step(tokens)
    parse_steps(rest, [step | acc])
  end

  defp parse_step([{:keyword, :do}, {:identifier, name} | rest]) do
    {args, rest2} = parse_args(rest)
    {constraints, rest3} = parse_constraints(rest2)

    step = %{
      type: :action,
      name: name,
      body: args,
      constraints: constraints,
      metadata: %{}
    }

    {step, rest3}
  end

  defp parse_step([{:keyword, :fork}, {:symbol, :lbrace} | rest]) do
    {steps, [{:symbol, :rbrace} | rest2]} = parse_steps(rest, [])

    step = %{
      type: :parallel,
      name: nil,
      body: steps,
      constraints: [],
      metadata: %{}
    }

    {step, rest2}
  end

  defp parse_step([{:keyword, :when} | rest]) do
    {condition, rest2} = parse_condition(rest)
    {then_steps, rest3} = parse_block(rest2)
    {else_steps, rest4} = parse_else_block(rest3)

    step = %{
      type: :choice,
      name: nil,
      body: %{condition: condition, then: then_steps, else: else_steps},
      constraints: [],
      metadata: %{}
    }

    {step, rest4}
  end

  defp parse_step([{:keyword, :while} | rest]) do
    {condition, rest2} = parse_condition(rest)
    {body_steps, rest3} = parse_block(rest2)

    step = %{
      type: :loop,
      name: nil,
      body: %{condition: condition, body: body_steps},
      constraints: [],
      metadata: %{}
    }

    {step, rest3}
  end

  defp parse_args([{:symbol, :lparen} | rest]) do
    parse_args_list(rest, [])
  end

  defp parse_args(tokens), do: {[], tokens}

  defp parse_args_list([{:symbol, :rparen} | rest], acc) do
    {Enum.reverse(acc), rest}
  end

  defp parse_args_list([{:symbol, :comma} | rest], acc) do
    parse_args_list(rest, acc)
  end

  defp parse_args_list([{_type, value} | rest], acc) do
    parse_args_list(rest, [value | acc])
  end

  defp parse_constraints([{:keyword, :with}, {:symbol, :lbrace} | rest]) do
    parse_constraint_list(rest, [])
  end

  defp parse_constraints(tokens), do: {[], tokens}

  defp parse_constraint_list([{:symbol, :rbrace} | rest], acc) do
    {Enum.reverse(acc), rest}
  end

  defp parse_constraint_list([{:keyword, :timeout}, {:number, ms} | rest], acc) do
    constraint = %{type: :timeout, value: ms}
    parse_constraint_list(rest, [constraint | acc])
  end

  defp parse_constraint_list([{:keyword, :retry}, {:number, count} | rest], acc) do
    constraint = %{type: :retry, value: %{count: count, delay: 1000, backoff: :exponential}}
    parse_constraint_list(rest, [constraint | acc])
  end

  defp parse_condition(tokens) do
    # Simplified: take until lbrace
    {cond_tokens, rest} = Enum.split_while(tokens, fn t -> t != {:symbol, :lbrace} end)
    condition = cond_tokens |> Enum.map(fn {_, v} -> v end)
    {condition, rest}
  end

  defp parse_block([{:symbol, :lbrace} | rest]) do
    parse_steps(rest, [])
  end

  defp parse_else_block([{:keyword, :else}, {:symbol, :lbrace} | rest]) do
    parse_steps(rest, [])
  end

  defp parse_else_block(tokens), do: {[], tokens}

  # Private: Code Generation

  defp generate_fsharp(workflow) do
    """
    module Workflows.#{Macro.camelize(to_string(workflow.name))}

    open Cepaf.Orchestration
    open Cepaf.Core

    let #{workflow.name} =
        workflow {
    #{Enum.map_join(workflow.steps, "\n", &generate_step(&1, 2))}
        }
    """
  end

  defp generate_step(%{type: :action, name: name, body: args, constraints: constraints}, indent) do
    pad = String.duplicate("    ", indent)
    constraint_code = generate_constraints(constraints)

    "#{pad}do! #{name} (#{inspect(args)})#{constraint_code}"
  end

  defp generate_step(%{type: :parallel, body: steps}, indent) do
    pad = String.duplicate("    ", indent)
    inner = Enum.map_join(steps, "\n", &generate_step(&1, indent + 1))

    """
    #{pad}parallel {
    #{inner}
    #{pad}}
    """
  end

  defp generate_step(
         %{type: :choice, body: %{condition: cond, then: then_steps, else: else_steps}},
         indent
       ) do
    pad = String.duplicate("    ", indent)
    then_code = Enum.map_join(then_steps, "\n", &generate_step(&1, indent + 1))
    else_code = Enum.map_join(else_steps, "\n", &generate_step(&1, indent + 1))

    """
    #{pad}if #{inspect(cond)} then
    #{then_code}
    #{pad}else
    #{else_code}
    """
  end

  defp generate_step(%{type: :loop, body: %{condition: cond, body: body_steps}}, indent) do
    pad = String.duplicate("    ", indent)
    body_code = Enum.map_join(body_steps, "\n", &generate_step(&1, indent + 1))

    """
    #{pad}while #{inspect(cond)} do
    #{body_code}
    #{pad}done
    """
  end

  defp generate_step(%{type: :sequence, body: steps}, indent) do
    Enum.map_join(steps, "\n", &generate_step(&1, indent))
  end

  defp generate_constraints([]), do: ""

  defp generate_constraints(constraints) do
    parts =
      constraints
      |> Enum.map(fn
        %{type: :timeout, value: ms} -> "timeout #{ms}"
        %{type: :retry, value: %{count: n}} -> "retry #{n}"
        _ -> ""
      end)
      |> Enum.reject(&(&1 == ""))

    if Enum.empty?(parts), do: "", else: " |> " <> Enum.join(parts, " |> ")
  end

  # Private: Validation

  defp validate_name(errors, %{name: name}) when is_atom(name), do: errors
  defp validate_name(errors, _), do: [{:invalid_name, "Workflow name must be an atom"} | errors]

  defp validate_steps(errors, %{steps: steps}) when is_list(steps) do
    step_errors =
      steps
      |> Enum.with_index()
      |> Enum.flat_map(fn {step, idx} -> validate_step(step, idx) end)

    errors ++ step_errors
  end

  defp validate_steps(errors, _), do: [{:invalid_steps, "Steps must be a list"} | errors]

  defp validate_step(%{type: type}, idx)
       when type not in [:action, :parallel, :choice, :loop, :sequence] do
    [{:invalid_step_type, "Invalid step type at index #{idx}: #{type}"}]
  end

  defp validate_step(%{type: :action, name: nil}, idx) do
    [{:missing_action_name, "Action at index #{idx} must have a name"}]
  end

  defp validate_step(_, _), do: []

  defp validate_constraints(errors, %{steps: steps}) do
    constraint_errors =
      steps
      |> Enum.flat_map(fn step -> validate_step_constraints(step.constraints) end)

    errors ++ constraint_errors
  end

  defp validate_step_constraints(constraints) do
    Enum.flat_map(constraints, fn
      %{type: :timeout, value: ms} when not is_integer(ms) or ms <= 0 ->
        [{:invalid_timeout, "Timeout must be a positive integer"}]

      %{type: :retry, value: %{count: n}} when not is_integer(n) or n <= 0 ->
        [{:invalid_retry, "Retry count must be a positive integer"}]

      _ ->
        []
    end)
  end

  defp validate_inputs_outputs(errors, %{inputs: inputs, outputs: outputs})
       when is_list(inputs) and is_list(outputs) do
    errors
  end

  defp validate_inputs_outputs(errors, _) do
    [{:invalid_io, "Inputs and outputs must be lists"} | errors]
  end
end
