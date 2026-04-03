defmodule IndrajaalWeb.Api.Mobile.Config.DeviceGroupsControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.DeviceGroupsController.

  WHAT: Verifies device groups controller functions for mobile API config.
  WHY: Ensures device group management endpoints are correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.DeviceGroupsController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.DeviceGroupsController)
    end
  end

  describe "CRUD actions" do
    test "index/2 function exists" do
      assert function_exported?(DeviceGroupsController, :index, 2)
    end

    test "show/2 function exists" do
      assert function_exported?(DeviceGroupsController, :show, 2)
    end

    test "create/2 function exists" do
      assert function_exported?(DeviceGroupsController, :create, 2)
    end

    test "update/2 function exists" do
      assert function_exported?(DeviceGroupsController, :update, 2)
    end

    test "delete/2 function exists" do
      assert function_exported?(DeviceGroupsController, :delete, 2)
    end
  end

  describe "bulk actions" do
    test "bulk_create/2 function exists" do
      assert function_exported?(DeviceGroupsController, :bulk_create, 2)
    end

    test "bulk_update/2 function exists" do
      assert function_exported?(DeviceGroupsController, :bulk_update, 2)
    end

    test "bulk_delete/2 function exists" do
      assert function_exported?(DeviceGroupsController, :bulk_delete, 2)
    end
  end

  describe "import/export actions" do
    test "import/2 function exists" do
      assert function_exported?(DeviceGroupsController, :import, 2)
    end

    test "export/2 function exists" do
      assert function_exported?(DeviceGroupsController, :export, 2)
    end
  end

  describe "template and versioning actions" do
    test "list_templates/2 function exists" do
      assert function_exported?(DeviceGroupsController, :list_templates, 2)
    end

    test "create_template/2 function exists" do
      assert function_exported?(DeviceGroupsController, :create_template, 2)
    end

    test "apply_template/2 function exists" do
      assert function_exported?(DeviceGroupsController, :apply_template, 2)
    end

    test "list_versions/2 function exists" do
      assert function_exported?(DeviceGroupsController, :list_versions, 2)
    end

    test "rollback/2 function exists" do
      assert function_exported?(DeviceGroupsController, :rollback, 2)
    end
  end
end
