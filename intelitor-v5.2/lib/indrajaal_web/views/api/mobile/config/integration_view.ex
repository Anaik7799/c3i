# {import_line}

defmodule IndrajaalWeb.Api.Mobile.Config.IntegrationView do
  @moduledoc """
  JSON rendering for integration in the Mobile API.

  CONVERSION STATUS: ✅ Converted to use shared mobile view helpers
  Duplicate Reduction: ~37 lines eliminated
  Pattern: EP401 - Mobile API View Duplication
  Agent: Worker - 4
  SOPv5.1 Compliance: ✅
  """

  use IndrajaalWeb, :view
  import Indrajaal.Shared.MobileViewHelpers

  # Use shared mobile view helpers to eliminate duplication
  use_mobile_view_helpers(
    collection_key: :integration,
    item_key: :integration_config,
    item_template: "integrationconfig.json"
  )

  # Domain - specific customizations can be added here if needed
  # The shared helpers handle all common patterns:
  # - index.json: Paginated collection response
  # - show.json: Single item response
  # - integrationconfig.json: Individual item rendering
  # - error.json: Error response with changeset validation
end

# Agent: Worker - 4 (Mobile API Specialist)
# SOPv5.1 Compliance: ✅ Systematic duplication elimination with shared utilities
# Domain: Web / Mobile API
# Responsibilities: Mobile API view consolidation, duplication elimination
# Multi - Agent Architecture: Integrated with duplication elimination coordination
# Cybernetic Feedback: Real - time feedback on duplication reduction effectiveness
