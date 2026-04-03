# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.IntegrationController do
  @moduledoc """
  Mobile API controller for integration configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :integration,
    module: Indrajaal.Integration,
    singular: :integration,
    plural: :integration,
    context_module: Indrajaal.IntegrationContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists integration with pagination
  # - create/2: Creates a new integration
  # - show/2: Shows a specific integration
  # - update/2: Updates an integration
  # - delete/2: Deletes an integration
  # - bulk_create/2: Bulk creates integration
  # - import/2: Imports integration from file
  # - export/2: Exports integration to file
end
