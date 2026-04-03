# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.AnalyticsController do
  @moduledoc """
  Mobile API controller for analytics configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :analytics,
    module: Indrajaal.AnalyticsContext,
    singular: :report,
    plural: :analytics

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists analytics with pagination
  # - create/2: Creates a new report
  # - show/2: Shows a specific report
  # - update/2: Updates a report
  # - delete/2: Deletes a report
  # - bulk_create/2: Bulk creates analytics
  # - import/2: Imports analytics from file
  # - export/2: Exports analytics to file
end
