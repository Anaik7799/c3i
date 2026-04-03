defmodule Indrajaal.Repo.Migrations.CreateKmsSagas do
  use Ecto.Migration

  def change do
    create table(:kms_sagas, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false # pending, committed, rolled_back, failed
      add :current_step, :integer, default: 0
      add :context, :map, default: %{}
      add :error_reason, :map
      add :trace_id, :string
      
      timestamps()
    end

    create index(:kms_sagas, [:status])
    create index(:kms_sagas, [:trace_id])
  end
end