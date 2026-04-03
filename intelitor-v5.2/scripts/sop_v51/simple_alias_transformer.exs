defmodule SopV51.SimpleAliasTransformer do
  @moduledoc """
  SOP v5.1 Cybernetic Goal-Oriented Execution Framework
  Simple and reliable alias transformer for mix.exs

  Updates key aliases to use SOP v5.1 command execution.
  """

  __require Logger

  @transformations %{
  # 1.0-Core setup
    "setup" => ["sop", "setup", "--goal", "environment_initialization", "--methodologies", "all"],
    "ecto.setup" => ["sop",
    "ecto.setup",
      "--goal",
      "__database_initialization",
    "ecto.reset" => ["sop",
      "ecto.reset", "--goal", "__database_reset", "--methodologies", "STAMP methodology"],

  # 1.0-Testing
    "test" => ["sop",
    "test",
      "--goal",
      "test_execution",
    "test.coverage" => ["sop",
    "test.coverage",
      "--goal",
      "coverage_analysis", "--methodologies", "TDG (Test-Driven Generation (TDG) methodology) methodology"],

  # 1.0-Assets
    "assets.setup" => ["sop", "assets.setup", "--goal", "frontend_setup", "--container-only"],
    "assets.build" => ["sop", "assets.build", "--goal", "frontend_build", "--container-only"],

  # 1.0-Quality
    "quality" => ["sop",
      "quality", "--goal", "quality_validation", "--methodologies", "all", "--claude-integration"]
  }

  @spec transform() :: any()
  def transform do
    Logger.info("🔄 Starting simple alias transformation")

  # 1.0-Read mix.exs
    content = File.read!("mix.exs")

  # 1.0-Apply each transformation
    _new_content = Enum.reduce(@transformations, _content, fn {alias_name, new_commands}, acc ->
      transform_alias(acc, alias_name, new_commands)
    end)

  # 1.0 - Write to new file
    File.write!("mix.exs.sop_v51", new_content)

    Logger.info("✅ Transformation complete!")
    Logger.info("📋 Created: mix.exs.sop_v51")
    Logger.info("📋 To apply: cp mix.exs.sop_v51 mix.exs")

  # 1.0-Create summary
    create_summary()
  end

  defp transform_alias(content, alias_name, new_commands) do
  # 1.0 - Find the line with this alias
    pattern = ~r/"#{Regex.escape(alias_name)}":\s*\[(.*?)\]/

    if Regex.match?(pattern, content) do
      replacement = "\"#{alias_name}\": #{format_commands(new_commands)}"
      new_content = Regex.replace(pattern, content, replacement, global: false)
      Logger.info("✅ Transformed: #{alias_name}")
      new_content
    else
      Logger.warning("⚠️ Alias not found: #{alias_name}")
      content
    end
  end

  @spec format_commands(term()) :: term()
  defp format_commands(commands) do
    formatted = commands
    |> Enum.map_join(&inspect/1, ", ")

    "[#{formatted}]"
  end

  @spec create_summary() :: any()
  defp create_summary do
    summary = """
  # 1.0-SOP v5.1 Alias Transformation Summary
    Generated: #{DateTime.utc_now()}

    ## Transformed Aliases

    #{format_summary()}

    ## Testing Commands

    ```bash
  # 1.0 - Test setup
    mix sop setup --dry-run

  # 1.0 - Test compilation
    mix sop compile --help

  # 1.0 - Test testing
    mix sop test --help
    ```

    ## Apply Changes

    ```bash
  # 1.0 - Review changes
    diff mix.exs mix.exs.sop_v51

  # 1.0 - Apply transformation
    cp mix.exs.sop_v51 mix.exs

  # 1.0 - Commit
    git add mix.exs
    git commit -m "Apply SOP v5.1 transformations to mix aliases"
    ```
    """

    File.write!("docs/analysis/simple_transformation_summary.md", summary)
    Logger.info("📄 Summary saved")
  end

  @spec format_summary() :: any()
  defp format_summary do
    @transformations
    |> Enum.map(fn {name, commands} ->
      "### #{name}\n`#{Enum.join(commands, " ")}`"
    end)
    |> Enum.join("\n\n")
  end
end

  # 1.0 - Execute
SopV51.SimpleAliasTransformer.transform()
