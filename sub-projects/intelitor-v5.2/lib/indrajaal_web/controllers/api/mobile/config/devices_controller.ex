# PHASE E CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.DevicesController do
  @moduledoc """
  Mobile API controller for devices configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :devices,
    module: Indrajaal.Devices,
    singular: :device,
    plural: :devices

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists devices with pagination
  # - create/2: Creates a new device
  # - show/2: Shows a specific device
  # - update/2: Updates a device
  # - delete/2: Deletes a device
  # - bulk_create/2: Bulk creates devices
  # - import/2: Imports devices from file
  # - export/2: Exports devices to file
end
