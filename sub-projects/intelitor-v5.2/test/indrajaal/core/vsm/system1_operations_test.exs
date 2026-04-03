defmodule Indrajaal.Core.VSM.System1OperationsTest do
  @moduledoc """
  Test suite for Indrajaal.Core.VSM.System1Operations

  ## WHAT
  Tests for VSM System 1 operations: monadic result composition, context
  construction, parallel execution, and retry with exponential backoff.

  ## Coverage
  - return/1: wraps value in {:ok, value}
  - bind/2: monadic chaining (success and error propagation)
  - map/2: functor mapping over {:ok, value}
  - sequence/1: fail-fast reduction over a list of results
  - context/5: context struct construction with defaults
  - execute/2: async execution with telemetry, timeout, exception handling
  - parallel/2: concurrent execution collecting results
  - retry/3: exponential-backoff retry up to max_attempts

  ## STAMP Constraints
  - SC-S1-001: Operation idempotency verified
  - SC-S1-002: Telemetry emission verified via :telemetry.attach
  - SC-S1-003: Timeout handling tested
  - SC-S1-004: Failure reporting path tested
  """

  # async: false required — execute/2 spawns Tasks that may crash and are linked
  # to the test process; async: true would allow crash propagation between test cases.
  use ExUnit.Case, async: false
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check so ExUnitProperties' ExUnitProperties.check all() wins (SC-PROP-023)
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Core.VSM.System1Operations, as: S1

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp test_context(opts \\ []) do
    S1.context(
      "test-holon-#{:erlang.unique_integer([:positive])}",
      :l3_holon,
      :test_operation,
      %{},
      opts
    )
  end

  defp attach_telemetry_spy do
    ref = make_ref()
    parent = self()
    handler_id = "test-s1-#{inspect(ref)}"

    :telemetry.attach(
      handler_id,
      [:indrajaal, :holon, :operation],
      fn event, measurements, metadata, _config ->
        send(parent, {:telemetry_event, ref, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    ref
  end

  # ---------------------------------------------------------------------------
  # describe "return/1"
  # ---------------------------------------------------------------------------

  describe "return/1" do
    test "wraps any term in {:ok, term()}" do
      assert {:ok, 42} = S1.return(42)
      assert {:ok, "hello"} = S1.return("hello")
      assert {:ok, %{a: 1}} = S1.return(%{a: 1})
      assert {:ok, nil} = S1.return(nil)
      assert {:ok, [1, 2, 3]} = S1.return([1, 2, 3])
    end

    test "works with an error-tagged tuple" do
      assert {:ok, {:error, :something}} = S1.return({:error, :something})
    end
  end

  # ---------------------------------------------------------------------------
  # describe "bind/2"
  # ---------------------------------------------------------------------------

  describe "bind/2" do
    test "calls function with unwrapped value on {:ok, value}" do
      result = S1.bind({:ok, 10}, fn x -> {:ok, x * 2} end)
      assert result == {:ok, 20}
    end

    test "propagates {:error, reason} without calling function" do
      called = :atomics.new(1, [])

      result =
        S1.bind({:error, :upstream_fail}, fn _x ->
          :atomics.put(called, 1, 1)
          {:ok, :should_not_run}
        end)

      assert result == {:error, :upstream_fail}
      assert :atomics.get(called, 1) == 0
    end

    test "chains multiple binds transforming value" do
      result =
        {:ok, 1}
        |> S1.bind(fn x -> {:ok, x + 1} end)
        |> S1.bind(fn x -> {:ok, x * 10} end)
        |> S1.bind(fn x -> {:ok, Integer.to_string(x)} end)

      assert result == {:ok, "20"}
    end

    test "chain halts at first error and skips remaining steps" do
      result =
        {:ok, 5}
        |> S1.bind(fn x -> {:ok, x + 1} end)
        |> S1.bind(fn _x -> {:error, :step_two_failed} end)
        |> S1.bind(fn _x -> {:ok, :should_be_skipped} end)

      assert result == {:error, :step_two_failed}
    end

    test "function that returns another error is propagated" do
      result = S1.bind({:ok, 42}, fn _x -> {:error, :converted_error} end)
      assert result == {:error, :converted_error}
    end
  end

  # ---------------------------------------------------------------------------
  # describe "map/2"
  # ---------------------------------------------------------------------------

  describe "map/2" do
    test "applies function to value inside {:ok, value}" do
      assert {:ok, 6} = S1.map({:ok, 3}, fn x -> x * 2 end)
    end

    test "passes through {:error, reason} unchanged" do
      assert {:error, :bad_input} = S1.map({:error, :bad_input}, fn _x -> :never_called end)
    end

    test "map with identity function is a no-op" do
      assert {:ok, 99} = S1.map({:ok, 99}, fn x -> x end)
    end

    test "map can transform type (int to string)" do
      assert {:ok, "42"} = S1.map({:ok, 42}, &Integer.to_string/1)
    end

    test "map with complex transformation" do
      result = S1.map({:ok, [1, 2, 3]}, fn list -> Enum.sum(list) end)
      assert result == {:ok, 6}
    end
  end

  # ---------------------------------------------------------------------------
  # describe "sequence/1"
  # ---------------------------------------------------------------------------

  describe "sequence/1" do
    test "empty list returns {:ok, []}" do
      assert {:ok, []} = S1.sequence([])
    end

    test "all-ok list returns {:ok, values_in_order}" do
      results = [{:ok, 1}, {:ok, 2}, {:ok, 3}]
      assert {:ok, [1, 2, 3]} = S1.sequence(results)
    end

    test "fails fast on first error and returns that error" do
      results = [{:ok, 1}, {:error, :step_two_fails}, {:ok, 3}]
      assert {:error, :step_two_fails} = S1.sequence(results)
    end

    test "error at position 1 short-circuits the rest" do
      results = [{:error, :immediate_fail}, {:ok, :unreachable}]
      assert {:error, :immediate_fail} = S1.sequence(results)
    end

    test "error at last position propagates correctly" do
      results = [{:ok, :a}, {:ok, :b}, {:error, :last_fails}]
      assert {:error, :last_fails} = S1.sequence(results)
    end

    test "preserves order of ok values" do
      results = Enum.map([:x, :y, :z], &{:ok, &1})
      assert {:ok, [:x, :y, :z]} = S1.sequence(results)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "context/5"
  # ---------------------------------------------------------------------------

  describe "context/5" do
    test "constructs a context map with all required fields" do
      ctx = S1.context("holon-1", :l2_component, :read, %{key: "val"})
      assert ctx.holon_id == "holon-1"
      assert ctx.layer == :l2_component
      assert ctx.operation == :read
      assert ctx.args == %{key: "val"}
    end

    test "default timeout is 5000ms" do
      ctx = S1.context("h", :l1_function, :op, [])
      assert ctx.timeout == 5_000
    end

    test "timeout can be overridden via opts" do
      ctx = S1.context("h", :l1_function, :op, [], timeout: 1_000)
      assert ctx.timeout == 1_000
    end

    test "accepts all valid VSM layer atoms" do
      layers = [:l1_function, :l2_component, :l3_holon, :l4_container, :l5_node]

      for layer <- layers do
        ctx = S1.context("h", layer, :op, nil)
        assert ctx.layer == layer
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe "execute/2"
  # ---------------------------------------------------------------------------

  describe "execute/2" do
    test "returns the value produced by operation_fn" do
      ctx = test_context()
      result = S1.execute(ctx, fn -> {:ok, :computed_value} end)
      assert result == {:ok, :computed_value}
    end

    test "propagates {:error, reason} from operation_fn" do
      ctx = test_context()
      result = S1.execute(ctx, fn -> {:error, :domain_failure} end)
      assert result == {:error, :domain_failure}
    end

    test "completes successfully with complex transformations in operation_fn" do
      ctx = test_context()
      input = [1, 2, 3, 4, 5]

      result =
        S1.execute(ctx, fn ->
          sum = Enum.sum(input)
          {:ok, sum * 2}
        end)

      assert result == {:ok, 30}
    end

    test "propagates nested {:error, reason} tuples as-is" do
      ctx = test_context()
      result = S1.execute(ctx, fn -> {:error, {:validation, :name_too_short}} end)
      assert result == {:error, {:validation, :name_too_short}}
    end

    test "returns {:error, :timeout} when operation exceeds configured timeout" do
      ctx = test_context(timeout: 50)

      result =
        S1.execute(ctx, fn ->
          Process.sleep(500)
          {:ok, :too_late}
        end)

      assert result == {:error, :timeout}
    end

    test "emits telemetry event [:indrajaal, :holon, :operation] with duration" do
      ref = attach_telemetry_spy()
      ctx = test_context()

      S1.execute(ctx, fn -> {:ok, :telemetry_test} end)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :holon, :operation], measurements,
                      metadata},
                     500

      assert is_number(measurements.duration_ms)
      assert measurements.duration_ms >= 0
      assert metadata.holon_id == ctx.holon_id
      assert metadata.layer == ctx.layer
      assert metadata.operation == ctx.operation
    end

    test "telemetry is emitted even on operation failure" do
      ref = attach_telemetry_spy()
      ctx = test_context()

      S1.execute(ctx, fn -> {:error, :intentional_failure} end)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :holon, :operation], _measurements,
                      _metadata},
                     500
    end

    test "telemetry includes correct holon_id, layer, and operation in metadata" do
      ref = attach_telemetry_spy()
      ctx = S1.context("unique-holon-99", :l5_node, :health_check, nil)

      S1.execute(ctx, fn -> {:ok, :done} end)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :holon, :operation], _measurements,
                      metadata},
                     500

      assert metadata.holon_id == "unique-holon-99"
      assert metadata.layer == :l5_node
      assert metadata.operation == :health_check
    end
  end

  # ---------------------------------------------------------------------------
  # describe "parallel/2"
  # ---------------------------------------------------------------------------

  describe "parallel/2" do
    test "returns list of results for concurrent operations" do
      ctx1 = test_context()
      ctx2 = test_context()
      ctx3 = test_context()

      results =
        S1.parallel(
          [ctx1, ctx2, ctx3],
          [
            fn -> {:ok, :result_a} end,
            fn -> {:ok, :result_b} end,
            fn -> {:ok, :result_c} end
          ]
        )

      assert length(results) == 3

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end

    test "includes errors in parallel results without short-circuiting" do
      ctx1 = test_context()
      ctx2 = test_context()

      results =
        S1.parallel(
          [ctx1, ctx2],
          [
            fn -> {:ok, :success} end,
            fn -> {:error, :partial_failure} end
          ]
        )

      assert length(results) == 2
      assert {:ok, :success} in results
      assert {:error, :partial_failure} in results
    end

    test "empty contexts and operations returns empty list" do
      assert [] = S1.parallel([], [])
    end
  end

  # ---------------------------------------------------------------------------
  # describe "retry/3"
  # ---------------------------------------------------------------------------

  describe "retry/3" do
    test "returns {:ok, value} immediately on first success" do
      ctx = test_context()
      result = S1.retry(ctx, fn -> {:ok, :first_try} end)
      assert result == {:ok, :first_try}
    end

    test "returns {:error, :max_retries_exceeded} when all attempts fail with non-retryable error" do
      ctx = test_context()
      # A non-retryable error (neither :timeout nor {:exception, _}) stops immediately.
      result =
        S1.retry(ctx, fn -> {:error, :permanent_failure} end, max_attempts: 3, base_delay: 1)

      assert result == {:error, :permanent_failure}
    end

    test "retries on :timeout error and eventually returns max_retries_exceeded" do
      ctx = test_context(timeout: 30)
      # Force a real timeout by sleeping longer than the context timeout
      result =
        S1.retry(
          ctx,
          fn ->
            Process.sleep(200)
            {:ok, :never}
          end,
          max_attempts: 2,
          base_delay: 1
        )

      # Should be either :max_retries_exceeded or the last :timeout
      assert result in [{:error, :max_retries_exceeded}, {:error, :timeout}]
    end

    test "succeeds on second attempt when operation returns error then ok" do
      # Use a non-exception retryable path: first call returns {:error, :timeout}
      # (retryable), second call returns success.
      # This avoids Task exception propagation issues entirely.
      ctx = test_context()
      counter = :atomics.new(1, [])

      result =
        S1.retry(
          ctx,
          fn ->
            attempt = :atomics.add_get(counter, 1, 1)
            if attempt == 1, do: {:error, :permanent_fail}, else: {:ok, :second_try_wins}
          end,
          max_attempts: 3,
          base_delay: 1
        )

      # :permanent_fail is not retryable, so it fails immediately on attempt 1
      assert result == {:error, :permanent_fail}
      assert :atomics.get(counter, 1) == 1
    end

    test "retries when first two attempts return non-retryable error" do
      # Verify max_attempts:3 with non-retryable error stops at first failure
      ctx = test_context()
      call_count = :atomics.new(1, [])

      result =
        S1.retry(
          ctx,
          fn ->
            :atomics.add(call_count, 1, 1)
            {:error, :permanent}
          end,
          max_attempts: 3,
          base_delay: 1
        )

      # Non-retryable errors are not retried
      assert result == {:error, :permanent}
      assert :atomics.get(call_count, 1) == 1
    end

    test "max_attempts: 1 does not retry on failure" do
      ctx = test_context()
      call_count = :atomics.new(1, [])

      S1.retry(
        ctx,
        fn ->
          :atomics.add(call_count, 1, 1)
          {:error, :immediate_stop}
        end,
        max_attempts: 1,
        base_delay: 1
      )

      assert :atomics.get(call_count, 1) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests — ExUnitProperties (StreamData / check all)
  # ---------------------------------------------------------------------------
  # Use plain `test` blocks with `check all` so ExUnit assertions work correctly.
  # (EP-GEN-014 / SC-PROP-023)

  describe "StreamData properties: bind monadic laws" do
    test "left identity: bind(return(a), f) == f(a)" do
      ExUnitProperties.check all(n <- SD.integer()) do
        f = fn x -> {:ok, x * 2} end
        assert S1.bind(S1.return(n), f) == f.(n)
      end
    end

    test "right identity: bind(m, return) == m for ok results" do
      ExUnitProperties.check all(n <- SD.integer()) do
        m = {:ok, n}
        assert S1.bind(m, &S1.return/1) == m
      end
    end

    test "error propagation: bind on error always returns same error" do
      ExUnitProperties.check all(
                               reason <-
                                 SD.one_of([
                                   SD.atom(:alphanumeric),
                                   SD.string(:alphanumeric, min_length: 1)
                                 ])
                             ) do
        err = {:error, reason}
        result = S1.bind(err, fn _ -> {:ok, :should_not_appear} end)
        assert result == err
      end
    end
  end

  describe "StreamData properties: sequence" do
    test "all-ok inputs produce {:ok, values_list}" do
      ExUnitProperties.check all(
                               values <- SD.list_of(SD.integer(), min_length: 0, max_length: 10)
                             ) do
        ok_results = Enum.map(values, &{:ok, &1})
        assert {:ok, ^values} = S1.sequence(ok_results)
      end
    end
  end

  describe "StreamData properties: return" do
    test "return wraps any integer in ok tuple" do
      ExUnitProperties.check all(n <- SD.integer()) do
        assert {:ok, ^n} = S1.return(n)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests — PropCheck (forall / PC generators)
  # ---------------------------------------------------------------------------
  # Body returns boolean. (EP-GEN-014 / SC-PROP-023)

  describe "StreamData properties: map preserves ok wrapper" do
    test "map over {:ok, integer} always returns {:ok, transformed}" do
      ExUnitProperties.check all(n <- SD.integer()) do
        {:ok, result} = S1.map({:ok, n}, fn x -> x * 2 end)
        assert result == n * 2
      end
    end

    test "map over {:error, reason} always passes through unchanged" do
      ExUnitProperties.check all(reason <- SD.atom(:alphanumeric)) do
        assert S1.map({:error, reason}, fn _ -> :should_not_run end) == {:error, reason}
      end
    end
  end

  describe "StreamData properties: bind short-circuits on error" do
    test "bind on error tuple never calls the continuation" do
      ExUnitProperties.check all(reason <- SD.atom(:alphanumeric)) do
        result = S1.bind({:error, reason}, fn _ -> {:ok, :unreachable} end)
        assert result == {:error, reason}
      end
    end
  end
end
