#!/usr/bin/env elixir

# Mix.install([{:jason, "~> 1.4"}]) # Removed for mix run context
require Logger

# Load the project code (assuming we are in project root)
# This script assumes the app is compiled or code is available.
# Since we are outside `mix run`, we need to ensure paths.
# But for simplicity, we will just redefine the Control module path if needed, 
# OR rely on mix run. Let's use `mix run` for this script to have environment.

defmodule LoggingVerification do
  alias Indrajaal.Logging.Control

  def run do
    IO.puts("🧪 Starting Logging Control Verification...")

    # 1. Verify Sampling
    IO.puts("1️⃣  Verifying Sampling Rate (1:10)")
    Control.update(:test_verify, %{level: :info, sampling_rate: 10})
    
    samples = 10_000
    allowed = 
      Enum.count(1..samples, fn _ -> 
        Control.should_log?(:test_verify, :info) 
      end)
    
    rate = allowed / samples
    IO.puts("   Samples: #{samples}, Allowed: #{allowed}, Rate: #{rate}")
    
    if rate > 0.08 and rate < 0.12 do
      IO.puts("   ✅ Sampling rate within expected range (0.1 +/- 0.02)")
    else
      IO.puts("   ❌ Sampling rate deviation too high!")
      exit({:shutdown, 1})
    end

    # 2. Verify Level Filtering
    IO.puts("2️⃣  Verifying Level Filtering (Min: :warning)")
    Control.update(:test_verify, %{level: :warning, sampling_rate: 1})
    
    if Control.should_log?(:test_verify, :info) do
      IO.puts("   ❌ Info log allowed when min level is Warning")
      exit({:shutdown, 1})
    else
      IO.puts("   ✅ Info log correctly suppressed")
    end

    if Control.should_log?(:test_verify, :warning) do
      IO.puts("   ✅ Warning log allowed")
    else
      IO.puts("   ❌ Warning log suppressed incorrectly")
      exit({:shutdown, 1})
    end

    # 3. Verify Critical Passthrough
    IO.puts("3️⃣  Verifying Critical Passthrough (SC-LOG-001)")
    # Set impossible sampling
    Control.update(:test_verify, %{level: :info, sampling_rate: 1_000_000})
    
    if Control.should_log?(:test_verify, :error) do
      IO.puts("   ✅ Error log allowed despite high sampling")
    else
      IO.puts("   ❌ Error log suppressed by sampling! VIOLATION!")
      exit({:shutdown, 1})
    end

    if Control.should_log?(:test_verify, :critical) do
      IO.puts("   ✅ Critical log allowed despite high sampling")
    else
      IO.puts("   ❌ Critical log suppressed by sampling! VIOLATION!")
      exit({:shutdown, 1})
    end

    IO.puts("\n🎉 ALL LOGGING VERIFICATION TESTS PASSED")
  end
end

LoggingVerification.run()
