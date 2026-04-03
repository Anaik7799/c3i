# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.VisitorManagementController do
  @moduledoc """
  Mobile API controller for visitor_management configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :visitor_management,
    module: Indrajaal.VisitorManagement,
    singular: :visitor,
    plural: :visitor_management

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists visitor_management with pagination
  # - create/2: Creates a new visitor
  # - show/2: Shows a specific visitor
  # - update/2: Updates a visitor
  # - delete/2: Deletes a visitor
  # - bulk_create/2: Bulk creates visitor_management
  # - import/2: Imports visitor_management from file
  # - export/2: Exports visitor_management to file
end
