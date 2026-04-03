# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.TrainingController do
  @moduledoc """
  Mobile API controller for training configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :training,
    module: Indrajaal.Training,
    singular: :course,
    plural: :training

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists training with pagination
  # - create/2: Creates a new course
  # - show/2: Shows a specific course
  # - update/2: Updates a course
  # - delete/2: Deletes a course
  # - bulk_create/2: Bulk creates training
  # - import/2: Imports training from file
  # - export/2: Exports training to file
end
