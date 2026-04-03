defmodule Indrajaal.Agents.EnvSentinel do
  @moduledoc """
  Audits the Nix/Devenv substrate for SIL6 deterministic compliance.
  """

  def audit_environment() do
    IO.puts("INITIATING SIL6 SUBSTRATE AUDIT...")
    
    # 1. Check devenv configuration
    if File.exists?("devenv.nix") do
      IO.puts("RESULT: DEVENV SUBSTRATE DETECTED")
      # Audit packages defined in devenv
      {out, _} = System.cmd("grep", ["-A", "20", "packages =", "devenv.nix"])
      IO.puts("PROBING PACKAGE INVENTORY:")
      IO.puts(out)
    else
      IO.puts("RESULT: DEVENV CONFIGURATION MISSING")
    end
    
    # 2. Check Nix shell status
    case System.get_env("IN_NIX_SHELL") do
      nil -> IO.puts("RESULT: NOT IN NIX-SHELL (Determinism Warning)")
      _ -> IO.puts("RESULT: NIX-SHELL ACTIVE (Deterministic Path)")
    end
  end
end

case System.argv() do
  ["--audit"] -> Indrajaal.Agents.EnvSentinel.audit_environment()
  _ -> IO.puts("Environment Sentinel ready for substrate verification.")
end
