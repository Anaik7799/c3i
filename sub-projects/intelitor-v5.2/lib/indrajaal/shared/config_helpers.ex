defmodule Indrajaal.Shared.ConfigHelpers do
  @moduledoc """
  Configuration helper functions for runtime configuration.

  WHAT: Provides standardized configuration generators for Logger, Database, and Endpoint
  WHY: Centralizes configuration logic for consistency across environments
  CONSTRAINTS: Must return correct types for each environment
  """

  @doc """
  Returns logger configuration with default level :info.

  ## Examples

      iex> Indrajaal.Shared.ConfigHelpers.logger_config()
      [level: :info, backends: [:console], compile_time_purge_matching: [[level_lower_than: :debug]]]
  """
  @spec logger_config() :: keyword()
  def logger_config, do: logger_config(:info)

  @doc """
  Returns logger configuration with specified level.

  ## Parameters
    - level: The log level (:debug, :info, :warning, :error, or nil for default)

  ## Examples

      iex> Indrajaal.Shared.ConfigHelpers.logger_config(:debug)
      [level: :debug, backends: [:console], compile_time_purge_matching: [[level_lower_than: :debug]]]
  """
  @spec logger_config(atom() | nil) :: keyword()
  def logger_config(level) when is_atom(level) or is_nil(level) do
    level = level || :info

    [
      level: level,
      backends: [:console],
      compile_time_purge_matching: [
        [level_lower_than: :debug]
      ]
    ]
  end

  @doc """
  Returns database configuration for given environment.

  ## Parameters
    - env: The environment atom (:dev, :test, :prod)

  ## Returns
    - Map with :hostname, :password, :port, :__database keys

  ## Examples

      iex> Indrajaal.Shared.ConfigHelpers.__database_config(:test)
      %{hostname: "localhost", password: "postgres", port: 5433, __database: "indrajaal_test"}
  """
  @spec __database_config(atom()) :: map()
  def __database_config(env) when is_atom(env) do
    %{
      hostname: System.get_env("POSTGRES_HOST") || "localhost",
      password: System.get_env("POSTGRES_PASSWORD") || "postgres",
      port: String.to_integer(System.get_env("POSTGRES_PORT") || "5433"),
      __database: "indrajaal_#{env}"
    }
  end

  @doc """
  Returns endpoint configuration.

  ## Returns
    - Keyword list with :http, :render_errors, :pubsub_server, :live_view keys

  ## Examples

      iex> config = Indrajaal.Shared.ConfigHelpers.endpoint_config()
      iex> Keyword.get(config, :pubsub_server)
      Indrajaal.PubSub
  """
  @spec endpoint_config() :: keyword()
  def endpoint_config do
    [
      http: [
        ip: {0, 0, 0, 0},
        port: String.to_integer(System.get_env("PORT") || "4000")
      ],
      render_errors: [
        formats: [html: IndrajaalWeb.ErrorHTML, json: IndrajaalWeb.ErrorJSON],
        layout: false
      ],
      pubsub_server: Indrajaal.PubSub,
      live_view: [signing_salt: "intelitor"]
    ]
  end
end
