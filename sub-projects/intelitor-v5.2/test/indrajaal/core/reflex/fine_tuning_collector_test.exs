defmodule Indrajaal.Core.Reflex.FineTuningCollectorTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Core.Reflex.FineTuningCollector

  setup do
    # PubSub is already started by the application — don't re-start it
    {:ok, pid} = FineTuningCollector.start_link(name: :test_ft_collector)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{pid: pid}
  end

  describe "stats/0" do
    test "returns initial statistics", %{pid: pid} do
      stats = GenServer.call(pid, :stats)
      assert stats.total_pairs == 0
      assert stats.pairs_since_finetune == 0
      assert stats.last_finetune_at == nil
      assert stats.finetune_threshold == 100
      assert stats.progress_pct == 0.0
      refute is_nil(stats.started_at)
    end
  end

  describe "record_pair/4" do
    test "increments pair counters", %{pid: pid} do
      GenServer.cast(pid, {:record_pair, "input text", "output text", "gpt-4", :summarize})
      :timer.sleep(10)

      stats = GenServer.call(pid, :stats)
      assert stats.total_pairs == 1
      assert stats.pairs_since_finetune == 1
    end

    test "broadcasts training pair to PubSub", %{pid: pid} do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:fine_tuning")

      GenServer.cast(pid, {:record_pair, "test input", "test output", "model-x", :classify})

      assert_receive {:training_pair, %{input: "test input", output: "test output"}}, 500
    end

    test "accumulates multiple pairs", %{pid: pid} do
      for i <- 1..5 do
        GenServer.cast(pid, {:record_pair, "input #{i}", "output #{i}", "model", :task})
      end

      :timer.sleep(50)

      stats = GenServer.call(pid, :stats)
      assert stats.total_pairs == 5
      assert stats.pairs_since_finetune == 5
      assert stats.progress_pct == 5.0
    end
  end

  describe "finetune threshold" do
    test "triggers finetune when threshold reached", %{pid: pid} do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:fine_tuning")

      # Set state to just below threshold
      :sys.replace_state(pid, fn state ->
        %{state | pairs_since_finetune: 99, total_pairs: 99}
      end)

      # This push should trigger the finetune
      GenServer.cast(pid, {:record_pair, "final", "output", "model", :task})
      :timer.sleep(50)

      assert_receive {:finetune_triggered, %{pairs: 100}}, 1000

      # Counter should be reset after trigger
      stats = GenServer.call(pid, :stats)
      assert stats.pairs_since_finetune == 0
      assert stats.total_pairs == 100
      refute is_nil(stats.last_finetune_at)
    end
  end

  describe "handle_info catch-all" do
    test "ignores unknown messages", %{pid: pid} do
      send(pid, :some_random_message)
      assert Process.alive?(pid)
    end
  end
end
