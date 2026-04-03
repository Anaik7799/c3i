defmodule Intelitor.Testing.DomainApiAnalyzerTest do
  @moduledoc """
  Test suite for Intelitor.Testing.DomainApiAnalyzer.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/testing/api_analyzer.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Testing.DomainApiAnalyzer

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(DomainApiAnalyzer)
    end

    test "module has __info__/1 function" do
      assert function_exported?(DomainApiAnalyzer, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = DomainApiAnalyzer.__info__(:module)
      assert info == Intelitor.Testing.DomainApiAnalyzer
    end
  end
end
