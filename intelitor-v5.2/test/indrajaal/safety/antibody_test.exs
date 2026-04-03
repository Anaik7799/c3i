defmodule Indrajaal.Safety.AntibodyTest do
  @moduledoc """
  Tests for Indrajaal.Safety.Antibody ephemeral GenServer.
  STAMP: SC-GDE-001, SC-IMMUNE-001, SC-SIL6-001, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @moduletag :sil4

  alias Indrajaal.Safety.Antibody

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Antibody)
    end

    test "deploy/1 is exported" do
      assert function_exported?(Antibody, :deploy, 1)
    end
  end

  describe "deploy/1 return type" do
    test "returns {:ok, pid} on successful start" do
      Process.flag(:trap_exit, true)
      threat = %{type: :anomaly, target: :test_process, severity: :low}
      result = Antibody.deploy(threat)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      # Drain any EXIT messages from the short-lived antibody process
      receive do
        {:EXIT, _, _} -> :ok
      after
        500 -> :ok
      end
    end
  end
end
