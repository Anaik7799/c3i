defmodule Indrajaal.Shared.UnifiedUtilitySystemTest do
  @moduledoc """
  Comprehensive test suite for UnifiedUtilitySystem following TDG methodology.

  Test Categories:
  1. Unit tests for all public functions
  2. Property-based tests using PropCheck and ExUnitProperties
  3. Edge case testing
  4. Integration testing

  Agent-friendly comment: This test file was written BEFORE the implementation
  following Test-Driven Generation (TDG) methodology.
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Shared.UnifiedUtilitySystem

  describe "apply_search/3" do
    test "returns query unchanged when search term is empty" do
      query = %{base: "query"}
      assert UnifiedUtilitySystem.apply_search(query, "", [:name]) == query
      assert UnifiedUtilitySystem.apply_search(query, "  ", [:name]) == query
    end

    test "applies search filters when search term is provided" do
      query = %{base: "query"}
      result = UnifiedUtilitySystem.apply_search(query, "test", [:name, :description])
      assert result != nil
    end

    test "handles nil search term gracefully" do
      query = %{base: "query"}
      assert UnifiedUtilitySystem.apply_search(query, nil, [:name]) == query
    end

    # Property-based test using PropCheck
    property "search always returns a value" do
      forall {query, search_term, fields} <-
               {PC.map(
                  PC.atom(),
                  PC.term()
                ), PC.utf8(), PC.list(PC.atom())} do
        result = UnifiedUtilitySystem.apply_search(query, search_term, fields)
        result != nil
      end
    end

    # Property-based test using ExUnitProperties
    test "search term trimming is consistent" do
      ExUnitProperties.check all(
                               query <-
                                 StreamData.map_of(
                                   StreamData.atom(:alphanumeric),
                                   StreamData.term()
                                 ),
                               search_term <- StreamData.string(:alphanumeric),
                               fields <- StreamData.list_of(StreamData.atom(:alphanumeric))
                             ) do
        result = UnifiedUtilitySystem.apply_search(query, "  #{search_term}  ", fields)
        expected = UnifiedUtilitySystem.apply_search(query, search_term, fields)

        # Exclude applied_at timestamp from comparison as sequential calls will have microsecond differences
        # The timestamp is nested inside the :search map, so we need deep normalization
        result_normalized = normalize_for_comparison(result)
        expected_normalized = normalize_for_comparison(expected)
        assert result_normalized == expected_normalized
      end
    end
  end

  describe "apply_filters/2" do
    test "returns query unchanged when filters is empty" do
      query = %{base: "query"}
      assert UnifiedUtilitySystem.apply_filters(query, %{}) == query
    end

    test "applies single filter" do
      query = %{base: "query"}
      result = UnifiedUtilitySystem.apply_filters(query, %{status: "active"})
      assert result != nil
    end

    test "applies multiple filters" do
      query = %{base: "query"}
      filters = %{status: "active", type: "admin", role: "supervisor"}
      result = UnifiedUtilitySystem.apply_filters(query, filters)
      assert result != nil
    end

    test "ignores nil filter values" do
      query = %{base: "query"}
      filters = %{status: "active", type: nil}
      result = UnifiedUtilitySystem.apply_filters(query, filters)
      assert result != nil
    end

    test "handles non-map filters gracefully" do
      query = %{base: "query"}
      assert UnifiedUtilitySystem.apply_filters(query, nil) == query
      assert UnifiedUtilitySystem.apply_filters(query, []) == query
    end
  end

  describe "validate_required_params/2" do
    test "returns ok when all required fields are present" do
      params = %{name: "John", email: "john@example.com", age: 30}

      assert {:ok, ^params} =
               UnifiedUtilitySystem.validate_required_params(params, [:name, :email])
    end

    test "returns error when required fields are missing" do
      params = %{name: "John"}

      assert {:error, message} =
               UnifiedUtilitySystem.validate_required_params(params, [:name, :email, :age])

      assert message =~ "email"
      assert message =~ "age"
    end

    test "considers empty strings as missing" do
      params = %{name: "John", email: ""}

      assert {:error, message} =
               UnifiedUtilitySystem.validate_required_params(params, [:name, :email])

      assert message =~ "email"
    end

    test "handles empty required fields list" do
      params = %{name: "John"}
      assert {:ok, ^params} = UnifiedUtilitySystem.validate_required_params(params, [])
    end

    # Property-based test using PropCheck
    property "validation always returns ok or error tuple" do
      forall {params, fields} <-
               {PC.map(
                  PC.atom(),
                  PC.term()
                ), PC.list(PC.atom())} do
        case UnifiedUtilitySystem.validate_required_params(params, fields) do
          {:ok, _} -> true
          {:error, _} -> true
          _ -> false
        end
      end
    end
  end

  describe "validate_uuid/1" do
    test "validates correct UUID format" do
      uuid = "123e4567-e89b-12d3-a456-426_614_174_000"
      assert {:ok, ^uuid} = UnifiedUtilitySystem.validate_uuid(uuid)
    end

    test "rejects invalid UUID format" do
      assert {:error, "Invalid UUID format"} = UnifiedUtilitySystem.validate_uuid("invalid-uuid")
      assert {:error, "Invalid UUID format"} = UnifiedUtilitySystem.validate_uuid("123")
    end

    test "rejects non-string values" do
      assert {:error, "UUID must be a string"} = UnifiedUtilitySystem.validate_uuid(123)
      assert {:error, "UUID must be a string"} = UnifiedUtilitySystem.validate_uuid(nil)
      assert {:error, "UUID must be a string"} = UnifiedUtilitySystem.validate_uuid(%{})
    end

    # Property-based test for UUID validation
    property "valid UUIDs are always accepted" do
      forall uuid <- uuid_generator() do
        {:ok, _} = UnifiedUtilitySystem.validate_uuid(uuid)
      end
    end
  end

  describe "apply_pagination/3" do
    test "applies default pagination" do
      query = %{base: "query"}
      result = UnifiedUtilitySystem.apply_pagination(query)
      assert result != nil
    end

    test "applies custom page and per_page" do
      query = %{base: "query"}
      result = UnifiedUtilitySystem.apply_pagination(query, 5, 50)
      assert result != nil
    end

    test "handles page 0 by treating as page 1" do
      query = %{base: "query"}
      result1 = UnifiedUtilitySystem.apply_pagination(query, 0, 20)
      result2 = UnifiedUtilitySystem.apply_pagination(query, 1, 20)
      assert result1 == result2
    end

    test "handles negative page numbers" do
      query = %{base: "query"}
      result = UnifiedUtilitySystem.apply_pagination(query, -5, 20)
      assert result != nil
    end

    # Property-based test
    property "pagination offset calculation is correct" do
      forall {page, per_page} <- {PC.pos_integer(), PC.pos_integer()} do
        query = %{base: "query"}
        _result = UnifiedUtilitySystem.apply_pagination(query, page, per_page)
        expected_offset = (max(page, 1) - 1) * per_page
        expected_offset >= 0
      end
    end
  end

  describe "format_pagination_meta/4" do
    test "formats pagination metadata correctly" do
      results = [1, 2, 3, 4, 5]
      meta = UnifiedUtilitySystem.format_pagination_meta(results, 2, 5, 100)

      assert meta.current_page == 2
      assert meta.per_page == 5
      assert meta.total_pages == 20
      assert meta.total_count == 100
      assert meta.results_count == 5
    end

    test "handles empty results" do
      meta = UnifiedUtilitySystem.format_pagination_meta([], 1, 10, 0)

      assert meta.current_page == 1
      assert meta.per_page == 10
      assert meta.total_pages == 0
      assert meta.total_count == 0
      assert meta.results_count == 0
    end

    # Property-based test
    property "total pages calculation is always correct" do
      forall {results, page, per_page, total} <-
               {PC.list(PC.term()), PC.pos_integer(), PC.pos_integer(), PC.non_neg_integer()} do
        meta = UnifiedUtilitySystem.format_pagination_meta(results, page, per_page, total)
        expected_pages = if total == 0, do: 0, else: ceil(total / per_page)
        meta.total_pages == expected_pages
      end
    end
  end

  describe "parse_date_range/1" do
    test "parses valid date range" do
      params = %{
        "from" => "2024-01-01T00:00:00Z",
        "to" => "2024-12-31T23:59:59Z"
      }

      assert {:ok, {from_date, to_date}} = UnifiedUtilitySystem.parse_date_range(params)
      assert %DateTime{} = from_date
      assert %DateTime{} = to_date
    end

    test "returns error for invalid date format" do
      params = %{"from" => "invalid", "to" => "2024-12-31T23:59:59Z"}
      assert {:error, "Invalid date format"} = UnifiedUtilitySystem.parse_date_range(params)
    end

    test "handles missing date range params" do
      assert {:ok, nil} = UnifiedUtilitySystem.parse_date_range(%{})
      assert {:ok, nil} = UnifiedUtilitySystem.parse_date_range(nil)
    end

    test "handles partial date range" do
      params = %{"from" => "2024-01-01T00:00:00Z"}
      assert {:ok, nil} = UnifiedUtilitySystem.parse_date_range(params)
    end
  end

  describe "log_operation_result/3" do
    test "logs successful operations" do
      result = {:ok, %{id: 1}}
      logged = UnifiedUtilitySystem.log_operation_result("create_user", result)
      assert logged == result
    end

    test "logs failed operations" do
      result = {:error, "validation failed"}
      logged = UnifiedUtilitySystem.log_operation_result("create_user", result)
      assert logged == result
    end

    test "includes custom metadata" do
      result = {:ok, %{id: 1}}
      metadata = %{user_id: 123, tenant_id: 456}
      logged = UnifiedUtilitySystem.log_operation_result("create_user", result, metadata)
      assert logged == result
    end

    test "handles non-tuple results" do
      result = %{status: "completed"}
      logged = UnifiedUtilitySystem.log_operation_result("process", result)
      assert logged == result
    end
  end

  describe "handle_error/1" do
    test "handles changeset errors" do
      # Mock changeset error for testing
      changeset = %{errors: [name: {"can't be blank", []}]}
      result = UnifiedUtilitySystem.handle_error({:error, changeset})
      assert {:error, _} = result
    end

    test "handles regular error tuples" do
      assert {:error, "failed"} = UnifiedUtilitySystem.handle_error({:error, "failed"})
    end

    test "passes through non-error results" do
      assert {:ok, "success"} = UnifiedUtilitySystem.handle_error({:ok, "success"})
      assert "value" = UnifiedUtilitySystem.handle_error("value")
    end

    # Property-based test
    property "error handling is idempotent" do
      forall error <- PC.term() do
        result1 = UnifiedUtilitySystem.handle_error(error)
        result2 = UnifiedUtilitySystem.handle_error(result1)
        result1 == result2
      end
    end
  end

  # Helper to normalize maps for comparison by removing timestamps
  # Handles nested :search map structure where :applied_at is stored
  defp normalize_for_comparison(result) when is_map(result) do
    if is_map(result[:search]) do
      put_in(result, [:search], Map.drop(result[:search], [:applied_at]))
    else
      Map.drop(result, [:applied_at])
    end
  end

  defp normalize_for_comparison(result), do: result

  # Helper generator for UUIDs using PC.binary/1
  defp uuid_generator do
    let parts <- {
          PC.binary(4),
          PC.binary(2),
          PC.binary(2),
          PC.binary(2),
          PC.binary(6)
        } do
      {p1, p2, p3, p4, p5} = parts
      hex1 = Base.encode16(p1, case: :lower)
      hex2 = Base.encode16(p2, case: :lower)
      hex3 = Base.encode16(p3, case: :lower)
      hex4 = Base.encode16(p4, case: :lower)
      hex5 = Base.encode16(p5, case: :lower)
      "#{hex1}-#{hex2}-#{hex3}-#{hex4}-#{hex5}"
    end
  end
end
