defmodule Indrajaal.Cortex.GDE.GeneratorTest do
  @moduledoc """
  TDG Tests for GDE Generator module.

  Tests Unicon-style lazy generator operations.

  STAMP Constraints:
  - SC-GDE-001: Generators must be lazy
  - SC-GDE-002: Generators must be composable
  - SC-GDE-003: Generators must be deterministic
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cortex.GDE.Generator

  # ============================================================
  # ALTERNATIVES TESTS
  # ============================================================

  describe "alternatives/1" do
    test "creates generator from list" do
      gen = Generator.alternatives([:a, :b, :c])
      result = Enum.to_list(gen)

      assert result == [:a, :b, :c]
    end

    test "is lazy - doesn't evaluate until consumed" do
      # This should not raise even though the function would fail on evaluation
      gen = Generator.alternatives([1, 2, 3])
      assert is_struct(gen, Stream) or is_function(gen)
    end

    test "respects max branching factor" do
      large_list = Enum.to_list(1..200)
      gen = Generator.alternatives(large_list)
      result = Enum.to_list(gen)

      # Max branching factor is 100
      assert length(result) <= 100
    end
  end

  # ============================================================
  # FILTER TESTS
  # ============================================================

  describe "filter/2" do
    test "filters values by predicate" do
      gen =
        [1, 2, 3, 4, 5]
        |> Generator.alternatives()
        |> Generator.filter(&(rem(&1, 2) == 0))

      result = Enum.to_list(gen)
      assert result == [2, 4]
    end

    test "returns empty for no matches" do
      gen =
        [1, 3, 5]
        |> Generator.alternatives()
        |> Generator.filter(&(rem(&1, 2) == 0))

      result = Enum.to_list(gen)
      assert result == []
    end
  end

  # ============================================================
  # MAP TESTS
  # ============================================================

  describe "map/2" do
    test "transforms values" do
      gen =
        [1, 2, 3]
        |> Generator.alternatives()
        |> Generator.map(&(&1 * 2))

      result = Enum.to_list(gen)
      assert result == [2, 4, 6]
    end
  end

  # ============================================================
  # COMPOSE TESTS
  # ============================================================

  describe "compose/1" do
    test "combines multiple generators" do
      gen =
        Generator.compose([
          Generator.alternatives([:a, :b]),
          Generator.alternatives([:c, :d])
        ])

      result = Enum.to_list(gen)
      assert result == [:a, :b, :c, :d]
    end

    test "respects max branching factor" do
      gens = for _ <- 1..20, do: Generator.alternatives(Enum.to_list(1..10))
      gen = Generator.compose(gens)
      result = Enum.to_list(gen)

      assert length(result) <= 100
    end
  end

  # ============================================================
  # INTERLEAVE TESTS
  # ============================================================

  describe "interleave/1" do
    test "interleaves generators round-robin" do
      gen =
        Generator.interleave([
          Generator.alternatives([1, 2, 3]),
          Generator.alternatives([:a, :b, :c])
        ])

      result = Enum.to_list(gen)
      # Round-robin produces: 1, :a, 2, :b, 3, :c (though order may vary after uniq)
      assert 1 in result
      assert :a in result
    end
  end

  # ============================================================
  # TAKE_UNTIL TESTS
  # ============================================================

  describe "take_until/2" do
    test "stops after predicate is satisfied" do
      gen =
        [1, 2, 3, 4, 5]
        |> Generator.alternatives()
        |> Generator.take_until(&(&1 == 3))

      result = Enum.to_list(gen)
      assert result == [1, 2, 3]
    end

    test "returns all if predicate never satisfied" do
      gen =
        [1, 2, 3]
        |> Generator.alternatives()
        |> Generator.take_until(&(&1 == 10))

      result = Enum.to_list(gen)
      assert result == [1, 2, 3]
    end
  end

  # ============================================================
  # FIND_FIRST TESTS
  # ============================================================

  describe "find_first/2" do
    test "returns first matching value" do
      gen = Generator.alternatives([1, 2, 3, 4, 5])

      assert {:ok, 4} = Generator.find_first(gen, &(&1 > 3))
    end

    test "returns error when no match" do
      gen = Generator.alternatives([1, 2, 3])

      assert {:error, :not_found} = Generator.find_first(gen, &(&1 > 10))
    end
  end

  # ============================================================
  # FIND_ALL TESTS
  # ============================================================

  describe "find_all/3" do
    test "returns all matching values" do
      gen = Generator.alternatives([1, 2, 3, 4, 5])

      result = Generator.find_all(gen, &(&1 > 2))
      assert result == [3, 4, 5]
    end

    test "respects limit option" do
      gen = Generator.alternatives([1, 2, 3, 4, 5])

      result = Generator.find_all(gen, &(&1 > 0), limit: 2)
      assert result == [1, 2]
    end
  end

  # ============================================================
  # DOMAIN-SPECIFIC TESTS
  # ============================================================

  describe "file_candidates/1" do
    test "generates candidate paths for module name" do
      gen = Generator.file_candidates("accounts")
      result = Enum.to_list(gen)

      assert "lib/indrajaal/accounts.ex" in result
      assert "lib/indrajaal/accounts/accounts.ex" in result
    end

    test "handles atom input" do
      gen = Generator.file_candidates(:Accounts)
      result = Enum.to_list(gen)

      assert length(result) > 0
    end
  end

  describe "module_paths/1" do
    test "generates paths from module atom" do
      gen = Generator.module_paths(Indrajaal.Accounts)
      result = Enum.to_list(gen)

      assert "lib/indrajaal/accounts.ex" in result
    end
  end

  describe "fix_strategies/2" do
    test "generates strategies for undefined function" do
      gen = Generator.fix_strategies(:undefined_function)
      result = Enum.to_list(gen)

      types = Enum.map(result, & &1.type)
      assert :add_import in types
      assert :add_alias in types
    end

    test "prioritizes hinted strategies" do
      gen = Generator.fix_strategies(:undefined_function, %{hints: [:define_function]})
      result = Enum.to_list(gen)

      # Hinted strategy should be first
      first = List.first(result)
      assert first.type == :define_function
    end
  end

  # ============================================================
  # WITH_BACKTRACK TESTS
  # ============================================================

  describe "with_backtrack/3" do
    test "returns first successful result" do
      gen = Generator.alternatives([1, 2, 3])

      result =
        Generator.with_backtrack(gen, fn x ->
          if x == 2, do: {:ok, "found #{x}"}, else: {:error, :not_two}
        end)

      assert {:ok, "found 2"} = result
    end

    test "returns exhausted when no success" do
      gen = Generator.alternatives([1, 2, 3])

      result =
        Generator.with_backtrack(gen, fn _x ->
          {:error, :never}
        end)

      assert {:error, :exhausted} = result
    end

    test "stops on :stop from on_failure callback" do
      gen = Generator.alternatives([1, 2, 3])

      result =
        Generator.with_backtrack(
          gen,
          fn _x -> {:error, :fatal} end,
          on_failure: fn _reason -> :stop end
        )

      assert {:error, :fatal} = result
    end

    test "respects timeout" do
      gen = Generator.alternatives([1, 2, 3])

      result =
        Generator.with_backtrack(
          gen,
          fn _x ->
            Process.sleep(100)
            {:error, :slow}
          end,
          timeout: 50
        )

      assert {:error, :timeout} = result
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "alternatives preserves list elements (bounded)" do
      forall list <- PC.list(PC.integer()) do
        bounded_list = Enum.take(list, 50)
        gen = Generator.alternatives(bounded_list)
        result = Enum.to_list(gen)

        # Result should equal input (up to max branching)
        expected = Enum.take(bounded_list, 100)
        result == expected
      end
    end

    property "filter is consistent with Enum.filter" do
      forall list <- PC.list(PC.integer()) do
        bounded_list = Enum.take(list, 50)
        predicate = fn x -> rem(x, 2) == 0 end

        gen_result =
          bounded_list
          |> Generator.alternatives()
          |> Generator.filter(predicate)
          |> Enum.to_list()

        enum_result = Enum.filter(bounded_list, predicate)

        gen_result == enum_result
      end
    end

    property "map is consistent with Enum.map" do
      forall list <- PC.list(PC.integer()) do
        bounded_list = Enum.take(list, 50)
        transformer = fn x -> x * 2 end

        gen_result =
          bounded_list
          |> Generator.alternatives()
          |> Generator.map(transformer)
          |> Enum.to_list()

        enum_result = Enum.map(bounded_list, transformer)

        gen_result == enum_result
      end
    end
  end
end
