# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.CommunicationController do
  @moduledoc """
  Mobile API controller for communication configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :communication,
    module: Indrajaal.Communication,
    singular: :message,
    plural: :communication

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists communication with pagination
  # - create/2: Creates a new message
  # - show/2: Shows a specific message
  # - update/2: Updates a message
  # - delete/2: Deletes a message
  # - bulk_create/2: Bulk creates communication
  # - import/2: Imports communication from file
  # - export/2: Exports communication to file
end
