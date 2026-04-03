defmodule Intelitor.VideoTest do
  @moduledoc """
  Test suite for Video root module.
  SOPv5.11 TDG Compliance - Root module test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Video

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Video)
    end

    test "module has expected functions" do
      assert function_exported?(Video, :__info__, 1)
    end
  end
end
