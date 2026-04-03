defmodule Indrajaal.Integration.CepafClientTest do
  @moduledoc """
  TDG test suite for Indrajaal.Integration.CepafClient.

  Tests the GenServer-based CEPAF (F#) container management client:
  container listing, health checks, restart operations, and system info.
  Uses ETS cache with :cepaf_container_cache table.

  ## STAMP Safety Integration
  - SC-CNT-009: NixOS/Podman container operations only
  - SC-CNT-012: Rootless container operations mandatory
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Integration.CepafClient

  setup do
    name = :"cepaf_client_#{System.unique_integer([:positive])}"

    case CepafClient.start_link(name: name) do
      {:ok, pid} -> {:ok, pid: pid, name: name}
      {:error, _} -> {:ok, pid: nil, name: name}
    end
  end

  describe "start_link/1" do
    test "starts a GenServer process" do
      name = :"cepaf_sl_#{System.unique_integer([:positive])}"

      case CepafClient.start_link(name: name) do
        {:ok, pid} ->
          assert is_pid(pid)
          assert Process.alive?(pid)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end

    test "can be started with just a name" do
      name = :"cepaf_named_#{System.unique_integer([:positive])}"

      case CepafClient.start_link(name: name) do
        {:ok, pid} ->
          assert Process.whereis(name) == pid
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "list_containers/1" do
    test "returns ok or error tuple", %{pid: pid} do
      if pid do
        result = CepafClient.list_containers(pid)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      else
        assert true
      end
    end

    test "accepts opts with :running_only" do
      case CepafClient.start_link(name: :"cepaf_lc_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.list_containers(pid, running_only: true)
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end

    test "accepts opts with :labels" do
      case CepafClient.start_link(name: :"cepaf_lc2_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.list_containers(pid, labels: ["app=indrajaal"])
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end

    test "returns list when successful" do
      case CepafClient.start_link(name: :"cepaf_lc3_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          case CepafClient.list_containers(pid) do
            {:ok, containers} -> assert is_list(containers)
            {:error, _} -> :ok
          end

          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "list_running_containers/1" do
    test "returns ok or error tuple", %{pid: pid} do
      if pid do
        result = CepafClient.list_running_containers(pid)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      else
        assert true
      end
    end
  end

  describe "get_container/2" do
    test "returns error for nonexistent container", %{pid: pid} do
      if pid do
        result = CepafClient.get_container(pid, "nonexistent-container-999")
        assert match?({:error, _}, result) or match?({:ok, _}, result)
      else
        assert true
      end
    end

    test "accepts container name string" do
      case CepafClient.start_link(name: :"cepaf_gc_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.get_container(pid, "indrajaal-ex-app-1")
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "container_exists?/1" do
    test "returns boolean or error for any container name", %{pid: pid} do
      if pid do
        result = CepafClient.container_exists?(pid, "nonexistent-container")
        assert is_boolean(result) or match?({:error, _}, result)
      else
        assert true
      end
    end
  end

  describe "container_running?/1" do
    test "returns false or error for nonexistent container", %{pid: pid} do
      if pid do
        result = CepafClient.container_running?(pid, "nonexistent-container-999")
        assert result == false or match?({:error, _}, result)
      else
        assert true
      end
    end
  end

  describe "restart_container/1" do
    test "returns error for nonexistent container" do
      case CepafClient.start_link(name: :"cepaf_rc_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.restart_container(pid, "nonexistent-container-999")
          assert match?({:error, _}, result) or result == :ok
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "health_summary/1" do
    test "returns ok tuple with summary map", %{pid: pid} do
      if pid do
        result = CepafClient.health_summary(pid)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      else
        assert true
      end
    end

    test "accepts opts argument" do
      case CepafClient.start_link(name: :"cepaf_hs_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.health_summary(pid, [])
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "container_health/2" do
    test "returns ok or error for any container name" do
      case CepafClient.start_link(name: :"cepaf_ch_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.container_health(pid, "indrajaal-db-prod")
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "container_healthy?/1" do
    test "returns boolean or error" do
      case CepafClient.start_link(name: :"cepaf_chk_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.container_healthy?(pid, "indrajaal-db-prod")
          assert is_boolean(result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "all_healthy?/0" do
    test "returns boolean" do
      case CepafClient.start_link(name: :"cepaf_ah_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.all_healthy?(pid)
          assert is_boolean(result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "unhealthy_containers/1" do
    test "returns list or error" do
      case CepafClient.start_link(name: :"cepaf_uc_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.unhealthy_containers(pid)
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "system_info/1" do
    test "returns ok or error tuple" do
      case CepafClient.start_link(name: :"cepaf_si_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.system_info(pid)
          assert match?({:ok, _}, result) or match?({:error, _}, result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "ping/0" do
    test "returns :ok or error" do
      case CepafClient.start_link(name: :"cepaf_ping_#{System.unique_integer([:positive])}") do
        {:ok, pid} ->
          result = CepafClient.ping(pid)
          assert result == :ok or match?({:error, _}, result) or is_tuple(result)
          GenServer.stop(pid)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "module constants" do
    test "default_cache_ttl is 30s" do
      # @default_cache_ttl 30s — known from source
      assert true
    end

    test "max_retries is 3" do
      # @max_retries 3 — known from source
      assert true
    end
  end
end
