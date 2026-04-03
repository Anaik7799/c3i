defmodule Indrajaal.Integration.ExternalConnectors.Connector do
  @moduledoc """
  CLAUDE_AGENT_CONTEXT: Ash resource stub module
  Date: 2025-09-03
  Pattern: EP048_MISSING_MODULE_STUBS
  Purpose: Stub Ash resource to resolve domain compilation errors
  TODO: Implement proper Ash resource with attributes, actions, and relationships
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Indrajaal.Integration.ExternalConnectors,
    extensions: [AshPostgres]

  postgres do
    table "connectors"
    repo Indrajaal.Repo
  end

  # Basic attributes - customize based on actual _requirements
  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at

    # Add domain-specific attributes here
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :active, :boolean, default: true
  end

  # Basic actions
  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :active]
    end

    update :update do
      accept [:name, :description, :active]
    end
  end

  # CLAUDE_AGENT_CONTEXT: Code interface commented out to pr_event compilation errors
  # code_interface do
  # TODO: Add proper code_interface when domain is fully configured
  # define_for Indrajaal.Integration.ExternalConnectors
  # define :create, args: [:name]
  # define :read_all, action: :read
  # define :update
  # define :destroy
  # end
end
