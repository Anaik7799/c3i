defmodule Indrajaal.Repo.Migrations.CreateKmsSagaDlq do
  use Ecto.Migration

  def change do
    create table(:kms_saga_dlq, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :saga_id, :uuid, null: false
      add :saga_name, :string, null: false
      add :failed_step, :string
      add :error_reason, :map
      add :context, :map
      add :retry_count, :integer, default: 0
      
      timestamps()
    end

    create index(:kms_saga_dlq, [:saga_id])
  end
end
