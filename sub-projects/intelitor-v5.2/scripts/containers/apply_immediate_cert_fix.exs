#!/usr/bin/env elixir

defmodule ApplyImmediateCertFix do
  @moduledoc """
  Apply immediate SSL certificate fix to running NixOS container
  
  This script fixes the `:no_cacerts_found` error in Erlang's pubkey_os_cacerts
  by properly installing CA certificates in the container.
  
  Based on TPS 5-Level RCA analysis of SSL certificate issues in NixOS containers.
  """

  @spec main(any()) :: any()
  def main(_args) do
    IO.puts """
    🔧 Applying Immediate Certificate Fix
    ====================================
    Date: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    Container: indrajaal-compile
    """
    
    apply_cert_fix("indrajaal-compile")
  end

  @spec apply_cert_fix(String.t()) :: any()
  defp apply_cert_fix(container_name) do
    IO.puts "\n🔧 Applying certificate fix to #{container_name}..."
    
    # Step 1: Install nss-cacert if not already installed
    IO.puts "📦 Installing CA certificates package..."
    case System.cmd("podman", ["exec", container_name, "sh", "-c", "nix-env -iA nixpkgs.cacert"]) do
      {output, 0} ->
        IO.puts "✅ CA certificates package installed: #{String.trim(output)}"
      {error, _} ->
        IO.puts "⚠️ CA package install warning: #{error}"
    end
    
    # Step 2: Find actual CA bundle file in Nix store
    IO.puts "📁 Finding CA bundle in Nix store..."
    case System.cmd("podman", ["exec", container_name, "sh", "-c", "find /nix/store -name 'ca-bundle.crt' -type f | head -1"]) do
      {ca_bundle_path, 0} ->
        ca_bundle_path = String.trim(ca_bundle_path)
        IO.puts "✅ Found CA bundle: #{ca_bundle_path}"
        
        # Step 3: Create /etc/ssl/certs directory and copy CA bundle
        IO.puts "🔧 Setting up certificate structure..."
        commands = [
          {"mkdir -p /etc/ssl/certs", "Creating certificate directory"},
          {"cp #{ca_bundle_path} /etc/ssl/certs/ca-bundle.crt", "Copying CA bundle"},
          {"ls -la /etc/ssl/certs/ca-bundle.crt", "Verifying installation"}
        ]
        
        Enum.each(commands, fn {cmd, desc} ->
          IO.puts "   #{desc}..."
          case System.cmd("podman", ["exec", container_name, "sh", "-c", cmd]) do
            {output, 0} ->
              if String.contains?(cmd, "ls -la") do
                IO.puts "✅ Certificate verified: #{String.trim(output)}"
              else
                IO.puts "✅ Success"
              end
            {error, _} ->
              IO.puts "❌ Command failed: #{cmd} - #{error}"
          end
        end)
        
        # Step 4: Test certificate access
        test_certificate_access(container_name)
        
      {error, _} ->
        IO.puts "❌ Could not find CA bundle: #{error}"
    end
  end

  @spec test_certificate_access(String.t()) :: any()
  defp test_certificate_access(container_name) do
    IO.puts "\n🧪 Testing certificate access..."
    
    test_cmd = """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt && \\
    export CURL_CA_BUNDLE=$SSL_CERT_FILE && \\
    export NIX_SSL_CERT_FILE=$SSL_CERT_FILE && \\
    echo "SSL_CERT_FILE: $SSL_CERT_FILE" && \\
    ls -la /etc/ssl/certs/ca-bundle.crt && \\
    echo "Certificate file exists and is readable"
    """
    
    case System.cmd("podman", ["exec", container_name, "sh", "-c", test_cmd]) do
      {output, 0} ->
        IO.puts "✅ Certificate test passed:"
        IO.puts String.trim(output)
        IO.puts "\n🎯 Certificate fix applied successfully!"
        IO.puts "📋 Ready for patient mode compilation"
      {error, _} ->
        IO.puts "❌ Certificate test failed: #{error}"
    end
  end
end

# Execute the fix
ApplyImmediateCertFix.main(System.argv())