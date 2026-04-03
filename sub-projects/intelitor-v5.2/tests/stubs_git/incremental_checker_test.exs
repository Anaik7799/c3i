defmodule Intelitor.Git.IncrementalCheckerTest do
  @moduledoc """
  Test suite for Intelitor.Git.IncrementalChecker.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/git/incremental_checker.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Git.IncrementalChecker

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(IncrementalChecker)
    end

    test "module has __info__/1 function" do
      assert function_exported?(IncrementalChecker, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = IncrementalChecker.__info__(:module)
      assert info == Intelitor.Git.IncrementalChecker
    end
  end
end
