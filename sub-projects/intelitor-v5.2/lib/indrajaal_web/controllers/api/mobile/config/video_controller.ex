# PHASE F CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.VideoController do
  @moduledoc """
  Mobile API controller for video configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :video,
    module: Indrajaal.Video,
    singular: :video_stream,
    plural: :video

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists video with pagination
  # - create/2: Creates a new video_stream
  # - show/2: Shows a specific video_stream
  # - update/2: Updates a video_stream
  # - delete/2: Deletes a video_stream
  # - bulk_create/2: Bulk creates video
  # - import/2: Imports video from file
  # - export/2: Exports video to file
end
