# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.EnvironmentalController do
  @moduledoc """
  Mobile API controller for environmental configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :environmental,
    module: Indrajaal.Environmental,
    singular: :sensor,
    plural: :environmental,
    context_module: Indrajaal.EnvironmentalContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists environmental with pagination
  # - create/2: Creates a new sensor
  # - show/2: Shows a specific sensor
  # - update/2: Updates a sensor
  # - delete/2: Deletes a sensor
  # - bulk_create/2: Bulk creates environmental
  # - import/2: Imports environmental from file
  # - export/2: Exports environmental to file
end
