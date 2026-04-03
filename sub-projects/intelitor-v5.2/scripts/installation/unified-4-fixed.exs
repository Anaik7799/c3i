#!/usr/bin/env elixir

# Indrajaal Unified System Installation and Management Script
# NixOS 25.05 ONLY - Complete setup with devenv.sh, Ash Framework
# QEMU/KVM for testing and deployment - No Docker/containers
# Version: 4.0.0 - Fixed

Mix.install([
  {:yaml_elixir, "~> 2.9"},
  {:jason, "~> 1.4"}
])

defmodule Indrajaal.UnifiedInstaller do
  @moduledoc """
  Unified installer for Indrajaal Security Monitoring System
  NixOS 25.05 ONLY-Uses devenv.sh for development, QEMU/KVM for deployment
  No Docker/containers - All services via Nix packages
  """

  # System Configuration
  @version "4.0.0"
  @project_name "indrajaal"
  @postgres_port 15_432
  @postgres_host "localhost"
  @app_port 4000

  # Main entry point
  @spec run() :: any()
  def run do
    IO.puts("🚀 Indrajaal Unified Installer v#{@version}")
    IO.puts("Setting up Indrajaal Security Monitoring System...")

    try do
      ensure_system_requirements()
      IO.puts("✅ System __requirements verified")

      create_elixir_project_structure()
      IO.puts("✅ Project structure created")

      setup_devenv_configuration()
      IO.puts("✅ Development environment configured")

      create_documentation()
      IO.puts("✅ Documentation created")

      IO.puts("\n🎉 Installation complete!")
      IO.puts("Next steps:")
      IO.puts("1. Run: devenv shell")
      IO.puts("2. Run: mix setup")
      IO.puts("3. Run: mix test")
      IO.puts("4. Run: mix phx.server")
    rescue
      error ->
        IO.puts("❌ Installation failed: #{inspect(error)}")
        System.halt(1)
    end
  end

  # System __requirements check
  @spec ensure_system_requirements() :: any()
  defp ensure_system_requirements do
    IO.puts("Checking system __requirements...")

    # Check for Elixir
    case System.cmd("elixir", ["--version"]) do
      {output, 0} ->
        IO.puts("  ✅ Elixir: #{String.trim(output) |> String.split("\n") |> hd()}

      _ ->
        raise "Elixir not found. Please install Elixir 1.19+"
    end

    # Check for Mix
    case System.cmd("mix", ["--version"]) do
      {output, 0} ->
        IO.puts("  ✅ Mix: #{String.trim(output)}")

      _ ->
        raise "Mix not found"
    end

    # Check for Git
    case System.cmd("git", ["--version"]) do
      {output, 0} ->
        IO.puts("  ✅ Git: #{String.trim(output)}")

      _ ->
        raise "Git not found"
    end
  end

  # Project structure and file generation
  @spec create_elixir_project_structure() :: any()
  defp create_elixir_project_structure do
    # Create directory structure
    create_directory_structure()

    # Create main mix.exs
    unless File.exists?("mix.exs") do
      File.write!("mix.exs", generate_mix_exs())
    end

    # Create configuration files
    create_config_files()

    # Create application files
    create_application_files()

    # Create .formatter.exs
    unless File.exists?(".formatter.exs") do
      File.write!(".formatter.exs", generate_formatter_config())
    end

    # Create .gitignore
    unless File.exists?(".gitignore") do
      File.write!(".gitignore", generate_gitignore())
    end

    :ok
  end

  @spec create_directory_structure() :: any()
  defp create_directory_structure do
    dirs = [
      # Main application structure-12 Ash domains
      "lib/indrajaal/core",
      "lib/indrajaal/accounts",
      "lib/indrajaal/policy",
      "lib/indrajaal/sites",
      "lib/indrajaal/devices",
      "lib/indrajaal/alarms",
      "lib/indrajaal/video",
      "lib/indrajaal/dispatch",
      "lib/indrajaal/maintenance",
      "lib/indrajaal/compliance",
      "lib/indrajaal/billing",
      "lib/indrajaal/integrations",
      "lib/indrajaal/auth",

      # Web interface
      "lib/indrajaal_web/controllers",
      "lib/indrajaal_web/live",
      "lib/indrajaal_web/channels",
      "lib/indrajaal_web/plugs",
      "lib/indrajaal_web/views",
      "lib/indrajaal_web/templates",

      # Mix tasks directory
      "lib/mix/tasks/ash",
      "lib/mix/tasks/docs",
      "lib/mix/tasks/project",
      "lib/mix/tasks/test",
      "lib/mix/tasks/unified",

      # Configuration and __data
      "config",
      "priv/repo/migrations",
      "priv/static",
      "priv/gettext",

      # Comprehensive test structure
      "test/indrajaal/accounts",
      "test/indrajaal/alarms",
      "test/indrajaal/auth",
      "test/indrajaal/billing",
      "test/indrajaal/compliance",
      "test/indrajaal/core",
      "test/indrajaal/devices",
      "test/indrajaal/dispatch",
      "test/indrajaal/integrations",
      "test/indrajaal/maintenance",
      "test/indrajaal/policy",
      "test/indrajaal/sites",
      "test/indrajaal/video",
      "test/indrajaal_web/channels",
      "test/indrajaal_web/controllers",
      "test/indrajaal_web/views",
      "test/integration",
      "test/performance",
      "test/security",
      "test/support/factories",
      "test/support/fixtures",
      "test/support/generators",
      "test/support/helpers",
      "test/support/mocks",

      # Analysis and operational directories
      "__data/analysis",
      "logs",
      "test_results",
      "tmp",

      # Documentation structure
      "docs/guides",
      "docs/archive",
      "docs/journal",
      "docs/test_reports",

      # Scripts organized by category
      "scripts/analysis",
      "scripts/archive",
      "scripts/installation",
      "scripts/maintenance",
      "scripts/setup",
      "scripts/testing"
    ]

    Enum.each(dirs, &File.mkdir_p!/1)
  end

  @spec generate_mix_exs() :: any()
  defp generate_mix_exs do
    """
    defmodule Indrajaal.MixProject do
      use Mix.Project

  @spec project() :: any()
      def project do
        [
          app: :indrajaal,
          version: "#{@version}",
          elixir: "~> 1.18",
          elixirc_paths: elixirc_paths(Mix.env()),
          start_permanent: Mix.env() == :prod,
          aliases: aliases(),
          deps: deps(),
          test_coverage: [tool: ExCoveralls],
          preferred_cli_env: [
            coveralls: :test,
            "coveralls.detail": :test,
            "coveralls.html": :test,
            "coveralls.github": :test,
            "test.coverage": :test
          ],
          dialyzer: [
            plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
            plt_add_apps: [:mix, :ex_unit]
          ]
        ]
      end

  @spec application() :: any()
      def application do
        [
          mod: {Indrajaal.Application, []},
          extra_applications: [
            :logger,
            :runtime_tools,
            :os_mon,
            :crypto,
            :ssl
          ]
        ]
      end

  @spec elixirc_paths(term()) :: term()
      defp elixirc_paths(:test), do: ["lib", "test/support"]
      defp elixirc_paths(_), do: ["lib"]

  @spec deps() :: any()
      defp deps do
        [
          # Ash Framework Core
          {:ash, "~> 3.5"},
          {:ash_postgres, "~> 2.4"},
          {:ash_authentication, "~> 4.2"},
          {:ash_state_machine, "~> 0.2"},
          {:ash_json_api, "~> 1.4"},
          {:ash_archival, "~> 1.0"},
          {:ash_admin, "~> 0.11"},

          # Phoenix Framework
          {:phoenix, "~> 1.7.10"},
          {:phoenix_ecto, "~> 4.5"},
          {:phoenix_html, "~> 4.0"},
          {:phoenix_live_reload, "~> 1.5", only: :dev},
          {:phoenix_live_view, "~> 0.20.2"},
          {:phoenix_live_dashboard, "~> 0.8.3"},
          {:phoenix_pubsub, "~> 2.1"},

          # Database & Storage
          {:ecto_sql, "~> 3.11"},
          {:postgrex, "~> 0.17"},
          {:ecto_psql_extras, "~> 0.8"},

          # Authentication & Authorization
          {:bcrypt_elixir, "~> 3.1"},
          {:guardian, "~> 2.3"},
          {:guardian_db, "~> 3.0"},

          # Background Jobs & Messaging
          {:oban, "~> 2.18"},

          # Development & Testing
          {:phoenix_dev_tools, "~> 1.0", only: :dev},
          {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
          {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
          {:heroicons, "~> 0.5"},
          {:floki, ">= 0.30.0", only: :test},
          {:excoveralls, "~> 0.18", only: :test},
          {:ex_machina, "~> 2.7", only: :test},
          {:faker, "~> 0.18", only: :test},
          {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
          {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
          {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
        ]
      end

  @spec aliases() :: any()
      defp aliases do
        [
          setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
          "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
          "ecto.reset": ["ecto.drop", "ecto.setup"],
          test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
          "test.coverage": ["coveralls.html"],
          "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
          "assets.build": ["tailwind indrajaal", "esbuild indrajaal"],
          "assets.deploy": [
            "tailwind indrajaal --minify",
            "esbuild indrajaal --minify",
            "phx.digest"
          ]
        ]
      end
    end
    """
  end

  @spec create_config_files() :: any()
  defp create_config_files do
    # Create config/config.exs
    unless File.exists?("config/config.exs") do
      File.write!("config/config.exs", generate_config())
    end

    # Create config/dev.exs
    unless File.exists?("config/dev.exs") do
      File.write!("config/dev.exs", generate_dev_config())
    end

    # Create config/test.exs
    unless File.exists?("config/test.exs") do
      File.write!("config/test.exs", generate_test_config())
    end

    # Create config/runtime.exs
    unless File.exists?("config/runtime.exs") do
      File.write!("config/runtime.exs", generate_runtime_config())
    end
  end

  @spec create_application_files() :: any()
  defp create_application_files do
    # Create main application file
    unless File.exists?("lib/indrajaal/application.ex") do
      File.write!("lib/indrajaal/application.ex", generate_application())
    end

    # Create repo file
    unless File.exists?("lib/indrajaal/repo.ex") do
      File.write!("lib/indrajaal/repo.ex", generate_repo())
    end

    # Create test helper
    unless File.exists?("test/test_helper.exs") do
      File.write!("test/test_helper.exs", generate_test_helper())
    end
  end

  @spec setup_devenv_configuration() :: any()
  defp setup_devenv_configuration do
    unless File.exists?("devenv.nix") do
      File.write!("devenv.nix", generate_devenv_config())
    end
  end

  @spec create_documentation() :: any()
  defp create_documentation do
    unless File.exists?("README.md") do
      File.write!("README.md", generate_readme())
    end
  end

  # Configuration generators
  @spec generate_config() :: any()
  defp generate_config do
    """
    import Config

    config :indrajaal,
      ecto_repos: [Indrajaal.Repo],
      generators: [timestamp_type: :utc_datetime]

    config :indrajaal_web,
      generators: [__context_app: :indrajaal]

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      url: [host: "localhost"],
      adapter: Bandit.PhoenixAdapter,
      render_errors: [
        formats: [html: IndrajaalWeb.ErrorHTML, json: IndrajaalWeb.ErrorJSON],
        layout: false
      ],
      pubsub_server: Indrajaal.PubSub,
      live_view: [signing_salt: "secret"]

    config :logger, :console,
      format: "$time $metadata[$level] $message\\n",
      metadata: [:__request_id]

    config :phoenix, :json_library, Jason

    import_config "\#{config_env()}.exs"
    """
  end

  @spec generate_dev_config() :: any()
  defp generate_dev_config do
    """
    import Config

    config :indrajaal, Indrajaal.Repo,
      __username: "postgres",
      password: "postgres",
      hostname: "localhost",
      port: #{@postgres_port},
      __database: "indrajaal_dev",
      stacktrace: true,
      show_sensitive_data_on_connection_error: true,
      pool_size: 10

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: #{@app_port}],
      check_origin: false,
      code_reloader: true,
      debug_errors: true,
      secret_key_base: "dev_secret_key_base_at_least_64_chars_long_for_development_only",
      watchers: []

    config :logger, :console, format: "[$level] $message\\n"

    config :phoenix, :stacktrace_depth, 20
    config :phoenix, :plug_init_mode, :runtime
    """
  end

  @spec generate_test_config() :: any()
  defp generate_test_config do
    """
    import Config

    config :indrajaal, Indrajaal.Repo,
      __username: "postgres",
      password: "postgres",
      hostname: "localhost",
      port: #{@postgres_port},
      __database: "indrajaal_test\#{System.get_env("MIX_TEST_PARTITION")}",
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: System.schedulers_online() * 2

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: 4002],
      secret_key_base: "test_secret_key_base_at_least_64_chars_long_for_testing_only",
      server: false

    config :logger, level: :warning
    config :phoenix, :plug_init_mode, :runtime
    """
  end

  @spec generate_runtime_config() :: any()
  defp generate_runtime_config do
    """
    import Config

    if System.get_env("PHX_SERVER") do
      config :indrajaal_web, IndrajaalWeb.Endpoint, server: true
    end
    """
  end

  @spec generate_application() :: any()
  defp generate_application do
    """
    defmodule Indrajaal.Application do
      @moduledoc false

      use Application

      @impl true
  @spec start(any(), any()) :: any()
      def start(_type, _args) do
        children = [
          Indrajaal.Repo,
          {Phoenix.PubSub, name: Indrajaal.PubSub},
          IndrajaalWeb.Endpoint
        ]

        __opts = [strategy: :one_for_one, name: Indrajaal.Supervisor]
        Supervisor.start_link(children, __opts)
      end

      @impl true
  @spec config_change(term(), term(), term()) :: term()
      def config_change(changed, _new, removed) do
        IndrajaalWeb.Endpoint.config_change(changed, removed)
        :ok
      end
    end
    """
  end

  @spec generate_repo() :: any()
  defp generate_repo do
    """
    defmodule Indrajaal.Repo do
      use Ecto.Repo,
        otp_app: :indrajaal,
        adapter: Ecto.Adapters.Postgres
    end
    """
  end

  @spec generate_test_helper() :: any()
  defp generate_test_helper do
    """
    ExUnit.start()
    Ecto.Adapters.SQL.Sandbox.mode(Indrajaal.Repo, :manual)
    """
  end

  @spec generate_formatter_config() :: any()
  defp generate_formatter_config do
    """
    [
      import_deps: [:ash, :ash_postgres, :phoenix],
      subdirectories: ["priv/*/migrations"],
      plugins: [Phoenix.LiveView.HTMLFormatter],
      inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
    ]
    """
  end

  @spec generate_gitignore() :: any()
  defp generate_gitignore do
    """
    # The directory Mix will write compiled artifacts to.
    /_build/

    # If you run "mix test --cover", coverage assets end up here.
    /cover/

    # The directory Mix downloads your dependencies sources to.
    /deps/

    # Where third-party dependencies like ExDoc output generated docs.
    /doc/

    # Ignore .fetch files in case you like to edit your project deps locally.
    /.fetch

    # If the VM crashes, it generates a dump, let's ignore it too.
    erl_crash.dump

    # Also ignore archive artifacts (built via "mix archive.build").
    *.ez

    # Ignore package tarball (built via "mix hex.build").
    indrajaal-*.tar

    # Temporary files, for example, from tests.
    /tmp/

    # Ignore test results
    /test_results/

    # Ignore logs
    /logs/

    # Ignore devenv files
    .devenv/

    # Ignore PLT files
    /priv/plts/

    # macOS
    .DS_Store

    # Editor files
    .vscode/
    .idea/
    *.swp
    *.swo
    *~

    # Environment variables
    .env
    .env.*
    """
  end

  @spec generate_devenv_config() :: any()
  defp generate_devenv_config do
    """
    { pkgs, lib, config, inputs, ... }:

    {
      packages = [
        pkgs.git
        pkgs.postgresql_17
      ];

      languages.elixir = {
        enable = true;
        package = pkgs.elixir_1_18;
      };

      services.postgres = {
        enable = true;
        package = pkgs.postgresql_17;
        listen_addresses = "127.0.0.1";
        port = #{@postgres_port};
        initialDatabases = [
          { name = "indrajaal_dev"; }
          { name = "indrajaal_test"; }
        ];
        initialScript = '''
          CREATE USER postgres SUPERUSER;
          ALTER USER postgres PASSWORD 'postgres';
        ''';
      };

      enterShell = '''
        echo "🚀 Indrajaal Development Environment"
        echo "PostgreSQL is running on port #{@postgres_port}"
        echo "Run 'mix setup' to initialize the project"
      ''';
    }
    """
  end

  @spec generate_readme() :: any()
  defp generate_readme do
    """
    # Indrajaal Security Monitoring System

    A comprehensive security monitoring
    and management system built with Elixir and the Ash Framework.

    ## Quick Start

    ```bash
    # Enter development environment
    devenv shell

    # Setup the project
    mix setup

    # Run tests
    mix test

    # Start the server
    mix phx.server
    ```

    ## Architecture-**12 Ash Domains**: Core,
    Accounts,
      Policy, Sites, Devices, Alarms, Video, Dispatch, Maintenance, Compliance, Billing, Integrations
    - **Multi-tenant**: Complete __data isolation with PostgreSQL RLS
    - **Real-time**: Phoenix PubSub with dual adapters (PG2 + PostgreSQL)
    - **Security-first**: End-to-end encryption, audit logging, compliance ready

    ## Development

    This project uses NixOS 25.05 and devenv.sh for reproducible development environments.

    ## License

    Copyright © 2024 Indrajaal Security Systems
    """
  end
end

# Execute the installer when run as a script
Indrajaal.UnifiedInstaller.run()

end
end
end
end
end
