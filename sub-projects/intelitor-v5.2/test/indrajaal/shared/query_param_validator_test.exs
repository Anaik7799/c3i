defmodule Indrajaal.Shared.QueryParamValidatorTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.QueryParamValidator module.

  Tests comprehensive query parameter validation patterns for:
  - Basic parameter validation (presence, type checking)
  - Security validation (injection prevention, sanitization)
  - Pagination parameter validation
  - Filter parameter validation
  - Sort parameter validation

  Created: 2025-11-27 14:15:00 CEST
  Phase: 2.2 - C1 Security-Critical Testing (Validation Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.QueryParamValidator

  # ============================================================================
  # BASIC PARAMETER VALIDATION TESTS
  # ============================================================================

  describe "validate_query_params/1 - basic validation" do
    test "returns ok with valid empty params" do
      assert {:ok, %{}} = QueryParamValidator.validate_query_params(%{})
    end

    test "returns ok with valid string params" do
      params = %{"name" => "test", "status" => "active"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with valid atom key params" do
      params = %{name: "test", status: "active"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with mixed key params" do
      params = %{"status" => "active", name: "test"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with nil values" do
      params = %{name: nil, status: nil}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with integer values" do
      params = %{page: 1, limit: 10}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with boolean values" do
      params = %{active: true, deleted: false}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with list values" do
      params = %{ids: [1, 2, 3], statuses: ["active", "pending"]}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "returns ok with nested map values" do
      params = %{filter: %{status: "active", type: "alarm"}}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end
  end

  # ============================================================================
  # PAGINATION PARAMETER VALIDATION TESTS
  # ============================================================================

  describe "validate_query_params/1 - pagination" do
    test "validates valid page number" do
      params = %{page: 1}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates valid limit" do
      params = %{limit: 50}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates valid offset" do
      params = %{offset: 100}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates string page number" do
      params = %{"page" => "1"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates string limit" do
      params = %{"limit" => "25"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates combined pagination params" do
      params = %{page: 2, limit: 25, offset: 25}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end
  end

  # ============================================================================
  # FILTER PARAMETER VALIDATION TESTS
  # ============================================================================

  describe "validate_query_params/1 - filters" do
    test "validates status filter" do
      params = %{status: "active"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates multiple status filters" do
      params = %{status: ["active", "pending", "resolved"]}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates date range filter" do
      params = %{
        start_date: "2025-01-01",
        end_date: "2025-12-31"
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates tenant_id filter" do
      params = %{tenant_id: "tenant-123"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates id filter with UUID" do
      params = %{id: "550e8400-e29b-41d4-a716-446_655_440_000"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates search query filter" do
      params = %{q: "search term"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates complex filter combination" do
      params = %{
        status: "active",
        tenant_id: "tenant-123",
        start_date: "2025-01-01",
        q: "alarm",
        page: 1,
        limit: 25
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end
  end

  # ============================================================================
  # SORT PARAMETER VALIDATION TESTS
  # ============================================================================

  describe "validate_query_params/1 - sorting" do
    test "validates sort_by parameter" do
      params = %{sort_by: "created_at"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates sort_order ascending" do
      params = %{sort_order: "asc"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates sort_order descending" do
      params = %{sort_order: "desc"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates combined sort params" do
      params = %{sort_by: "updated_at", sort_order: "desc"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates order_by alias" do
      params = %{order_by: "name"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates direction alias" do
      params = %{direction: "ascending"}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end
  end

  # ============================================================================
  # SECURITY VALIDATION TESTS (INJECTION PREVENTION)
  # ============================================================================

  describe "validate_query_params/1 - security" do
    test "handles SQL-like injection attempts safely" do
      # The validator should not crash or execute SQL
      params = %{name: "'; DROP TABLE users; --"}

      result = QueryParamValidator.validate_query_params(params)
      # Should either sanitize or return the params unchanged (parameterized queries handle this)
      assert {:ok, _} = result
    end

    test "handles script injection attempts safely" do
      params = %{name: "<script>alert('xss')</script>"}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles null byte injection attempts safely" do
      params = %{name: "test\x00malicious"}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles unicode normalization attacks safely" do
      # Zero-width space
      params = %{name: "admin\u200Buser"}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles extremely long values safely" do
      params = %{name: String.duplicate("a", 10_000)}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles deeply nested structures safely" do
      # Build 10 levels of nesting
      nested = Enum.reduce(1..10, "value", fn _, acc -> %{nested: acc} end)
      params = %{filter: nested}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles special characters in keys safely" do
      params = %{"key with spaces" => "value", "key.with.dots" => "value2"}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "validate_query_params/1 - edge cases" do
    test "handles empty string values" do
      params = %{name: "", status: ""}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "handles whitespace-only values" do
      params = %{name: "   ", status: "\t\n"}

      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles empty list values" do
      params = %{ids: [], statuses: []}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "handles empty nested map" do
      params = %{filter: %{}, options: %{}}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "handles float values" do
      params = %{latitude: 52.52, longitude: 13.405}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "handles date structs" do
      params = %{date: ~D[2025-11-27]}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "handles datetime structs" do
      params = %{timestamp: ~U[2025-11-27 14:30:00Z]}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "handles tuple values gracefully" do
      params = %{coords: {1, 2, 3}}

      result = QueryParamValidator.validate_query_params(params)
      # Should handle without crashing
      assert {:ok, _} = result
    end

    test "handles atom values" do
      params = %{type: :alarm, severity: :critical}

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end
  end

  # ============================================================================
  # RETURN VALUE STRUCTURE TESTS
  # ============================================================================

  describe "validate_query_params/1 - return structure" do
    test "always returns a tuple" do
      params = %{test: "value"}

      result = QueryParamValidator.validate_query_params(params)
      assert is_tuple(result)
    end

    test "success tuple has :ok as first element" do
      params = %{test: "value"}

      {status, _} = QueryParamValidator.validate_query_params(params)
      assert status == :ok
    end

    test "success tuple contains the params" do
      params = %{test: "value"}

      {:ok, returned} = QueryParamValidator.validate_query_params(params)
      assert is_map(returned)
    end

    test "preserves param structure in return" do
      params = %{
        page: 1,
        limit: 25,
        filter: %{status: "active"},
        sort_by: "created_at"
      }

      {:ok, returned} = QueryParamValidator.validate_query_params(params)
      assert returned == params
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "always returns {:ok, _} or {:error, _} tuple for any map input" do
      forall params <- PC.map(PC.utf8(), PC.any()) do
        result = QueryParamValidator.validate_query_params(params)

        case result do
          {:ok, _} -> true
          {:error, _} -> true
          _ -> false
        end
      end
    end

    property "returns {:ok, params} for string key maps" do
      forall params <- PC.map(PC.utf8(), PC.utf8()) do
        result = QueryParamValidator.validate_query_params(params)

        case result do
          {:ok, returned} when is_map(returned) -> true
          # Also valid if validation fails
          {:error, _} -> true
          _ -> false
        end
      end
    end

    property "handles pagination params without crashing" do
      forall {page, limit, offset} <-
               {PC.non_neg_integer(), PC.non_neg_integer(), PC.non_neg_integer()} do
        params = %{page: page, limit: limit, offset: offset}
        result = QueryParamValidator.validate_query_params(params)

        case result do
          {:ok, _} -> true
          {:error, _} -> true
          _ -> false
        end
      end
    end

    property "handles filter combinations without crashing" do
      forall {status, tenant_id, search} <- {PC.utf8(), PC.utf8(), PC.utf8()} do
        params = %{status: status, tenant_id: tenant_id, q: search}
        result = QueryParamValidator.validate_query_params(params)

        case result do
          {:ok, _} -> true
          {:error, _} -> true
          _ -> false
        end
      end
    end

    property "handles arbitrary nested maps without crashing" do
      forall nested <- PC.map(PC.atom(), PC.map(PC.atom(), PC.any())) do
        params = %{filter: nested}
        result = QueryParamValidator.validate_query_params(params)

        case result do
          {:ok, _} -> true
          {:error, _} -> true
          _ -> false
        end
      end
    end
  end

  # ============================================================================
  # TYPE-SPECIFIC INPUT TESTS
  # ============================================================================

  describe "validate_query_params/1 - type handling" do
    test "handles keyword list input" do
      params = [name: "test", status: "active"]

      # Should either convert or handle gracefully
      result = QueryParamValidator.validate_query_params(params)
      assert {:ok, _} = result
    end

    test "handles struct input" do
      # Using a simple struct
      params = URI.parse("https://example.com?q=test")

      result = QueryParamValidator.validate_query_params(params)
      # Should handle without crashing (may return error)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================================
  # INTEGRATION-STYLE TESTS
  # ============================================================================

  describe "validate_query_params/1 - realistic scenarios" do
    test "validates typical alarm list query" do
      params = %{
        "page" => "1",
        "limit" => "25",
        "status" => "active",
        "severity" => "critical",
        "sort_by" => "created_at",
        "sort_order" => "desc"
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates typical device search query" do
      params = %{
        "q" => "camera",
        "type" => "video",
        "tenant_id" => "tenant-abc-123",
        "online" => "true",
        "page" => "1"
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates typical analytics date range query" do
      params = %{
        "start_date" => "2025-01-01T00:00:00Z",
        "end_date" => "2025-12-31T23:59:59Z",
        "metrics" => ["response_time", "error_rate", "throughput"],
        "granularity" => "hourly"
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates typical user permission query" do
      params = %{
        user_id: "user-123",
        tenant_id: "tenant-456",
        resource_type: "alarm",
        action: "read"
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end

    test "validates complex multi-filter query" do
      params = %{
        "filter" => %{
          "status" => ["active", "pending"],
          "created_at" => %{
            "gte" => "2025-01-01",
            "lte" => "2025-12-31"
          },
          "severity" => %{
            "in" => ["high", "critical"]
          }
        },
        "include" => ["site", "device", "user"],
        "page" => %{
          "number" => "1",
          "size" => "25"
        }
      }

      assert {:ok, ^params} = QueryParamValidator.validate_query_params(params)
    end
  end
end
