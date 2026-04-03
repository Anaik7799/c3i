defmodule Intelitor.Compliance.DocumentTest do
  @moduledoc """
  Test suite for Intelitor.Compliance.Document.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/compliance/document.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Compliance.Document

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Document)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Document, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Document.__info__(:module)
      assert info == Intelitor.Compliance.Document
    end
  end
end
