#!/usr/bin/env elixir

# SOPv5.1 ENHANCED SCRIPT - simple_web_check.exs
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Updated: 2025-12-21

Mix.install([{:jason, "~> 1.4"}])
require Logger

defmodule SimpleWebCheck do
  @moduledoc """
  Verifies availability of all web pages (Controllers and LiveViews).
  """

  @spec run() :: :ok
  def run do
    IO.puts("""
    🌐 SIMPLE WEB PAGES CHECK
    =========================
    Testing Phoenix server web pages
    """)

    base_url = "http://localhost:4000"

    pages = [
      {"/", "Home Page"},
      {"/dev/dashboard", "Development Dashboard"},
      {"/dev/mailbox", "Mailbox Preview"},
      # Verified Existing
      {"/analytics/stamp-tdg-gde-advanced", "Advanced Analytics"},
      {"/admin/permissions", "Permissions Management"},
      {"/admin/access_control", "Access Control Monitoring"},
      {"/performance", "Performance Dashboard"},
      # Newly Restored
      {"/admin/config", "Config Management"},
      {"/monitoring", "Monitoring Dashboard"},
      {"/analytics/dashboard", "Analytics Dashboard"},
      {"/admin/system-status", "System Status"}
    ]

    results = Enum.map(pages, fn {path, name} ->
      test_page(base_url <> path, name)
    end)

    total = length(results)
    passed = Enum.count(results, fn {_, status} -> status == :ok end)
    failed = total - passed

    IO.puts("\n📊 SUMMARY:")
    IO.puts("Total pages: #{total}")
    IO.puts("Passed: #{passed}")
    IO.puts("Failed: #{failed}")

    if passed == total do
      IO.puts("🎉 All web pages are working!")
    else
      IO.puts("⚠️  Some pages need attention")
      exit({:shutdown, 1})
    end

    IO.puts("\n✅ Web pages check completed")
  end

  defp test_page(url, name) do
    IO.puts("\n📋 Testing: #{name}")
    IO.puts("URL: #{url}")

    case System.cmd("curl", [
      "-s", "-o", "/dev/null", "-w", "%{http_code}",
      "--max-time", "10", url
    ]) do
      {status_code, 0} ->
        code = String.trim(status_code) |> String.to_integer()
        if code >= 200 and code < 400 do
          IO.puts("✅ OK (#{code})")
          {name, :ok}
        else
          IO.puts("❌ ERROR (#{code})")
          {name, :error}
        end

      {error, _} ->
        IO.puts("❌ FAILED: #{error}")
        {name, :failed}
    end
  end
end

SimpleWebCheck.run()