# final_verification.exs

IO.puts "--- FINAL VERIFICATION PROTOCOL INITIATED ---"

# Step 1: Deep Clean
IO.puts "\n[PHASE 1] Sterilizing Environment..."
System.cmd("elixir", ["scripts/containers/vto_orchestrator.exs", "--action", "stop"])

# Step 2: Build Artifacts
IO.puts "\n[PHASE 2] Building Hardened Artifacts..."
System.cmd("podman", ["build", "-f", "Dockerfile.sopv51-base", "-t", "localhost/sopv51-base:latest", "."])
System.cmd("podman", ["build", "-f", "Dockerfile.sopv51-app", "-t", "localhost:5000/indrajaal-sopv51-elixir-app:nixos-devenv", "."])

# Step 3: Run CAFE Test Executor
IO.puts "\n[PHASE 3] Executing CAFE Test & Verification Plan..."
System.cmd("elixir", ["scripts/testing/ace_verification_engine.exs"])

# Step 4: Final Report
IO.puts "\n--- FINAL VERIFICATION PROTOCOL COMPLETE ---"
IO.puts "Review the output above for detailed results of each test phase."
