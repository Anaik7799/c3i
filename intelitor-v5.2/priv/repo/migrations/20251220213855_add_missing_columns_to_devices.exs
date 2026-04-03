defmodule Indrajaal.Repo.Migrations.AddMissingColumnsToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :description, :text
      add :firmware_version, :text
      add :ip_address, :text
      add :mac_address, :text
      add :site_id, references(:sites, type: :uuid, on_delete: :nilify_all)
    end

    create index(:devices, [:site_id])
  end
end