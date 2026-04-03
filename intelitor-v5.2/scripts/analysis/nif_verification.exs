defmodule Indrajaal.Analysis.NifVerification do
  @moduledoc """
  Verifies the MathNif against the Elixir auditor.
  """

  alias Indrajaal.Analysis.{ShannonAuditor, MathNif}

  def run do
    data = "Indrajaal v20.0.0 Singularity Verification Payload"
    
    IO.puts("--- ENTROPY VERIFICATION ---")
    elixir_h = ShannonAuditor.calculate_entropy(data)
    rust_h = MathNif.calculate_entropy(data)
    
    IO.puts("Elixir H: #{elixir_h}")
    IO.puts("Rust NIF H: #{rust_h}")
    
    if abs(elixir_h - rust_h) < 0.0001 do
      IO.puts("✅ VERIFIED: Parity achieved.")
    else
      IO.puts("❌ FAILED: Parity mismatch.")
    end

    IO.puts("\n--- PERFORMANCE TRIAGE ---")
    # Large data for performance check
    large_data = String.duplicate("ABCDEFGH", 100_000) # 800KB
    
    {t_elixir, _} = :timer.tc(fn -> ShannonAuditor.calculate_entropy(large_data) end)
    {t_rust, _} = :timer.tc(fn -> MathNif.calculate_entropy(large_data) end)
    
    IO.puts("Elixir: #{t_elixir} μs")
    IO.puts("Rust NIF: #{t_rust} μs")
    IO.puts("Acceleration: #{Float.round(t_elixir / t_rust, 2)}x")
  end
end

Indrajaal.Analysis.NifVerification.run()
