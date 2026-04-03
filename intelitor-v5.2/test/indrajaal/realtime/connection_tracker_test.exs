defmodule Indrajaal.Realtime.ConnectionTrackerTest do
  @moduledoc """
  Tests for Indrajaal.Realtime.ConnectionTracker.

  Note: This module is wrapped in `if false do...end` in source,
  so it does NOT exist at runtime. Tests verify this behaviour.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "ConnectionTracker is NOT defined at runtime (guarded by if false)" do
      result = Code.ensure_loaded(Indrajaal.Realtime.ConnectionTracker)
      assert result == {:error, :nofile}
    end

    test "module is absent from loaded modules list" do
      loaded = :code.all_loaded() |> Enum.map(&elem(&1, 0))
      refute Indrajaal.Realtime.ConnectionTracker in loaded
    end
  end

  describe "source file existence" do
    test "source file exists on disk" do
      path =
        Path.join([
          File.cwd!(),
          "lib/indrajaal/realtime/connection_tracker.ex"
        ])

      assert File.exists?(path)
    end

    test "source file contains if false guard" do
      path =
        Path.join([
          File.cwd!(),
          "lib/indrajaal/realtime/connection_tracker.ex"
        ])

      content = File.read!(path)
      assert String.contains?(content, "if false do")
    end
  end
end
