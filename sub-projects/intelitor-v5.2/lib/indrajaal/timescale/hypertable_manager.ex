defmodule Indrajaal.Timescale.HypertableManager do
  @moduledoc """
  Shared hypertable management functions for TimescaleDB.
  Eliminates duplication across timescale scripts.
  """

  @spec drop_hypertable(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def drop_hypertable(table_name, schema \\ "public") do
    drop_query = """
    DO $$
    BEGIN
      -- Drop continuous aggregates first
      PERFORM drop_continuous_aggregate(format('%I.%I', sch.nspname, cagg.__user_view_name), true)
      FROM timescaledb_catalog.continuous_agg cagg
      JOIN timescaledb_catalog.hypertable ht ON cagg.mat_hypertable_id = ht.id
      JOIN pg_namespace sch ON ht.schema_name = sch.nspname
      WHERE ht.table_name = '#{table_name}' AND ht.schema_name = '#{schema}';

      -- Drop the hypertable
      IF EXISTS (
        SELECT 1 FROM timescaledb_catalog.hypertable
        WHERE table_name = '#{table_name}' AND schema_name = '#{schema}'
      ) THEN
        EXECUTE format('DROP TABLE %I.%I CASCADE', '#{schema}', '#{table_name}');
        RAISE NOTICE 'Dropped hypertable: %.%', '#{schema}', '#{table_name}';
      ELSE
        RAISE NOTICE 'Hypertable %.% does not exist', '#{schema}', '#{table_name}';
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Failed to drop %: %', '#{table_name}', SQLERRM;
    END $$;
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, drop_query) do
      {:ok, _} -> {:ok, "Dropped hypertable: #{schema}.#{table_name}"}
      {:error, error} -> {:error, error}
    end
  end

  @spec create_hypertable(binary(), binary(), binary(), map()) ::
          {:ok, binary()} | {:error, term()}
  def create_hypertable(schema, table_name, time_column, opts \\ %{}) do
    chunk_interval = Map.get(opts, :chunk_interval, "7 days")

    create_query = """
    SELECT create_hypertable(
      '#{schema}.#{table_name}',
      '#{time_column}',
      chunk_time_interval => INTERVAL '#{chunk_interval}',
      if_not_exists => TRUE
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, create_query) do
      {:ok, _} -> {:ok, "Created hypertable: #{schema}.#{table_name}"}
      {:error, error} -> {:error, error}
    end
  end
end
