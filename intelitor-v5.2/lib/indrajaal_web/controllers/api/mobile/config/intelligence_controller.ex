# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.IntelligenceController do
  @moduledoc """
  Mobile API controller for intelligence configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :intelligence,
    module: Indrajaal.Intelligence,
    singular: :alert,
    plural: :intelligence,
    context_module: Indrajaal.IntelligenceContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists intelligence with pagination
  # - create/2: Creates a new alert
  # - show/2: Shows a specific alert
  # - update/2: Updates an alert
  # - delete/2: Deletes an alert
  # - bulk_create/2: Bulk creates intelligence
  # - import/2: Imports intelligence from file
  # - export/2: Exports intelligence to file
end
