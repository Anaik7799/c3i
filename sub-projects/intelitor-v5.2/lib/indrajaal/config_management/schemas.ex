defmodule Indrajaal.ConfigManagement.ConfigTemplate do
  @moduledoc """
  Schema for configuration templates.

  Agent: Helper - 1 manages templates
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "config_templates" do
    field :name, :string
    field :description, :string
    field :domain, :string
    field :template_type, :string
    field :fields, :map
    field :field_overrides, :map
    field :active, :boolean, default: true

    field :tenant_id, :binary_id
    belongs_to :parent_template, __MODULE__

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  def changeset(template \\ %__MODULE__{}, attrs) do
    template
    |> cast(attrs, [
      :name,
      :description,
      :domain,
      :template_type,
      :fields,
      :field_overrides,
      :active,
      :tenant_id,
      :parent_template_id
    ])
    |> validate_required([:name, :domain, :fields])
    |> validate_inclusion(:domain, ~w(devices alarms sites __users notifications
                                     maintenance video_analytics reports schedules))
    |> merge_parent_fields()
  end

  @spec merge_parent_fields(term()) :: term()
  defp merge_parent_fields(changeset) do
    case get_field(changeset, :parent_template_id) do
      nil ->
        changeset

      parent_id ->
        parent = Indrajaal.Repo.get(__MODULE__, parent_id)

        if parent do
          base_fields = parent.fields || %{}
          overrides = get_field(changeset, :field_overrides) || %{}
          merged = Map.merge(base_fields, overrides)
          put_change(changeset, :fields, merged)
        else
          add_error(changeset, :parent_template_id, "does not exist")
        end
    end
  end
end

defmodule Indrajaal.ConfigManagement.ConfigVersion do
  @moduledoc """
  Schema for configuration version history.

  Agent: Helper - 3 manages versions
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "config_versions" do
    field :entity_type, :string
    field :entity_id, :binary_id
    field :version_number, :integer
    field :previous_value, :map
    field :new_value, :map
    field :change_summary, :string
    field :changed_by, :binary_id
    field :changed_at, :utc_datetime

    field :tenant_id, :binary_id

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  def changeset(version, attrs) do
    version
    |> cast(attrs, [
      :entity_type,
      :entity_id,
      :version_number,
      :previous_value,
      :new_value,
      :change_summary,
      :changed_by,
      :changed_at,
      :tenant_id
    ])
    |> validate_required([
      :entity_type,
      :entity_id,
      :version_number,
      :new_value,
      :changed_by,
      :changed_at
    ])
    |> validate_number(:version_number, greater_than: 0)
    |> unique_constraint([:entity_type, :entity_id, :version_number])
  end
end

