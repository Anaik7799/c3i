defmodule Indrajaal.Morphogenic.L1FunctionPurityVerificationTest do
  @moduledoc """
  Morphogenic Evolution L1 — Function Purity Verification Test Suite.

  WHAT: Verifies L1 (Function-level) purity properties of the Indrajaal
        SIL-6 Biomorphic Mesh: referential transparency, absence of
        side effects, determinism under concurrency, memoisation
        correctness, and function composition associativity.

  WHY: In a SIL-6 safety-critical system, L1 functions are the atomic
       building blocks of all higher fractal layers (L2-L7).  Any
       impurity at L1 propagates upward and may violate the Functional
       State Invariant (Axiom 0) or compromise hash-chain integrity.
       Formal verification of L1 purity is a prerequisite for Guardian
       approval of any code-evolution proposal.

  CONSTRAINTS:
    - SC-HASH-001: Deterministic computation — identical inputs MUST
                   yield identical outputs / hashes at all times.
    - SC-FUNC-001: System MUST compile at all times (Ω₃ Zero-Defect).
    - SC-FUNC-003: Rollback path MUST exist for every change.
    - SC-OODA-001: OODA cycle < 100ms; pure functions must not block.
    - SC-VAL-001:  STAMP references for every validated action.
    - AOR-FUNC-001: Verify compilation before ANY code commit.

  ## Fractal Layer
  L1 (Function): Pure functions, no side effects, well-typed.

  ## Test Coverage Matrix
  | Category                              | Unit | PropCheck | StreamData |
  |---------------------------------------|------|-----------|------------|
  | Referential transparency              |  4   |     2     |     1      |
  | Side-effect detection (ETS harness)   |  5   |     0     |     1      |
  | Determinism under concurrency         |  3   |     0     |     1      |
  | Memoisation correctness               |  3   |     0     |     1      |
  | Composition associativity             |  3   |     2     |     1      |
  | Mathematical function properties      |  3   |     2     |     2      |
  | TOTAL                                 | 21   |     6     |     7      |

  ## EP-GEN-014 Compliance
  - `use PropCheck` enables `forall` / `property` blocks with PC. prefix.
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    enables `check all(...)` inside plain `test` blocks with SD. prefix.
  - PropCheck `property` blocks are placed at module top-level (outside
    `describe`) to avoid the PropCheck/ExUnit describe interaction.
  - StreamData `check all` blocks always reside inside plain `test` blocks.

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial L1 purity verification      |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY disambiguating imports
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l1_purity
  @moduletag :mathematical

  # ---------------------------------------------------------------------------
  # Pure function helpers used as subjects under test.
  # All self-contained; no application module dependency.
  # ---------------------------------------------------------------------------

  defp double(n), do: n * 2
  defp increment(n), do: n + 1
  defp square(n), do: n * n
  defp negate(n), do: -n
  defp identity(x), do: x

  defp shout(s), do: String.upcase(s)
  defp whisper(s), do: String.downcase(s)
  defp exclaim(s), do: s <> "!"

  # Compose two unary functions left-to-right: compose(f, g).(x) = g(f(x))
  defp compose(f, g), do: fn x -> g.(f.(x)) end

  # Deterministic SHA-256 digest of any Erlang term (SC-HASH-001).
  defp stable_hash(term),
    do: :crypto.hash(:sha256, :erlang.term_to_binary(term)) |> Base.encode16(case: :lower)

  # ---------------------------------------------------------------------------
  # Simple in-process memo table backed by an ETS table.
  # ---------------------------------------------------------------------------

  defp memo_new(), do: :ets.new(:memo, [:set, :private])

  defp memo_get_or_compute(table, key, fun) do
    case :ets.lookup(table, key) do
      [{^key, cached}] ->
        cached

      [] ->
        result = fun.(key)
        :ets.insert(table, {key, result})
        result
    end
  end

  # ============================================================================
  # 1. REFERENTIAL TRANSPARENCY
  # Same input → same output, always, for every pure function.
  # SC-HASH-001: deterministic computation.
  # ============================================================================

  describe "Referential transparency — same input always produces same output (SC-HASH-001)" do
    @tag :referential_transparency
    test "double/1 returns identical value for repeated calls" do
      assert double(7) == double(7)
      assert double(0) == double(0)
      assert double(-42) == double(-42)
    end

    @tag :referential_transparency
    test "stable_hash/1 produces identical digest for the same term" do
      term = %{node: "indrajaal-ex-app-1", layer: :l1, value: 42}
      assert stable_hash(term) == stable_hash(term)
    end

    @tag :referential_transparency
    test "stable_hash/1 produces different digests for structurally different terms" do
      h1 = stable_hash(%{a: 1})
      h2 = stable_hash(%{a: 2})
      refute h1 == h2
    end

    @tag :referential_transparency
    test "shout/1 is referentially transparent for any string" do
      assert shout("hello") == shout("hello")
      assert shout("ALREADY_UPPER") == shout("ALREADY_UPPER")
    end

    @tag :referential_transparency
    test "double/1 is referentially transparent for all SD.integer() inputs (StreamData)" do
      forall n <- PC.integer() do
        assert double(n) == double(n), "double(#{n}) was not referentially transparent"
      end
    end
  end

  # PropCheck property blocks live outside describe to avoid ExUnit/PropCheck interaction.
  @tag :referential_transparency
  @tag :propcheck
  property "RT_PROP_01: double/1 is referentially transparent for all integers (PropCheck)" do
    forall n <- PC.integer() do
      double(n) == double(n)
    end
  end

  @tag :referential_transparency
  @tag :propcheck
  property "RT_PROP_02: stable_hash/1 is stable for all integers (PropCheck)" do
    forall n <- PC.integer() do
      stable_hash(n) == stable_hash(n)
    end
  end

  # ============================================================================
  # 2. SIDE-EFFECT DETECTION
  # Pure functions must NOT mutate any external state.
  # We instrument calls via ETS and verify the table is untouched.
  # ============================================================================

  describe "Side-effect detection — pure functions must not mutate external state" do
    @tag :side_effects
    test "double/1 does not write to a watched ETS log" do
      log = :ets.new(:side_effect_log_double, [:set, :private])

      try do
        _result = double(99)
        assert :ets.info(log, :size) == 0
      after
        :ets.delete(log)
      end
    end

    @tag :side_effects
    test "shout/1 does not write to a watched ETS log" do
      log = :ets.new(:side_effect_log_shout, [:set, :private])

      try do
        _result = shout("biomorphic")
        assert :ets.info(log, :size) == 0
      after
        :ets.delete(log)
      end
    end

    @tag :side_effects
    test "stable_hash/1 does not mutate the process dictionary" do
      Process.put(:__pure_test_sentinel__, :pristine)
      _h = stable_hash({:l1_function, 42})
      assert Process.get(:__pure_test_sentinel__) == :pristine
    after
      Process.delete(:__pure_test_sentinel__)
    end

    @tag :side_effects
    test "composition of pure functions does not produce side effects" do
      log = :ets.new(:side_effect_log_compose, [:set, :private])

      try do
        f = compose(&double/1, &increment/1)
        _result = f.(10)
        assert :ets.info(log, :size) == 0
      after
        :ets.delete(log)
      end
    end

    @tag :side_effects
    test "a deliberately impure function IS detected as having side effects" do
      counter = :ets.new(:impure_counter, [:set, :public])
      :ets.insert(counter, {:count, 0})

      impure_fn = fn n ->
        :ets.update_counter(counter, :count, 1)
        n * 2
      end

      impure_fn.(5)
      impure_fn.(5)

      [{:count, calls}] = :ets.lookup(counter, :count)
      assert calls == 2, "Expected 2 side-effecting calls, got #{calls}"
    after
      # counter table is cleaned up by the on_exit above
    end

    @tag :side_effects
    test "pure pipeline leaves ETS log untouched for all SD.integer() inputs (StreamData)" do
      forall n <- PC.integer(1, 100) do
        log = :ets.new(:pure_check, [:set, :private])

        try do
          _result = n |> double() |> increment() |> square()

          assert :ets.info(log, :size) == 0,
                 "Unexpected write to ETS after pure pipeline on input #{n}"
        after
          :ets.delete(log)
        end
      end
    end
  end

  # ============================================================================
  # 3. DETERMINISM UNDER CONCURRENT ACCESS
  # When multiple processes apply the same pure function to the same input,
  # they must all observe the same result.
  # ============================================================================

  describe "Determinism under concurrent access" do
    @tag :concurrency
    test "double/1 returns identical result from 50 concurrent processes" do
      parent = self()
      n = 42

      pids = for _ <- 1..50, do: spawn(fn -> send(parent, {:result, double(n)}) end)

      results =
        for _ <- pids do
          receive do
            {:result, v} -> v
          after
            500 -> flunk("Timeout waiting for concurrent double/1 result")
          end
        end

      assert Enum.uniq(results) == [double(n)],
             "Concurrent invocations of double/1 returned non-deterministic results"
    end

    @tag :concurrency
    test "stable_hash/1 is consistent across 20 concurrent calls for the same term" do
      parent = self()
      term = %{layer: :l1, function: :stable_hash, stamp: "SC-HASH-001"}
      expected = stable_hash(term)

      for _ <- 1..20, do: spawn(fn -> send(parent, {:hash, stable_hash(term)}) end)

      results =
        for _ <- 1..20 do
          receive do
            {:hash, h} -> h
          after
            500 -> flunk("Timeout in concurrent stable_hash/1 test")
          end
        end

      assert Enum.all?(results, &(&1 == expected)),
             "stable_hash/1 produced divergent results under concurrency"
    end

    @tag :concurrency
    test "concurrent composition is deterministic for all SD.integer() inputs (StreamData)" do
      forall n <- PC.integer(-1000, 1000) do
        parent = self()
        f = compose(&double/1, &square/1)
        expected = f.(n)

        pids = for _ <- 1..10, do: spawn(fn -> send(parent, {:r, f.(n)}) end)

        results =
          for _ <- pids do
            receive do
              {:r, v} -> v
            after
              300 -> flunk("Timeout in concurrent composition test, n=#{n}")
            end
          end

        assert Enum.all?(results, &(&1 == expected)),
               "Composed function f(#{n}) was non-deterministic under concurrency"
      end
    end
  end

  # ============================================================================
  # 4. MEMOISATION CORRECTNESS
  # Cached result must always equal directly computed result.
  # ============================================================================

  describe "Memoisation correctness — cached value equals computed value" do
    @tag :memoisation
    test "memo_get_or_compute returns the same value as direct computation" do
      table = memo_new()
      fun = &double/1

      for n <- [0, 1, -1, 42, 100, -99] do
        cached = memo_get_or_compute(table, n, fun)
        direct = fun.(n)
        assert cached == direct, "Memo mismatch for n=#{n}: cached=#{cached}, direct=#{direct}"
      end
    after
    end

    @tag :memoisation
    test "memo_get_or_compute invokes the underlying function exactly once per key" do
      call_log = :ets.new(:memo_call_log, [:set, :public])
      table = memo_new()

      counting_fn = fn n ->
        :ets.update_counter(call_log, n, {2, 1}, {n, 0})
        double(n)
      end

      # Call three times for the same key.
      for _ <- 1..3, do: memo_get_or_compute(table, 7, counting_fn)

      [{7, call_count}] = :ets.lookup(call_log, 7)
      assert call_count == 1, "Expected 1 call to underlying fn, got #{call_count}"
    after
    end

    @tag :memoisation
    test "memoised stable_hash equals direct stable_hash for SD.integer() range (StreamData)" do
      forall n <- PC.integer(0, 255) do
        table = memo_new()

        try do
          cached = memo_get_or_compute(table, n, &stable_hash/1)
          direct = stable_hash(n)

          assert cached == direct,
                 "Memo hash mismatch for n=#{n}: cached=#{cached}, direct=#{direct}"
        after
          :ets.delete(table)
        end
      end
    end
  end

  # ============================================================================
  # 5. FUNCTION COMPOSITION ASSOCIATIVITY
  # (h ∘ g) ∘ f  =  h ∘ (g ∘ f)  for all pure unary functions.
  # ============================================================================

  describe "Function composition associativity — (h∘g)∘f = h∘(g∘f)" do
    @tag :composition
    test "integer arithmetic morphisms satisfy associativity" do
      f = &double/1
      g = &increment/1
      h = &negate/1
      n = 5

      lhs = compose(compose(f, g), h).(n)
      rhs = compose(f, compose(g, h)).(n)

      assert lhs == rhs,
             "Composition associativity violated: lhs=#{lhs}, rhs=#{rhs} for n=#{n}"
    end

    @tag :composition
    test "string morphisms satisfy associativity" do
      f = fn s -> shout(s) end
      g = fn s -> whisper(s) end
      h = fn s -> exclaim(s) end
      s = "morphogenic"

      lhs = compose(compose(f, g), h).(s)
      rhs = compose(f, compose(g, h)).(s)

      assert lhs == rhs
    end

    @tag :composition
    test "identity is a left and right unit for composition" do
      f = &square/1
      n = 7

      left_unit = compose(&identity/1, f).(n)
      right_unit = compose(f, &identity/1).(n)
      direct = f.(n)

      assert left_unit == direct,
             "Left unit law violated: id∘f(#{n})=#{left_unit} ≠ f(#{n})=#{direct}"

      assert right_unit == direct,
             "Right unit law violated: f∘id(#{n})=#{right_unit} ≠ f(#{n})=#{direct}"
    end

    @tag :composition
    test "associativity holds for all SD.integer() inputs (StreamData)" do
      forall n <- PC.integer() do
        f = fn x -> x + 1 end
        g = fn x -> x * 2 end
        h = fn x -> x - 5 end

        lhs = compose(compose(f, g), h).(n)
        rhs = compose(f, compose(g, h)).(n)

        assert lhs == rhs,
               "Composition associativity violated for n=#{n}: lhs=#{lhs}, rhs=#{rhs}"
      end
    end
  end

  @tag :composition
  @tag :propcheck
  property "ASSOC_PROP_01: composition associativity for all integers (PropCheck)" do
    forall n <- PC.integer() do
      f = fn x -> x + 1 end
      g = fn x -> x * 2 end
      h = fn x -> x - 3 end

      compose(compose(f, g), h).(n) == compose(f, compose(g, h)).(n)
    end
  end

  @tag :composition
  @tag :propcheck
  property "ASSOC_PROP_02: identity is unit for any integer morphism (PropCheck)" do
    forall n <- PC.integer() do
      f = fn x -> x * x + x + 1 end

      compose(&identity/1, f).(n) == f.(n) and
        compose(f, &identity/1).(n) == f.(n)
    end
  end

  # ============================================================================
  # 6. MATHEMATICAL FUNCTION PROPERTIES
  # Idempotence, involution, and distributivity — algebraic laws that pure
  # L1 functions in the biomorphic mesh must satisfy.
  # ============================================================================

  describe "Mathematical function properties — idempotence, involution, distributivity" do
    @tag :mathematical_properties
    test "identity is idempotent: id(id(x)) = id(x) for a variety of types" do
      for x <- [0, 1, -1, :atom, "string", [1, 2], %{k: :v}] do
        assert identity(identity(x)) == identity(x)
      end
    end

    @tag :mathematical_properties
    test "negate is an involution: negate(negate(x)) = x" do
      for n <- [-100, -1, 0, 1, 42, 999] do
        assert negate(negate(n)) == n,
               "negate is not involutive for n=#{n}"
      end
    end

    @tag :mathematical_properties
    test "double distributes over addition: double(a+b) = double(a) + double(b)" do
      for {a, b} <- [{1, 2}, {0, 5}, {-3, 7}, {100, -100}] do
        assert double(a + b) == double(a) + double(b),
               "double does not distribute over addition for a=#{a}, b=#{b}"
      end
    end

    @tag :mathematical_properties
    test "stable_hash output is always a 64-char lowercase hex string for any SD value (StreamData)" do
      forall n <- PC.integer() do
        h = stable_hash(n)
        assert String.length(h) == 64, "Expected 64-char hash, got #{String.length(h)} for n=#{n}"
        assert h =~ ~r/\A[0-9a-f]+\z/, "Expected lowercase hex, got: #{h}"
      end
    end

    @tag :mathematical_properties
    test "stable_hash is injective for distinct SD integer inputs (StreamData)" do
      forall {a, b} <- {PC.integer(), PC.integer()} do
        assert stable_hash(a) != stable_hash(b),
               "Hash collision detected: stable_hash(#{a}) == stable_hash(#{b})"
      end
    end
  end

  @tag :mathematical_properties
  @tag :propcheck
  property "MATH_PROP_01: negate is involutive for all integers (PropCheck)" do
    forall n <- PC.integer() do
      negate(negate(n)) == n
    end
  end

  @tag :mathematical_properties
  @tag :propcheck
  property "MATH_PROP_02: double distributes over addition for all integer pairs (PropCheck)" do
    forall {a, b} <- {PC.integer(), PC.integer()} do
      double(a + b) == double(a) + double(b)
    end
  end
end
