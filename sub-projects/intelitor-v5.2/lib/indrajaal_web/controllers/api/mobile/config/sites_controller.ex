# PHASE E CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.SitesController do
  @moduledoc """
  Mobile API controller for sites configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :sites,
    module: Indrajaal.Sites,
    singular: :site,
    plural: :sites

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists sites with pagination
  # - create/2: Creates a new site
  # - show/2: Shows a specific site
  # - update/2: Updates a site
  # - delete/2: Deletes a site
  # - bulk_create/2: Bulk creates sites
  # - import/2: Imports sites from file
  # - export/2: Exports sites to file
end
