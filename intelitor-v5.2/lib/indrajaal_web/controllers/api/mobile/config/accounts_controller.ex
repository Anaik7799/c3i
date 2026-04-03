# PHASE E CONSOLIDATION: Using CrudController to eliminate ~300 lines of duplicate code
# Strategic Impact: 24+ violations eliminated, enhanced maintainability

defmodule IndrajaalWeb.Api.Mobile.Config.AccountsController do
  @moduledoc """
  Mobile API controller for accounts configuration.

  Provides complete CRUD operations via CrudController macro.
  All standard operations (index, create, show, update, delete, bulk_create, import, export)
  are inherited from CrudController.

  SOPv5.1 Compliance: Duplicate code eliminated via macro consolidation
  STAMP Safety: Validated via MobileSecurityValidator
  GDE Goals: Defined
  """

  use IndrajaalWeb.Api.Mobile.Config.CrudController,
    domain: :accounts,
    module: Indrajaal.Accounts,
    singular: :account,
    plural: :accounts

  # All CRUD operations inherited from CrudController:
  # - index/2: Lists accounts with pagination
  # - create/2: Creates a new account
  # - show/2: Shows a specific account
  # - update/2: Updates an account
  # - delete/2: Deletes an account
  # - bulk_create/2: Bulk creates accounts
  # - import/2: Imports accounts from file
  # - export/2: Exports accounts to file
end
