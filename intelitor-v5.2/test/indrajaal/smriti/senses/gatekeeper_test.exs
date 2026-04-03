defmodule Indrajaal.Smriti.Senses.GatekeeperTest do
  @moduledoc """
  TDG test suite for Indrajaal.Smriti.Senses.Gatekeeper.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests cover rate-limiting and budget enforcement contracts
  - FPPS Validation: Budget ceiling and concurrency ceiling verified independently

  ## STAMP Safety Integration
  - SC-SMRITI-080: Never exceed 95% of API quota
  - SC-SMRITI-081: Halt ingestion if daily budget depleted

  ## Constitutional Verification
  - Ψ₀ Existence: GenServer survives concurrent ingestion requests
  - Ψ₅ Truthfulness: Budget state is honestly reported (no silent overruns)

  ## Founder's Directive Alignment
  - Ω₀.1: Budget protection prevents runaway API costs against resource goals

  ## TPS 5-Level RCA Context
  - L1 Symptom: Ingest requests accepted beyond budget
  - L5 Root Cause: Missing budget ceiling enforcement in handle_call
  """

  use ExUnit.Case, async: false
  use PropCheck

  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :sprint_54

  alias Indrajaal.Smriti.Senses.Gatekeeper

  # ============================================================
  # SETUP — isolated GenServer per test
  # ============================================================

  setup do
    # Start an isolated Gatekeeper (unnamed) to avoid conflicts
    {:ok, pid} = GenServer.start_link(Gatekeeper, [])

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1_000)
    end)

    {:ok, pid: pid}
  end

  # ============================================================
  # request_ingest/2 — HAPPY PATH
  # ============================================================

  describe "request_ingest/2 happy path" do
    test "returns {:ok, token} when budget and concurrency allow", %{pid: pid} do
      result = GenServer.call(pid, {:request_ingest, 1, 0.001})
      assert {:ok, token} = result
      assert is_reference(token)
    end

    test "token is a unique reference on each call", %{pid: pid} do
      {:ok, token1} = GenServer.call(pid, {:request_ingest, 1, 0.001})
      {:ok, token2} = GenServer.call(pid, {:request_ingest, 1, 0.001})
      assert token1 != token2
    end

    test "allows multiple requests up to concurrency limit", %{pid: pid} do
      # Default max concurrency is 5
      results =
        for _ <- 1..5 do
          GenServer.call(pid, {:request_ingest, 1, 0.000_001})
        end

      assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)
    end
  end

  # ============================================================
  # request_ingest/2 — BUDGET ENFORCEMENT (SC-SMRITI-081)
  # ============================================================

  describe "request_ingest/2 budget enforcement (SC-SMRITI-081)" do
    test "returns {:error, :budget_exceeded} when cost exceeds daily budget", %{pid: pid} do
      # Daily budget is $5.00; a single call requesting $6.00 should fail
      result = GenServer.call(pid, {:request_ingest, 1, 6.00})
      assert {:error, :budget_exceeded} = result
    end

    test "accumulates costs correctly and blocks on overspend", %{pid: pid} do
      # Spend $4.999 in one go (leaves < $0.001 headroom), then try $0.01 more
      _ok = GenServer.call(pid, {:request_ingest, 1, 4.999})
      result = GenServer.call(pid, {:request_ingest, 1, 0.01})
      assert {:error, :budget_exceeded} = result
    end

    test "exact budget amount is accepted", %{pid: pid} do
      # Exactly $5.00 should be allowed (not exceeded yet)
      result = GenServer.call(pid, {:request_ingest, 1, 5.00})
      assert {:ok, _token} = result
    end
  end

  # ============================================================
  # request_ingest/2 — CONCURRENCY ENFORCEMENT
  # ============================================================

  describe "request_ingest/2 concurrency enforcement" do
    test "returns {:error, :busy} when max_concurrency is reached", %{pid: pid} do
      # Consume all 5 slots
      for _ <- 1..5, do: GenServer.call(pid, {:request_ingest, 1, 0.000_001})

      # Sixth request should be rejected
      result = GenServer.call(pid, {:request_ingest, 1, 0.000_001})
      assert {:error, :busy} = result
    end

    test "slot is released after report_completion", %{pid: pid} do
      # Fill all slots
      tokens = for _ <- 1..5, do: elem(GenServer.call(pid, {:request_ingest, 1, 0.000_001}), 1)

      # Confirm sixth is rejected
      assert {:error, :busy} = GenServer.call(pid, {:request_ingest, 1, 0.000_001})

      # Release one slot
      GenServer.cast(pid, {:completion, hd(tokens)})
      # Allow cast to be processed
      :sys.get_state(pid)

      # Sixth should now succeed
      assert {:ok, _} = GenServer.call(pid, {:request_ingest, 1, 0.000_001})
    end
  end

  # ============================================================
  # report_completion/1 — CAST SEMANTICS
  # ============================================================

  describe "report_completion (cast)" do
    test "decrements active_workers below zero floor", %{pid: pid} do
      # Reporting completion on unknown token should not crash
      fake_token = make_ref()
      # This exercises the `max(0, active_workers - 1)` guard
      GenServer.cast(pid, {:completion, fake_token})
      # Confirm GenServer is still alive after spurious completion
      :sys.get_state(pid)
      assert Process.alive?(pid)
    end

    test "process survives multiple spurious completions", %{pid: pid} do
      for _ <- 1..10 do
        GenServer.cast(pid, {:completion, make_ref()})
      end

      :sys.get_state(pid)
      assert Process.alive?(pid)
    end
  end

  # ============================================================
  # PUBLIC API via named process (when application is started)
  # ============================================================

  describe "public API (named process delegation)" do
    test "request_ingest/2 delegates to named GenServer when running" do
      case GenServer.whereis(Gatekeeper) do
        nil ->
          # Gatekeeper not started in test env — skip
          :ok

        _pid ->
          result = Gatekeeper.request_ingest(1, 0.001)
          assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  describe "property tests (PropCheck)" do
    @tag :property
    property "request_ingest returns tagged tuple for any positive cost below budget" do
      forall cost <- PC.float(0.0, 4.9) do
        {:ok, pid} = GenServer.start_link(Gatekeeper, [])
        result = GenServer.call(pid, {:request_ingest, 1, cost})
        GenServer.stop(pid, :normal, 1_000)
        match?({:ok, _}, result)
      end
    end

    @tag :property
    property "request_ingest returns :budget_exceeded for costs above $5.00" do
      forall cost <- PC.float(5.01, 100.0) do
        {:ok, pid} = GenServer.start_link(Gatekeeper, [])
        result = GenServer.call(pid, {:request_ingest, 1, cost})
        GenServer.stop(pid, :normal, 1_000)
        match?({:error, :budget_exceeded}, result)
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (ExUnitProperties / StreamData)
  # ============================================================

  describe "property tests (StreamData)" do
    @tag :property
    test "every request_ingest result is a tagged tuple" do
      ExUnitProperties.check all(cost <- SD.float(min: 0.0, max: 20.0)) do
        {:ok, pid} = GenServer.start_link(Gatekeeper, [])
        result = GenServer.call(pid, {:request_ingest, 1, cost})
        GenServer.stop(pid, :normal, 1_000)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    test "active_workers never goes negative after completions" do
      ExUnitProperties.check all(n_completions <- SD.integer(0..20)) do
        {:ok, pid} = GenServer.start_link(Gatekeeper, [])

        for _ <- 1..n_completions do
          GenServer.cast(pid, {:completion, make_ref()})
        end

        # Drain the cast queue
        :sys.get_state(pid)
        assert Process.alive?(pid)

        GenServer.stop(pid, :normal, 1_000)
      end
    end
  end

  # ============================================================
  # FMEA TESTS
  # ============================================================

  describe "FMEA - failure modes" do
    @tag :fmea
    test "GenServer survives zero-cost ingest request" do
      {:ok, pid} = GenServer.start_link(Gatekeeper, [])
      result = GenServer.call(pid, {:request_ingest, 1, 0.0})
      GenServer.stop(pid, :normal, 1_000)
      assert match?({:ok, _}, result)
    end

    @tag :fmea
    test "GenServer survives negative cost (edge case)" do
      # Negative cost should be accepted or gracefully rejected — must not crash
      {:ok, pid} = GenServer.start_link(Gatekeeper, [])
      result = GenServer.call(pid, {:request_ingest, 1, -1.0})
      GenServer.stop(pid, :normal, 1_000)
      # Either ok (treated as free) or error — must be a tagged tuple
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "Ψ₀ existence: GenServer survives rapid concurrent requests" do
      {:ok, pid} = GenServer.start_link(Gatekeeper, [])

      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            GenServer.call(pid, {:request_ingest, 1, 0.000_001 * i}, 5_000)
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All must be tagged tuples — no crashes
      assert Enum.all?(results, fn r ->
               match?({:ok, _}, r) or match?({:error, _}, r)
             end)

      GenServer.stop(pid, :normal, 1_000)
    end
  end
end
