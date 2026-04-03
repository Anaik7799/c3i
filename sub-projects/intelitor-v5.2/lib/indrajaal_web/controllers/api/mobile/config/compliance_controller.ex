# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.ComplianceController do
  @moduledoc """
  Mobile API controller for compliance configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :compliance,
    module: Indrajaal.Compliance,
    singular: :policy,
    plural: :compliance

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists compliance with pagination
  # - create/2: Creates a new policy
  # - show/2: Shows a specific policy
  # - update/2: Updates a policy
  # - delete/2: Deletes a policy
  # - bulk_create/2: Bulk creates compliance
  # - import/2: Imports compliance from file
  # - export/2: Exports compliance to file
end
