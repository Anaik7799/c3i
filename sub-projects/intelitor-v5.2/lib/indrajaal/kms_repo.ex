defmodule Indrajaal.KMSRepo do
  @moduledoc """
  WHAT: Ecto repository backed by SQLite3 for the Knowledge Management System (KMS/SMRITI).
  WHY: Provides a dedicated, portable repo for holon state and knowledge graph persistence,
       separate from the primary PostgreSQL repo, per the Holon State Sovereignty axiom (Ω₇).
  CONSTRAINTS: AOR-HOLON-001 (holon state in SQLite), SC-DB-001 (BaseResource), SC-DBLOCAL-001 (WAL mode)
  """
  use Ecto.Repo,
    otp_app: :indrajaal,
    adapter: Ecto.Adapters.SQLite3

  # Standard Ecto configuration will be picked up from config/config.exs
end
