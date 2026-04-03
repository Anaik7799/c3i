defmodule Intelitor.Integration.ContainerArchitectureTest do
  @moduledoc """
  Integration tests for SOPv5.11 3-Container Architecture.
  Validates:
  1. intelitor-db (Database)
  2. intelitor-app (Application)
  3. intelitor-obs (Observability)
  """
  use ExUnit.Case, async: false

  describe "3-Container Model Validation" do
    @describetag :integration
    @describetag :container

    test "podman-compose.yml defines correct 3 containers" do
      # Read compose file
      {:ok, content} = File.read("podman-compose.yml")

      assert String.contains?(content, "intelitor-db:")
      assert String.contains?(content, "intelitor-app:")
      assert String.contains?(content, "intelitor-obs:")

      # Verify obsolete containers are NOT present
      refute String.contains?(content, "signoz-clickhouse:")
      refute String.contains?(content, "signoz-query-service:")
    end

    test "operational scripts reference correct containers" do
      # Check dev-start script
      {:ok, dev_script} = File.read("scripts/env/dev-start.exs")
      assert String.contains?(dev_script, "intelitor-db")
      assert String.contains?(dev_script, "intelitor-obs")

      # Check demo-start script
      {:ok, demo_script} = File.read("scripts/env/demo-start.exs")
      assert String.contains?(demo_script, "podman-compose")
    end
  end

  describe "Container Health Checks (Simulation)" do
    @describetag :integration
    @describetag :container_health

    test "containers have health check definitions" do
      {:ok, content} = File.read("podman-compose.yml")

      # Check for healthcheck blocks
      assert Regex.scan(~r/healthcheck:/, content) |> length() == 3
    end
  end
end
