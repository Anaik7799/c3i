defmodule Indrajaal.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  @spec up() :: any()
  def up do
    Oban.Migration.up(version: 12)
  end

  @spec down() :: any()
  def down do
    Oban.Migration.down(version: 1)
  end
end
