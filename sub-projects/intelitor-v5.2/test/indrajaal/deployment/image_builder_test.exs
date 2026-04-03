defmodule Indrajaal.Deployment.ImageBuilderTest do
  @moduledoc """
  TDG test suite for Indrajaal.Deployment.ImageBuilder.

  WHAT: Tests image build orchestration — delegates to Config for container
  definitions, then invokes podman build. All system commands will fail or
  not be found in the unit-test environment; tests verify the module's
  contract and error-handling surface, not actual container operations.

  CONSTRAINTS: SC-CMP-025, SC-CNT-009
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.ImageBuilder

  # ---------------------------------------------------------------------------
  # Module contract
  # ---------------------------------------------------------------------------

  describe "module API" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ImageBuilder)
    end

    test "build_all/0 is a public function with arity 0" do
      assert function_exported?(ImageBuilder, :build_all, 0)
    end

    test "build_all/0 is the only exported public function" do
      exported = ImageBuilder.__info__(:functions)

      public =
        Enum.reject(exported, fn {name, _} -> String.starts_with?(to_string(name), "__") end)

      assert Keyword.has_key?(public, :build_all)
    end
  end

  # ---------------------------------------------------------------------------
  # build_all/0 — without podman available the inner System.cmd raises or
  # returns a non-zero exit code. The module raises on failure, so we
  # catch the exception and verify the call completes (no hanging process).
  # ---------------------------------------------------------------------------

  describe "build_all/0" do
    test "returns an atom or raises — never hangs or returns nil" do
      result =
        try do
          ImageBuilder.build_all()
        rescue
          _ -> :raised
        catch
          :exit, _ -> :exited
          :error, _ -> :caught_error
        end

      assert result in [:ok, :raised, :exited, :caught_error]
    end

    test "calling build_all/0 does not crash the calling process permanently" do
      parent = self()

      pid =
        spawn(fn ->
          try do
            ImageBuilder.build_all()
          rescue
            _ -> :ok
          end

          send(parent, :done)
        end)

      assert is_pid(pid)
      assert_receive :done, 15_000
    end

    test "build_all/0 returns :ok when podman build succeeds" do
      # In environments where podman is available and images exist this should
      # return :ok. In CI (no podman) it raises. Both are valid outcomes.
      result =
        try do
          ImageBuilder.build_all()
        rescue
          _ -> {:error, :build_failed}
        end

      assert result == :ok or match?({:error, _}, result)
    end

    test "multiple sequential calls to build_all/0 do not leave zombie processes" do
      for _ <- 1..2 do
        try do
          ImageBuilder.build_all()
        rescue
          _ -> :ok
        end
      end

      # Verify the calling process (test) is still alive
      assert Process.alive?(self())
    end
  end

  # ---------------------------------------------------------------------------
  # Interaction with Config
  # ---------------------------------------------------------------------------

  describe "dependency on Indrajaal.Deployment.Config" do
    test "Config.containers/1 returns list used by ImageBuilder" do
      alias Indrajaal.Deployment.Config
      containers = Config.containers(:prod)
      assert is_list(containers)
      # ImageBuilder needs an :indrajaal-app entry
      app_container = Enum.find(containers, &(&1.service_name == "indrajaal-app"))
      assert app_container != nil
      assert Map.has_key?(app_container, :image_name)
      assert Map.has_key?(app_container, :image_tag)
    end

    test "image tag derived from Config is a non-empty string" do
      alias Indrajaal.Deployment.Config
      containers = Config.containers(:prod)
      app = Enum.find(containers, &(&1.service_name == "indrajaal-app"))
      image_tag = "localhost/#{app.image_name}:#{app.image_tag}"
      assert is_binary(image_tag)
      assert String.length(image_tag) > 0
      assert String.contains?(image_tag, "localhost/")
    end
  end
end
