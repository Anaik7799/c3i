defmodule Indrajaal.Core.HotSwapTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.HotSwap

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HotSwap)
    end
  end

  describe "reload/1" do
    test "function is exported" do
      assert function_exported?(HotSwap, :reload, 1)
    end

    test "returns error tuple for non-existent module" do
      result = HotSwap.reload(DoesNotExist.Module)
      assert match?({:error, _}, result)
    end

    test "attempts to reload a loaded module" do
      # We expect either :ok or an error — not a crash
      result = HotSwap.reload(Indrajaal.Core.HotSwap)
      assert match?({:ok, _}, result) or match?({:error, _}, result) or result == :ok
    end

    test "returns a result tuple" do
      result = HotSwap.reload(Kernel)
      assert is_tuple(result) or result == :ok
    end
  end
end
