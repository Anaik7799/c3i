alias Indrajaal.Prometheus.Verifier
alias Indrajaal.Analysis.ShannonAuditor

# 1. Setup - Create a low-entropy baseline file
path = "data/tmp/entropy_test.ex"
File.write!(path, "defmodule Test do def ok, do: :ok end")

%{entropy: h_base} = ShannonAuditor.audit_file(path)
IO.puts("Baseline Entropy: #{h_base}")

# 2. Test - Minor change (should pass)
File.write!(path, "defmodule Test do def ok, do: :ok; def pass, do: :ok end")
case Verifier.verify_semantic_entropy(path, h_base) do
  :ok -> IO.puts("✅ PASS: Minor change accepted")
  error -> IO.puts("❌ FAIL: Minor change rejected: #{inspect(error)}")
end

# 3. Test - Entropy surge (garbage injection)
garbage = for _ <- 1..1000, into: "", do: <<:rand.uniform(255)>>
File.write!(path, garbage)
case Verifier.verify_semantic_entropy(path, h_base) do
  {:error, {:constraint_violation, :shannon_entropy_surge_detected}} -> 
    IO.puts("✅ PASS: Entropy surge correctly blocked")
  other -> 
    IO.puts("❌ FAIL: Surge not blocked as expected: #{inspect(other)}")
end

# 4. Test - Entropy surge with justification (should pass)
claims = %{complexity_justification: "This is a formal justification for the increased complexity required by the quantum-safe vault integration. It exceeds the 50 byte threshold."}
case Verifier.verify_semantic_entropy(path, h_base, claims) do
  :ok -> IO.puts("✅ PASS: Surge accepted with justification")
  error -> IO.puts("❌ FAIL: Surge rejected despite justification: #{inspect(error)}")
end

File.rm(path)
