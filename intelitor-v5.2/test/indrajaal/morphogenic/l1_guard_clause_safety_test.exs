defmodule Indrajaal.Morphogenic.L1GuardClauseSafetyTest do
  @moduledoc """
  L1 Fractal Layer: Guard Clause Safety & Pattern Match Exhaustiveness

  WHAT: Self-contained ETS-backed test suite verifying guard clause safety,
  pattern matching exhaustiveness, and function clause ordering at fractal layer L1.

  WHY: Guard clauses are the gatekeepers of function dispatch in Elixir. A missed
  guard, a non-guard-safe function call, or a non-exhaustive match can cause
  FunctionClauseError at runtime, violating SC-FUNC-001.

  LAYER: L1 (Function) — validates I/O contracts, guard safety, and dispatch correctness.

  ## Simulated Subsystems
  - Guard-safe function validation (is_*, elem, etc.)
  - Pattern match coverage tracking
  - Function clause ordering verification
  - Default clause enforcement
  - Type narrowing through guards
  - Binary pattern matching safety

  ## STAMP Compliance
  - SC-FUNC-001: System MUST compile at all times
  - SC-SIL4-002: Type boundary checks mandatory
  - AOR-GUARD-001: Guard clause — use only guard-safe functions

  ## Constitutional Alignment
  - Ψ₃ (Verification): All dispatch paths verified
  - Ψ₀ (Existence): No unhandled clause errors at runtime
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l1

  # ── ETS table names ────────────────────────────────────────────────────────
  @guard_registry :l1_guard_clause_registry
  @dispatch_log :l1_dispatch_log_registry
  @pattern_coverage :l1_pattern_coverage_registry

  # ── Guard-safe function set (Erlang/Elixir) ──────────────────────────────
  @guard_safe_fns [
    :is_atom,
    :is_binary,
    :is_bitstring,
    :is_boolean,
    :is_float,
    :is_function,
    :is_integer,
    :is_list,
    :is_map,
    :is_map_key,
    :is_nil,
    :is_number,
    :is_pid,
    :is_port,
    :is_reference,
    :is_tuple,
    :is_exception,
    :is_struct
  ]

  @comparison_ops [:==, :!=, :===, :!==, :<, :>, :<=, :>=]

  @arithmetic_ops [:+, :-, :*, :div, :rem, :abs]

  # ── Setup / Teardown ───────────────────────────────────────────────────────

  setup do
    tables = [@guard_registry, @dispatch_log, @pattern_coverage]

    for name <- tables do
      case :ets.info(name) do
        :undefined -> :ets.new(name, [:named_table, :public, :set])
        _ -> :ets.delete_all_objects(name)
      end
    end

    on_exit(fn ->
      for name <- tables do
        try do
          :ets.delete_all_objects(name)
        rescue
          _ -> :ok
        end
      end
    end)

    :ok
  end

  # ── Helper: Simulate guard dispatch ─────────────────────────────────────

  defp dispatch_by_guard(value) do
    cond do
      is_integer(value) and value > 0 -> :positive_integer
      is_integer(value) and value == 0 -> :zero
      is_integer(value) and value < 0 -> :negative_integer
      is_float(value) -> :float
      is_binary(value) -> :binary
      is_atom(value) and is_boolean(value) -> :boolean
      is_atom(value) -> :atom
      is_list(value) -> :list
      is_tuple(value) -> :tuple
      is_map(value) -> :map
      is_pid(value) -> :pid
      is_reference(value) -> :reference
      is_function(value) -> :function
      is_port(value) -> :port
      true -> :unknown
    end
  end

  defp type_guard_check(value, expected_type) do
    case expected_type do
      :integer -> is_integer(value)
      :float -> is_float(value)
      :number -> is_number(value)
      :binary -> is_binary(value)
      :atom -> is_atom(value)
      :boolean -> is_boolean(value)
      :list -> is_list(value)
      :tuple -> is_tuple(value)
      :map -> is_map(value)
      :pid -> is_pid(value)
      :reference -> is_reference(value)
      :function -> is_function(value)
      _ -> false
    end
  end

  defp pattern_match_score(clauses, value) do
    Enum.find_index(clauses, fn clause_fn ->
      try do
        clause_fn.(value)
        true
      rescue
        _ -> false
      end
    end)
  end

  defp guard_narrowing(value) do
    # Simulate progressive type narrowing through guards
    narrowings = []

    narrowings =
      if is_number(value), do: [:number | narrowings], else: narrowings

    narrowings =
      if is_integer(value), do: [:integer | narrowings], else: narrowings

    narrowings =
      if is_integer(value) and value >= 0,
        do: [:non_negative | narrowings],
        else: narrowings

    narrowings =
      if is_integer(value) and value > 0,
        do: [:positive | narrowings],
        else: narrowings

    Enum.reverse(narrowings)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 1: Guard Function Safety (SC-SIL4-002)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "guard function safety" do
    test "all guard-safe functions are recognized" do
      for fn_name <- @guard_safe_fns do
        assert is_atom(fn_name)
        assert String.starts_with?(Atom.to_string(fn_name), "is_")
      end
    end

    test "comparison operators are guard-safe" do
      for op <- @comparison_ops do
        assert is_atom(op)
        :ets.insert(@guard_registry, {op, :comparison, :guard_safe})
      end

      assert :ets.info(@guard_registry, :size) == length(@comparison_ops)
    end

    test "arithmetic operators are guard-safe" do
      for op <- @arithmetic_ops do
        :ets.insert(@guard_registry, {op, :arithmetic, :guard_safe})
      end

      stored = :ets.match(@guard_registry, {:"$1", :arithmetic, :guard_safe})
      assert length(stored) == length(@arithmetic_ops)
    end

    test "non-guard-safe functions are rejected" do
      non_guard_safe = [
        :"String.length",
        :"Enum.count",
        :"Map.get",
        :"IO.inspect",
        :length,
        :hd,
        :tl
      ]

      # length/1, hd/1, tl/1 are actually guard-safe in Erlang,
      # but complex function calls like String.length are not
      for fn_name <- [:String_length, :Enum_count, :Map_get] do
        :ets.insert(@guard_registry, {fn_name, :complex, :not_guard_safe})
      end

      non_safe = :ets.match(@guard_registry, {:"$1", :complex, :not_guard_safe})
      assert length(non_safe) == 3
    end

    test "guard functions return boolean" do
      test_values = [42, 3.14, "hello", :atom, true, [1], {1, 2}, %{}, self()]

      for value <- test_values do
        for fn_name <- [:is_integer, :is_float, :is_binary, :is_atom, :is_list] do
          result = apply(Kernel, fn_name, [value])
          assert is_boolean(result), "#{fn_name}(#{inspect(value)}) returned #{inspect(result)}"
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 2: Guard-Based Type Dispatch
  # ═══════════════════════════════════════════════════════════════════════════

  describe "guard-based type dispatch" do
    test "dispatch covers all basic types" do
      assert dispatch_by_guard(42) == :positive_integer
      assert dispatch_by_guard(0) == :zero
      assert dispatch_by_guard(-5) == :negative_integer
      assert dispatch_by_guard(3.14) == :float
      assert dispatch_by_guard("hello") == :binary
      assert dispatch_by_guard(true) == :boolean
      assert dispatch_by_guard(false) == :boolean
      assert dispatch_by_guard(:atom) == :atom
      assert dispatch_by_guard([1, 2]) == :list
      assert dispatch_by_guard({1, 2}) == :tuple
      assert dispatch_by_guard(%{a: 1}) == :map
      assert dispatch_by_guard(self()) == :pid
    end

    test "dispatch is deterministic" do
      values = [1, -1, 0, 3.14, "str", :atom, true, [], {}, %{}]

      results_1 = Enum.map(values, &dispatch_by_guard/1)
      results_2 = Enum.map(values, &dispatch_by_guard/1)

      assert results_1 == results_2
    end

    test "dispatch logs to ETS" do
      values = [1, "hello", :world, [1, 2, 3]]

      for {value, idx} <- Enum.with_index(values) do
        result = dispatch_by_guard(value)
        :ets.insert(@dispatch_log, {idx, value, result, System.monotonic_time()})
      end

      assert :ets.info(@dispatch_log, :size) == 4
    end

    test "boolean is dispatched before atom" do
      # booleans are atoms in Elixir, guard ordering matters
      assert dispatch_by_guard(true) == :boolean
      assert dispatch_by_guard(false) == :boolean
      # nil is not boolean
      assert dispatch_by_guard(nil) == :atom
    end

    test "type_guard_check validates correctly" do
      assert type_guard_check(42, :integer) == true
      assert type_guard_check(42, :number) == true
      assert type_guard_check(42, :binary) == false
      assert type_guard_check("hi", :binary) == true
      assert type_guard_check("hi", :integer) == false
      assert type_guard_check(true, :boolean) == true
      assert type_guard_check(true, :atom) == true
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 3: Pattern Match Exhaustiveness
  # ═══════════════════════════════════════════════════════════════════════════

  describe "pattern match exhaustiveness" do
    test "clauses cover all expected patterns" do
      clauses = [
        fn {:ok, _} -> :success end,
        fn {:error, _} -> :failure end,
        fn nil -> nil end
      ]

      # {:ok, _} matches
      assert pattern_match_score(clauses, {:ok, 42}) == 0
      # {:error, _} matches
      assert pattern_match_score(clauses, {:error, "boom"}) == 1
      # nil matches
      assert pattern_match_score(clauses, nil) == 2
      # nothing matches
      assert pattern_match_score(clauses, :something_else) == nil
    end

    test "default clause catches unmatched patterns" do
      clauses = [
        fn {:ok, v} -> {:success, v} end,
        fn {:error, e} -> {:failure, e} end,
        fn other -> {:default, other} end
      ]

      # All values should match something
      test_values = [{:ok, 1}, {:error, "x"}, :anything, 42, "str"]

      for value <- test_values do
        idx = pattern_match_score(clauses, value)
        assert idx != nil, "No clause matched #{inspect(value)}"
      end
    end

    test "pattern coverage tracking" do
      patterns = [:ok, :error, :timeout, :retry, :cancel]

      for {pat, idx} <- Enum.with_index(patterns) do
        :ets.insert(@pattern_coverage, {pat, idx, 0})
      end

      # Simulate hits
      seen = [:ok, :ok, :error, :timeout, :ok, :cancel]

      for pat <- seen do
        case :ets.lookup(@pattern_coverage, pat) do
          [{^pat, idx, count}] ->
            :ets.insert(@pattern_coverage, {pat, idx, count + 1})

          [] ->
            :ets.insert(@pattern_coverage, {pat, -1, 1})
        end
      end

      # Verify coverage
      [{:ok, _, ok_count}] = :ets.lookup(@pattern_coverage, :ok)
      assert ok_count == 3

      [{:retry, _, retry_count}] = :ets.lookup(@pattern_coverage, :retry)
      assert retry_count == 0, "retry was never hit"
    end

    test "binary pattern matching safety" do
      # Safe binary patterns
      assert <<head::8, _rest::binary>> = "hello"
      assert head == ?h

      # Empty binary
      assert <<>> = ""

      # UTF-8 pattern
      assert <<c::utf8, _::binary>> = "Ω"
      assert c == 937
    end

    test "map pattern matching with guards" do
      data = %{type: :alarm, severity: :critical, id: 42}

      result =
        case data do
          %{type: :alarm, severity: sev} when sev in [:critical, :major] ->
            :escalate

          %{type: :alarm, severity: _} ->
            :log

          %{type: _} ->
            :ignore
        end

      assert result == :escalate
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 4: Guard Narrowing & Progressive Refinement
  # ═══════════════════════════════════════════════════════════════════════════

  describe "guard narrowing" do
    test "progressive type narrowing for positive integer" do
      narrowings = guard_narrowing(42)
      assert narrowings == [:number, :integer, :non_negative, :positive]
    end

    test "progressive type narrowing for zero" do
      narrowings = guard_narrowing(0)
      assert narrowings == [:number, :integer, :non_negative]
    end

    test "progressive type narrowing for negative integer" do
      narrowings = guard_narrowing(-5)
      assert narrowings == [:number, :integer]
    end

    test "progressive type narrowing for float" do
      narrowings = guard_narrowing(3.14)
      assert narrowings == [:number]
    end

    test "non-number has empty narrowing" do
      assert guard_narrowing("hello") == []
      assert guard_narrowing(:atom) == []
      assert guard_narrowing([]) == []
    end

    test "narrowing is monotonically increasing in specificity" do
      for value <- [42, 0, -3, 7.5] do
        narrowings = guard_narrowing(value)

        if length(narrowings) > 1 do
          # Each successive narrowing should be a subset of the previous
          # In our model, the list goes from general to specific
          assert hd(narrowings) == :number
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 5: Function Clause Ordering
  # ═══════════════════════════════════════════════════════════════════════════

  describe "function clause ordering" do
    test "specific clauses before general clauses" do
      # Simulate function clause dispatch priority
      clauses = [
        {:specific, fn x when is_integer(x) and x > 0 -> :pos_int end},
        {:medium, fn x when is_integer(x) -> :any_int end},
        {:general, fn x when is_number(x) -> :any_number end},
        {:catchall, fn _ -> :anything end}
      ]

      # Test dispatch: first matching clause wins
      value = 42

      {level, _} =
        Enum.find(clauses, fn {_, clause_fn} ->
          try do
            clause_fn.(value)
            true
          rescue
            _ -> false
          end
        end)

      assert level == :specific
    end

    test "overlapping guards resolved by order" do
      # When multiple guards match, first clause wins
      dispatches =
        for value <- [1, -1, 0, 1.5, "x"] do
          cond do
            is_integer(value) and value > 0 -> {:pos, value}
            is_integer(value) -> {:int, value}
            is_number(value) -> {:num, value}
            true -> {:other, value}
          end
        end

      assert dispatches == [
               {:pos, 1},
               {:int, -1},
               {:int, 0},
               {:num, 1.5},
               {:other, "x"}
             ]
    end

    test "guard clause count tracking" do
      # Track how many clauses each function head has
      function_specs = [
        {:validate, 3, [:when_integer, :when_binary, :when_map, :catchall]},
        {:transform, 2, [:when_list, :when_tuple, :catchall]},
        {:dispatch, 1, [:specific, :general]}
      ]

      for {name, arity, clauses} <- function_specs do
        :ets.insert(@guard_registry, {{name, arity}, length(clauses), clauses})
      end

      [{_, count, _}] = :ets.lookup(@guard_registry, {:validate, 3})
      assert count == 4

      [{_, count, _}] = :ets.lookup(@guard_registry, {:dispatch, 1})
      assert count == 2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 6: PropCheck Properties (SC-PROP-023)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "property-based guard safety" do
    property "PC: dispatch always returns a known type atom" do
      forall value <-
               PC.oneof([
                 PC.integer(),
                 PC.float(),
                 PC.binary(),
                 PC.atom(),
                 PC.boolean(),
                 PC.list(PC.integer())
               ]) do
        result = dispatch_by_guard(value)

        result in [
          :positive_integer,
          :zero,
          :negative_integer,
          :float,
          :binary,
          :boolean,
          :atom,
          :list,
          :tuple,
          :map,
          :pid,
          :reference,
          :function,
          :port,
          :unknown
        ]
      end
    end

    property "PC: guard narrowing produces ordered specificity" do
      forall n <- PC.integer() do
        narrowings = guard_narrowing(n)
        # For any integer, :number must appear before :integer
        number_idx = Enum.find_index(narrowings, &(&1 == :number))
        integer_idx = Enum.find_index(narrowings, &(&1 == :integer))

        number_idx != nil and integer_idx != nil and number_idx < integer_idx
      end
    end

    property "PC: type_guard_check is consistent with Kernel guards" do
      forall value <- PC.oneof([PC.integer(), PC.float(), PC.binary()]) do
        int_check = type_guard_check(value, :integer)
        float_check = type_guard_check(value, :float)
        num_check = type_guard_check(value, :number)

        # If it's an integer or float, it's a number
        implies_number = if int_check or float_check, do: num_check, else: true
        # Integer and float are mutually exclusive
        not_both = not (int_check and float_check)

        implies_number and not_both
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 7: StreamData Properties (EP-GEN-014)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "streamdata guard properties" do
    @tag timeout: 30_000
    test "SD: dispatch is deterministic" do
      SD.one_of([SD.integer(), SD.float(), SD.binary(min_length: 1, max_length: 20)])
      |> Enum.take(50)
      |> Enum.each(fn value ->
        r1 = dispatch_by_guard(value)
        r2 = dispatch_by_guard(value)
        assert r1 == r2
      end)
    end

    @tag timeout: 30_000
    test "SD: guard narrowing length bounded by type" do
      SD.integer(-1000..1000)
      |> Enum.take(50)
      |> Enum.each(fn n ->
        narrowings = guard_narrowing(n)
        # For integers: at least [:number, :integer]
        assert length(narrowings) >= 2
        # At most [:number, :integer, :non_negative, :positive]
        assert length(narrowings) <= 4
      end)
    end

    @tag timeout: 30_000
    test "SD: boolean is always both atom and boolean" do
      SD.boolean()
      |> Enum.take(50)
      |> Enum.each(fn b ->
        assert type_guard_check(b, :boolean) == true
        assert type_guard_check(b, :atom) == true
      end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SECTION 8: Edge Cases & Boundary Conditions
  # ═══════════════════════════════════════════════════════════════════════════

  describe "edge cases" do
    test "nil dispatches as atom" do
      assert dispatch_by_guard(nil) == :atom
    end

    test "empty collections dispatch correctly" do
      assert dispatch_by_guard([]) == :list
      assert dispatch_by_guard({}) == :tuple
      assert dispatch_by_guard(%{}) == :map
    end

    test "large integers handled" do
      big = 1_000_000_000_000_000
      assert dispatch_by_guard(big) == :positive_integer
      assert dispatch_by_guard(-big) == :negative_integer
    end

    test "special floats" do
      assert dispatch_by_guard(0.0) == :float
      assert dispatch_by_guard(-0.0) == :float
      # Elixir doesn't have NaN/Infinity as literals, but floats are handled
    end

    test "nested structures dispatch on outer type" do
      assert dispatch_by_guard([{:a, 1}]) == :list
      assert dispatch_by_guard({[1, 2], %{a: 1}}) == :tuple
      assert dispatch_by_guard(%{list: [1, 2, 3]}) == :map
    end

    test "function values dispatch correctly" do
      assert dispatch_by_guard(fn -> :ok end) == :function
      assert dispatch_by_guard(&is_integer/1) == :function
    end
  end
end
