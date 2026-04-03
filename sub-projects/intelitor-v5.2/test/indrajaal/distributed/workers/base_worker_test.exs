defmodule Indrajaal.Distributed.Workers.BaseWorkerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Workers.BaseWorker

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(BaseWorker)
    end
  end

  describe "behaviour callbacks" do
    test "defines handle_job/2 callback" do
      callbacks = BaseWorker.behaviour_info(:callbacks)
      assert {:handle_job, 2} in callbacks
    end

    test "defines worker_init/1 callback" do
      callbacks = BaseWorker.behaviour_info(:callbacks)
      assert {:worker_init, 1} in callbacks
    end

    test "defines worker_state/1 callback" do
      callbacks = BaseWorker.behaviour_info(:callbacks)
      assert {:worker_state, 1} in callbacks
    end

    test "defines worker_metrics/1 callback" do
      callbacks = BaseWorker.behaviour_info(:callbacks)
      assert {:worker_metrics, 1} in callbacks
    end

    test "defines handle_worker_info/2 callback" do
      callbacks = BaseWorker.behaviour_info(:callbacks)
      assert {:handle_worker_info, 2} in callbacks
    end

    test "behaviour_info returns at least 5 callbacks" do
      callbacks = BaseWorker.behaviour_info(:callbacks)
      assert is_list(callbacks)
      assert length(callbacks) >= 5
    end
  end

  describe "__using__ macro injection" do
    test "macro is defined" do
      assert macro_exported?(BaseWorker, :__using__, 1)
    end
  end
end
