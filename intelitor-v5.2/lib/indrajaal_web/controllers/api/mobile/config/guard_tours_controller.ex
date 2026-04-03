# PHASE E CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.GuardToursController do
  @moduledoc """
  Mobile API controller for guard_tours configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :guard_tours,
    module: Indrajaal.GuardTours,
    singular: :guard_tour,
    plural: :guard_tours,
    context_module: Indrajaal.GuardToursContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists guard_tours with pagination
  # - create/2: Creates a new guard_tour
  # - show/2: Shows a specific guard_tour
  # - update/2: Updates a guard_tour
  # - delete/2: Deletes a guard_tour
  # - bulk_create/2: Bulk creates guard_tours (uses GuardToursContext)
  # - import/2: Imports guard_tours from file (uses GuardToursContext)
  # - export/2: Exports guard_tours to file (uses GuardToursContext)
end
