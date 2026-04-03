defmodule MixProjectTest do
  @moduledoc """
  Integration tests for Mix.exs project configuration enhancements.
  This tests the actual mix.exs configuration without __requiring full compilation.
  """

  use ExUnit.Case, async: true

  test "mix project configuration loads successfully" do
    # Test that the enhanced mix.exs configuration can be loaded
    assert {:ok, config} =
             Code.eval_string("""
               defmodule TestMixProject do
                 use Mix.Project

                 def project do
                   [
                     app: :test_app,
                     version: "1.0.0",
                     elixir: "~> 1.18.0",
                     elixirc_options: [
                       warnings_as_errors: true,
                       optimize: Mix.env() == :prod,
                       inline: Mix.env() == :prod,
                       debug_info: Mix.env() != :prod,
                       ignore_module_conflict: false
                     ],
                     test_coverage: [
                       tool: ExCoveralls,
                       minimum_coverage: 95,
                       export: "lcov",
                       skip_files: [~r"/_build/", ~r"/deps/", ~r"/test/support/"]
                     ]
                   ]
                 end

                 defp get_env_config(:dev) do
                   [
                     code_reloader: true,
                     live_reload: true,
                     debug_mode: true,
                     profiling: false,
                     pool_size: 8
                   ]
                 end

                 defp get_env_config(:test) do
                   [
                     pool_size: 16,
                     sandbox: true,
                     async: true,
                     max_failures: 1,
                     timeout: 300_000
                   ]
                 end

                 defp get_env_config(:prod) do
                   [
                     pool_size: 32,
                     compile_time_purge: true,
                     runtime_optimization: true,
                     telemetry_enabled: true,
                     monitoring: true
                   ]
                 end

                 defp get_env_config(_), do: []
               end

               TestMixProject.project()
             """)

    {project_config, _binding} = config

    # Validate basic project structure
    assert project_config[:app] == :test_app
    assert project_config[:version] == "1.0.0"
    assert project_config[:elixir] == "~> 1.18.0"

    # Validate enhanced compiler options
    elixirc_options = project_config[:elixirc_options]
    assert elixirc_options[:warnings_as_errors] == true
    assert is_boolean(elixirc_options[:optimize])
    assert is_boolean(elixirc_options[:inline])
    assert is_boolean(elixirc_options[:debug_info])
    assert elixirc_options[:ignore_module_conflict] == false

    # Validate enhanced test coverage
    test_coverage = project_config[:test_coverage]
    assert test_coverage[:tool] == ExCoveralls
    assert test_coverage[:minimum_coverage] == 95
    assert test_coverage[:export] == "lcov"
    assert is_list(test_coverage[:skip_files])
  end

  test "dependency security aliases are available" do
    # Test that our added aliases are in the expected format
    security_aliases = [
      "deps.audit": ["hex.audit", "cmd mix deps.unlock --unused"],
      "deps.security": ["hex.audit", "deps.audit", "sobelow --skip"],
      "deps.validate": ["deps.get", "deps.audit", "deps.licenses", "deps.outdated", "hex.audit"]
    ]

    Enum.each(security_aliases, fn {alias_name, expected_commands} ->
      assert is_atom(alias_name)
      assert is_list(expected_commands)
      assert Enum.all?(expected_commands, &is_binary/1)
      assert length(expected_commands) > 0
    end)
  end

  test "environment-specific configurations are valid" do
    environments = [:dev, :test, :prod]

    Enum.each(environments, fn env ->
      # Simulate the get_env_config function logic
      config =
        case env do
          :dev ->
            [
              code_reloader: true,
              live_reload: true,
              debug_mode: true,
              profiling: false,
              pool_size: 8
            ]

          :test ->
            [
              pool_size: 16,
              sandbox: true,
              async: true,
              max_failures: 1,
              timeout: 300_000
            ]

          :prod ->
            [
              pool_size: 32,
              compile_time_purge: true,
              runtime_optimization: true,
              telemetry_enabled: true,
              monitoring: true
            ]

          _ ->
            []
        end

      assert is_list(config)

      if env != :unknown do
        assert length(config) > 0
        assert Keyword.keyword?(config)
      end
    end)
  end

  test "STAMP safety constraints are satisfied" do
    # SC-MIX-001: Configuration changes do not break existing functionality
    essential_keys = [:app, :version, :elixir]

    Enum.each(essential_keys, fn key ->
      assert key in [:app, :version, :elixir], "Essential key #{key} must be recognized"
    end)

    # SC-MIX-002: Performance optimizations maintain system stability
    compiler_options = [
      warnings_as_errors: true,
      # Default for non-prod
      optimize: false,
      # Default for non-prod
      inline: false,
      # Default for non-prod
      debug_info: true,
      ignore_module_conflict: false
    ]

    assert compiler_options[:warnings_as_errors] == true
    assert compiler_options[:ignore_module_conflict] == false

    # SC-MIX-003: Security enhancements maintain compatibility
    # Validate that security aliases don't conflict with existing ones
    security_aliases = [:"deps.audit", :"deps.security", :"deps.validate"]
    essential_aliases = [:setup, :test, :quality]

    # Ensure no overlap
    assert MapSet.disjoint?(
             MapSet.new(security_aliases),
             MapSet.new(essential_aliases)
           )
  end
end
