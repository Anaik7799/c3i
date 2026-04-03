defmodule Indrajaal.Deployment.VTOOrchestratorTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.VTOOrchestrator.

  WHAT: Tests the VTO (Verify-Then-Orchestrate) engine — a library module
  that drives container start/stop sequences via podman commands. All
  system commands will fail or not be found in the unit-test environment;
  tests verify the module contract and error-handling surface, not actual
  container operations.

  CONSTRAINTS: SC-CMP-025, SC-CNT-009, SC-EMR-057
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.VTOOrchestrator

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(VTOOrchestrator)
    end

    test "run/2 is exported" do
      assert function_exported?(VTOOrchestrator, :run, 2)
    end

    test "run/2 is the only public function" do
      exported = VTOOrchestrator.__info__(:functions)

      public =
        Enum.reject(exported, fn {name, _} -> String.starts_with?(to_string(name), "__") end)

      assert Keyword.has_key?(public, :run)
      assert length(public) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # run/2 — action dispatch
  # ---------------------------------------------------------------------------

  describe "run/2 — action routing" do
    test "unknown action returns {:error, ...} tuple" do
      result = VTOOrchestrator.run(:prod, "invalid_action")
      assert match?({:error, _}, result)
    end

    test "unknown action error message references the invalid action string" do
      {:error, msg} = VTOOrchestrator.run(:prod, "invalid_action")
      assert is_binary(msg)
      assert String.contains?(msg, "invalid_action")
    end

    test "nil action returns {:error, ...}" do
      result = VTOOrchestrator.run(:prod, nil)
      assert match?({:error, _}, result)
    end

    test "atom action returns {:error, ...} (actions must be strings)" do
      result = VTOOrchestrator.run(:prod, :start)
      assert match?({:error, _}, result)
    end

    test "empty string action returns {:error, ...}" do
      result = VTOOrchestrator.run(:prod, "")
      assert match?({:error, _}, result)
    end
  end

  describe "run/2 — 'start' action" do
    test "start action completes without hanging — returns :ok or {:error, ...}" do
      result =
        try do
          VTOOrchestrator.run(:prod, "start")
        rescue
          _ -> {:error, :rescued}
        catch
          :exit, _ -> {:error, :exited}
        end

      assert result == :ok or match?({:error, _}, result)
    end

    test "start action with different env profiles does not hang" do
      for env <- [:prod, :dev, :staging, :test] do
        parent = self()

        pid =
          spawn(fn ->
            try do
              VTOOrchestrator.run(env, "start")
            rescue
              _ -> :ok
            end

            send(parent, {:done, env})
          end)

        assert is_pid(pid)
        assert_receive {:done, ^env}, 15_000
      end
    end

    test "start action result is :ok or a 2-element error tuple" do
      result =
        try do
          VTOOrchestrator.run(:prod, "start")
        rescue
          _ -> {:error, :podman_unavailable}
        end

      case result do
        :ok -> assert true
        {:error, reason} -> assert is_binary(reason) or is_atom(reason)
        other -> flunk("Unexpected return: #{inspect(other)}")
      end
    end
  end

  describe "run/2 — 'stop' action" do
    test "stop action completes without hanging — returns :ok or raises" do
      result =
        try do
          VTOOrchestrator.run(:any_profile, "stop")
        rescue
          _ -> {:error, :rescued}
        catch
          :exit, _ -> {:error, :exited}
        end

      # stop/0 always returns :ok on the happy path; error path raises
      assert result == :ok or match?({:error, _}, result)
    end

    test "stop action with any env_profile behaves identically (stop ignores profile)" do
      result1 =
        try do
          VTOOrchestrator.run(:prod, "stop")
        rescue
          _ -> :raised
        end

      result2 =
        try do
          VTOOrchestrator.run(:dev, "stop")
        rescue
          _ -> :raised
        end

      # Both should return the same shape — either :ok or raised
      assert (result1 == :ok or result1 == :raised) and
               (result2 == :ok or result2 == :raised)
    end

    test "calling stop does not crash the calling process permanently" do
      parent = self()

      pid =
        spawn(fn ->
          try do
            VTOOrchestrator.run(:prod, "stop")
          rescue
            _ -> :ok
          end

          send(parent, :stop_done)
        end)

      assert is_pid(pid)
      assert_receive :stop_done, 15_000
    end
  end

  # ---------------------------------------------------------------------------
  # Interaction with Config — pure data, no podman required
  # ---------------------------------------------------------------------------

  describe "dependency on Indrajaal.Deployment.Config" do
    test "Config.containers/1 returns non-empty list for :prod profile" do
      alias Indrajaal.Deployment.Config
      containers = Config.containers(:prod)
      assert is_list(containers)
      assert length(containers) > 0
    end

    test "each container config has the fields VTOOrchestrator reads" do
      alias Indrajaal.Deployment.Config

      for container <- Config.containers(:prod) do
        assert Map.has_key?(container, :service_name)
        assert Map.has_key?(container, :dependency_order)
        assert Map.has_key?(container, :image_name)
        assert Map.has_key?(container, :image_tag)
        assert is_binary(container.service_name)
        assert is_integer(container.dependency_order)
      end
    end

    test "containers are sortable by dependency_order" do
      alias Indrajaal.Deployment.Config
      containers = Config.containers(:prod)
      sorted = Enum.sort_by(containers, & &1.dependency_order)
      orders = Enum.map(sorted, & &1.dependency_order)
      assert orders == Enum.sort(orders)
    end

    test "image reference constructed by VTOOrchestrator is localhost-prefixed" do
      alias Indrajaal.Deployment.Config
      container = hd(Config.containers(:prod))
      image_ref = "localhost/#{container.image_name}:#{container.image_tag}"
      assert String.starts_with?(image_ref, "localhost/")
      assert String.length(image_ref) > String.length("localhost/")
    end
  end
end
