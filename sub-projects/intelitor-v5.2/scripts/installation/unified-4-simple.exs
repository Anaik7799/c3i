#!/usr/bin/env elixir

# Simplified Indrajaal Unified System Installation Script
# NixOS 25.05 ONLY - Core functions without TUI
# Version: 4.0.0

Mix.install([
  {:jason, "~> 1.4"},
  {:yaml_elixir, "~> 2.9"}
])

defmodule Indrajaal.UnifiedInstallerSimple do
  @moduledoc """
  Simplified unified installer for Indrajaal Security Monitoring System
  NixOS 25.05 ONLY - Uses devenv.sh for development
  """

  # System Configuration
  @version "4.0.0"
  @project_name "indrajaal"

  @spec run() :: any()
  def run do
    IO.puts("🚀 Indrajaal Unified Installer v#{@version}")
    IO.puts("Creating project structure...")

    # Create directory structure
    create_directory_structure()
    IO.puts("✅ Directory structure created")

    # Create basic project files
    create_project_files()
    IO.puts("✅ Project files created")

    # Create configuration files
    create_config_files()
    IO.puts("✅ Configuration files created")

    # Create application structure
    create_application_files()
    IO.puts("✅ Application files created")

    # Create test files
    create_test_files()
    IO.puts("✅ Test files created")

    IO.puts("\n🎉 Installation complete!")
    IO.puts("Next steps:")
    IO.puts("1. Run: mix setup")
    IO.puts("2. Run: mix test")
    IO.puts("3. Run: mix phx.server")
  end

  @spec create_directory_structure() :: any()
  defp create_directory_structure do
    dirs = [
      # Main application structure - 12 Ash domains
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

  @spec create_project_files() :: any()
  defp create_project_files do
    # Create mix.exs if it doesn't exist
    unless File.exists?("mix.exs") do
      File.write!("mix.exs", generate_mix_exs())
    end

    # Create .formatter.exs
    unless File.exists?(".formatter.exs") do
      File.write!(".formatter.exs", generate_formatter_config())
    end

    # Create .gitignore
    unless File.exists?(".gitignore") do
      File.write!(".gitignore", generate_gitignore())
    end
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
  end

  @spec create_test_files() :: any()
  defp create_test_files do
    # Create test_helper.exs
    unless File.exists?("test/test_helper.exs") do
      File.write!("test/test_helper.exs", generate_test_helper())
    end

    # Create support files
    create_test_support_files()
  end

  @spec create_test_support_files() :: any()
  defp create_test_support_files do
    files = [
      {"test/support/channel_case.ex", generate_channel_case()},
      {"test/support/conn_case.ex", generate_conn_case()},
      {"test/support/test_case.ex", generate_test_case()},
      {"test/support/factory.ex", generate_factory()},
      {"test/support/fixtures/fixtures.ex", generate_fixtures()},
      {"test/support/generators/generators.ex", generate_generators()},
      {"test/support/helpers/test_helpers.ex", generate_test_helpers()}
    ]

    Enum.each(files, fn {path, content} ->
      unless File.exists?(path) do
        File.write!(path, content)
      end
    end)
  end

  # Configuration generators
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

    # Ignore uploaded files in development
    /priv/static/uploads/

    # Ignore assets cache
    /priv/static/assets/

    # Ignore compiled CSS and JS
    /assets/node_modules/

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

    config :esbuild,
      version: "0.19.12",
      indrajaal: [
        args:
          ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
        cd: Path.expand("../assets", __DIR__),
        env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
      ]

    config :tailwind,
      version: "3.4.0",
      indrajaal: [
        args: ~w(
          --config=tailwind.config.js
          --input=css/app.css
          --output=../priv/static/assets/app.css
        ),
        cd: Path.expand("../assets", __DIR__)
      ]

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
      port: 15_432,
      __database: "indrajaal_dev",
      stacktrace: true,
      show_sensitive_data_on_connection_error: true,
      pool_size: 10

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: 4000],
      check_origin: false,
      code_reloader: true,
      debug_errors: true,
      secret_key_base: "dev_secret_key_base_at_least_64_chars_long_for_development_only",
      watchers: [
        esbuild: {Esbuild, :install_and_run, [:indrajaal, ~w(--sourcemap=inline --watch)]},
        tailwind: {Tailwind, :install_and_run, [:indrajaal, ~w(--watch)]}
      ]

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      live_reload: [
        patterns: [
          ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
          ~r"priv/gettext/.*(po)$",
          ~r"lib/indrajaal_web/(controllers|live|components)/.*(ex|heex)$"
        ]
      ]

    config :logger, :console, format: "[$level] $message\\n"

    config :phoenix, :stacktrace_depth, 20

    config :phoenix, :plug_init_mode, :runtime

    config :phoenix_live_view,
      debug_heex_annotations: true,
      enable_expensive_runtime_checks: true
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
      port: 15_432,
      __database: "indrajaal_test\#{System.get_env("MIX_TEST_PARTITION")}",
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: System.schedulers_online() * 2

    config :indrajaal_web, IndrajaalWeb.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: 4002],
      secret_key_base: "test_secret_key_base_at_least_64_chars_long_for_testing_only",
      server: false

    config :logger, level: :warning

    config :phoenix, :plug_init_mode, :runtime

    config :phoenix_live_view,
      enable_expensive_runtime_checks: true
    """
  end

  @spec generate_runtime_config() :: any()
  defp generate_runtime_config do
    """
    import Config

    if System.get_env("PHX_SERVER") do
      config :indrajaal_web, IndrajaalWeb.Endpoint, server: true
    end

    if config_env() == :prod do
      __database_url =
        System.get_env("DATABASE_URL") ||
          raise \"\"\"
          environment variable DATABASE_URL is missing.
          For example: ecto://USER:PASS@HOST/DATABASE
          \"\"\"

      maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

      config :indrajaal, Indrajaal.Repo,
        url: __database_url,
        pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
        socket_options: maybe_ipv6

      secret_key_base =
        System.get_env("SECRET_KEY_BASE") ||
          raise \"\"\"
          environment variable SECRET_KEY_BASE is missing.
          You can generate one by calling: mix phx.gen.secret
          \"\"\"

      host = System.get_env("PHX_HOST") || "example.com"
      port = String.to_integer(System.get_env("PORT") || "4000")

      config :indrajaal_web, IndrajaalWeb.Endpoint,
        url: [host: host, port: 443, scheme: "https"],
        http: [
          ip: {0, 0, 0, 0, 0, 0, 0, 0},
          port: port
        ],
        secret_key_base: secret_key_base
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
          IndrajaalWeb.Telemetry,
          Indrajaal.Repo,
          {DNSCluster, query: Application.get_env(:indrajaal, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: Indrajaal.PubSub},
          {Finch, name: Indrajaal.Finch},
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

  @spec init(any(), any()) :: any()
      def init(_type, config) do
        {:ok, Keyword.put(config, :url, System.get_env("DATABASE_URL"))}
      end
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

  @spec generate_channel_case() :: any()
  defp generate_channel_case do
    """
    defmodule IndrajaalWeb.ChannelCase do
      use ExUnit.CaseTemplate

      using do
        quote do
          import Phoenix.ChannelTest
          import IndrajaalWeb.ChannelCase

          @endpoint IndrajaalWeb.Endpoint
        end
      end

      setup tags do
        Indrajaal.DataCase.setup_sandbox(tags)
        :ok
      end
    end
    """
  end

  @spec generate_conn_case() :: any()
  defp generate_conn_case do
    """
    defmodule IndrajaalWeb.ConnCase do
      use ExUnit.CaseTemplate

      using do
        quote do
          import Plug.Conn
          import Phoenix.ConnTest
          import IndrajaalWeb.ConnCase

          alias IndrajaalWeb.Router.Helpers, as: Routes

          @endpoint IndrajaalWeb.Endpoint
        end
      end

      setup tags do
        Indrajaal.DataCase.setup_sandbox(tags)
        {:ok, conn: Phoenix.ConnTest.build_conn()}
      end
    end
    """
  end

  @spec generate_test_case() :: any()
  defp generate_test_case do
    """
    defmodule Indrajaal.TestCase do
      use ExUnit.CaseTemplate

      using do
        quote do
          import Indrajaal.TestCase
        end
      end

      setup tags do
        Indrajaal.DataCase.setup_sandbox(tags)
        :ok
      end
    end
    """
  end

  @spec generate_factory() :: any()
  defp generate_factory do
    """
    defmodule Indrajaal.Factory do
      use ExMachina.Ecto, repo: Indrajaal.Repo

      # Define factories here
    end
    """
  end

  @spec generate_fixtures() :: any()
  defp generate_fixtures do
    """
    defmodule Indrajaal.Fixtures do
      @moduledoc \"\"\"
      Test fixtures for Indrajaal.
      \"\"\"

      # Define fixtures here
    end
    """
  end

  @spec generate_generators() :: any()
  defp generate_generators do
    """
    defmodule Indrajaal.Generators do
      @moduledoc \"\"\"
      Test __data generators for Indrajaal.
      \"\"\"

      # Define generators here
    end
    """
  end

  @spec generate_test_helpers() :: any()
  defp generate_test_helpers do
    """
    defmodule Indrajaal.TestHelpers do
      @moduledoc \"\"\"
      Test helper functions for Indrajaal.
      \"\"\"

      # Define helper functions here
    end
    """
  end
end

# Run the installer
Indrajaal.UnifiedInstallerSimple.run()
