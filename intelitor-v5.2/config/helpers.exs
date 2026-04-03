defmodule Indrajaal.Config.Helpers do
  @moduledoc """
  Configuration helpers loaded before the main application.
  This module provides standardized configuration patterns for use
  across all environment-specific config files (dev/test/prod).
  """

  @doc """
  Standard logger configuration.
  """
  def logger_config(level \\ :info) do
    [
      backends: [:console, LoggerJSON],
      level: level,
      compile_time_purge_matching: [
        [level_lower_than: :info]
      ]
    ]
  end

  @doc """
  Standard database configuration pattern.
  """
  def database_config(env) do
    %{
      username: System.get_env("POSTGRES_USER", "postgres"),
      password: System.get_env("POSTGRES_PASSWORD", "postgres"),
      hostname: System.get_env("DATABASE_HOST", "localhost"),
      database: "indrajaal_#{env}",
      port: String.to_integer(System.get_env("PGPORT", "5433"))
    }
  end

  @doc """
  Standard Phoenix endpoint configuration.
  """
  def endpoint_config do
    [
      http: [ip: {127, 0, 0, 1}, port: 4000],
      render_errors: [
        formats: [html: IndrajaalWeb.ErrorHTML, json: IndrajaalWeb.ErrorJSON],
        layout: false
      ],
      pubsub_server: Indrajaal.PubSub,
      live_view: [signing_salt: System.get_env("LV_SIGNING_SALT")]
    ]
  end
end
