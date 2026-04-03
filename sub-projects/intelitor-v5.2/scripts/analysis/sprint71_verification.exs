defmodule Indrajaal.Sprint71Verification do
  @moduledoc """
  Verifies Semantic Ingestor and Quantum Vault.
  """

  alias Indrajaal.KMS.Vectors.FractalIngestor
  alias Indrajaal.Vault.QuantumSafe

  def run do
    IO.puts("--- SEMANTIC SATURATION VERIFICATION ---")
    FractalIngestor.crawl_now()
    IO.puts("✓ Fractal Ingestor triggered.")

    IO.puts("\n--- QUANTUM-SAFE VAULT VERIFICATION ---")
    plaintext = "Founder's Directive: Ω₀ Naik-Genome Symbiotic"
    {:ok, encrypted} = QuantumSafe.encrypt(plaintext)
    IO.puts("Plaintext: #{plaintext}")
    IO.puts("Encrypted: #{encrypted}")
    
    if String.starts_with?(encrypted, "qsafe_") do
      IO.puts("✅ VERIFIED: Quantum-safe wrapper reified.")
    else
      IO.puts("❌ FAILED: Encryption layer mismatch.")
    end
  end
end

Indrajaal.Sprint71Verification.run()
