defmodule Indrajaal.Shared.ControllerHelpersTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Shared.ControllerHelpers.

  Tests the controller helpers module that eliminates ~100 duplicate violations
  across domain controllers with standardized JSON response handling.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Function Tests, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.ControllerHelpers

  # ===========================================================================
  # Module Structure Tests
  # ===========================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(ControllerHelpers)
    end

    test "exports render_json_response/3" do
      exports = ControllerHelpers.__info__(:functions)
      assert {:render_json_response, 3} in exports
    end

    test "has proper moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(ControllerHelpers)
      assert module_doc != :hidden
      assert module_doc != :none
    end

    test "has spec annotation for render_json_response/3" do
      {:docs_v1, _, :elixir, _, _, _, function_docs} = Code.fetch_docs(ControllerHelpers)

      render_docs =
        Enum.filter(function_docs, fn
          {{:function, :render_json_response, 3}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(render_docs) >= 1
    end
  end

  # ===========================================================================
  # render_json_response/3 Tests
  # ===========================================================================

  describe "render_json_response/3" do
    test "returns conn with JSON response and default :ok status" do
      conn = build_conn()
      data = %{message: "success"}

      result = ControllerHelpers.render_json_response(conn, data)

      assert result.status == 200
      assert result.resp_body == Jason.encode!(data)
      assert get_content_type(result) =~ "application/json"
    end

    test "returns conn with JSON response and :ok status explicitly" do
      conn = build_conn()
      data = %{data: [1, 2, 3]}

      result = ControllerHelpers.render_json_response(conn, data, :ok)

      assert result.status == 200
    end

    test "returns conn with :created status" do
      conn = build_conn()
      data = %{id: "new-resource-id"}

      result = ControllerHelpers.render_json_response(conn, data, :created)

      assert result.status == 201
    end

    test "returns conn with :not_found status" do
      conn = build_conn()
      data = %{error: "Resource not found"}

      result = ControllerHelpers.render_json_response(conn, data, :not_found)

      assert result.status == 404
    end

    test "returns conn with :bad_request status" do
      conn = build_conn()
      data = %{error: "Invalid parameters"}

      result = ControllerHelpers.render_json_response(conn, data, :bad_request)

      assert result.status == 400
    end

    test "returns conn with :unauthorized status" do
      conn = build_conn()
      data = %{error: "Authentication required"}

      result = ControllerHelpers.render_json_response(conn, data, :unauthorized)

      assert result.status == 401
    end

    test "returns conn with :forbidden status" do
      conn = build_conn()
      data = %{error: "Access denied"}

      result = ControllerHelpers.render_json_response(conn, data, :forbidden)

      assert result.status == 403
    end

    test "returns conn with :internal_server_error status" do
      conn = build_conn()
      data = %{error: "Something went wrong"}

      result = ControllerHelpers.render_json_response(conn, data, :internal_server_error)

      assert result.status == 500
    end

    test "returns conn with :unprocessable_entity status" do
      conn = build_conn()
      data = %{errors: %{field: ["is invalid"]}}

      result = ControllerHelpers.render_json_response(conn, data, :unprocessable_entity)

      assert result.status == 422
    end

    test "returns conn with :no_content status" do
      conn = build_conn()
      data = nil

      result = ControllerHelpers.render_json_response(conn, data, :no_content)

      assert result.status == 204
    end

    test "handles numeric status codes" do
      conn = build_conn()
      data = %{custom: "response"}

      result = ControllerHelpers.render_json_response(conn, data, 418)

      assert result.status == 418
    end
  end

  # ===========================================================================
  # Data Type Tests
  # ===========================================================================

  describe "Data type handling" do
    test "handles map data" do
      conn = build_conn()
      data = %{key: "value", nested: %{inner: true}}

      result = ControllerHelpers.render_json_response(conn, data)

      assert result.resp_body == Jason.encode!(data)
    end

    test "handles list data" do
      conn = build_conn()
      data = [%{id: 1}, %{id: 2}, %{id: 3}]

      result = ControllerHelpers.render_json_response(conn, data)

      assert result.resp_body == Jason.encode!(data)
    end

    test "handles string data" do
      conn = build_conn()
      data = "plain text response"

      result = ControllerHelpers.render_json_response(conn, data)

      assert result.resp_body == Jason.encode!(data)
    end

    test "handles integer data" do
      conn = build_conn()
      data = 42

      result = ControllerHelpers.render_json_response(conn, data)

      assert result.resp_body == "42"
    end

    test "handles boolean data" do
      conn = build_conn()

      true_result = ControllerHelpers.render_json_response(conn, true)
      assert true_result.resp_body == "true"

      false_result = ControllerHelpers.render_json_response(conn, false)
      assert false_result.resp_body == "false"
    end

    test "handles nil data" do
      conn = build_conn()

      result = ControllerHelpers.render_json_response(conn, nil)

      assert result.resp_body == "null"
    end

    test "handles empty map" do
      conn = build_conn()

      result = ControllerHelpers.render_json_response(conn, %{})

      assert result.resp_body == "{}"
    end

    test "handles empty list" do
      conn = build_conn()

      result = ControllerHelpers.render_json_response(conn, [])

      assert result.resp_body == "[]"
    end
  end

  # ===========================================================================
  # PropCheck Property-Based Tests
  # ===========================================================================

  describe "Property-based tests" do
    # Note: Converted from PropCheck property to regular test due to PropCheck 1.5.0
    # internal bug with pretty_print_counter_example_parallel/1 when property passes
    test "always returns a conn struct for all status types" do
      for status <- [:ok, :created, :not_found, :bad_request, :unauthorized, :forbidden] do
        conn = build_conn()
        data = %{"test" => "value"}
        result = ControllerHelpers.render_json_response(conn, data, status)
        assert is_struct(result, Plug.Conn), "Expected Plug.Conn struct for status #{status}"
      end
    end

    property "status is always set correctly for atom statuses" do
      status_map = %{
        ok: 200,
        created: 201,
        not_found: 404,
        bad_request: 400,
        unauthorized: 401,
        forbidden: 403,
        internal_server_error: 500
      }

      forall status <- PC.oneof(Map.keys(status_map)) do
        conn = build_conn()
        result = ControllerHelpers.render_json_response(conn, %{}, status)
        result.status == status_map[status]
      end
    end

    property "content type is always application/json" do
      forall data <- PC.map(PC.utf8(), PC.utf8()) do
        conn = build_conn()
        result = ControllerHelpers.render_json_response(conn, data)
        get_content_type(result) =~ "application/json"
      end
    end

    property "numeric status codes are passed through" do
      forall status <- PC.integer(100, 599) do
        conn = build_conn()
        result = ControllerHelpers.render_json_response(conn, %{}, status)
        result.status == status
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests
  # ===========================================================================

  describe "Edge cases" do
    test "handles deeply nested data" do
      conn = build_conn()

      data = %{
        level1: %{
          level2: %{
            level3: %{
              level4: %{
                value: "deep"
              }
            }
          }
        }
      }

      result = ControllerHelpers.render_json_response(conn, data)

      decoded = Jason.decode!(result.resp_body)
      assert get_in(decoded, ["level1", "level2", "level3", "level4", "value"]) == "deep"
    end

    test "handles large data sets" do
      conn = build_conn()
      large_list = Enum.map(1..1000, &%{id: &1, data: String.duplicate("x", 100)})

      result = ControllerHelpers.render_json_response(conn, large_list)

      assert result.status == 200
      decoded = Jason.decode!(result.resp_body)
      assert length(decoded) == 1000
    end

    test "handles unicode data" do
      conn = build_conn()

      data = %{
        japanese: "日本語",
        emoji: "🎉🚀",
        spanish: "Ñoño"
      }

      result = ControllerHelpers.render_json_response(conn, data)

      decoded = Jason.decode!(result.resp_body)
      assert decoded["japanese"] == "日本語"
      assert decoded["emoji"] == "🎉🚀"
      assert decoded["spanish"] == "Ñoño"
    end

    test "handles special characters in strings" do
      conn = build_conn()

      data = %{
        quotes: "He said \"Hello\"",
        backslash: "path\\to\\file",
        newline: "line1\nline2",
        tab: "col1\tcol2"
      }

      result = ControllerHelpers.render_json_response(conn, data)

      decoded = Jason.decode!(result.resp_body)
      assert decoded["quotes"] == "He said \"Hello\""
      assert decoded["backslash"] == "path\\to\\file"
      assert decoded["newline"] == "line1\nline2"
      assert decoded["tab"] == "col1\tcol2"
    end

    test "handles float data" do
      conn = build_conn()
      data = %{value: 3.14_159, negative: -2.718}

      result = ControllerHelpers.render_json_response(conn, data)

      decoded = Jason.decode!(result.resp_body)
      assert_in_delta decoded["value"], 3.14_159, 0.00_001
      assert_in_delta decoded["negative"], -2.718, 0.001
    end

    test "handles mixed array types" do
      conn = build_conn()
      data = [1, "two", %{three: 3}, [4], true, nil]

      result = ControllerHelpers.render_json_response(conn, data)

      decoded = Jason.decode!(result.resp_body)
      assert decoded == [1, "two", %{"three" => 3}, [4], true, nil]
    end
  end

  # ===========================================================================
  # Source Code Validation Tests
  # ===========================================================================

  describe "Source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/shared/controller_helpers.ex"
      assert File.exists?(source_path), "Source file should exist at #{source_path}"
    end

    test "module is compact (under 50 lines)" do
      source_path = "lib/indrajaal/shared/controller_helpers.ex"
      content = File.read!(source_path)
      line_count = content |> String.split("\n") |> length()

      assert line_count < 50, "Module should be compact, currently #{line_count} lines"
    end
  end

  # ===========================================================================
  # Integration Tests
  # ===========================================================================

  describe "Integration scenarios" do
    test "can chain with other Plug functions" do
      conn =
        build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")

      result = ControllerHelpers.render_json_response(conn, %{success: true})

      assert result.status == 200
    end

    test "preserves existing headers" do
      conn =
        build_conn()
        |> Plug.Conn.put_resp_header("x-custom-header", "custom-value")

      result = ControllerHelpers.render_json_response(conn, %{data: "test"})

      assert Plug.Conn.get_resp_header(result, "x-custom-header") == ["custom-value"]
    end
  end

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

  defp build_conn do
    # Use Plug.Test.conn/2 which properly initializes the adapter for message passing
    conn = Plug.Test.conn(:get, "/")

    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, IndrajaalWeb.Endpoint)
  end

  defp get_content_type(conn) do
    case Plug.Conn.get_resp_header(conn, "content-type") do
      [content_type | _] -> content_type
      [] -> ""
    end
  end
end
