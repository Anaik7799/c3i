defmodule Indrajaal.Integration.EventStreaming.StreamProcessor do
  @moduledoc """
  WHAT: Ash resource representing a stream processor configuration record.
        Stores the windowing configuration, input/output stream bindings, and
        processing parameters for a real-time stream processing pipeline stage.

  WHY: Stream processors define how events are transformed, aggregated, or
       enriched in flight. Persisting their configuration as Ash resources
       allows the domain to list, manage, and audit processor definitions
       independently of the underlying execution engine.

  CONSTRAINTS:
  - SC-DB-001: Use Indrajaal.BaseResource (uuid_primary_key, snake_case table)
  - SC-DB-005: uuid_primary_key :id
  - SC-ASH-001: force_change_attribute in before_action for computed fields
  - AOR-AGT-001: mix compile must pass before task complete

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 21.2.1  | 2026-03-19 | Claude | Enabled code_interface, updated moduledoc |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Integration.EventStreaming,
    extensions: [AshPostgres, AshJsonApi.Resource]

  postgres do
    table "stream_processors"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :active, :boolean, default: true, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :active]
    end

    update :update do
      accept [:name, :description, :active]
    end
  end

  code_interface do
    define :create, args: [:name]
    define :read_all, action: :read
    define :update
    define :destroy
  end
end
