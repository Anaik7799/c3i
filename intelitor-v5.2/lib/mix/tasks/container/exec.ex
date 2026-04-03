defmodule Mix.Tasks.Container.Exec do
  @moduledoc """
  Executes commands inside containers.

  Runs commands in the __context of a running container, with support for
  interactive sessions, environment variables, and working directory control.

  ## Usage

      mix container.exec CONTAINER_NAME COMMAND [ARGS] [OPTIONS]
      mix container.exec app ls -la
      mix container.exec app iex -S mix

  ## Options

    * `--interactive` - Keep STDIN open and allocate TTY
    * `--env KEY = VALUE` - Set environment variables
    * `--workdir DIR` - Working directory inside container
    * `--user USER` - Username or UID to run as
    * `--detach` - Run command in background
    * `--verbose` - Show detailed output
    * `--agent - mode` - Enable agent coordination

  ## Examples

      # List files in container
      mix container.exec app ls -la /app

      # Interactive shell
      mix container.exec app --interactive bash

      # Run IEx session
      mix container.exec app --interactive iex -S mix

      # Execute with environment variables
      mix container.exec app --env MIX_ENV = prod mix compile

  Created: 2025 - 08 - 05 17:48:00 CEST
  Framework: SOPv5.1 + Container Command Execution
  """

  use Mix.Task
  import Mix.Tasks.Container

  @shortdoc "Execute commands in containers"

  @impl Mix.Task
  @spec run(any()) :: any()
  def run(args) do
    {opts, remaining_args} = parse_exec_options(args)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      return()
    end

    if remaining_args == [] do
      Mix.raise(
        "Error: Container name and command __required\nUsage: mix container.exec <name> <command>"
      )
    end

    [container_name | command_parts] = remaining_args

    if command_parts == [] do
      Mix.raise("Error: Command __required\nUsage: mix container.exec <name> <command>")
    end

    validate_container_runtime!()

    # Check if container exists and is running
    case get_container_info(container_name) do
      {:ok, info} ->
        state = get_in(info, ["State", "Status"])

        if state == "running" do
          # Log to Claude
          ensure_claude_logging("exec", %{
            container: container_name,
            command: Enum.join(command_parts, " "),
            options: opts
          })

          # Execute command
          execute_in_container(container_name, command_parts, opts)
        else
          Mix.shell().error("Error: Container not running: #{container_name}")
          Mix.shell().info("Info: Container status: #{state}")
        end

      {:error, :not_found} ->
        Mix.shell().error("Error: Container not found: #{container_name}")
    end
  end

  @spec parse_exec_options(term()) :: term()
  defp parse_exec_options(args) do
    {opts, remaining_args, _} =
      OptionParser.parse(args,
        switches: [
          interactive: :boolean,
          env: :keep,
          workdir: :string,
          user: :string,
          detach: :boolean,
          verbose: :boolean,
          agent_mode: :boolean,
          help: :boolean
        ],
        aliases: [
          i: :interactive,
          e: :env,
          w: :workdir,
          u: :user,
          d: :detach
        ]
      )

    {opts, remaining_args}
  end

  defp execute_in_container(name, command_parts, opts) do
    # Build exec command
    exec_args = build_exec_command(opts)

    # Add container name and command
    args = exec_args ++ [name] ++ command_parts

    # Show command being executed if verbose
    if opts[:verbose] do
      Mix.shell().info("[LAUNCH] Executing: podman #{Enum.join(args, " ")}")
    end

    # Execute based on mode
    cond do
      opts[:interactive] ->
        execute_interactive(args, opts)

      opts[:detach] ->
        execute_detached(name, args, opts)

      true ->
        execute_standard(args, opts)
    end
  end

  @spec build_exec_command(term()) :: term()
  defp build_exec_command(opts) do
    args = ["exec"]

    # Add interactive flags
    args =
      if opts[:interactive] do
        args ++ ["-it"]
      else
        args
      end

    # Add detach flag
    args =
      if opts[:detach] do
        args ++ ["-d"]
      else
        args
      end

    # Add environment variables
    args =
      if opts[:env] do
        env_args =
          opts
          |> Keyword.get_values(:env)
          |> Enum.flat_map(fn env -> ["--env", env] end)

        args ++ env_args
      else
        args
      end

    # Add working directory
    args =
      if opts[:workdir] do
        args ++ ["--workdir", opts[:workdir]]
      else
        args
      end

    # Add user
    args =
      if opts[:user] do
        args ++ ["--user", opts[:user]]
      else
        args
      end

    args
  end

  @spec execute_interactive(term(), term()) :: term()
  defp execute_interactive(args, _opts) do
    # For interactive commands, we need to use the native system call
    # to properly handle TTY allocation
    case System.cmd("podman", args, into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {_, code} ->
        # Non - zero exit codes are normal for interactive sessions
        if code == 130 do
          # Ctrl + C was pressed
          Mix.shell().info("\n🛑 Session terminated")
        else
          Mix.shell().error("\nWarning:  Command exited with code: #{code}")
        end
    end
  end

  defp execute_detached(name, args, _opts) do
    case System.cmd("podman", args, stderr_to_stdout: true) do
      {output, 0} ->
        exec_id = String.trim(output)
        Mix.shell().info("Success: Command started in background")
        Mix.shell().info("🆔 Exec ID: #{String.slice(exec_id, 0, 12)}")
        Mix.shell().info("Info: Use 'podman logs #{name}' to view output")

      {error, code} ->
        Mix.shell().error("Error: Failed to execute command (exit code: #{code})")
        if error != "", do: Mix.shell().error(error)
    end
  end

  @spec execute_standard(term(), term()) :: term()
  defp execute_standard(args, opts) do
    # For non - interactive commands, capture output based on verbosity
    if opts[:verbose] do
      # Stream output directly
      case run_podman_command(args, into: IO.stream(:stdio, :line)) do
        :ok ->
          :ok

        {:error, code} ->
          Mix.shell().error("\nError: Command failed with exit code: #{code}")
      end
    else
      # Capture and display output
      case System.cmd("podman", args, stderr_to_stdout: true) do
        {output, 0} ->
          if output != "" do
            IO.puts(output)
          end

          :ok

        {output, code} ->
          if output != "" do
            IO.puts(output)
          end

          Mix.shell().error("\nError: Command failed with exit code: #{code}")
      end
    end
  end

  @spec return() :: any()
  defp return, do: :ok
end
