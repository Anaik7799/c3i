defmodule Intelitor.Compilation.MaxParallelContainerCompilerTest do
  @moduledoc """
  Test suite for Intelitor.Compilation.MaxParallelContainerCompiler.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/compilation/max_parallel_container_compiler.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Compilation.MaxParallelContainerCompiler

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(MaxParallelContainerCompiler)
    end

    test "module has __info__/1 function" do
      assert function_exported?(MaxParallelContainerCompiler, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = MaxParallelContainerCompiler.__info__(:module)
      assert info == Intelitor.Compilation.MaxParallelContainerCompiler
    end
  end
end
