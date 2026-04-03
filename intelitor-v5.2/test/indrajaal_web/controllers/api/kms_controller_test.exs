defmodule IndrajaalWeb.Api.KmsControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.KmsController.

  WHAT: Verifies the KMS (Knowledge Management System) controller functions exist.
  WHY: Ensures knowledge graph API endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.KmsController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.KmsController)
    end
  end

  describe "controller actions" do
    test "oracle/2 function exists" do
      assert function_exported?(KmsController, :oracle, 2)
    end

    test "index/2 function exists" do
      assert function_exported?(KmsController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(KmsController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(KmsController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(KmsController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(KmsController, :delete, 2)
    end

    test "children/2 function exists" do
      assert function_exported?(KmsController, :children, 2)
    end

    test "descendants/2 function exists" do
      assert function_exported?(KmsController, :descendants, 2)
    end

    test "create_edge/2 function exists" do
      assert function_exported?(KmsController, :create_edge, 2)
    end

    test "search/2 function exists" do
      assert function_exported?(KmsController, :search, 2)
    end

    test "health/2 function exists" do
      assert function_exported?(KmsController, :health, 2)
    end

    test "entropy/2 function exists" do
      assert function_exported?(KmsController, :entropy, 2)
    end

    test "stats/2 function exists" do
      assert function_exported?(KmsController, :stats, 2)
    end
  end
end
