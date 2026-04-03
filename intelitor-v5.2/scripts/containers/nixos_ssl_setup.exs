#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule NixOSSSLSetup do
  @moduledoc """
  Automated SSL certificate setup for NixOS containers
  Implements TPS 5-Level RCA solution for SSL certificate issues
  
  TPS Analysis Applied:
  Level 5: Design Philosophy - Comprehensive certificate path strategy
  Level 4: Configuration Gap - Missing symlinks from NixOS paths to expected paths  
  Level 3: System Behavior - Erlang certificate lookup system incompatible with NixOS
  Level 2: Surface Cause - Missing certificate paths
  Level 1: Symptom - Mix operations failing with SSL errors
  
  STAMP Safety Constraints:
  SC-SSL-001: System SHALL load minimum 100 SSL certificates
  SC-SSL-002: System SHALL provide certificates at all expected Erlang paths
  SC-SSL-003: System SHALL validate certificate accessibility before completion
  """
  
  def main(args) do
    IO.puts("🔒 NixOS SSL Certificate Setup - TPS 5-Level RCA Solution")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Date: #{DateTime.utc_now() |> DateTime.to_string()}")
    IO.puts("")
    
    container = get_container_name(args)
    automated = Enum.member?(args, "--automated")
    debug = Enum.member?(args, "--debug")
    validate_only = Enum.member?(args, "--validate")
    
    IO.puts("Container: #{container}")
    IO.puts("Mode: #{if automated, do: "Automated", else: "Interactive"}")
    IO.puts("")
    
    if validate_only do
      validate_ssl_setup(container, debug)
    else
      setup_ssl_certificates(container, automated, debug)
    end
  end
  
  def setup_ssl_certificates(container, _automated, debug) do
    IO.puts("🔍 Phase 1: Locating CA certificate bundles in Nix store...")
    
    # Find all available CA certificate bundles in Nix store
    ca_bundles = find_nix_ca_bundles(container, debug)
    
    if Enum.empty?(ca_bundles) do
      IO.puts("❌ CRITICAL: No CA certificate bundles found in Nix store")
      IO.puts("This violates STAMP Safety Constraint SC-SSL-001")
      System.halt(1)
    end
    
    # Use the first available bundle (most recent)
    primary_bundle = hd(ca_bundles)
    IO.puts("📋 Primary CA bundle selected: #{primary_bundle}")
    
    if length(ca_bundles) > 1 and debug do
      IO.puts("🔍 Additional bundles found:")
      ca_bundles
      |> Enum.drop(1)
      |> Enum.each(fn bundle -> IO.puts("   - #{bundle}") end)
    end
    
    IO.puts("")
    IO.puts("🔧 Phase 2: Creating comprehensive certificate symlinks...")
    
    # Create comprehensive symlink strategy (TPS Level 5 Solution)
    create_certificate_directories(container, debug)
    setup_certificate_symlinks(container, primary_bundle, debug)
    
    IO.puts("")
    IO.puts("✅ Phase 3: Validating SSL certificate configuration...")
    
    # Validate SSL configuration (STAMP Safety Constraints)
    validate_ssl_setup(container, debug)
    
    IO.puts("")
    IO.puts("🎉 SSL certificate setup completed successfully!")
    IO.puts("TPS 5-Level RCA solution implemented and validated")
  end
  
  defp find_nix_ca_bundles(container, debug) do
    if debug, do: IO.puts("🔍 Searching Nix store for CA certificate bundles...")
    
    case System.cmd("podman", [
      "exec", container, "find", "/nix/store", 
      "-name", "ca-bundle.crt", "-type", "f"
    ]) do
      {output, 0} ->
        bundles = output
        |> String.trim()
        |> String.split("\\n")
        |> Enum.reject(&(&1 == ""))
        
        if debug do
          IO.puts("Found #{length(bundles)} CA certificate bundles:")
          Enum.each(bundles, fn bundle -> IO.puts("   - #{bundle}") end)
        end
        
        bundles
        
      {error, exit_code} ->
        IO.puts("❌ Error searching for CA bundles (exit code: #{exit_code})")
        IO.puts("Error output: #{error}")
        []
    end
  end
  
  defp create_certificate_directories(container, debug) do
    directories = ["/etc/ssl/certs", "/etc/pki/tls/certs"]
    
    Enum.each(directories, fn dir ->
      if debug, do: IO.puts("📁 Creating directory: #{dir}")
      
      case System.cmd("podman", ["exec", container, "mkdir", "-p", dir]) do
        {_output, 0} -> 
          if debug, do: IO.puts("   ✅ Directory created: #{dir}")
        {error, exit_code} ->
          IO.puts("   ❌ Failed to create directory #{dir} (exit code: #{exit_code}): #{error}")
      end
    end)
  end
  
  defp setup_certificate_symlinks(container, ca_bundle_path, _debug) do
    # Comprehensive certificate paths based on TPS 5-Level RCA
    certificate_paths = [
      "/etc/ssl/certs/ca-bundle.crt",
      "/etc/pki/tls/certs/ca-bundle.crt", 
      "/etc/ssl/certs/ca-certificates.crt",
      "/etc/ssl/cert.pem"
    ]
    
    IO.puts("Creating #{length(certificate_paths)} certificate symlinks...")
    
    Enum.each(certificate_paths, fn cert_path ->
      case System.cmd("podman", ["exec", container, "ln", "-sf", ca_bundle_path, cert_path]) do
        {_output, 0} ->
          IO.puts("🔗 ✅ #{cert_path} -> #{ca_bundle_path}")
        {error, exit_code} ->
          IO.puts("🔗 ❌ Failed to create #{cert_path} (exit code: #{exit_code}): #{error}")
      end
    end)
  end
  
  defp validate_ssl_setup(container, debug) do
    IO.puts("🧪 Running SSL validation tests...")
    
    # Test 1: Erlang certificate loading (Primary validation)
    {_cert_output, _cert_exit_code} = System.cmd("podman", [
      "exec", container, "elixir", "-e", 
      "IO.puts(length(:pubkey_os_cacerts.get()))"
    ])
    
    case cert_exit_code do
      0 ->
        cert_count = cert_output |> String.trim() |> String.to_integer()
        
        if cert_count >= 100 do
          IO.puts("✅ SSL Test 1: Certificate loading successful (#{cert_count} certificates)")
        else
          IO.puts("❌ SSL Test 1: Insufficient certificates loaded (#{cert_count} < 100)")
          IO.puts("STAMP Safety Constraint SC-SSL-001 VIOLATED")
          System.halt(1)
        end
        
      _ ->
        IO.puts("❌ SSL Test 1: Certificate loading failed")
        IO.puts("Error output: #{cert_output}")
        IO.puts("STAMP Safety Constraint SC-SSL-001 VIOLATED")
        System.halt(1)
    end
    
    # Test 2: Certificate file accessibility
    certificate_paths = [
      "/etc/ssl/certs/ca-bundle.crt",
      "/etc/pki/tls/certs/ca-bundle.crt",
      "/etc/ssl/certs/ca-certificates.crt", 
      "/etc/ssl/cert.pem"
    ]
    
    accessible_paths = Enum.filter(certificate_paths, fn path ->
      case System.cmd("podman", ["exec", container, "test", "-f", path]) do
        {_output, 0} -> true
        _ -> false
      end
    end)
    
    if length(accessible_paths) == length(certificate_paths) do
      IO.puts("✅ SSL Test 2: All certificate paths accessible (#{length(accessible_paths)}/#{length(certificate_paths)})")
    else
      IO.puts("❌ SSL Test 2: Missing certificate paths (#{length(accessible_paths)}/#{length(certificate_paths)})")
      IO.puts("STAMP Safety Constraint SC-SSL-002 VIOLATED")
      
      missing_paths = certificate_paths -- accessible_paths
      IO.puts("Missing paths:")
      Enum.each(missing_paths, fn path -> IO.puts("   - #{path}") end)
      
      System.halt(1)
    end
    
    # Test 3: Mix hex functionality (Integration test)
    {_hex_output, _hex_exit_code} = System.cmd("podman", [
      "exec", container, "sh", "-c", "cd /workspace && mix local.hex --force"
    ])
    
    case hex_exit_code do
      0 ->
        IO.puts("✅ SSL Test 3: Mix Hex integration successful")
      _ ->
        IO.puts("⚠️  SSL Test 3: Mix Hex integration failed (may be normal if Mix not fully setup)")
        if debug do
          IO.puts("Hex output: #{hex_output}")
        end
    end
    
    IO.puts("")
    IO.puts("🛡️ STAMP Safety Constraint Validation:")
    IO.puts("   ✅ SC-SSL-001: Minimum 100 certificates loaded")
    IO.puts("   ✅ SC-SSL-002: All certificate paths accessible") 
    IO.puts("   ✅ SC-SSL-003: Certificate accessibility validated")
  end
  
  defp get_container_name(args) do
    case Enum.find_index(args, &(&1 == "--container")) do
      nil -> "indrajaal-dev-app"  # default
      index -> Enum.at(args, index + 1, "indrajaal-dev-app")
    end
  end
end

# Help information
if Enum.member?(System.argv(), "--help") do
  IO.puts("""
  NixOS SSL Setup - TPS 5-Level RCA Solution
  
  Usage: elixir nixos_ssl_setup.exs [options]
  
  Options:
    --container NAME     Container name (default: indrajaal-dev-app)
    --automated          Run in automated mode (no prompts)
    --debug              Enable debug output  
    --validate           Only validate existing SSL setup
    --help               Show this help
    
  Examples:
    elixir nixos_ssl_setup.exs --automated
    elixir nixos_ssl_setup.exs --container my-container --debug
    elixir nixos_ssl_setup.exs --validate --debug
    
  STAMP Safety Constraints:
    SC-SSL-001: System SHALL load minimum 100 SSL certificates
    SC-SSL-002: System SHALL provide certificates at all expected paths
    SC-SSL-003: System SHALL validate certificate accessibility
  """)
  
  System.halt(0)
end

NixOSSSLSetup.main(System.argv())