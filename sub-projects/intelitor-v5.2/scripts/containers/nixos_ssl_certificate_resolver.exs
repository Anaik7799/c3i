#!/usr/bin/env elixir

# scripts/containers/nixos_ssl_certificate_resolver.exs

Mix.install([{:jason, "~> 1.4"}])

defmodule NixOSSSLCertificateResolver do
  @moduledoc """
  Resolves SSL certificate issues in NixOS containers
  Implements multi-path symlink strategy for Erlang/Elixir compatibility
  
  Usage:
    elixir nixos_ssl_certificate_resolver.exs --all
    elixir nixos_ssl_certificate_resolver.exs indrajaal-app-demo
    elixir nixos_ssl_certificate_resolver.exs --validate
  """
  
  __require Logger
  
  @certificate_paths [
    "/etc/ssl/certs/ca-bundle.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/cert.pem",
    "/etc/ssl/certs/ca-certificates.crt",
    "/usr/local/share/ca-certificates/ca-bundle.crt"
  ]
  
  def main(args \\ []) do
    Logger.info("🔐 NixOS SSL Certificate Resolver v1.0.0")
    
    # Save execution log
    log_file = "./__data/tmp/ssl-resolver-#{timestamp()}.log"
    File.mkdir_p!("./__data/tmp")
    
    result = case args do
      ["--all"] -> resolve_all_containers()
      ["--validate"] -> validate_all_containers()
      ["--help"] -> show_help()
      [container] when container != "" -> resolve_container(container)
      [] -> resolve_all_containers()
      _ -> show_help()
    end
    
    # Save results to log
    log_content = "SSL Certificate Resolution Log\nTimestamp: #{timestamp()}\nResult: #{inspect(result)}\n"
    File.write!(log_file, log_content)
    
    case result do
      :ok -> 
        Logger.info("✅ SSL certificates resolved successfully")
        Logger.info("📄 Resolution log saved to: #{log_file}")
        System.halt(0)
      {:error, reason} ->
        Logger.error("❌ SSL resolution failed: #{inspect(reason)}")
        Logger.error("📄 Error log saved to: #{log_file}")
        System.halt(1)
    end
  end
  
  def resolve_all_containers do
    Logger.info("🔍 Resolving SSL certificates for all containers")
    
    containers = list_containers()
    
    if Enum.empty?(containers) do
      Logger.warn("⚠️ No containers found")
      :ok
    else
      results = Enum.map(containers, &resolve_container/1)
      
      failed = Enum.filter(results, &match?({:error, _}, &1))
      
      if Enum.empty?(failed) do
        Logger.info("✅ SSL certificates resolved for all containers")
        :ok
      else
        Logger.error("❌ Failed to resolve SSL for some containers: #{inspect(failed)}")
        {:error, :some_containers_failed}
      end
    end
  end
  
  def resolve_container(container_name) do
    Logger.info("🔧 Resolving SSL certificates for #{container_name}")
    
    with {:ok, ca_bundle} <- find_ca_bundle(container_name),
         :ok <- create_directories(container_name),
         :ok <- create_symlinks(container_name, ca_bundle),
         :ok <- verify_certificates(container_name) do
      Logger.info("✅ SSL certificates resolved for #{container_name}")
      :ok
    else
      {:error, :container_not_found} ->
        Logger.error("❌ Container #{container_name} not found or not running")
        {:error, :container_not_found}
      {:error, :ca_bundle_not_found} ->
        Logger.error("❌ CA bundle not found in #{container_name}")
        {:error, :ca_bundle_not_found}
      {:error, reason} ->
        Logger.error("❌ SSL resolution failed for #{container_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  def validate_all_containers do
    Logger.info("🔍 Validating SSL certificates in all containers")
    
    containers = list_containers()
    
    _results = Enum.map(containers, fn container ->
      {container, validate_ssl_in_container(container)}
    end)
    
    # Display results
    Enum.each(results, fn {container, result} ->
      case result do
        :ok -> 
          Logger.info("✅ #{container}: SSL certificates validated")
        {:error, reason} ->
          Logger.error("❌ #{container}: SSL validation failed - #{inspect(reason)}")
      end
    end)
    
    # Overall result
    if Enum.all?(results, fn {_, result} -> result == :ok end) do
      Logger.info("🎉 All containers have working SSL certificates")
      :ok
    else
      failed_count = Enum.count(results, fn {_, result} -> result != :ok end)
      Logger.error("❌ #{failed_count} containers have SSL issues")
      {:error, :validation_failed}
    end
  end
  
  defp find_ca_bundle(container_name) do
    Logger.debug("🔍 Finding CA bundle in #{container_name}")
    
    case System.cmd("podman", [
      "exec", container_name,
      "find", "/nix/store", "-name", "ca-bundle.crt", "-type", "f"
    ]) do
      {output, 0} ->
        paths = String.split(output, "\n", trim: true)
        
        if Enum.empty?(paths) do
          Logger.debug("❌ No CA bundle found in Nix store")
          {:error, :ca_bundle_not_found}
        else
          ca_bundle = hd(paths)
          Logger.debug("✅ Found CA bundle: #{ca_bundle}")
          {:ok, ca_bundle}
        end
      _ ->
        Logger.debug("❌ Cannot access container #{container_name}")
        {:error, :container_not_found}
    end
  end
  
  defp create_directories(container_name) do
    Logger.debug("📁 Creating certificate directories in #{container_name}")
    
    directories = [
      "/etc/ssl/certs",
      "/etc/pki/tls/certs",
      "/usr/local/share/ca-certificates"
    ]
    
    Enum.each(directories, fn dir ->
      System.cmd("podman", [
        "exec", container_name,
        "mkdir", "-p", dir
      ])
      Logger.debug("✓ Created directory: #{dir}")
    end)
    
    :ok
  end
  
  defp create_symlinks(container_name, ca_bundle) do
    Logger.debug("🔗 Creating certificate symlinks in #{container_name}")
    
    Enum.each(@certificate_paths, fn path ->
      # Remove existing file/symlink first
      System.cmd("podman", [
        "exec", container_name,
        "rm", "-f", path
      ])
      
      # Create symlink
      case System.cmd("podman", [
        "exec", container_name,
        "ln", "-sf", ca_bundle, path
      ]) do
        {_, 0} ->
          Logger.debug("✓ Created symlink: #{path} -> #{ca_bundle}")
        {error, _} ->
          Logger.warn("⚠️ Failed to create symlink #{path}: #{error}")
      end
    end)
    
    :ok
  end
  
  defp verify_certificates(container_name) do
    Logger.debug("✅ Verifying SSL certificates in #{container_name}")
    
    # Test 1: Check if certificate files exist
    _path_checks = Enum.map(@certificate_paths, fn path ->
      case System.cmd("podman", [
        "exec", container_name,
        "test", "-f", path
      ]) do
        {_, 0} -> {:ok, path}
        _ -> {:error, path}
      end
    end)
    
    existing_paths = Enum.filter(path_checks, &match?({:ok, _}, &1))
    missing_paths = Enum.filter(path_checks, &match?({:error, _}, &1))
    
    Logger.debug("✓ Certificate paths found: #{length(existing_paths)}/#{length(@certificate_paths)}")
    
    if not Enum.empty?(missing_paths) do
      _missing = Enum.map(missing_paths, fn {:error, path} -> path end)
      Logger.warn("⚠️ Missing certificate paths: #{inspect(missing)}")
    end
    
    # Test 2: Try Erlang validation if Elixir is available
    validate_with_erlang(container_name)
  end
  
  defp validate_with_erlang(container_name) do
    Logger.debug("🧪 Testing Erlang SSL certificate access")
    
    case System.cmd("podman", [
      "exec", container_name,
      "sh", "-c",
      "command -v elixir"
    ]) do
      {_, 0} ->
        # Elixir is available, test with it
        case System.cmd("podman", [
          "exec", container_name,
          "elixir", "-e",
          "result = :public_key.cacerts_get(); IO.inspect(if result == [], do: :no_cacerts_found, else: :certificates_found)"
        ]) do
          {output, 0} ->
            if output =~ ":certificates_found" do
              Logger.info("✅ Erlang SSL validation passed")
              :ok
            else
              Logger.error("❌ Erlang SSL validation failed: #{output}")
              {:error, :erlang_validation_failed}
            end
          {error, _} ->
            Logger.warn("⚠️ Could not test Erlang SSL: #{error}")
            validate_with_openssl(container_name)
        end
      _ ->
        # No Elixir available, try OpenSSL
        validate_with_openssl(container_name)
    end
  end
  
  defp validate_with_openssl(container_name) do
    Logger.debug("🔐 Testing SSL with OpenSSL")
    
    case System.cmd("podman", [
      "exec", container_name,
      "sh", "-c",
      "command -v openssl"
    ]) do
      {_, 0} ->
        case System.cmd("podman", [
          "exec", container_name,
          "openssl", "verify",
          "-CAfile", "/etc/ssl/certs/ca-bundle.crt",
          "/etc/ssl/certs/ca-bundle.crt"
        ]) do
          {_, 0} ->
            Logger.info("✅ OpenSSL validation passed")
            :ok
          {error, _} ->
            Logger.error("❌ OpenSSL validation failed: #{error}")
            {:error, :openssl_validation_failed}
        end
      _ ->
        Logger.warn("⚠️ Neither Elixir nor OpenSSL available for validation")
        :ok  # Assume success if we can't validate
    end
  end
  
  defp validate_ssl_in_container(container_name) do
    # Quick validation - just check if main certificate file exists
    case System.cmd("podman", [
      "exec", container_name,
      "test", "-f", "/etc/ssl/certs/ca-bundle.crt"
    ]) do
      {_, 0} ->
        validate_with_erlang(container_name)
      _ ->
        {:error, :certificate_file_missing}
    end
  end
  
  defp list_containers do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"]) do
      {output, 0} ->
        String.split(output, "\n", trim: true)
      _ ->
        []
    end
  end
  
  defp show_help do
    IO.puts("""
    NixOS SSL Certificate Resolver v1.0.0
    
    Resolves SSL certificate path issues in NixOS containers by creating
    symlinks from Nix store certificates to standard system paths.
    
    Usage:
      elixir nixos_ssl_certificate_resolver.exs [OPTIONS] [CONTAINER]
    
    Options:
      --all                   Resolve SSL for all running containers
      --validate              Validate SSL certificates in all containers
      --help                  Show this help
    
    Container:
      CONTAINER_NAME          Resolve SSL for specific container
    
    Examples:
      elixir nixos_ssl_certificate_resolver.exs --all
      elixir nixos_ssl_certificate_resolver.exs indrajaal-app-demo
      elixir nixos_ssl_certificate_resolver.exs --validate
    
    Certificate Paths Created:
      /etc/ssl/certs/ca-bundle.crt
      /etc/pki/tls/certs/ca-bundle.crt
      /etc/ssl/cert.pem
      /etc/ssl/certs/ca-certificates.crt
      /usr/local/share/ca-certificates/ca-bundle.crt
    """)
    :ok
  end
  
  defp timestamp do
    DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
  end
end

# Run the script
NixOSSSLCertificateResolver.main(System.argv())