defmodule Indrajaal.ConfigManagement.ChangeRequest do
  @moduledoc """
  Schema for configuration change __requests.

  Agent: Helper - 4 manages change __requests
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "change_requests" do
    field :entity_type, :string
    field :entity_id, :binary_id
    field :changes, :map
    field :reason, :string
    field :status, :string, default: "pending"
    field :risk_level, :string
    field :__required_approvals, :integer, default: 1
    field :approval_count, :integer, default: 0
    field :emergency, :boolean, default: false

    field :__requested_by, :binary_id
    field :__requested_at, :utc_datetime
    field :approved_by, :binary_id
    field :approved_at, :utc_datetime
    field :rejected_by, :binary_id
    field :rejected_at, :utc_datetime
    field :rejection_reason, :string
    field :applied_at, :utc_datetime

    field :tenant_id, :binary_id
    has_many :approvals, Indrajaal.ConfigManagement.ChangeApproval

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :entity_type,
      :entity_id,
      :changes,
      :reason,
      :status,
      :risk_level,
      :__required_approvals,
      :approval_count,
      :emergency,
      :__requested_by,
      :__requested_at,
      :approved_by,
      :approved_at,
      :rejected_by,
      :rejected_at,
      :rejection_reason,
      :applied_at,
      :tenant_id
    ])
    |> validate_required([:entity_type, :entity_id, :changes, :__requested_by])
    |> validate_inclusion(:status, ~w(pending partially_approved approved rejected
                                     auto_approved cancelled))
    |> validate_inclusion(:risk_level, ~w(low medium high critical))
  end
end

defmodule Indrajaal.ConfigManagement.ChangeApproval do
  @moduledoc """
  Schema for individual change approvals.

  Agent: Helper - 4 tracks approvals
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "change_approvals" do
    belongs_to :change_request, Indrajaal.ConfigManagement.ChangeRequest
    field :approved_by, :binary_id
    field :approved_at, :utc_datetime
    field :comments, :string

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  def changeset(approval \\ %__MODULE__{}, attrs) do
    approval
    |> cast(attrs, [:change_request_id, :approved_by, :approved_at, :comments])
    |> validate_required([:change_request_id, :approved_by, :approved_at])
  end

  @spec process_request(any(), any()) :: any()
  def process_request(approval \\ %__MODULE__{}, attrs) do
    approval
    |> cast(attrs, [:change_request_id, :approved_by, :approved_at, :comments])
    |> validate_required([:change_request_id, :approved_by, :approved_at])
  end
end

defmodule Indrajaal.ConfigManagement.ConfigSync do
  @moduledoc """
  Schema for configuration synchronization tracking.

  Agent: Helper - 4 manages sync operations
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "config_syncs" do
    field :source_tenant_id, :binary_id
    field :target_tenant_id, :binary_id
    field :domain, :string
    field :sync_type, :string
    field :status, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :records_created, :integer, default: 0
    field :records_updated, :integer, default: 0
    field :records_failed, :integer, default: 0
    field :error_details, {:array, :map}, default: []

    timestamps()
  end

  @spec process_request(any(), any()) :: any()
  def process_request(sync \\ %__MODULE__{}, attrs) do
    sync
    |> cast(attrs, [
      :source_tenant_id,
      :target_tenant_id,
      :domain,
      :sync_type,
      :status,
      :started_at,
      :completed_at,
      :records_created,
      :records_updated,
      :records_failed,
      :error_details
    ])
    |> validate_required([:source_tenant_id, :target_tenant_id, :domain, :sync_type])
    |> validate_inclusion(:sync_type, ~w(full incremental selective))
    |> validate_inclusion(:status, ~w(pending in_progress completed failed cancelled))
  end
end

defmodule Indrajaal.ConfigManagement.ConfigBackup do
  @moduledoc """
  Schema for configuration backups.

  Agent: Helper - 3 manages backups
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "config_backups" do
    field :name, :string
    field :description, :string
    field :backup_type, :string
    field :domains, {:array, :string}
    field :status, :string
    field :size_bytes, :integer
    field :record_count, :integer
    field :storage_path, :string
    field :checksum, :string
    field :encrypted, :boolean, default: true
    field :compression, :string, default: "gzip"
    field :retention_days, :integer, default: 90
    field :created_by, :binary_id
    field :tenant_id, :binary_id

    timestamps()
  end

  @spec process_request(any(), any()) :: any()
  def process_request(backup \\ %__MODULE__{}, attrs) do
    backup
    |> cast(attrs, [
      :name,
      :description,
      :backup_type,
      :domains,
      :status,
      :size_bytes,
      :record_count,
      :storage_path,
      :checksum,
      :encrypted,
      :compression,
      :retention_days,
      :created_by,
      :tenant_id
    ])
    |> validate_required([:name, :backup_type, :domains, :tenant_id])
    |> validate_inclusion(:backup_type, ~w(full incremental selective))
    |> validate_inclusion(:status, ~w(pending in_progress completed failed))
    |> validate_inclusion(:compression, ~w(none gzip bzip2 xz))
    |> validate_number(:retention_days, greater_than: 0)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
