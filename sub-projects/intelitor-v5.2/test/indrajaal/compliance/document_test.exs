defmodule Indrajaal.Compliance.DocumentTest do
  @moduledoc """
  Tests for Indrajaal.Compliance.Document Ash resource.
  STAMP: SC-GDE-001, SC-DB-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance.Document

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Document)
    end

    test "is an Ash resource (has spark_is/0)" do
      assert function_exported?(Document, :spark_is, 0)
    end
  end

  describe "code interface" do
    test "get/1 or get/2 is exported" do
      assert function_exported?(Document, :get, 1) or
               function_exported?(Document, :get, 2)
    end

    test "list/0 or list/1 is exported" do
      assert function_exported?(Document, :list, 0) or
               function_exported?(Document, :list, 1)
    end

    test "create/1 or create/2 is exported" do
      assert function_exported?(Document, :create, 1) or
               function_exported?(Document, :create, 2)
    end
  end

  describe "resource type" do
    test "spark_is/0 returns Ash.Resource marker" do
      assert Document.spark_is() == Ash.Resource
    end
  end
end
