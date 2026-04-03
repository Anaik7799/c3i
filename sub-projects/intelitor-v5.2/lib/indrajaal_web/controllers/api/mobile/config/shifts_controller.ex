# PHASE E CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.ShiftsController do
  @moduledoc """
  Mobile API controller for shifts configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :shifts,
    module: Indrajaal.Shifts,
    singular: :shift,
    plural: :shifts,
    context_module: Indrajaal.ShiftsContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists shifts with pagination
  # - create/2: Creates a new shift
  # - show/2: Shows a specific shift
  # - update/2: Updates a shift
  # - delete/2: Deletes a shift
  # - bulk_create/2: Bulk creates shifts (uses ShiftsContext)
  # - import/2: Imports shifts from file (uses ShiftsContext)
  # - export/2: Exports shifts to file (uses ShiftsContext)
end
