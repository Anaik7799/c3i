# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.FleetManagementController do
  @moduledoc """
  Mobile API controller for fleet_management configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :fleet_management,
    module: Indrajaal.FleetManagement,
    singular: :vehicle,
    plural: :fleet_management,
    context_module: Indrajaal.FleetManagementContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists fleet_management with pagination
  # - create/2: Creates a new vehicle
  # - show/2: Shows a specific vehicle
  # - update/2: Updates a vehicle
  # - delete/2: Deletes a vehicle
  # - bulk_create/2: Bulk creates fleet_management
  # - import/2: Imports fleet_management from file
  # - export/2: Exports fleet_management to file
end
