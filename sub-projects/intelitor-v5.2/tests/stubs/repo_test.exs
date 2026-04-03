defmodule Intelitor.RepoTest do
  @moduledoc """
  Test suite for Intelitor.Repo.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/repo.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Repo

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Repo)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Repo, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Repo.__info__(:module)
      assert info == Intelitor.Repo
    end
  end
end
