defmodule Indrajaal.Cortex.GDE.Generator do
  @moduledoc """
  Unicon-style Generators: Functions that return streams of potential values.

  WHAT: Lazy stream-based value generation for Goal-Directed Evaluation.
  WHY: Enables automatic backtracking - on failure, try next candidate.
  CONSTRAINTS: Must be composable, lazy, and deterministic.

  ## Unicon Inspiration

  In Unicon (successor to Icon), generators produce sequences of values.
  When a value fails, the system backtracks and tries the next value.
  This module brings that paradigm to Elixir for autonomous problem solving.

  ## Usage Examples

  ```elixir
  # Generate alternative file paths and find first valid
  alias Indrajaal.Cortex.GDE.Generator

  result = Generator.find_first(
    Generator.file_candidates("accounts"),
    &File.exists?/1
  )
  # => {:ok, "lib/indrajaal/accounts/accounts.ex"}

  # Compose generators for complex searches
  paths = Generator.compose([
    Generator.file_candidates("auth"),
    Generator.module_paths(Indrajaal.Authentication)
  ])
  ```

  ## STAMP Constraints

  - SC-GDE-001: Generators must be lazy (no eager evaluation)
  - SC-GDE-002: Generators must be composable
  - SC-GDE-003: Generators must be deterministic (same input = same output)

  ## AOR Rules

  - AOR-GDE-001: Use generators for candidate exploration
  - AOR-GDE-002: Limit branching factor to prevent explosion

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-001 to SC-GDE-003 |
  """

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type generator :: Enumerable.t()
  @type predicate :: (term() -> boolean())
  @type transformer :: (term() -> term())

  # ============================================================
  # CONSTANTS
  # ============================================================

  @max_branching_factor 100
  @default_timeout_ms 30_000

  # ============================================================
  # CORE GENERATOR FUNCTIONS
  # ============================================================

  @doc """
  Creates a generator from a list of alternatives.

  ## Parameters
  - alternatives: List of candidate values

  ## Returns
  - Stream of alternatives (lazy)

  ## Example

      Generator.alternatives([:path1, :path2, :path3])
      |> Enum.take(2)
      # => [:path1, :path2]
  """
  @spec alternatives([term()]) :: generator()
  def alternatives(list) when is_list(list) do
    Stream.take(list, @max_branching_factor)
  end

  @doc """
  Creates a generator that yields values matching a predicate.

  ## Parameters
  - generator: Source generator
  - predicate: Function that returns true for valid values

  ## Returns
  - Filtered stream
  """
  @spec filter(generator(), predicate()) :: generator()
  def filter(generator, predicate) when is_function(predicate, 1) do
    Stream.filter(generator, predicate)
  end

  @doc """
  Transforms generator values using a mapper function.

  ## Parameters
  - generator: Source generator
  - transformer: Function to transform each value

  ## Returns
  - Transformed stream
  """
  @spec map(generator(), transformer()) :: generator()
  def map(generator, transformer) when is_function(transformer, 1) do
    Stream.map(generator, transformer)
  end

  @doc """
  Composes multiple generators into a single stream.

  ## Parameters
  - generators: List of generators to compose

  ## Returns
  - Combined stream (flattened, interleaved)

  ## Example

      Generator.compose([
        Generator.alternatives([:a, :b]),
        Generator.alternatives([:c, :d])
      ])
      |> Enum.to_list()
      # => [:a, :b, :c, :d]
  """
  @spec compose([generator()]) :: generator()
  def compose(generators) when is_list(generators) do
    generators
    |> Stream.flat_map(& &1)
    |> Stream.take(@max_branching_factor)
  end

  @doc """
  Interleaves multiple generators (round-robin).

  ## Parameters
  - generators: List of generators

  ## Returns
  - Interleaved stream

  ## Example

      Generator.interleave([
        Generator.alternatives([1, 2, 3]),
        Generator.alternatives([:a, :b, :c])
      ])
      |> Enum.to_list()
      # => [1, :a, 2, :b, 3, :c]
  """
  @spec interleave([generator()]) :: generator()
  def interleave(generators) when is_list(generators) do
    generators
    |> Enum.map(&Stream.cycle/1)
    |> Stream.zip()
    |> Stream.flat_map(&Tuple.to_list/1)
    |> Stream.uniq()
    |> Stream.take(@max_branching_factor)
  end

  @doc """
  Takes values until a predicate returns true.

  ## Parameters
  - generator: Source generator
  - predicate: Stop predicate (stops AFTER first true)

  ## Returns
  - Stream that stops when predicate is satisfied
  """
  @spec take_until(generator(), predicate()) :: generator()
  def take_until(generator, predicate) when is_function(predicate, 1) do
    Stream.transform(generator, false, fn
      _elem, true ->
        {:halt, true}

      elem, false ->
        if predicate.(elem) do
          {[elem], true}
        else
          {[elem], false}
        end
    end)
  end

  @doc """
  Finds the first value that satisfies a predicate.

  ## Parameters
  - generator: Source generator
  - predicate: Success predicate

  ## Returns
  - {:ok, value} if found
  - {:error, :not_found} if exhausted
  """
  @spec find_first(generator(), predicate()) :: {:ok, term()} | {:error, :not_found}
  def find_first(generator, predicate) when is_function(predicate, 1) do
    case Enum.find(generator, predicate) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  @doc """
  Finds all values that satisfy a predicate.

  ## Parameters
  - generator: Source generator
  - predicate: Success predicate
  - opts: Options
    - :limit - Maximum values to return (default: 10)

  ## Returns
  - List of matching values
  """
  @spec find_all(generator(), predicate(), keyword()) :: [term()]
  def find_all(generator, predicate, opts \\ []) when is_function(predicate, 1) do
    limit = Keyword.get(opts, :limit, 10)

    generator
    |> Stream.filter(predicate)
    |> Enum.take(limit)
  end

  # ============================================================
  # DOMAIN-SPECIFIC GENERATORS
  # ============================================================

  @doc """
  Generates candidate file paths for a module name.

  ## Parameters
  - module_name: String or atom representing module name

  ## Returns
  - Generator of possible file paths

  ## Example

      Generator.file_candidates("accounts")
      |> Enum.take(5)
      # => ["lib/indrajaal/accounts.ex", "lib/indrajaal/accounts/accounts.ex", ...]
  """
  @spec file_candidates(String.t() | atom()) :: generator()
  def file_candidates(module_name) do
    name = normalize_module_name(module_name)

    [
      # Direct path
      "lib/indrajaal/#{name}.ex",
      # Domain directory
      "lib/indrajaal/#{name}/#{name}.ex",
      # Nested paths
      "lib/indrajaal/#{name}/context.ex",
      "lib/indrajaal/#{name}/domain.ex",
      # Web paths
      "lib/indrajaal_web/#{name}.ex",
      "lib/indrajaal_web/controllers/#{name}_controller.ex",
      "lib/indrajaal_web/live/#{name}_live.ex",
      # Test paths
      "test/indrajaal/#{name}_test.exs",
      "test/indrajaal/#{name}/#{name}_test.exs"
    ]
    |> alternatives()
  end

  @doc """
  Generates candidate paths from a module atom.

  ## Parameters
  - module: Module atom (e.g., Indrajaal.Accounts)

  ## Returns
  - Generator of possible file paths
  """
  @spec module_paths(module()) :: generator()
  def module_paths(module) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.map_join("/", &Macro.underscore/1)
    |> then(fn path ->
      last_module = List.last(Module.split(module))
      last_module_underscore = last_module |> Macro.underscore()

      [
        "lib/#{path}.ex",
        "lib/#{path}/#{last_module_underscore}.ex"
      ]
    end)
    |> alternatives()
  end

  @doc """
  Generates candidate fix strategies for an error type.

  ## Parameters
  - error_type: Type of error (atom)
  - context: Error context map

  ## Returns
  - Generator of fix strategies
  """
  @spec fix_strategies(atom(), map()) :: generator()
  def fix_strategies(error_type, context \\ %{}) do
    base_strategies = strategies_for_error(error_type)

    # Prioritize strategies based on context
    context_hints = Map.get(context, :hints, [])

    prioritized =
      if Enum.empty?(context_hints) do
        base_strategies
      else
        # Move hinted strategies to front
        {hinted, others} = Enum.split_with(base_strategies, &(&1.type in context_hints))
        hinted ++ others
      end

    alternatives(prioritized)
  end

  @doc """
  Generates candidate parameter values for a function.

  ## Parameters
  - spec: Parameter specification
  - opts: Generation options

  ## Returns
  - Generator of parameter value maps
  """
  @spec parameter_candidates(map(), keyword()) :: generator()
  def parameter_candidates(spec, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    # Generate combinations from spec
    spec
    |> Enum.map(fn {key, generator} ->
      {key, Enum.take(generator, 5)}
    end)
    |> generate_combinations()
    |> Enum.take(limit)
    |> alternatives()
  end

  # ============================================================
  # BACKTRACKING SUPPORT
  # ============================================================

  @doc """
  Executes a function with automatic backtracking on failure.

  ## Parameters
  - generator: Generator of candidate values
  - func: Function to try with each value
  - opts: Options
    - :on_failure - Callback for failures
    - :timeout - Maximum time in ms

  ## Returns
  - {:ok, result} on first success
  - {:error, :exhausted} if all candidates fail
  - {:error, :timeout} if timeout exceeded
  """
  @spec with_backtrack(generator(), (term() -> {:ok, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, :exhausted | :timeout}
  def with_backtrack(generator, func, opts \\ []) when is_function(func, 1) do
    on_failure = Keyword.get(opts, :on_failure, fn _reason -> :continue end)
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    start_time = System.monotonic_time(:millisecond)

    Enum.reduce_while(generator, {:error, :exhausted}, fn candidate, _acc ->
      if System.monotonic_time(:millisecond) - start_time > timeout do
        {:halt, {:error, :timeout}}
      else
        case func.(candidate) do
          {:ok, result} -> {:halt, {:ok, result}}
          {:error, reason} -> handle_backtrack_failure(reason, on_failure)
        end
      end
    end)
  end

  defp handle_backtrack_failure(reason, on_failure) do
    case on_failure.(reason) do
      :stop -> {:halt, {:error, reason}}
      :continue -> {:cont, {:error, :exhausted}}
    end
  end

  @doc """
  Runs multiple generators in parallel and returns first success.

  ## Parameters
  - generators: List of {generator, func} tuples
  - opts: Options
    - :timeout - Maximum time in ms

  ## Returns
  - {:ok, result} from first successful generator
  - {:error, :all_failed} if none succeed
  """
  @spec race([{generator(), (term() -> {:ok, term()} | {:error, term()})}], keyword()) ::
          {:ok, term()} | {:error, :all_failed}
  def race(generators, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    # Run each generator in a task
    tasks =
      Enum.map(generators, fn {generator, func} ->
        Task.async(fn ->
          with_backtrack(generator, func, timeout: timeout)
        end)
      end)

    # Wait for first success or all to complete
    result =
      Enum.reduce_while(tasks, {:error, :all_failed}, fn task, acc ->
        case Task.yield(task, timeout) || Task.shutdown(task) do
          {:ok, {:ok, result}} -> {:halt, {:ok, result}}
          _ -> {:cont, acc}
        end
      end)

    # Shutdown remaining tasks
    Enum.each(tasks, fn task ->
      Task.shutdown(task, :brutal_kill)
    end)

    result
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp normalize_module_name(name) when is_atom(name) do
    name |> Atom.to_string() |> Macro.underscore()
  end

  defp normalize_module_name(name) when is_binary(name) do
    Macro.underscore(name)
  end

  defp strategies_for_error(:undefined_function) do
    [
      %{type: :add_import, priority: 1},
      %{type: :add_alias, priority: 2},
      %{type: :define_function, priority: 3},
      %{type: :fix_typo, priority: 4}
    ]
  end

  defp strategies_for_error(:undefined_module) do
    [
      %{type: :add_alias, priority: 1},
      %{type: :create_module, priority: 2},
      %{type: :fix_module_name, priority: 3}
    ]
  end

  defp strategies_for_error(:pattern_match_error) do
    [
      %{type: :add_clause, priority: 1},
      %{type: :fix_pattern, priority: 2},
      %{type: :add_guard, priority: 3}
    ]
  end

  defp strategies_for_error(:type_error) do
    [
      %{type: :add_conversion, priority: 1},
      %{type: :fix_type, priority: 2},
      %{type: :add_typespec, priority: 3}
    ]
  end

  defp strategies_for_error(_) do
    [
      %{type: :generic_fix, priority: 5}
    ]
  end

  defp generate_combinations(key_values) do
    case key_values do
      [] ->
        [%{}]

      [{key, values} | rest] ->
        rest_combinations = generate_combinations(rest)

        for value <- values, combo <- rest_combinations do
          Map.put(combo, key, value)
        end
    end
  end
end
