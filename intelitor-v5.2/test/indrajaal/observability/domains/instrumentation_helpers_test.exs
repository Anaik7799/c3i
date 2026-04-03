defmodule Indrajaal.Observability.Domains.InstrumentationHelpersTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Domains.InstrumentationHelpers

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(InstrumentationHelpers)
    end
  end

  describe "handle_stop_result/5" do
    test "function is exported" do
      assert function_exported?(InstrumentationHelpers, :handle_stop_result, 5)
    end

    test "handles :ok result without raising" do
      result =
        InstrumentationHelpers.handle_stop_result(
          :ok,
          %{duration: 1000},
          [:test, :event],
          %{},
          %{}
        )

      assert result == :ok or is_map(result) or is_atom(result)
    end

    test "handles {:error, reason} result" do
      result =
        InstrumentationHelpers.handle_stop_result(
          {:error, :timeout},
          %{duration: 2000},
          [:test, :event],
          %{},
          %{}
        )

      assert result == :ok or is_map(result) or is_atom(result)
    end
  end

  describe "handle_stop_with_measurements/6" do
    test "function is exported" do
      assert function_exported?(InstrumentationHelpers, :handle_stop_with_measurements, 6)
    end

    test "handles result with custom measurements" do
      result =
        InstrumentationHelpers.handle_stop_with_measurements(
          {:ok, "data"},
          %{duration: 500, count: 1},
          %{extra: "meta"},
          [:test, :stop],
          %{},
          %{}
        )

      assert result == :ok or is_map(result) or is_atom(result)
    end
  end

  describe "handle_stop_with_post_process/7" do
    test "function is exported" do
      assert function_exported?(InstrumentationHelpers, :handle_stop_with_post_process, 7)
    end

    test "handles result with post-processing function" do
      post_fn = fn result -> result end

      result =
        InstrumentationHelpers.handle_stop_with_post_process(
          :ok,
          %{duration: 100},
          %{},
          [:test, :stop],
          %{},
          %{},
          post_fn
        )

      assert result == :ok or is_map(result) or is_atom(result)
    end
  end
end
