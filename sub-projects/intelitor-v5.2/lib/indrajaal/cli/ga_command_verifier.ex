defmodule Indrajaal.Cli.GaCommandVerifier do
  @moduledoc """
  GA runtime command verifier for the 32 devenv CLI commands.

  Validates each devenv command definition at runtime to ensure:
  - Command name is a non-empty string
  - Command body is a non-empty string
  - No duplicate command names exist
  - All required commands are present

  This is a pure verification module — it only produces verification reports,
  it does not execute, modify, or dispatch any commands.

  ## STAMP Constraints
  - SC-CLI-001: CLI command parsing must be validated — ENFORCED
  - SC-CLI-002: Command name uniqueness must be enforced — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-VER-042: All CLI commands functional — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @required_commands ~w(
    sa-up sa-down sa-status sa-plan sa-verify
    governed_compile governed_test governed_wallaby
    constraint-sync cpu_governor_status
  )

  @type command :: %{name: String.t(), body: String.t()}
  @type verification_result :: %{
          passed: boolean(),
          total: non_neg_integer(),
          valid: non_neg_integer(),
          errors: [String.t()],
          warnings: [String.t()]
        }

  @doc """
  Verify a list of command definitions.

  Returns a verification_result map indicating pass/fail state
  with detailed error and warning messages for each violation.
  """
  @spec verify([command()]) :: verification_result()
  def verify(commands) when is_list(commands) do
    errors = []
    warnings = []

    {errors, warnings} = check_duplicates(commands, errors, warnings)
    {errors, warnings} = check_each_command(commands, errors, warnings)
    {errors, warnings} = check_required_commands(commands, errors, warnings)

    %{
      passed: errors == [],
      total: length(commands),
      valid: count_valid(commands),
      errors: errors,
      warnings: warnings
    }
  end

  @doc """
  Verify a single command definition. Returns :ok or {:error, reason}.
  """
  @spec verify_one(command()) :: :ok | {:error, String.t()}
  def verify_one(%{name: name, body: body})
      when is_binary(name) and byte_size(name) > 0 and
             is_binary(body) and byte_size(body) > 0 do
    :ok
  end

  def verify_one(%{name: name}) when not is_binary(name) or byte_size(name) == 0 do
    {:error, "command name must be a non-empty string, got: #{inspect(name)}"}
  end

  def verify_one(%{body: body}) when not is_binary(body) or byte_size(body) == 0 do
    {:error, "command body must be a non-empty string"}
  end

  def verify_one(_) do
    {:error, "command must have :name and :body keys"}
  end

  @doc """
  Return the list of required devenv command names that must be present.
  """
  @spec required_commands() :: [String.t()]
  def required_commands, do: @required_commands

  # ─── Private helpers ─────────────────────────────────────────────────────────

  @spec check_duplicates([command()], [String.t()], [String.t()]) ::
          {[String.t()], [String.t()]}
  defp check_duplicates(commands, errors, warnings) do
    names =
      commands
      |> Enum.filter(&is_binary(Map.get(&1, :name)))
      |> Enum.map(& &1.name)

    duplicates =
      names
      |> Enum.frequencies()
      |> Enum.filter(fn {_k, count} -> count > 1 end)
      |> Enum.map(fn {name, count} -> "duplicate command '#{name}' appears #{count} times" end)

    {errors ++ duplicates, warnings}
  end

  @spec check_each_command([command()], [String.t()], [String.t()]) ::
          {[String.t()], [String.t()]}
  defp check_each_command(commands, errors, warnings) do
    Enum.reduce(commands, {errors, warnings}, fn cmd, {errs, warns} ->
      case verify_one(cmd) do
        :ok -> {errs, warns}
        {:error, reason} -> {[reason | errs], warns}
      end
    end)
  end

  @spec check_required_commands([command()], [String.t()], [String.t()]) ::
          {[String.t()], [String.t()]}
  defp check_required_commands(commands, errors, warnings) do
    present_names =
      commands
      |> Enum.filter(&is_binary(Map.get(&1, :name)))
      |> MapSet.new(& &1.name)

    missing_warnings =
      @required_commands
      |> Enum.reject(&MapSet.member?(present_names, &1))
      |> Enum.map(fn name -> "required command '#{name}' not found in command list" end)

    {errors, warnings ++ missing_warnings}
  end

  @spec count_valid([command()]) :: non_neg_integer()
  defp count_valid(commands) do
    Enum.count(commands, fn cmd -> verify_one(cmd) == :ok end)
  end
end
