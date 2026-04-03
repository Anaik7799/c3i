# Script to verify SIL-6 Saga Functionality
# Run with: mix run scripts/testing/verify_sil6_saga.exs

require Logger

Logger.info("🧪 Starting SIL-6 Saga Verification...")

# 1. Define a Mock Saga
step1 = %{
  name: "Allocate Resource",
  execute: fn ctx -> 
    Logger.info("  [Step 1] Allocating...")
    {:ok, Map.put(ctx, :resource_id, 123)}
  end,
  compensate: fn ctx -> 
    Logger.info("  [Step 1] Deallocating #{ctx.resource_id}...")
    :ok
  end
}

step2_fail = %{
  name: "Critical Operation",
  execute: fn _ctx -> 
    Logger.info("  [Step 2] Attempting critical op...")
    {:error, :simulated_failure}
  end,
  compensate: fn _ -> :ok end
}

# 2. Run Saga (Expect Failure & Rollback)
Logger.info("--- TEST 1: Failure & Rollback ---")
Indrajaal.Transactions.SagaManager.start_saga("TestFailSaga", [step1, step2_fail])

# Wait for async execution
Process.sleep(1000)

# 3. Run Saga (Success)
step2_success = %{
  name: "Critical Operation",
  execute: fn ctx -> 
    Logger.info("  [Step 2] Success! Resource: #{ctx.resource_id}")
    {:ok, ctx}
  end,
  compensate: fn _ -> :ok end
}

Logger.info("--- TEST 2: Success ---")
Indrajaal.Transactions.SagaManager.start_saga("TestSuccessSaga", [step1, step2_success])

Process.sleep(1000)
Logger.info("✅ Verification Complete.")
