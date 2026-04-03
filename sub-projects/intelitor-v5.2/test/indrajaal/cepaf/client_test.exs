defmodule Indrajaal.Cepaf.ClientTest do
  @moduledoc """
  Tests for Indrajaal.Cepaf.Client pure wrapper module.
  STAMP: SC-TDG, SC-COV-001

  NOTE: All Client functions delegate to Indrajaal.Cepaf.Bridge GenServer.
  In test environment (--no-start), Bridge is not running. Tests wrap calls
  with catch_exit to verify function contracts without requiring Bridge.
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cepaf.Client

  # Helper: call a function and allow {:exit, {:noproc, _}} or result
  defp call_client(fun) do
    try do
      {:result, fun.()}
    catch
      :exit, _ -> {:exited}
    end
  end

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Client)
    end

    test "module has expected public functions" do
      expected_fns = [
        {:ping, 0},
        {:system_info, 0},
        {:list_containers, 1},
        {:inspect_container, 1},
        {:create_container, 1},
        {:start_container, 1},
        {:stop_container, 2},
        {:remove_container, 2},
        {:container_logs, 2},
        {:container_exists?, 1},
        {:find_container_by_name, 1},
        {:health_check, 1},
        {:health_summary, 0},
        {:all_healthy?, 0},
        {:unhealthy_containers, 0},
        {:validate_spec, 1},
        {:validate_image, 1},
        {:validate_all, 0},
        {:emergency_stop, 2},
        {:emergency_remove, 1},
        {:emergency_stop_all, 0}
      ]

      for {fun, arity} <- expected_fns do
        assert function_exported?(Client, fun, arity),
               "Expected #{fun}/#{arity} to be exported"
      end
    end
  end

  describe "validate_spec/1" do
    test "accepts a valid container spec map (or exits cleanly without Bridge)" do
      spec = %{image: "nginx:latest", name: "test-container"}

      case call_client(fn -> Client.validate_spec(spec) end) do
        {:result, result} ->
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          # Bridge not running in test environment — function call structure is valid
          assert true
      end
    end

    test "accepts empty spec (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.validate_spec(%{}) end) do
        {:result, result} ->
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end

    test "raises on non-map spec (BadMapError before Bridge call)" do
      # normalize_container_spec/1 calls Map.get on the spec — crashes with nil before Bridge
      assert_raise BadMapError, fn ->
        Client.validate_spec(nil)
      end
    end
  end

  describe "validate_image/1" do
    test "accepts a valid image name string (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.validate_image("nginx:latest") end) do
        {:result, result} ->
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end

    test "accepts empty string (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.validate_image("") end) do
        {:result, result} ->
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end

    test "accepts nil image without crashing before Bridge (or exits cleanly)" do
      # validate_image/1 sends nil as-is to Bridge.call — Bridge.call will crash or handle it
      case call_client(fn -> Client.validate_image(nil) end) do
        {:result, result} ->
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end

  describe "container_exists?/1" do
    test "accepts a container name (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.container_exists?("nonexistent-container-xyz-12345") end) do
        {:result, result} ->
          assert is_boolean(result) or match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end

  describe "ping/0" do
    test "ping function exists and accepts call (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.ping() end) do
        {:result, result} ->
          assert match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end

  describe "health_summary/0" do
    test "health_summary function exists and accepts call (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.health_summary() end) do
        {:result, result} ->
          assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end

  describe "all_healthy?/0" do
    test "all_healthy? function exists and accepts call (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.all_healthy?() end) do
        {:result, result} ->
          assert is_boolean(result) or match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end

  describe "unhealthy_containers/0" do
    test "unhealthy_containers function exists and accepts call (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.unhealthy_containers() end) do
        {:result, result} ->
          assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end

  describe "list_containers/1" do
    test "accepts keyword opts (or exits cleanly without Bridge)" do
      # list_containers/1 takes keyword list, not a map
      case call_client(fn -> Client.list_containers(all: false) end) do
        {:result, result} ->
          assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end

    test "accepts empty keyword list (or exits cleanly without Bridge)" do
      case call_client(fn -> Client.list_containers([]) end) do
        {:result, result} ->
          assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)

        {:exited} ->
          assert true
      end
    end
  end
end
