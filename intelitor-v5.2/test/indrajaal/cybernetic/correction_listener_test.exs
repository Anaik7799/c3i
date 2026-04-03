defmodule Indrajaal.Cybernetic.CorrectionListenerTest do
  @moduledoc """
  TDG tests for Indrajaal.Cybernetic.CorrectionListener GenServer.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cybernetic.CorrectionListener

  describe "CorrectionListener module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CorrectionListener)
    end

    test "start_link/1 is exported" do
      assert function_exported?(CorrectionListener, :start_link, 1)
    end

    test "handle_correction/2 is exported" do
      assert function_exported?(CorrectionListener, :handle_correction, 2)
    end
  end

  describe "CorrectionListener GenServer behavior" do
    test "implements GenServer callbacks" do
      assert function_exported?(CorrectionListener, :init, 1)

      assert function_exported?(CorrectionListener, :handle_call, 3) or
               function_exported?(CorrectionListener, :handle_cast, 2) or
               function_exported?(CorrectionListener, :handle_info, 2)
    end
  end

  describe "CorrectionListener child_spec" do
    test "has child_spec/1" do
      assert function_exported?(CorrectionListener, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = CorrectionListener.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
