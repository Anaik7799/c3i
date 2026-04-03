defmodule Indrajaal.CLI.CommandVerifier do
  @moduledoc """
  GA runtime command verifier — validates the 32 essential devenv commands.

  Pure module that checks which of the 32 registered devenv commands are available
  in the current `$PATH`. Returns a structured verification report with per-command
  availability, overall pass/fail status, and ANSI-coloured terminal output.

  No side effects other than calling `System.find_executable/1` (read-only OS query).

  ## Design

  The 32 commands fall into 5 categories:
  1. **App lifecycle** — `app`, `app-start`, `app-iex`
  2. **Compile & quality** — `compile`, `compile-strict`, `compile-profile`, `compile-xref`, `quality`, `quality-full`
  3. **Test** — `test`, `test-cover`, `test-e2e`, `governed-compile`, `governed-test`, `governed-wallaby`, `test-sil6`
  4. **CEPAF** — `cepaf-build`, `cepaf-test`, `zenoh-ffi-build`, `constraint-sync`
  5. **SA mesh** — `sa-up`, `sa-down`, `sa-status`, `sa-health`, `sa-verify`, `sa-monitor`,
     `sa-dashboard`, `sa-orchestrate`, `sa-checkpoint`, `sa-mesh`, `sa-mesh-boot`, `sa-mesh-status`

  ## STAMP Compliance
  - SC-CLI-001: CLI commands available
  - SC-CLI-002: Command availability checked at runtime
  - SC-FUNC-001: Module must compile without errors/warnings

  ## Example

      result = CommandVerifier.verify_all()
      IO.puts(CommandVerifier.format_report(result))

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — task d2004f7f |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type command_name :: String.t()
  @type category :: :app | :compile | :test | :cepaf | :sa_mesh

  @type command_spec :: %{
          name: command_name(),
          category: category(),
          critical: boolean()
        }

  @type verification_result :: %{
          name: command_name(),
          category: category(),
          critical: boolean(),
          available: boolean(),
          path: String.t() | nil
        }

  @type report :: %{
          results: [verification_result()],
          total: non_neg_integer(),
          available_count: non_neg_integer(),
          missing_count: non_neg_integer(),
          critical_missing: [command_name()],
          passed: boolean(),
          checked_at: DateTime.t()
        }

  # ANSI escape codes
  @reset "\e[0m"
  @bold "\e[1m"
  @green "\e[32m"
  @yellow "\e[33m"
  @red "\e[31m"
  @cyan "\e[36m"
  @gray "\e[90m"

  # ---------------------------------------------------------------------------
  # Command registry — 32 essential devenv commands
  # ---------------------------------------------------------------------------

  @commands [
    # App lifecycle (3)
    %{name: "app", category: :app, critical: true},
    %{name: "app-start", category: :app, critical: true},
    %{name: "app-iex", category: :app, critical: false},
    # Compile & quality (6)
    %{name: "compile", category: :compile, critical: true},
    %{name: "compile-strict", category: :compile, critical: true},
    %{name: "compile-profile", category: :compile, critical: false},
    %{name: "quality", category: :compile, critical: true},
    %{name: "quality-full", category: :compile, critical: false},
    %{name: "compile-xref", category: :compile, critical: false},
    # Test (7)
    %{name: "test", category: :test, critical: true},
    %{name: "test-cover", category: :test, critical: true},
    %{name: "test-e2e", category: :test, critical: true},
    %{name: "governed-compile", category: :test, critical: true},
    %{name: "governed-test", category: :test, critical: true},
    %{name: "governed-wallaby", category: :test, critical: false},
    %{name: "test-sil6", category: :test, critical: true},
    # CEPAF (4)
    %{name: "cepaf-build", category: :cepaf, critical: true},
    %{name: "cepaf-test", category: :cepaf, critical: true},
    %{name: "zenoh-ffi-build", category: :cepaf, critical: false},
    %{name: "constraint-sync", category: :cepaf, critical: true},
    # SA mesh (12)
    %{name: "sa-up", category: :sa_mesh, critical: true},
    %{name: "sa-down", category: :sa_mesh, critical: true},
    %{name: "sa-status", category: :sa_mesh, critical: true},
    %{name: "sa-health", category: :sa_mesh, critical: true},
    %{name: "sa-verify", category: :sa_mesh, critical: true},
    %{name: "sa-monitor", category: :sa_mesh, critical: false},
    %{name: "sa-dashboard", category: :sa_mesh, critical: false},
    %{name: "sa-orchestrate", category: :sa_mesh, critical: false},
    %{name: "sa-checkpoint", category: :sa_mesh, critical: true},
    %{name: "sa-mesh", category: :sa_mesh, critical: true},
    %{name: "sa-mesh-boot", category: :sa_mesh, critical: false},
    %{name: "sa-mesh-status", category: :sa_mesh, critical: false}
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Verify all 32 registered devenv commands and return a structured `report()`.

  Uses `System.find_executable/1` to check path availability.
  """
  @spec verify_all() :: report()
  def verify_all do
    results = Enum.map(@commands, &verify_command/1)

    available_count = Enum.count(results, & &1.available)
    missing = Enum.reject(results, & &1.available)
    critical_missing = missing |> Enum.filter(& &1.critical) |> Enum.map(& &1.name)

    %{
      results: results,
      total: length(results),
      available_count: available_count,
      missing_count: length(missing),
      critical_missing: critical_missing,
      passed: critical_missing == [],
      checked_at: DateTime.utc_now()
    }
  end

  @doc """
  Verify a single command by name.

  Returns a `verification_result()` map. Returns `nil` if the command is not in
  the registered command list.
  """
  @spec verify_one(command_name()) :: verification_result() | nil
  def verify_one(name) when is_binary(name) do
    case Enum.find(@commands, &(&1.name == name)) do
      nil -> nil
      spec -> verify_command(spec)
    end
  end

  @doc """
  Return the list of all registered command specs (read-only, no verification).
  """
  @spec registered_commands() :: [command_spec()]
  def registered_commands, do: @commands

  @doc """
  Format a `report()` as a multi-line ANSI-coloured terminal string.
  """
  @spec format_report(report()) :: String.t()
  def format_report(report) when is_map(report) do
    status_line =
      if report.passed do
        "#{@green}PASS#{@reset}"
      else
        "#{@red}FAIL#{@reset}  (#{length(report.critical_missing)} critical missing)"
      end

    header = "#{@bold}#{@cyan}── Command Verifier Report ────────────────────#{@reset}"
    summary = "Status  #{status_line}  |  #{report.available_count}/#{report.total} available"
    ts = Calendar.strftime(report.checked_at, "%H:%M:%S")
    footer = "#{@gray}Checked  #{ts} UTC#{@reset}"

    category_lines =
      report.results
      |> Enum.group_by(& &1.category)
      |> Enum.map(fn {cat, results} ->
        cat_str = category_label(cat)
        rows = Enum.map(results, &format_result_row/1)
        ["  #{@bold}#{cat_str}#{@reset}"] ++ rows
      end)
      |> List.flatten()

    missing_lines =
      if report.critical_missing == [] do
        []
      else
        names = Enum.join(report.critical_missing, ", ")
        ["#{@red}Critical missing:  #{names}#{@reset}"]
      end

    ([header, summary] ++ category_lines ++ missing_lines ++ [footer])
    |> Enum.join("\n")
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp verify_command(%{name: name, category: cat, critical: crit}) do
    {available, path} =
      case System.find_executable(name) do
        nil -> {false, nil}
        found -> {true, found}
      end

    %{name: name, category: cat, critical: crit, available: available, path: path}
  end

  defp format_result_row(%{name: name, available: true, critical: crit}) do
    marker = if crit, do: "★", else: "·"
    "    #{@green}#{marker}  #{name}#{@reset}"
  end

  defp format_result_row(%{name: name, available: false, critical: true}) do
    "    #{@red}✗  #{name}  (MISSING — critical)#{@reset}"
  end

  defp format_result_row(%{name: name, available: false, critical: false}) do
    "    #{@yellow}○  #{name}  (missing)#{@reset}"
  end

  defp category_label(:app), do: "App Lifecycle"
  defp category_label(:compile), do: "Compile & Quality"
  defp category_label(:test), do: "Test"
  defp category_label(:cepaf), do: "CEPAF"
  defp category_label(:sa_mesh), do: "SA Mesh"
end
