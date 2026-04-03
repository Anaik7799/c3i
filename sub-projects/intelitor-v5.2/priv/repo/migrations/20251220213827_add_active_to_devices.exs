defmodule Indrajaal.Repo.Migrations.AddActiveToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :active, :boolean, default: true, null: false
    end
  end
end