defmodule Indrajaal.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :text, default: "user", null: false
    end

    create index(:users, [:role])
  end
end
