# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.MaintenanceController do
  @moduledoc """
  Mobile API controller for maintenance configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :maintenance,
    module: Indrajaal.Maintenance,
    singular: :work_order,
    plural: :maintenance,
    context_module: Indrajaal.MaintenanceContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists maintenance with pagination
  # - create/2: Creates a new work_order
  # - show/2: Shows a specific work_order
  # - update/2: Updates a work_order
  # - delete/2: Deletes a work_order
  # - bulk_create/2: Bulk creates maintenance
  # - import/2: Imports maintenance from file
  # - export/2: Exports maintenance to file
end
