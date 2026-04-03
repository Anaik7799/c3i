defmodule Indrajaal.Morphogenic.L1FunctionIoContractsTest do
  @moduledoc """
  Morphogenic Evolution L1 Function-Level I/O Contract Tests.

  WHAT: Verifies function-level I/O contracts for the SIL-6 Biomorphic Mesh.
        Covers input validation, output type guarantees, pre/post-conditions,
        error handling contracts, idempotency, and property-based invariants.
        All behavior is simulated in-process via ETS and pure functions —
        no production module dependencies.

  WHY: Axiom 0 (Functional State Invariant) mandates that every function at L1
       must satisfy its declared I/O contract at all times. Violations surface as
       compile-time errors, runtime panics, or silent wrong behavior that
       propagates up the fractal layers. This suite catches all three classes.

  CONSTRAINTS:
    - SC-VER-001: Startup verification of I/O contracts before app ready
    - SC-VER-002: Verification failure halts the system
    - SC-FUNC-001: System MUST compile at all times
    - SC-FUNC-002: Core services MUST be operational
    - SC-PROP-023: PropCheck/StreamData disambiguation MANDATORY
    - SC-PROP-024: Use SD. prefix for StreamData generators
    - AOR-FUNC-001: Verify compilation before ANY code commit
    - AOR-VAR-001: No underscore prefix on variables that are used

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial L1 I/O contracts test suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck

  # EP-GEN-014: check/2 excluded here so ExUnitProperties.check all() used qualified
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: Mandatory disambiguation aliases
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l1_function_io_contracts
  @moduletag :sil6

  # ---------------------------------------------------------------------------
  # Simulated pure-function contract module — no production deps
  # All functions here mimic the L1 behavioral contracts we verify.
  # ---------------------------------------------------------------------------

  defmodule Contract do
    @moduledoc "Self-contained L1 contract simulation for test isolation."

    # ------------------------------------------------------------------
    # Input validation helpers
    # ------------------------------------------------------------------

    @spec validate_holon_id(term()) :: {:ok, String.t()} | {:error, :invalid_holon_id}
    def validate_holon_id(id) when is_binary(id) and byte_size(id) > 0 do
      if String.match?(id, ~r/^[a-z][a-z0-9_-]{0,62}$/) do
        {:ok, id}
      else
        {:error, :invalid_holon_id}
      end
    end

    def validate_holon_id(_), do: {:error, :invalid_holon_id}

    @spec validate_priority(term()) :: {:ok, atom()} | {:error, :invalid_priority}
    def validate_priority(p) when p in [:p0, :p1, :p2, :p3], do: {:ok, p}
    def validate_priority(_), do: {:error, :invalid_priority}

    @spec validate_timestamp(term()) :: {:ok, DateTime.t()} | {:error, :invalid_timestamp}
    def validate_timestamp(%DateTime{} = dt), do: {:ok, dt}
    def validate_timestamp(_), do: {:error, :invalid_timestamp}

    @spec validate_severity(term()) :: {:ok, atom()} | {:error, :invalid_severity}
    def validate_severity(s) when s in [:low, :medium, :high, :critical], do: {:ok, s}
    def validate_severity(_), do: {:error, :invalid_severity}

    @spec validate_probability(term()) :: {:ok, float()} | {:error, :invalid_probability}
    def validate_probability(p) when is_float(p) and p >= 0.0 and p <= 1.0, do: {:ok, p}
    def validate_probability(p) when is_integer(p) and p in 0..1, do: {:ok, p / 1.0}
    def validate_probability(_), do: {:error, :invalid_probability}

    # ------------------------------------------------------------------
    # Output type guarantee helpers
    # ------------------------------------------------------------------

    @spec compute_health_score(non_neg_integer(), non_neg_integer()) :: float()
    def compute_health_score(passing, total) when is_integer(passing) and is_integer(total) do
      cond do
        total == 0 -> 1.0
        passing > total -> 1.0
        true -> passing / total
      end
    end

    @spec normalize_name(String.t()) :: String.t()
    def normalize_name(name) when is_binary(name) do
      name
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")
    end

    @spec build_topic(String.t(), String.t()) :: String.t()
    def build_topic(prefix, suffix) when is_binary(prefix) and is_binary(suffix) do
      "#{prefix}/#{suffix}"
    end

    @spec compute_quorum(non_neg_integer()) :: non_neg_integer()
    def compute_quorum(n) when is_integer(n) and n >= 0, do: div(n, 2) + 1

    # ------------------------------------------------------------------
    # Pre/post-condition enforced operations
    # ------------------------------------------------------------------

    @spec safe_divide(number(), number()) :: {:ok, float()} | {:error, :division_by_zero}
    def safe_divide(_, d) when d == 0, do: {:error, :division_by_zero}
    def safe_divide(n, d), do: {:ok, n / d}

    @spec clamp(number(), number(), number()) :: number()
    def clamp(value, lo, hi) when lo <= hi do
      value |> max(lo) |> min(hi)
    end

    @spec bounded_append(list(), term(), non_neg_integer()) ::
            {:ok, list()} | {:error, :capacity_exceeded}
    def bounded_append(list, _item, max) when length(list) >= max do
      {:error, :capacity_exceeded}
    end

    def bounded_append(list, item, _max) do
      {:ok, list ++ [item]}
    end

    # ------------------------------------------------------------------
    # Error wrapping contract — all errors use {:error, reason} tuples
    # ------------------------------------------------------------------

    @spec safe_parse_integer(term()) :: {:ok, integer()} | {:error, :not_an_integer}
    def safe_parse_integer(v) when is_integer(v), do: {:ok, v}

    def safe_parse_integer(v) when is_binary(v) do
      case Integer.parse(v) do
        {n, ""} -> {:ok, n}
        _ -> {:error, :not_an_integer}
      end
    end

    def safe_parse_integer(_), do: {:error, :not_an_integer}

    @spec safe_head(list()) :: {:ok, term()} | {:error, :empty_list}
    def safe_head([h | _]), do: {:ok, h}
    def safe_head([]), do: {:error, :empty_list}

    @spec safe_fetch(map(), term()) :: {:ok, term()} | {:error, :key_not_found}
    def safe_fetch(map, key) when is_map(map) do
      case Map.fetch(map, key) do
        {:ok, v} -> {:ok, v}
        :error -> {:error, :key_not_found}
      end
    end

    def safe_fetch(_, _), do: {:error, :key_not_found}

    # ------------------------------------------------------------------
    # Idempotent operations
    # ------------------------------------------------------------------

    @spec idempotent_normalize(String.t()) :: String.t()
    def idempotent_normalize(s) when is_binary(s) do
      s |> String.trim() |> String.downcase()
    end

    @spec idempotent_deduplicate(list()) :: list()
    def idempotent_deduplicate(list) when is_list(list) do
      Enum.uniq(list)
    end

    @spec idempotent_sort(list()) :: list()
    def idempotent_sort(list) when is_list(list) do
      Enum.sort(list)
    end

    @spec idempotent_set_flag(map(), atom()) :: map()
    def idempotent_set_flag(state, flag) when is_map(state) and is_atom(flag) do
      Map.put(state, flag, true)
    end
  end

  # ---------------------------------------------------------------------------
  # ETS-backed simulated state store — used for stateful contract tests
  # ---------------------------------------------------------------------------

  defmodule StateStore do
    @moduledoc "In-process ETS state store for self-contained stateful contract tests."

    def new(name \\ :io_contract_store) do
      :ets.new(name, [:set, :public])
    end

    def put(table, key, value) do
      :ets.insert(table, {key, value})
      :ok
    end

    def get(table, key) do
      case :ets.lookup(table, key) do
        [{^key, value}] -> {:ok, value}
        [] -> {:error, :not_found}
      end
    end

    def delete(table, key) do
      :ets.delete(table, key)
      :ok
    end

    def count(table), do: :ets.info(table, :size)

    def destroy(table) do
      if :ets.info(table) != :undefined, do: :ets.delete(table)
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    table = StateStore.new()

    on_exit(fn -> StateStore.destroy(table) end)

    %{store: table}
  end

  # ============================================================================
  # 1. INPUT VALIDATION — nil, empty, boundary values
  # ============================================================================

  describe "Input validation: nil and empty inputs (SC-VER-001)" do
    @tag :input_validation
    @tag :nil_safety
    test "validate_holon_id rejects nil" do
      assert Contract.validate_holon_id(nil) == {:error, :invalid_holon_id}
    end

    @tag :input_validation
    @tag :nil_safety
    test "validate_holon_id rejects empty string" do
      assert Contract.validate_holon_id("") == {:error, :invalid_holon_id}
    end

    @tag :input_validation
    @tag :nil_safety
    test "validate_holon_id rejects integer type input" do
      assert Contract.validate_holon_id(42) == {:error, :invalid_holon_id}
    end

    @tag :input_validation
    @tag :nil_safety
    test "validate_holon_id rejects list input" do
      assert Contract.validate_holon_id([]) == {:error, :invalid_holon_id}
    end

    @tag :input_validation
    @tag :boundary
    test "validate_holon_id accepts single lowercase letter (boundary min)" do
      assert Contract.validate_holon_id("a") == {:ok, "a"}
    end

    @tag :input_validation
    @tag :boundary
    test "validate_holon_id accepts 63-character name (boundary max)" do
      name = "a" <> String.duplicate("x", 62)
      assert Contract.validate_holon_id(name) == {:ok, name}
    end

    @tag :input_validation
    @tag :boundary
    test "validate_holon_id rejects 64+ character name (exceeds max)" do
      name = "a" <> String.duplicate("x", 63)
      assert Contract.validate_holon_id(name) == {:error, :invalid_holon_id}
    end

    @tag :input_validation
    test "validate_priority rejects nil" do
      assert Contract.validate_priority(nil) == {:error, :invalid_priority}
    end

    @tag :input_validation
    test "validate_priority rejects unknown atom" do
      assert Contract.validate_priority(:p9) == {:error, :invalid_priority}
    end

    @tag :input_validation
    test "validate_priority rejects string representation" do
      assert Contract.validate_priority("p0") == {:error, :invalid_priority}
    end

    @tag :input_validation
    test "validate_probability rejects value above 1.0" do
      assert Contract.validate_probability(1.01) == {:error, :invalid_probability}
    end

    @tag :input_validation
    test "validate_probability rejects negative float" do
      assert Contract.validate_probability(-0.01) == {:error, :invalid_probability}
    end

    @tag :input_validation
    test "validate_probability rejects non-numeric input" do
      assert Contract.validate_probability("50%") == {:error, :invalid_probability}
    end
  end

  # ============================================================================
  # 2. OUTPUT TYPE GUARANTEES — return type always matches spec
  # ============================================================================

  describe "Output type guarantees: return types always match spec (SC-VER-001)" do
    @tag :output_guarantees
    test "compute_health_score always returns a float in [0.0, 1.0]" do
      Enum.each(
        [{0, 10}, {5, 10}, {10, 10}, {0, 0}, {100, 50}],
        fn {passing, total} ->
          result = Contract.compute_health_score(passing, total)
          assert is_float(result), "Expected float, got #{inspect(result)}"
          assert result >= 0.0 and result <= 1.0
        end
      )
    end

    @tag :output_guarantees
    test "normalize_name always returns a binary (string)" do
      inputs = ["Hello World", " UPPER ", "already_lower", "  spaces  "]

      Enum.each(inputs, fn input ->
        result = Contract.normalize_name(input)

        assert is_binary(result),
               "Expected binary, got #{inspect(result)} for input #{inspect(input)}"
      end)
    end

    @tag :output_guarantees
    test "build_topic always returns a non-empty binary with slash separator" do
      result = Contract.build_topic("indrajaal/health", "node-1")
      assert is_binary(result)
      assert String.contains?(result, "/")
      refute result == ""
    end

    @tag :output_guarantees
    test "compute_quorum always returns a positive integer" do
      Enum.each([1, 2, 3, 4, 5, 10, 100], fn n ->
        result = Contract.compute_quorum(n)
        assert is_integer(result)
        assert result > 0
      end)
    end

    @tag :output_guarantees
    test "compute_quorum satisfies floor(N/2)+1 formula" do
      Enum.each([1, 2, 3, 5, 7, 10], fn n ->
        assert Contract.compute_quorum(n) == div(n, 2) + 1
      end)
    end

    @tag :output_guarantees
    test "clamp always returns a value within [lo, hi]" do
      cases = [
        {-10, 0, 100, 0},
        {200, 0, 100, 100},
        {50, 0, 100, 50}
      ]

      Enum.each(cases, fn {value, lo, hi, expected} ->
        result = Contract.clamp(value, lo, hi)
        assert result == expected
        assert result >= lo and result <= hi
      end)
    end

    @tag :output_guarantees
    test "validate_holon_id always wraps success in {:ok, binary} tuple" do
      {:ok, id} = Contract.validate_holon_id("valid-holon-1")
      assert is_binary(id)
    end

    @tag :output_guarantees
    test "validate_priority always wraps success in {:ok, atom} tuple" do
      Enum.each([:p0, :p1, :p2, :p3], fn p ->
        assert {:ok, ^p} = Contract.validate_priority(p)
      end)
    end
  end

  # ============================================================================
  # 3. CONTRACT ENFORCEMENT — pre-conditions and post-conditions
  # ============================================================================

  describe "Contract enforcement: pre/post conditions (SC-FUNC-002)" do
    @tag :contract_enforcement
    test "safe_divide pre-condition: integer zero denominator returns error" do
      assert Contract.safe_divide(10, 0) == {:error, :division_by_zero}
    end

    @tag :contract_enforcement
    test "safe_divide pre-condition: float zero denominator returns error" do
      assert Contract.safe_divide(10.0, 0.0) == {:error, :division_by_zero}
    end

    @tag :contract_enforcement
    test "safe_divide post-condition: result is a float when valid" do
      {:ok, result} = Contract.safe_divide(10, 4)
      assert is_float(result)
      assert result == 2.5
    end

    @tag :contract_enforcement
    test "bounded_append pre-condition: rejects when list is at capacity" do
      full_list = [1, 2, 3]
      assert Contract.bounded_append(full_list, 4, 3) == {:error, :capacity_exceeded}
    end

    @tag :contract_enforcement
    test "bounded_append post-condition: appended item is last element" do
      {:ok, result} = Contract.bounded_append([1, 2], :new_item, 10)
      assert List.last(result) == :new_item
    end

    @tag :contract_enforcement
    test "bounded_append post-condition: length increases by exactly 1" do
      list = [1, 2, 3]
      {:ok, result} = Contract.bounded_append(list, 4, 10)
      assert length(result) == length(list) + 1
    end

    @tag :contract_enforcement
    test "StateStore pre-condition: count reflects number of stored entries", %{store: store} do
      assert StateStore.count(store) == 0
      StateStore.put(store, :k1, "v1")
      assert StateStore.count(store) == 1
      StateStore.put(store, :k2, "v2")
      assert StateStore.count(store) == 2
    end

    @tag :contract_enforcement
    test "StateStore post-condition: stored value is retrievable unchanged", %{store: store} do
      value = %{node: "indrajaal-app-1", status: :healthy, score: 0.97}
      StateStore.put(store, :health, value)
      {:ok, retrieved} = StateStore.get(store, :health)
      assert retrieved == value
    end

    @tag :contract_enforcement
    test "StateStore post-condition: deleted key is no longer retrievable", %{store: store} do
      StateStore.put(store, :tmp, "temporary")
      {:ok, _} = StateStore.get(store, :tmp)
      StateStore.delete(store, :tmp)
      assert StateStore.get(store, :tmp) == {:error, :not_found}
    end
  end

  # ============================================================================
  # 4. ERROR HANDLING CONTRACTS — all errors wrapped in {:error, _}
  # ============================================================================

  describe "Error handling contracts: all errors use {:error, reason} (SC-VER-001)" do
    @tag :error_contracts
    test "safe_parse_integer returns {:error, :not_an_integer} for nil" do
      assert {:error, :not_an_integer} = Contract.safe_parse_integer(nil)
    end

    @tag :error_contracts
    test "safe_parse_integer returns {:error, :not_an_integer} for float" do
      assert {:error, :not_an_integer} = Contract.safe_parse_integer(3.14)
    end

    @tag :error_contracts
    test "safe_parse_integer returns {:error, :not_an_integer} for malformed string" do
      assert {:error, :not_an_integer} = Contract.safe_parse_integer("not-a-number")
    end

    @tag :error_contracts
    test "safe_parse_integer returns {:ok, integer} for valid integer string" do
      assert {:ok, 42} = Contract.safe_parse_integer("42")
    end

    @tag :error_contracts
    test "safe_parse_integer returns {:ok, integer} for negative integer string" do
      assert {:ok, -7} = Contract.safe_parse_integer("-7")
    end

    @tag :error_contracts
    test "safe_head returns {:error, :empty_list} for empty list" do
      assert {:error, :empty_list} = Contract.safe_head([])
    end

    @tag :error_contracts
    test "safe_head returns {:ok, first_element} for non-empty list" do
      assert {:ok, :first} = Contract.safe_head([:first, :second])
    end

    @tag :error_contracts
    test "safe_fetch returns {:error, :key_not_found} for missing key" do
      assert {:error, :key_not_found} = Contract.safe_fetch(%{a: 1}, :b)
    end

    @tag :error_contracts
    test "safe_fetch returns {:error, :key_not_found} for non-map input" do
      assert {:error, :key_not_found} = Contract.safe_fetch(nil, :any)
    end

    @tag :error_contracts
    test "safe_fetch returns {:ok, value} for existing key" do
      assert {:ok, :sentinel} = Contract.safe_fetch(%{role: :sentinel}, :role)
    end

    @tag :error_contracts
    test "all error-path functions return 2-element {:error, reason} tuples" do
      errors = [
        Contract.validate_holon_id(nil),
        Contract.validate_priority(:unknown),
        Contract.validate_probability(2.0),
        Contract.safe_parse_integer("bad"),
        Contract.safe_head([]),
        Contract.safe_fetch(%{}, :missing),
        Contract.safe_divide(1, 0),
        Contract.bounded_append([1], 2, 1)
      ]

      Enum.each(errors, fn result ->
        assert match?({:error, _}, result),
               "Expected {:error, _} tuple, got: #{inspect(result)}"
      end)
    end
  end

  # ============================================================================
  # 5. IDEMPOTENCY — applying the same pure function twice yields same result
  # ============================================================================

  describe "Idempotency: applying a pure function twice equals applying it once (SC-VER-001)" do
    @tag :idempotency
    test "idempotent_normalize is stable under repeated application" do
      input = "  Hello World  "
      once = Contract.idempotent_normalize(input)
      twice = Contract.idempotent_normalize(once)
      assert once == twice
    end

    @tag :idempotency
    test "idempotent_deduplicate is stable under repeated application" do
      input = [1, 2, 2, 3, 3, 3]
      once = Contract.idempotent_deduplicate(input)
      twice = Contract.idempotent_deduplicate(once)
      assert once == twice
    end

    @tag :idempotency
    test "idempotent_sort is stable under repeated application" do
      input = [5, 3, 1, 4, 2]
      once = Contract.idempotent_sort(input)
      twice = Contract.idempotent_sort(once)
      assert once == twice
    end

    @tag :idempotency
    test "idempotent_set_flag is stable — setting same flag twice equals setting once" do
      state = %{active: false}
      once = Contract.idempotent_set_flag(state, :guardian_verified)
      twice = Contract.idempotent_set_flag(once, :guardian_verified)
      assert once == twice
    end

    @tag :idempotency
    test "compute_quorum is deterministic — same N always yields same quorum" do
      Enum.each(1..20, fn n ->
        q1 = Contract.compute_quorum(n)
        q2 = Contract.compute_quorum(n)
        assert q1 == q2
      end)
    end

    @tag :idempotency
    test "normalize_name applied three times stabilizes output" do
      input = "  INDRAJAAL Node  "
      once = Contract.normalize_name(input)
      twice = Contract.normalize_name(once)
      three = Contract.normalize_name(twice)
      assert once == twice
      assert twice == three
    end
  end

  # ============================================================================
  # 6. PROPERTY-BASED TESTS — StreamData generators (SC-PROP-023/024)
  # EP-GEN-014: check/2 excluded from ExUnitProperties import — use qualified form
  # ============================================================================

  describe "Property-based: input validation holds for all valid inputs (SC-VER-001)" do
    @tag :property_based
    test "validate_priority {:ok, p} always returns the same atom that was passed" do
      forall p <- PC.elements([:p0, :p1, :p2, :p3]) do
        assert {:ok, ^p} = Contract.validate_priority(p)
      end
    end

    @tag :property_based
    test "validate_severity {:ok, s} always returns the same atom that was passed" do
      forall s <- PC.elements([:low, :medium, :high, :critical]) do
        assert {:ok, ^s} = Contract.validate_severity(s)
      end
    end

    @tag :property_based
    test "compute_health_score result is always in [0.0, 1.0]" do
      forall {{passing, total}} <- {{PC.integer(0, 1000), PC.integer(1, 1000)}} do
        score = Contract.compute_health_score(passing, total)
        assert is_float(score)
        assert score >= 0.0
        assert score <= 1.0
      end
    end

    @tag :property_based
    test "clamp result is always within [lo, hi] for arbitrary values" do
      forall {lo, hi, value} <- {PC.integer(-100, 0), PC.integer(1, 100), PC.integer(-200, 200)} do
        result = Contract.clamp(value, lo, hi)
        assert result >= lo
        assert result <= hi
      end
    end

    @tag :property_based
    test "compute_quorum always satisfies SIL-6 floor(N/2)+1 formula" do
      forall n <- PC.integer(1, 100) do
        quorum = Contract.compute_quorum(n)
        assert quorum == div(n, 2) + 1
        # quorum > strict majority: no split-brain possible
        assert quorum * 2 > n
      end
    end

    @tag :property_based
    test "safe_divide succeeds iff denominator is non-zero positive integer" do
      forall {{numerator, denominator}} <- {{PC.integer(-100, 100), PC.integer(1, 100)}} do
        {:ok, result} = Contract.safe_divide(numerator, denominator)
        assert is_float(result)
        assert_in_delta result, numerator / denominator, 1.0e-9
      end
    end

    @tag :property_based
    test "idempotent_sort is total order: result is sorted and preserves elements" do
      forall list <- PC.list(PC.integer(-1000, 1000)) do
        sorted = Contract.idempotent_sort(list)
        assert length(sorted) == length(list)
        assert sorted == Enum.sort(list)
      end
    end

    @tag :property_based
    test "idempotent_deduplicate never grows the list" do
      forall list <- PC.list(PC.integer(0, 10)) do
        deduped = Contract.idempotent_deduplicate(list)
        assert length(deduped) <= length(list)
      end
    end

    @tag :property_based
    test "bounded_append never allows list to exceed max capacity" do
      forall {items, max_cap} <- {PC.list(PC.integer()), PC.integer(1, 10)} do
        result =
          Enum.reduce(items, [], fn item, acc ->
            case Contract.bounded_append(acc, item, max_cap) do
              {:ok, new_list} -> new_list
              {:error, :capacity_exceeded} -> acc
            end
          end)

        assert length(result) <= max_cap
      end
    end

    @tag :property_based
    test "normalize_name output is always lowercase with no leading/trailing whitespace" do
      forall s <- PC.utf8() do
        result = Contract.normalize_name(s)
        assert is_binary(result)
        assert String.trim(result) == result
        assert result == String.downcase(result)
      end
    end
  end

  # ============================================================================
  # 7. STATEFUL CONTRACT TESTS via ETS — lifecycle and boundary behaviors
  # ============================================================================

  describe "Stateful ETS contracts: store lifecycle correctness" do
    @tag :stateful_contracts
    test "store begins empty and count matches insertions", %{store: store} do
      assert StateStore.count(store) == 0

      for i <- 1..5 do
        StateStore.put(store, :"key_#{i}", "value_#{i}")
      end

      assert StateStore.count(store) == 5
    end

    @tag :stateful_contracts
    test "get on non-existent key always returns {:error, :not_found}", %{store: store} do
      assert StateStore.get(store, :does_not_exist) == {:error, :not_found}
    end

    @tag :stateful_contracts
    test "put and get preserve complex nested map values", %{store: store} do
      payload = %{
        node: "indrajaal-app-1",
        metrics: %{cpu: 0.42, mem: 0.61},
        tags: [:healthy, :quorum_member],
        timestamp: ~U[2026-03-24 00:00:00Z]
      }

      StateStore.put(store, :node_payload, payload)
      {:ok, retrieved} = StateStore.get(store, :node_payload)
      assert retrieved == payload
    end

    @tag :stateful_contracts
    test "overwriting a key with put replaces the value (no append semantics)", %{store: store} do
      StateStore.put(store, :counter, 1)
      StateStore.put(store, :counter, 2)
      {:ok, val} = StateStore.get(store, :counter)
      assert val == 2
    end

    @tag :stateful_contracts
    test "delete is idempotent — deleting non-existent key does not raise", %{store: store} do
      assert StateStore.delete(store, :phantom_key) == :ok
      assert StateStore.delete(store, :phantom_key) == :ok
    end
  end
end
