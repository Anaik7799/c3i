defmodule Indrajaal.KMS.ContextTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Context.
  Tests module existence and Ecto context function surface only.
  No DB connections — KMSRepo is not started in this test.
  STAMP: SC-KMS-001, SC-MIG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Context

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Context)
    end
  end

  describe "public API surface" do
    test "exports get_task!/1" do
      assert function_exported?(Context, :get_task!, 1)
    end

    test "exports list_tasks/1" do
      assert function_exported?(Context, :list_tasks, 1)
    end

    test "exports create_task/1" do
      assert function_exported?(Context, :create_task, 1)
    end

    test "exports update_task/2" do
      assert function_exported?(Context, :update_task, 2)
    end

    test "exports delete_task/1" do
      assert function_exported?(Context, :delete_task, 1)
    end

    test "exports add_dependency/2" do
      assert function_exported?(Context, :add_dependency, 2)
    end

    test "exports remove_dependency/2" do
      assert function_exported?(Context, :remove_dependency, 2)
    end

    test "exports transition_status/2" do
      assert function_exported?(Context, :transition_status, 2)
    end
  end
end
