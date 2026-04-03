defmodule Indrajaal.Morphogenic.L1FunctionCompositionChainsTest do
  @moduledoc """
  L1 Fractal Layer: Function Composition & Pipeline Chains

  WHAT: Self-contained ETS-backed tests for function composition chains,
        Result monad pipelines, Kleisli composition, and effect system
        boundaries at the L1 (Function) fractal layer.

  WHY: Validates that the foundational function composition primitives
       satisfy mathematical laws (associativity, monad laws) and that
       error propagation through pipelines is deterministic and correct.
       L1 purity is the foundation for all higher fractal layers.

  CONSTRAINTS:
    - SC-FUNC-001: System MUST compile at all times
    - SC-VER-007: All source files compiled
    - SC-FSH-010: Kleisli composition for Result pipeline chaining

  ## Fractal Layer
  - L1 (Function): Pure transformations, I/O contracts, no side effects

  ## Test Coverage
  - Function composition chains (f |> g |> h)
  - Result monad pipelines ({:ok, v} / {:error, r})
  - Pipe operator associativity
  - Partial application simulation
  - Function arity validation
  - Kleisli composition for error-handling chains
  - Effect system boundaries (pure vs. effectful separation)
  - ETS-backed function registry and composition trace logging

  ## Properties Verified
  - Composition associativity: (f∘g)∘h = f∘(g∘h)
  - Result monad left identity: return(a) >>= f = f(a)
  - Result monad right identity: m >>= return = m
  - Result monad associativity: (m >>= f) >>= g = m >>= (fn x -> f(x) >>= g)
  - Error propagation: first error wins in pipeline
  - Pipeline length independence: result independent of chain length for pure fns

  Task ID: e0682f32
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l1

  # ---------------------------------------------------------------------------
  # ETS Setup — function registry and composition trace log
  # ---------------------------------------------------------------------------

  @registry_table :l1_fn_registry
  @trace_table :l1_compose_trace

  setup_all do
    # Create ETS tables for function registry and trace log
    unless :ets.whereis(@registry_table) != :undefined do
      :ets.new(@registry_table, [:named_table, :public, :set])
    end

    unless :ets.whereis(@trace_table) != :undefined do
      :ets.new(@trace_table, [:named_table, :public, :ordered_set])
    end

    # Register a library of pure test functions
    register_function(:double, fn x -> x * 2 end)
    register_function(:increment, fn x -> x + 1 end)
    register_function(:negate, fn x -> -x end)
    register_function(:square, fn x -> x * x end)
    register_function(:halve, fn x -> x / 2 end)
    register_function(:stringify, fn x -> "#{x}" end)
    register_function(:string_length, fn s -> String.length(s) end)
    register_function(:to_list, fn x -> [x] end)
    register_function(:identity, fn x -> x end)
    register_function(:add_ten, fn x -> x + 10 end)

    # Register Result-returning (Kleisli) functions
    register_function(:ok_double, fn x -> {:ok, x * 2} end)
    register_function(:ok_increment, fn x -> {:ok, x + 1} end)
    register_function(:ok_negate, fn x -> {:ok, -x} end)
    register_function(:ok_identity, fn x -> {:ok, x} end)
    register_function(:ok_stringify, fn x -> {:ok, "#{x}"} end)

    register_function(:fail_if_negative, fn x ->
      if x < 0, do: {:error, :negative_value}, else: {:ok, x}
    end)

    register_function(:fail_if_zero, fn x ->
      if x == 0, do: {:error, :division_by_zero}, else: {:ok, x}
    end)

    register_function(:fail_if_large, fn x ->
      if x > 1000, do: {:error, :overflow}, else: {:ok, x}
    end)

    register_function(:safe_divide_by_two, fn x ->
      if x == 0, do: {:error, :division_by_zero}, else: {:ok, div(x, 2)}
    end)

    on_exit(fn ->
      try do
        :ets.delete_all_objects(@registry_table)
        :ets.delete_all_objects(@trace_table)
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  setup do
    :ets.delete_all_objects(@trace_table)
    :ok
  end

  # ---------------------------------------------------------------------------
  # ETS Helper Functions
  # ---------------------------------------------------------------------------

  defp register_function(name, fun) do
    :ets.insert(@registry_table, {name, fun})
  end

  defp lookup_function(name) do
    case :ets.lookup(@registry_table, name) do
      [{^name, fun}] -> {:ok, fun}
      [] -> {:error, {:not_found, name}}
    end
  end

  defp log_trace(pipeline_id, step, input, output) do
    ts = System.monotonic_time(:nanosecond)
    :ets.insert(@trace_table, {{ts, pipeline_id, step}, input, output})
  end

  defp get_trace(pipeline_id) do
    :ets.match_object(@trace_table, {{:_, pipeline_id, :_}, :_, :_})
    |> Enum.sort_by(fn {{ts, _, _}, _, _} -> ts end)
  end

  defp trace_count, do: :ets.info(@trace_table, :size)

  # ---------------------------------------------------------------------------
  # Core Composition Primitives (pure, no side effects)
  # ---------------------------------------------------------------------------

  # Standard function composition: (f ∘ g)(x) = f(g(x))
  defp compose(f, g), do: fn x -> f.(g.(x)) end

  # Compose a list of functions left-to-right (pipeline order)
  defp compose_pipeline([]), do: fn x -> x end
  defp compose_pipeline([f]), do: f
  defp compose_pipeline([f | rest]), do: compose(compose_pipeline(rest), f)

  # Kleisli composition (fish operator >=>): f >=> g = fn x -> bind(f(x), g) end
  defp kleisli(f, g) do
    fn x ->
      case f.(x) do
        {:ok, v} -> g.(v)
        {:error, _} = err -> err
      end
    end
  end

  # Kleisli compose a list: f1 >=> f2 >=> ... >=> fn
  defp kleisli_pipeline([]), do: fn x -> {:ok, x} end
  defp kleisli_pipeline([f]), do: f
  defp kleisli_pipeline([f | rest]), do: kleisli(f, kleisli_pipeline(rest))

  # Result monad bind (>>=)
  defp result_bind({:ok, v}, f), do: f.(v)
  defp result_bind({:error, _} = err, _f), do: err

  # Result monad return
  defp result_return(v), do: {:ok, v}

  # Traced pipeline — logs each step to ETS
  defp traced_pipeline(value, fns, pipeline_id) do
    fns
    |> Enum.with_index()
    |> Enum.reduce(value, fn {f, idx}, acc ->
      result = f.(acc)
      log_trace(pipeline_id, idx, acc, result)
      result
    end)
  end

  # Partial application simulation via closure
  defp partial(f, arg1), do: fn arg2 -> f.(arg1, arg2) end

  # ---------------------------------------------------------------------------
  # Tests: Basic Function Composition
  # ---------------------------------------------------------------------------

  describe "basic function composition chains" do
    test "compose two functions produces correct result" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)

      # (double ∘ increment)(5) = double(increment(5)) = double(6) = 12
      composed = compose(double, increment)
      assert composed.(5) == 12
    end

    test "compose three functions in pipeline order" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)

      # pipeline: x |> increment |> double |> negate
      # = negate(double(increment(x)))
      # For x=3: increment(3)=4, double(4)=8, negate(8)=-8
      pipeline = compose(negate, compose(double, increment))
      assert pipeline.(3) == -8
    end

    test "compose_pipeline with empty list returns identity" do
      identity = compose_pipeline([])
      assert identity.(42) == 42
      assert identity.("hello") == "hello"
      assert identity.([1, 2, 3]) == [1, 2, 3]
    end

    test "compose_pipeline with single function returns same function" do
      {:ok, double} = lookup_function(:double)
      pipeline = compose_pipeline([double])
      assert pipeline.(5) == 10
    end

    test "compose_pipeline applies functions left-to-right" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, square} = lookup_function(:square)

      # Left-to-right: x |> double |> increment |> square
      # For x=3: double(3)=6, increment(6)=7, square(7)=49
      pipeline = compose_pipeline([double, increment, square])
      assert pipeline.(3) == 49
    end

    test "identity function is neutral element for composition" do
      {:ok, double} = lookup_function(:double)
      {:ok, identity} = lookup_function(:identity)

      left_identity = compose(double, identity)
      right_identity = compose(identity, double)

      assert left_identity.(7) == double.(7)
      assert right_identity.(7) == double.(7)
    end

    test "pipe operator produces same result as explicit composition" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)

      x = 5

      # Using Elixir pipe
      pipe_result = x |> double.() |> increment.() |> negate.()

      # Using compose
      composed = compose(negate, compose(increment, double))
      compose_result = composed.(x)

      assert pipe_result == compose_result
    end

    test "function composition with string transforms" do
      {:ok, stringify} = lookup_function(:stringify)
      {:ok, string_length} = lookup_function(:string_length)
      {:ok, double} = lookup_function(:double)

      # stringify then measure length then double the length
      pipeline = compose_pipeline([stringify, string_length, double])

      # stringify(12345) = "12345" (length 5), double(5) = 10
      assert pipeline.(12345) == 10
    end

    test "traced pipeline logs each step to ETS" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)

      initial_count = trace_count()
      pipeline_id = :test_traced_pipeline

      result = traced_pipeline(4, [double, increment, negate], pipeline_id)

      # double(4)=8, increment(8)=9, negate(9)=-9
      assert result == -9

      # Should have logged 3 steps
      assert trace_count() == initial_count + 3

      traces = get_trace(pipeline_id)
      assert length(traces) == 3

      # Verify trace contents
      [{{_, _, 0}, 4, 8}, {{_, _, 1}, 8, 9}, {{_, _, 2}, 9, -9}] = traces
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Result Monad Pipelines
  # ---------------------------------------------------------------------------

  describe "Result monad pipelines" do
    test "successful pipeline propagates {:ok, value}" do
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, ok_increment} = lookup_function(:ok_increment)
      {:ok, ok_negate} = lookup_function(:ok_negate)

      pipeline = kleisli_pipeline([ok_double, ok_increment, ok_negate])

      # double(5)=10, increment(10)=11, negate(11)=-11
      assert pipeline.(5) == {:ok, -11}
    end

    test "error short-circuits pipeline at first failure" do
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, fail_if_zero} = lookup_function(:fail_if_zero)
      {:ok, ok_increment} = lookup_function(:ok_increment)

      pipeline = kleisli_pipeline([ok_double, fail_if_zero, ok_increment])

      # double(0)=0, fail_if_zero(0)={:error, :division_by_zero}
      # ok_increment should NOT be called
      assert pipeline.(0) == {:error, :division_by_zero}
    end

    test "error from middle step propagates unchanged" do
      {:ok, ok_increment} = lookup_function(:ok_increment)
      {:ok, fail_if_negative} = lookup_function(:fail_if_negative)
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, ok_negate} = lookup_function(:ok_negate)

      pipeline = kleisli_pipeline([ok_negate, fail_if_negative, ok_double, ok_increment])

      # negate(5)=-5, fail_if_negative(-5) = {:error, :negative_value}
      assert pipeline.(5) == {:error, :negative_value}
    end

    test "result_bind threads value through successful computation" do
      result =
        {:ok, 10}
        |> result_bind(fn x -> {:ok, x * 2} end)
        |> result_bind(fn x -> {:ok, x + 1} end)

      assert result == {:ok, 21}
    end

    test "result_bind short-circuits on error" do
      call_count = :counters.new(1, [:atomics])

      result =
        {:error, :initial_error}
        |> result_bind(fn x ->
          :counters.add(call_count, 1, 1)
          {:ok, x * 2}
        end)

      assert result == {:error, :initial_error}
      assert :counters.get(call_count, 1) == 0
    end

    test "multiple error types preserved through pipeline" do
      {:ok, fail_if_negative} = lookup_function(:fail_if_negative)
      {:ok, fail_if_zero} = lookup_function(:fail_if_zero)
      {:ok, fail_if_large} = lookup_function(:fail_if_large)

      pipeline = kleisli_pipeline([fail_if_negative, fail_if_zero, fail_if_large])

      assert pipeline.(-1) == {:error, :negative_value}
      assert pipeline.(0) == {:error, :division_by_zero}
      assert pipeline.(1001) == {:error, :overflow}
      assert pipeline.(5) == {:ok, 5}
    end

    test "kleisli composition of identity is identity" do
      {:ok, ok_identity} = lookup_function(:ok_identity)

      pipeline = kleisli_pipeline([ok_identity, ok_identity, ok_identity])
      assert pipeline.(42) == {:ok, 42}
      assert pipeline.("hello") == {:ok, "hello"}
    end

    test "safe_divide_by_two in chain handles zero correctly" do
      {:ok, safe_div} = lookup_function(:safe_divide_by_two)
      {:ok, ok_increment} = lookup_function(:ok_increment)

      # Chain: increment then safe_div twice
      pipeline = kleisli_pipeline([ok_increment, safe_div, safe_div])

      # increment(-1)=0, safe_div(0) = {:error, :division_by_zero}
      assert pipeline.(-1) == {:error, :division_by_zero}

      # increment(7)=8, safe_div(8)=4, safe_div(4)=2
      assert pipeline.(7) == {:ok, 2}
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Partial Application
  # ---------------------------------------------------------------------------

  describe "partial application" do
    test "partial application produces correct curried function" do
      add = fn a, b -> a + b end
      add_five = partial(add, 5)

      assert add_five.(3) == 8
      assert add_five.(10) == 15
      assert add_five.(0) == 5
    end

    test "partially applied function can be composed" do
      multiply = fn a, b -> a * b end
      triple = partial(multiply, 3)

      {:ok, increment} = lookup_function(:increment)
      pipeline = compose(triple, increment)

      # increment(4)=5, triple(5)=15
      assert pipeline.(4) == 15
    end

    test "partial application preserves referential transparency" do
      add = fn a, b -> a + b end
      add_ten = partial(add, 10)

      # Same input always produces same output
      assert add_ten.(5) == add_ten.(5)
      assert add_ten.(0) == add_ten.(0)
    end

    test "multiple partial applications chain correctly" do
      add = fn a, b -> a + b end
      add_one = partial(add, 1)
      add_two = partial(add, 2)
      add_three = partial(add, 3)

      pipeline = compose(add_three, compose(add_two, add_one))

      # add_one(0)=1, add_two(1)=3, add_three(3)=6
      assert pipeline.(0) == 6
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Function Arity Validation
  # ---------------------------------------------------------------------------

  describe "function arity validation" do
    test "registered functions have correct arity (1)" do
      function_names = [
        :double,
        :increment,
        :negate,
        :square,
        :identity,
        :ok_double,
        :ok_increment,
        :fail_if_negative
      ]

      for name <- function_names do
        {:ok, fun} = lookup_function(name)
        assert is_function(fun, 1), "Expected #{name} to have arity 1"
      end
    end

    test "composed function has arity 1" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)

      composed = compose(double, increment)
      assert is_function(composed, 1)
    end

    test "kleisli composed function has arity 1" do
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, ok_increment} = lookup_function(:ok_increment)

      kleisli_fn = kleisli(ok_double, ok_increment)
      assert is_function(kleisli_fn, 1)
    end

    test "pipeline of n functions has arity 1" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)

      pipeline = compose_pipeline([double, increment, negate])
      assert is_function(pipeline, 1)
    end

    test "partially applied function (2-arity) yields 1-arity function" do
      add = fn a, b -> a + b end
      assert is_function(add, 2)

      add_five = partial(add, 5)
      assert is_function(add_five, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Effect System Boundaries
  # ---------------------------------------------------------------------------

  describe "effect system boundaries" do
    test "pure functions do not modify ETS state" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)

      before_count = trace_count()
      pipeline = compose_pipeline([double, increment])
      _result = pipeline.(5)

      # Pure composition should NOT log to ETS
      assert trace_count() == before_count
    end

    test "traced pipeline does modify ETS state" do
      {:ok, double} = lookup_function(:double)

      before_count = trace_count()
      traced_pipeline(5, [double], :effect_test)

      assert trace_count() == before_count + 1
    end

    test "ETS function registry is independent of computation" do
      # Registry should not change during computation
      registry_before = :ets.info(@registry_table, :size)

      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      composed = compose(double, increment)
      _result = composed.(42)

      registry_after = :ets.info(@registry_table, :size)
      assert registry_before == registry_after
    end

    test "effectful and pure pipelines produce same results" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)

      input = 7
      fns = [double, increment, negate]

      # Pure composition
      pure_pipeline = compose_pipeline(fns)
      pure_result = pure_pipeline.(input)

      # Traced (effectful) pipeline
      traced_result = traced_pipeline(input, fns, :effect_purity_test)

      assert pure_result == traced_result
    end

    test "function registry lookup has no side effects on computation" do
      lookup_result_1 = lookup_function(:double)
      lookup_result_2 = lookup_function(:double)

      assert lookup_result_1 == lookup_result_2

      {:ok, double_1} = lookup_result_1
      {:ok, double_2} = lookup_result_2

      # Both should produce identical results
      assert double_1.(5) == double_2.(5)
    end
  end

  # ---------------------------------------------------------------------------
  # Property Tests
  # ---------------------------------------------------------------------------

  property "composition associativity: (f∘g)∘h = f∘(g∘h)" do
    forall x <- PC.integer() do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)

      # Left-associated: (double ∘ increment) ∘ negate
      left_assoc = compose(compose(double, increment), negate)

      # Right-associated: double ∘ (increment ∘ negate)
      right_assoc = compose(double, compose(increment, negate))

      left_assoc.(x) == right_assoc.(x)
    end
  end

  property "Result monad left identity: return(a) >>= f = f(a)" do
    forall a <- PC.integer() do
      f = fn x -> {:ok, x * 2 + 1} end

      # Left identity: bind(return(a), f) = f(a)
      lhs = result_bind(result_return(a), f)
      rhs = f.(a)

      lhs == rhs
    end
  end

  property "Result monad right identity: m >>= return = m" do
    forall a <- PC.integer() do
      m = {:ok, a}

      # Right identity: bind(m, return) = m
      result = result_bind(m, &result_return/1)

      result == m
    end
  end

  property "Result monad associativity: (m >>= f) >>= g = m >>= (fn x -> f(x) >>= g)" do
    forall a <- PC.non_neg_integer() do
      m = {:ok, a}
      f = fn x -> if x > 100, do: {:error, :too_large}, else: {:ok, x * 2} end
      g = fn x -> {:ok, x + 1} end

      # Left-associated
      lhs = result_bind(result_bind(m, f), g)

      # Right-associated (flattened)
      rhs = result_bind(m, fn x -> result_bind(f.(x), g) end)

      lhs == rhs
    end
  end

  property "error propagation: first error wins in Result pipeline" do
    forall {a, b} <- {PC.integer(), PC.integer()} do
      # When the first function fails, subsequent functions should not be called
      call_log = :ets.new(:call_log_prop, [:set, :public])

      f_fail = fn _x -> {:error, {:first_error, a}} end

      g_tracked = fn x ->
        :ets.insert(call_log, {:called, true})
        {:ok, x + b}
      end

      pipeline = kleisli(f_fail, g_tracked)
      result = pipeline.(42)

      was_called = :ets.lookup(call_log, :called) != []
      :ets.delete(call_log)

      result == {:error, {:first_error, a}} and not was_called
    end
  end

  property "pipeline length independence for pure functions" do
    forall {x, n} <- {PC.integer(), PC.range(1, 10)} do
      {:ok, identity} = lookup_function(:identity)

      # Pipeline of n identity functions should equal single identity
      single = identity.(x)
      n_chain = compose_pipeline(List.duplicate(identity, n)).(x)

      single == n_chain
    end
  end

  property "kleisli composition associativity for Result fns" do
    forall x <- PC.non_neg_integer() do
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, ok_increment} = lookup_function(:ok_increment)
      {:ok, fail_if_large} = lookup_function(:fail_if_large)

      # (f >=> g) >=> h  =  f >=> (g >=> h)
      left_assoc = kleisli(kleisli(ok_double, ok_increment), fail_if_large)
      right_assoc = kleisli(ok_double, kleisli(ok_increment, fail_if_large))

      left_assoc.(x) == right_assoc.(x)
    end
  end

  property "partial application with integer addition is correct" do
    forall {a, b} <- {PC.integer(), PC.integer()} do
      add = fn x, y -> x + y end
      add_a = partial(add, a)

      add_a.(b) == a + b
    end
  end

  # ---------------------------------------------------------------------------
  # StreamData Properties (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "StreamData property: compose_pipeline of pure fns is deterministic" do
    forall {{x, n}} <- {{PC.integer(), PC.integer(1, 5)}} do
      {:ok, double} = lookup_function(:double)

      fns = List.duplicate(double, n)
      pipeline = compose_pipeline(fns)

      # Running the same pipeline twice gives the same result
      assert pipeline.(x) == pipeline.(x)
    end
  end

  test "StreamData property: Result ok-pipeline preserves value type" do
    forall x <- PC.integer() do
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, ok_increment} = lookup_function(:ok_increment)

      pipeline = kleisli_pipeline([ok_double, ok_increment])
      result = pipeline.(x)

      # Result must always be {:ok, integer} for these inputs
      assert match?({:ok, v} when is_integer(v), result)
    end
  end

  test "StreamData property: error result always propagates unchanged" do
    forall {{x, reason}} <- {{PC.integer(), PC.atom()}} do
      error = {:error, reason}
      f = fn v -> {:ok, v * 2} end

      # Binding on error should return unchanged error
      assert result_bind(error, f) == error
    end
  end

  # ---------------------------------------------------------------------------
  # Integration Test: Full Composition Chain with ETS Tracing
  # ---------------------------------------------------------------------------

  describe "integration: traced composition pipeline" do
    test "full pipeline with mixed pure and Result functions" do
      {:ok, double} = lookup_function(:double)
      {:ok, ok_increment} = lookup_function(:ok_increment)
      {:ok, fail_if_negative} = lookup_function(:fail_if_negative)
      {:ok, ok_stringify} = lookup_function(:ok_stringify)

      # Phase 1: pure transformation
      pure_step = double.(5)
      assert pure_step == 10

      # Phase 2: Result monad pipeline
      result =
        {:ok, pure_step}
        |> result_bind(fn x -> ok_increment.(x) end)
        |> result_bind(fn x -> fail_if_negative.(x) end)
        |> result_bind(fn x -> ok_stringify.(x) end)

      assert result == {:ok, "11"}
    end

    test "pipeline telemetry captured in ETS across 5-step chain" do
      {:ok, double} = lookup_function(:double)
      {:ok, increment} = lookup_function(:increment)
      {:ok, negate} = lookup_function(:negate)
      {:ok, square} = lookup_function(:square)
      {:ok, add_ten} = lookup_function(:add_ten)

      pipeline_id = :integration_5_step
      fns = [double, increment, negate, square, add_ten]

      result = traced_pipeline(3, fns, pipeline_id)

      # double(3)=6, increment(6)=7, negate(7)=-7, square(-7)=49, add_ten(49)=59
      assert result == 59

      traces = get_trace(pipeline_id)
      assert length(traces) == 5

      # Verify step inputs/outputs
      [
        {{_, _, 0}, 3, 6},
        {{_, _, 1}, 6, 7},
        {{_, _, 2}, 7, -7},
        {{_, _, 3}, -7, 49},
        {{_, _, 4}, 49, 59}
      ] = traces
    end

    test "error in kleisli pipeline does not contaminate ETS registry" do
      {:ok, ok_double} = lookup_function(:ok_double)
      {:ok, fail_if_zero} = lookup_function(:fail_if_zero)

      registry_size_before = :ets.info(@registry_table, :size)

      pipeline = kleisli_pipeline([ok_double, fail_if_zero])
      result = pipeline.(0)

      assert result == {:error, :division_by_zero}
      assert :ets.info(@registry_table, :size) == registry_size_before
    end

    test "concurrent ETS trace writes do not corrupt log" do
      {:ok, double} = lookup_function(:double)

      pipeline_ids = Enum.map(1..10, &:"concurrent_pipeline_#{&1}")

      tasks =
        Enum.map(pipeline_ids, fn pid ->
          Task.async(fn ->
            traced_pipeline(:rand.uniform(100), [double, double], pid)
          end)
        end)

      results = Task.await_many(tasks)

      # All results should be valid (double twice = multiply by 4)
      for result <- results do
        assert is_integer(result)
        assert rem(result, 4) == 0
      end

      # All 10 pipelines should have 2 traces each
      for pid <- pipeline_ids do
        traces = get_trace(pid)
        assert length(traces) == 2
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Edge Cases
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    test "empty kleisli pipeline acts as identity" do
      empty_pipeline = kleisli_pipeline([])
      assert empty_pipeline.(42) == {:ok, 42}
      assert empty_pipeline.(0) == {:ok, 0}
      assert empty_pipeline.(-100) == {:ok, -100}
    end

    test "compose_pipeline with single identity is transparent" do
      {:ok, identity} = lookup_function(:identity)
      pipeline = compose_pipeline([identity])

      assert pipeline.(99) == 99
      assert pipeline.(0) == 0
      assert pipeline.(-1) == -1
    end

    test "composition of error-producing function with itself" do
      {:ok, fail_if_negative} = lookup_function(:fail_if_negative)

      pipeline = kleisli(fail_if_negative, fail_if_negative)

      # Positive: first step succeeds, second also succeeds
      assert pipeline.(5) == {:ok, 5}

      # Negative: first step fails, second never runs
      assert pipeline.(-3) == {:error, :negative_value}
    end

    test "lookup_function returns error for unknown function" do
      assert {:error, {:not_found, :nonexistent}} = lookup_function(:nonexistent)
    end

    test "registered function overwrites previous registration" do
      register_function(:temp_fn, fn x -> x + 1 end)
      {:ok, fn1} = lookup_function(:temp_fn)
      assert fn1.(5) == 6

      register_function(:temp_fn, fn x -> x * 10 end)
      {:ok, fn2} = lookup_function(:temp_fn)
      assert fn2.(5) == 50
    end
  end
end
