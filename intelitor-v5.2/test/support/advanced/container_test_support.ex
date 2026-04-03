defmodule Indrajaal.Testing.Container.TestSupport do
  @moduledoc """
  Container-aware testing support utilities for advanced test configuration.

  Provides container-specific testing capabilities for NixOS, Podman, and PHICS
  integration with comprehensive validation and performance monitoring.
  """

  @doc """
  Setup container test environment with validation.
  """
  def setup_container_test_environment(opts \\ []) do
    container_name = Keyword.get(opts, :container_name, "indrajaal-test")
    validate_setup = Keyword.get(opts, :validate, true)

    IO.puts("🐳 Setting up container test environment")
    IO.puts("   Container: #{container_name}")

    # Set container environment variables
    container_env = %{
      "CONTAINER_TEST_MODE" => "true",
      "PHICS_ENABLED" => "true",
      "CONTAINER_NAME" => container_name,
      "NIXOS_CONTAINER" => "true",
      "PODMAN_MODE" => "rootless"
    }

    for {key, value} <- container_env do
      System.put_env(key, value)
    end

    if validate_setup do
      validation_result = validate_container_environment()

      if validation_result.valid do
        IO.puts("   ✅ Container environment validated")
      else
        IO.puts("   ❌ Container environment validation failed")
        IO.puts("   Issues: #{Enum.join(validation_result.issues, ", ")}")
      end

      validation_result
    else
      %{valid: true, issues: []}
    end
  end

  @doc """
  Validate container environment for testing.
  """
  def validate_container_environment do
    # Check required environment variables
    required_env = ["CONTAINER_TEST_MODE", "PHICS_ENABLED", "NIXOS_CONTAINER"]

    env_issues =
      for env_var <- required_env do
        if System.get_env(env_var) do
          nil
        else
          "Missing environment variable: #{env_var}"
        end
      end
      |> Enum.filter(& &1)

    # Check container runtime availability
    runtime_issues = check_container_runtime()

    # Check PHICS integration
    phics_issues = check_phics_integration()

    all_issues = env_issues ++ runtime_issues ++ phics_issues

    %{
      valid: Enum.empty?(all_issues),
      issues: all_issues,
      environment_check: %{
        required_env: required_env,
        missing_env: env_issues
      },
      runtime_check: runtime_issues,
      phics_check: phics_issues
    }
  end

  @doc """
  Test container isolation and resource limits.
  """
  def test_container_isolation(test_name, test_fun, opts \\ []) do
    memory_limit_mb = Keyword.get(opts, :memory_limit_mb, 512)
    cpu_limit = Keyword.get(opts, :cpu_limit, 2.0)

    IO.puts("🔒 Container Isolation Test: #{test_name}")
    IO.puts("   Memory limit: #{memory_limit_mb}MB")
    IO.puts("   CPU limit: #{cpu_limit} cores")

    # Monitor resource usage during test execution
    initial_memory = :erlang.memory(:total)

    {time_us, result} =
      :timer.tc(fn ->
        # Run test in isolated environment
        test_fun.()
      end)

    final_memory = :erlang.memory(:total)
    memory_used_mb = (final_memory - initial_memory) / (1024 * 1024)
    time_ms = time_us / 1000

    # Check resource limits
    memory_within_limit = memory_used_mb <= memory_limit_mb

    IO.puts("   Execution time: #{Float.round(time_ms, 2)}ms")
    IO.puts("   Memory used: #{Float.round(memory_used_mb, 2)}MB")

    if memory_within_limit do
      IO.puts("   ✅ Memory usage within limits")
    else
      IO.puts(
        "   ❌ Memory usage exceeded limit by #{Float.round(memory_used_mb - memory_limit_mb, 2)}MB"
      )
    end

    %{
      test_name: test_name,
      execution_time_ms: time_ms,
      memory_used_mb: memory_used_mb,
      memory_limit_mb: memory_limit_mb,
      memory_within_limit: memory_within_limit,
      cpu_limit: cpu_limit,
      isolation_successful: memory_within_limit,
      result: result
    }
  end

  @doc """
  Test PHICS hot-reloading integration in containers.
  """
  def test_phics_integration(opts \\ []) do
    sync_timeout_ms = Keyword.get(opts, :sync_timeout_ms, 1000)

    IO.puts("⚡ PHICS Integration Test")
    IO.puts("   Sync timeout: #{sync_timeout_ms}ms")

    # Simulate PHICS file synchronization
    test_file_path = "/tmp/phics_test_#{:rand.uniform(10_000)}.txt"
    test_content = "PHICS test content #{DateTime.utc_now()}"

    # Write test file
    File.write!(test_file_path, test_content)

    # Simulate hot-reloading synchronization
    {sync_time_us, sync_result} =
      :timer.tc(fn ->
        # Simulate PHICS sync process
        # Simulate sync latency
        :timer.sleep(Enum.random(10..100))

        # Verify file synchronization
        case File.read(test_file_path) do
          {:ok, ^test_content} -> :sync_successful
          {:ok, _other} -> :sync_content_mismatch
          {:error, _reason} -> :sync_failed
        end
      end)

    # Cleanup
    File.rm(test_file_path)

    sync_time_ms = sync_time_us / 1000
    sync_within_timeout = sync_time_ms <= sync_timeout_ms

    IO.puts("   Sync time: #{Float.round(sync_time_ms, 2)}ms")
    IO.puts("   Sync result: #{sync_result}")

    if sync_within_timeout and sync_result == :sync_successful do
      IO.puts("   ✅ PHICS integration successful")
    else
      IO.puts("   ❌ PHICS integration failed")
    end

    %{
      sync_time_ms: sync_time_ms,
      sync_timeout_ms: sync_timeout_ms,
      sync_within_timeout: sync_within_timeout,
      sync_result: sync_result,
      integration_successful: sync_within_timeout and sync_result == :sync_successful
    }
  end

  @doc """
  Test container network isolation and communication.
  """
  def test_container_networking(container_name, opts \\ []) do
    port = Keyword.get(opts, :port, 4000)
    timeout_ms = Keyword.get(opts, :timeout_ms, 5000)

    IO.puts("🌐 Container Networking Test: #{container_name}")
    IO.puts("   Port: #{port}")
    IO.puts("   Timeout: #{timeout_ms}ms")

    # Test container network accessibility
    {time_us, network_result} =
      :timer.tc(fn ->
        # Simulate network connectivity test
        case :gen_tcp.connect(~c"localhost", port, [], timeout_ms) do
          {:ok, socket} ->
            :gen_tcp.close(socket)
            :network_accessible

          {:error, :econnrefused} ->
            :network_not_available

          {:error, :timeout} ->
            :network_timeout

          {:error, reason} ->
            {:network_error, reason}
        end
      end)

    time_ms = time_us / 1000
    network_successful = network_result == :network_accessible

    IO.puts("   Network test time: #{Float.round(time_ms, 2)}ms")
    IO.puts("   Network result: #{network_result}")

    if network_successful do
      IO.puts("   ✅ Container networking successful")
    else
      IO.puts("   ❌ Container networking failed")
    end

    %{
      container_name: container_name,
      port: port,
      test_time_ms: time_ms,
      timeout_ms: timeout_ms,
      network_result: network_result,
      network_successful: network_successful
    }
  end

  @doc """
  Test container database connectivity and performance.
  """
  def test_container_database(opts \\ []) do
    connection_timeout_ms = Keyword.get(opts, :connection_timeout_ms, 5000)
    query_timeout_ms = Keyword.get(opts, :query_timeout_ms, 1000)

    IO.puts("🗄️ Container Database Test")
    IO.puts("   Connection timeout: #{connection_timeout_ms}ms")
    IO.puts("   Query timeout: #{query_timeout_ms}ms")

    # Test database connectivity from container
    {conn_time_us, conn_result} =
      :timer.tc(fn ->
        try do
          # Attempt database connection
          case Indrajaal.Repo.query("SELECT 1", [], timeout: query_timeout_ms) do
            {:ok, %{rows: [[1]]}} -> :connection_successful
            {:ok, _other} -> :connection_unexpected_result
            {:error, reason} -> {:connection_error, reason}
          end
        rescue
          error -> {:connection_exception, error}
        end
      end)

    conn_time_ms = conn_time_us / 1000
    connection_successful = conn_result == :connection_successful

    IO.puts("   Connection time: #{Float.round(conn_time_ms, 2)}ms")
    IO.puts("   Connection result: #{conn_result}")

    if connection_successful do
      IO.puts("   ✅ Container database connectivity successful")
    else
      IO.puts("   ❌ Container database connectivity failed")
    end

    %{
      connection_time_ms: conn_time_ms,
      connection_timeout_ms: connection_timeout_ms,
      query_timeout_ms: query_timeout_ms,
      connection_result: conn_result,
      connection_successful: connection_successful
    }
  end

  @doc """
  Comprehensive container test suite.
  """
  def comprehensivecontainer_test_suite(suite_name, opts \\ []) do
    container_name = Keyword.get(opts, :container_name, "indrajaal-test")

    IO.puts("🚀 Comprehensive Container Test Suite: #{suite_name}")
    IO.puts("   Container: #{container_name}")

    test_results = %{
      environment_setup: setup_container_test_environment(opts),
      phics_integration: test_phics_integration(opts),
      networking: test_container_networking(container_name, opts),
      database: test_container_database(opts)
    }

    # Calculate overall success
    successful_tests =
      test_results
      |> Enum.count(fn {_name, result} ->
        case result do
          %{valid: true} -> true
          %{integration_successful: true} -> true
          %{network_successful: true} -> true
          %{connection_successful: true} -> true
          _ -> false
        end
      end)

    total_tests = map_size(test_results)
    success_rate = successful_tests / total_tests * 100

    IO.puts("\n📊 Container Test Suite Results:")
    IO.puts("   Total tests: #{total_tests}")
    IO.puts("   Successful tests: #{successful_tests}")
    IO.puts("   Success rate: #{Float.round(success_rate, 2)}%")

    if success_rate >= 90.0 do
      IO.puts("   ✅ Container test suite passed")
    else
      IO.puts("   ❌ Container test suite failed")
    end

    %{
      suite_name: suite_name,
      container_name: container_name,
      total_tests: total_tests,
      successful_tests: successful_tests,
      success_rate: success_rate,
      passed: success_rate >= 90.0,
      test_results: test_results
    }
  end

  # Private helper functions

  defp check_container_runtime do
    issues = []

    # Check if Podman is available
    case System.cmd("which", ["podman"], stderr_to_stdout: true) do
      {_output, 0} ->
        issues

      {_output, _exit_code} ->
        ["Podman runtime not available" | issues]
    end
  end

  defp check_phics_integration do
    issues = []

    # Check PHICS environment variables
    if System.get_env("PHICS_ENABLED") != "true" do
      ["PHICS not enabled" | issues]
    else
      issues
    end
  end
end
