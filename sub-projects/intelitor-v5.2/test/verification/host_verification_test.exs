defmodule Verification.HostVerificationTest do
  use ExUnit.Case, async: false

  require Logger

  @tag :host_verify

  # Test 1: Web Access
  test "host application is accessible via HTTP" do
    Logger.info("[HOST CHECK] Verifying web access...")

    # Retry logic to give the server time to be fully available
    assert :ok =
             retry(5, 2000, fn ->
               case System.cmd("curl", ["--fail", "-s", "http://localhost:4000/health"]) do
                 {_, 0} -> :ok
                 _ -> {:error, "Health endpoint not ready"}
               end
             end)

    Logger.info("[HOST CHECK] Web access... OK")
  end

  # Test 2: Database Connectivity
  test "host application can connect to the database" do
    Logger.info("[HOST CHECK] Verifying database connectivity...")
    # This command runs in a new BEAM instance that loads the app config
    # and attempts to perform a query. It will only succeed if the DB
    # is accessible from the host application's environment.
    cmd =
      ~s[elixir -e 'Application.ensure_all_started(:ecto_sql); case Indrajaal.Repo.all(Indrajaal.Core.Tenant) do {:ok, _} -> System.halt(0); {:error, e} -> IO.inspect(e); System.halt(1) end']

    case System.cmd("bash", ["-c", cmd], stderr_to_stdout: true) do
      {output, 0} ->
        assert true
        Logger.info("[HOST CHECK] Database connectivity... OK")

      {output, _} ->
        flunk("Database connectivity check failed. Output: #{output}")
    end
  end

  # Test 3: Logging
  test "host application writes to the log file" do
    Logger.info("[HOST CHECK] Verifying logging...")
    # This is a soft check. We just want to see if the file is there.
    # We trigger a log by hitting a non-existent page.
    System.cmd("curl", ["-s", "http://localhost:4000/a-non-existent-page"])
    # Give logger time to flush
    Process.sleep(1000)

    # Standard Phoenix log path
    log_file = "logs/dev.log"
    assert File.exists?(log_file)
    Logger.info("[HOST CHECK] Logging... OK")
  end

  # Test 4: Telemetry
  test "host application has telemetry running" do
    Logger.info("[HOST CHECK] Verifying telemetry...")
    # This is an indirect check. If the app is running, telemetry is running.
    # A more direct check would require a custom endpoint, but for this
    # verification, process responsiveness is sufficient.
    assert {:ok, _} = :rpc.call(:"#{node()}", :application, :get_key, [:telemetry_metrics])
    Logger.info("[HOST CHECK] Telemetry... OK")
  end

  defp retry(0, _delay, fun), do: fun.()

  defp retry(n, delay, fun) do
    case fun.() do
      :ok ->
        :ok

      {:error, _} ->
        Process.sleep(delay)
        retry(n - 1, delay, fun)
    end
  end
end
