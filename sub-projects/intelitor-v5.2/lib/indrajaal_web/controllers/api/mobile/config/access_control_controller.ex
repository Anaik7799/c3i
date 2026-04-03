# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.AccessControlController do
  @moduledoc """
  Mobile API controller for access_control configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :access_control,
    module: Indrajaal.AccessControl,
    singular: :access_rule,
    plural: :access_control,
    context_module: Indrajaal.AccessControlContext

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists access_control with pagination
  # - create/2: Creates a new access_rule
  # - show/2: Shows a specific access_rule
  # - update/2: Updates an access_rule
  # - delete/2: Deletes an access_rule
  # - bulk_create/2: Bulk creates access_control
  # - import/2: Imports access_control from file
  # - export/2: Exports access_control to file
end
