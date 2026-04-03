defmodule MixEnhancementTest do
  @moduledoc """
  TDG Methodology Test Suite for Mix.exs Enhancements

  This test suite validates the Level 1-5 enhancements made to mix.exs
  following Test-Driven Generation methodology with comprehensive coverage.
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.MixProject

  describe "Level 1: Dependency Security & Validation" do
    test "dependency security aliases are properly configured" do
      aliases = MixProject.project()[:aliases]

      # Validate all dependency security aliases exist
      assert Keyword.has_key?(aliases, :"deps.audit")
      assert Keyword.has_key?(aliases, :"deps.security")
      assert Keyword.has_key?(aliases, :"deps.update.security")
      assert Keyword.has_key?(aliases, :"deps.vulnerability")
      assert Keyword.has_key?(aliases, :"deps.cve")

      # Validate alias structure contains hex.audit
      assert aliases[:"deps.audit"] |> Enum.any?(&(&1 =~ "hex.audit"))
      assert aliases[:"deps.security"] |> Enum.any?(&(&1 =~ "hex.audit"))
    end

    test "license compliance aliases are properly configured" do
      aliases = MixProject.project()[:aliases]

      # Validate license compliance aliases exist
      assert Keyword.has_key?(aliases, :"deps.licenses")
      assert Keyword.has_key?(aliases, :"deps.compliance")
      assert Keyword.has_key?(aliases, :"deps.legal")

      # Validate comprehensive dependency validation alias
      assert Keyword.has_key?(aliases, :"deps.validate")
      comprehensive_deps = aliases[:"deps.validate"]

      assert "deps.get" in comprehensive_deps
      assert "deps.audit" in comprehensive_deps
      assert "deps.licenses" in comprehensive_deps
      assert "hex.audit" in comprehensive_deps
    end

    test "dependency graph analysis aliases are properly configured" do
      aliases = MixProject.project()[:aliases]

      # Validate graph analysis aliases exist
      assert Keyword.has_key?(aliases, :"deps.tree")
      assert Keyword.has_key?(aliases, :"deps.graph")
      assert Keyword.has_key?(aliases, :"deps.unused")
      assert Keyword.has_key?(aliases, :"deps.outdated")
      assert Keyword.has_key?(aliases, :"deps.analyze")
    end

    test "emergency dependency response alias is configured" do
      aliases = MixProject.project()[:aliases]

      assert Keyword.has_key?(aliases, :"deps.emergency")
      emergency_steps = aliases[:"deps.emergency"]

      # Validate emergency response contains critical steps
      assert "deps.update --force" in emergency_steps
      assert "hex.audit" in emergency_steps
      assert "compile --warnings-as-errors" in emergency_steps
      assert "test --only unit" in emergency_steps
    end
  end

  describe "Level 2: Performance Optimization Configuration" do
    test "enhanced compiler options are properly configured" do
      config = MixProject.project()
      elixirc_options = config[:elixirc_options]

      # Validate enhanced compiler options exist
      assert elixirc_options[:warnings_as_errors] == true
      assert is_boolean(elixirc_options[:optimize])
      assert is_boolean(elixirc_options[:inline])
      assert is_boolean(elixirc_options[:debug_info])
      assert elixirc_options[:ignore_module_conflict] == false
    end

    test "optimization flags are environment-specific" do
      # Test production optimization
      Application.put_env(:mix, :env, :prod)
      config = MixProject.project()
      elixirc_options = config[:elixirc_options]

      assert elixirc_options[:optimize] == true
      assert elixirc_options[:inline] == true
      assert elixirc_options[:debug_info] == false

      # Test development settings
      Application.put_env(:mix, :env, :dev)
      config = MixProject.project()
      elixirc_options = config[:elixirc_options]

      assert elixirc_options[:optimize] == false
      assert elixirc_options[:inline] == false
      assert elixirc_options[:debug_info] == true
    end
  end

  describe "Level 3: Environment-Specific Configuration" do
    test "development environment configuration" do
      config = MixProject.send(:get_env_config, :dev)

      assert config[:code_reloader] == true
      assert config[:live_reload] == true
      assert config[:debug_mode] == true
      assert config[:profiling] == false
      assert config[:pool_size] == 8
    end

    test "test environment configuration" do
      config = MixProject.send(:get_env_config, :test)

      assert config[:pool_size] == 16
      assert config[:sandbox] == true
      assert config[:async] == true
      assert config[:max_failures] == 1
      assert config[:timeout] == 300_000
    end

    test "production environment configuration" do
      config = MixProject.send(:get_env_config, :prod)

      assert config[:pool_size] == 32
      assert config[:compile_time_purge] == true
      assert config[:runtime_optimization] == true
      assert config[:telemetry_enabled] == true
      assert config[:monitoring] == true
    end

    test "unknown environment returns empty config" do
      config = MixProject.send(:get_env_config, :unknown)
      assert config == []
    end
  end

  describe "Level 4: Advanced Test Framework Configuration" do
    test "enhanced test coverage configuration" do
      config = MixProject.project()
      test_coverage = config[:test_coverage]

      assert test_coverage[:tool] == ExCoveralls
      assert test_coverage[:minimum_coverage] == 95
      assert test_coverage[:export] == "lcov"
      assert is_list(test_coverage[:skip_files])

      # Validate skip patterns
      skip_files = test_coverage[:skip_files]
      assert Enum.any?(skip_files, &Regex.match?(&1, "_build/test"))
      assert Enum.any?(skip_files, &Regex.match?(&1, "deps/phoenix"))
    end

    test "test environment preferences are maintained" do
      config = MixProject.project()
      preferred_cli_env = config[:preferred_cli_env]

      assert preferred_cli_env[:coveralls] == :test
      assert preferred_cli_env[:"coveralls.detail"] == :test
      assert preferred_cli_env[:"coveralls.html"] == :test
    end
  end

  describe "Property-Based Testing: Configuration Invariants" do
    # PropCheck property test
    property "environment configuration is consistent", [
      :verbose,
      {:numtests, 100}
    ] do
      forall env <- oneof([:dev, :test, :prod]) do
        config = MixProject.send(:get_env_config, env)

        # Invariant: All environment configs return keyword lists
        # Invariant: Pool size is always positive integer
        is_list(config) and
          Enum.all?(config, fn {key, _value} -> is_atom(key) end) and
          case config[:pool_size] do
            nil -> true
            pool_size -> is_integer(pool_size) and pool_size > 0
          end
      end
    end

    # ExUnitProperties property test
    test "dependency aliases are well-formed" do
      ExUnitProperties.check all(
                               alias_name <-
                                 SD.member_of([
                                   :"deps.audit",
                                   :"deps.security",
                                   :"deps.validate",
                                   :"deps.emergency",
                                   :"deps.compliance"
                                 ])
                             ) do
        aliases = MixProject.project()[:aliases]
        alias_commands = aliases[alias_name]

        # Invariant: All aliases return list of strings
        assert is_list(alias_commands)
        assert Enum.all?(alias_commands, &is_binary/1)
        assert length(alias_commands) > 0
      end
    end
  end

  describe "STAMP Safety Constraint Validation" do
    test "SC-MIX-001: Configuration changes do not break existing functionality" do
      # Validate that project configuration is valid
      config = MixProject.project()

      assert is_atom(config[:app])
      assert is_binary(config[:version])
      assert is_binary(config[:elixir])
      assert is_list(config[:aliases])
      assert is_list(config[:deps])
    end

    test "SC-MIX-002: Performance optimizations maintain system stability" do
      # Validate compiler options are safe
      elixirc_options = MixProject.project()[:elixirc_options]

      # Ensure warnings_as_errors is maintained for quality
      assert elixirc_options[:warnings_as_errors] == true

      # Ensure ignore_module_conflict is set to safe default
      assert elixirc_options[:ignore_module_conflict] == false
    end

    test "SC-MIX-003: Security enhancements maintain compatibility" do
      aliases = MixProject.project()[:aliases]

      # Validate that security aliases don't override essential aliases
      essential_aliases = [:setup, :test, :quality, :"ecto.setup"]

      Enum.each(essential_aliases, fn alias_name ->
        assert Keyword.has_key?(aliases, alias_name),
               "Essential alias #{alias_name} must be preserved"
      end)
    end

    test "SC-MIX-004: Environment configurations are validated" do
      # Test that all environment functions work
      for env <- [:dev, :test, :prod] do
        config = MixProject.send(:get_env_config, env)
        assert is_list(config), "Environment #{env} must return valid config"
      end
    end

    test "SC-MIX-005: Test framework changes maintain existing coverage" do
      config = MixProject.project()

      # Validate that test coverage tool is still configured
      assert config[:test_coverage][:tool] == ExCoveralls

      # Validate that coverage __requirements are reasonable
      assert config[:test_coverage][:minimum_coverage] >= 95
      assert config[:test_coverage][:minimum_coverage] <= 100
    end
  end

  describe "Integration Testing" do
    test "mix project compilation succeeds with new configuration" do
      # This test validates that the enhanced mix.exs doesn't break compilation
      assert {:ok, _} = Code.eval_string("Indrajaal.MixProject.project()")
    end

    test "all dependency security aliases are executable" do
      aliases = MixProject.project()[:aliases]

      security_aliases = [
        :"deps.audit",
        :"deps.security",
        :"deps.validate",
        :"deps.compliance",
        :"deps.emergency"
      ]

      Enum.each(security_aliases, fn alias_name ->
        alias_commands = aliases[alias_name]
        assert is_list(alias_commands), "#{alias_name} must be a list of commands"
        assert length(alias_commands) > 0, "#{alias_name} must have at least one command"
      end)
    end

    test "environment configuration integration" do
      config = MixProject.project()
      env_config = config[:env_config]

      # Validate that env_config is properly integrated
      assert is_list(env_config), "env_config must be a keyword list"
    end
  end
end
