#!/usr/bin/env elixir

defmodule TestEnvManager do
  @moduledoc """
  SOP v5.11 Containerized Test Execution System.
  Ensures all testing is performed inside Podman containers.
  """

  def run(args) do
    IO.puts("🚀 INTELITOR CONTAINERIZED TEST SUITE")
    IO.puts("========================================")
    
    # 1. Start all containers
    IO.puts("📦 Bringing up test environment stack...")
    case System.cmd("podman-compose", ["up", "-d"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✅ Stack is UP.")
        
        # 2. Wait for Database readiness
        wait_for_postgres()
        
        # 3. Execute tests inside the app container
        IO.puts("🧪 Running tests in 'indrajaal-app-demo'...")
        
        # We enforce MIX_ENV=test and use the internal database URL
        # We use 'postgres' as host because that's the service name in compose
        test_env_vars = [
          {"MIX_ENV", "test"},
          {"DATABASE_URL", "postgres://postgres:postgres@postgres:5433/indrajaal_test"}
        ]
        
        exec_cmd = ["exec"] ++ 
                   Enum.flat_map(test_env_vars, fn {k, v} -> ["-e", "#{k}=#{v}"] end) ++ 
                   ["indrajaal-app-demo", "mix", "test"] ++ args
        
        IO.puts("Executing: podman #{Enum.join(exec_cmd, " ")}")
        
        {_, exit_code} = System.cmd("podman", exec_cmd, into: IO.stream(:stdout, :line))
        
        if exit_code == 0 do
          IO.puts("\n🎉 ALL TESTS PASSED (Containerized)")
        else
          IO.puts("\n❌ TESTS FAILED (Containerized)")
          System.halt(exit_code)
        end
        
      {error, _} ->
        IO.puts("❌ Failed to start test environment:\n#{error}")
        System.halt(1)
    end
  end

  defp wait_for_postgres do
    container_name = "indrajaal-timescaledb-demo"
    IO.write("⏳ Waiting for database readiness...")
    
    # Loop for max 60 seconds
    Enum.reduce_while(1..30, :ok, fn i, _acc ->
      case System.cmd("podman", ["inspect", "--format", "{{.State.Health.Status}}", container_name]) do
        {"healthy\n", 0} ->
          IO.puts("\n✅ Database is healthy.")
          {:halt, :ok}
        _ ->
          IO.write(".")
          Process.sleep(2000)
          {:cont, :ok}
      end
    end)
  end
end

TestEnvManager.run(System.argv())
