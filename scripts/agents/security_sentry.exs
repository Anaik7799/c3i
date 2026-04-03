defmodule Indrajaal.Agents.SecuritySentry do
  @moduledoc """
  SIL6 Security Sentry for static analysis and dependency auditing.
  """

  def audit_security() do
    IO.puts("INITIATING SIL6 SECURITY AUDIT...")
    
    # 1. Static Analysis (Sobelow)
    IO.puts("PROBING VULNERABILITIES (Sobelow)...")
    {sobelow_out, _} = System.cmd("mix", ["sobelow", "--quiet", "--format", "json"])
    
    # 2. Dependency Audit
    IO.puts("PROBING DEPENDENCY INTEGRITY...")
    {audit_out, _} = System.cmd("mix", ["hex.audit"])
    
    IO.puts("RESULT: AUDIT COMPLETE")
    %{sobelow: sobelow_out, audit: audit_out}
  end
end

case System.argv() do
  ["--audit"] -> 
    Indrajaal.Agents.SecuritySentry.audit_security()
  _ -> 
    IO.puts("Security Sentry active.")
end
