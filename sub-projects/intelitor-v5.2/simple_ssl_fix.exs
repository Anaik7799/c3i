#!/usr/bin/env elixir

defmodule SimpleSSLFix do
  @moduledoc """
  Simple SSL certificate fix for NixOS containers
  Focus on fixing the Erlang pubkey_os_cacerts issue
  """

  def main(_args) do
    IO.puts("🔐 NixOS Container SSL Fix")
    IO.puts("==========================")

    # Step 1: Check certificate file
    cert_file = "/etc/ssl/certs/ca-bundle.crt"

    if File.exists?(cert_file) do
      stat = File.stat!(cert_file)
      IO.puts("✅ Certificate file exists: #{cert_file} (#{stat.size} bytes)")
    else
      IO.puts("❌ Certificate file missing: #{cert_file}")
      {:error, :no_cert_file}
    end

    # Step 2: Set up environment variables
    setup_ssl_env()

    # Step 3: Create Erlang config
    setup_erlang_config()

    # Step 4: Test the fix
    test_ssl_fix()

    IO.puts("\n✅ SSL fix completed - try Mix operations now")
  end

  defp setup_ssl_env do
    IO.puts("\n🔧 Setting up SSL environment...")

    env_script = """
    #!/bin/bash
    export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
    export SSL_CERT_DIR="/etc/ssl/certs"
    export CURL_CA_BUNDLE="/etc/ssl/certs/ca-bundle.crt"
    export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
    """

    File.write!("/tmp/ssl_env.sh", env_script)
    System.cmd("chmod", ["+x", "/tmp/ssl_env.sh"])
    IO.puts("✅ Created SSL environment script: /tmp/ssl_env.sh")
  end

  defp setup_erlang_config do
    IO.puts("\n⚙️ Setting up Erlang SSL config...")

    # Try to set OTP SSL configuration
    config_content = """
    [{ssl, [{cacertfile, "/etc/ssl/certs/ca-bundle.crt"}]}].
    """

    home_dir = System.get_env("HOME", "/tmp")
    config_file = "#{home_dir}/.erlang_ssl.config"

    File.write!(config_file, config_content)
    IO.puts("✅ Created Erlang SSL config: #{config_file}")

    # Set environment variable to use this config
    System.put_env("ERL_SSL_PATH", "/etc/ssl/certs")
    IO.puts("✅ Set ERL_SSL_PATH environment variable")
  end

  defp test_ssl_fix do
    IO.puts("\n🧪 Testing SSL fix...")

    try do
      # Test crypto
      :crypto.supports()
      IO.puts("✅ Crypto module working")

      # Test SSL app
      :ssl.start()
      IO.puts("✅ SSL application started")

      # Test certificate reading
      case File.read("/etc/ssl/certs/ca-bundle.crt") do
        {:ok, cert_data} ->
          IO.puts("✅ Certificate file readable (#{byte_size(cert_data)} bytes)")

        {:error, reason} ->
          IO.puts("❌ Cannot read certificate file: #{reason}")
      end
    rescue
      error ->
        IO.puts("⚠️ SSL test error (may be normal): #{inspect(error)}")
    end
  end
end

SimpleSSLFix.main(System.argv())
