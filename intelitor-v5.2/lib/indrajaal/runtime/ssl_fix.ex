defmodule Indrajaal.Runtime.SSLFix do
  @moduledoc """
  A module to programmatically fix SSL certificate issues in Nix-based containers.
  This module directly configures the Erlang `:ssl` and `:public_key` applications,
  bypassing environment-related lookup problems.
  """

  require Logger

  def init do
    Logger.info("[SSLFix] Initializing Erlang SSL configuration...")

    case find_nix_cert_path() do
      {:ok, path} ->
        Logger.info("[SSLFix] Found CA bundle at: #{path}")
        apply_ssl_config(path)
        :ok

      {:error, reason} ->
        Logger.error("[SSLFix] Could not find CA bundle: #{reason}")
        :error
    end
  end

  defp find_nix_cert_path do
    # In a Nix environment, certs are in a path like /nix/store/....-cacert-.../etc/ssl/certs/ca-bundle.crt
    case Path.wildcard("/nix/store/*-cacert-*/etc/ssl/certs/ca-bundle.crt") do
      [path | _] -> {:ok, to_charlist(path)}
      [] -> {:error, :not_found}
    end
  end

  defp apply_ssl_config(path) do
    # For Erlang's :ssl application
    :ok = :ssl.setopts(:default, cacertfile: path)
    Logger.info("[SSLFix] Applied `cacertfile` to :ssl application.")

    # For Erlang's :public_key application (which was the source of the crash)
    :ok = :public_key.cacerts_load(path)
    Logger.info("[SSLFix] Loaded CA certs into :public_key application.")

    # For good measure, set the application env for OTP < 25
    Application.put_env(:ssl, :cacertfile, path)
  end
end
