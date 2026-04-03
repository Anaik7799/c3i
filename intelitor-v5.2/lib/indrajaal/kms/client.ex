defmodule Indrajaal.KMS.Client do
  @moduledoc """
  Client for the F# KMS Cortex.

  This module replaces direct DB access (Ecto/Exqlite) with a bridge to the
  F# 'Cepaf.Kms' service. It uses a Port to communicate via Stdio/JSON.

  ## Architecture
  Elixir -> Port -> F# KmsServer -> SQLite/DuckDB

  ## Constraints
  - SC-KMS-REF-002: All access via this client.
  - SC-KMS-REF-004: Handle timeouts/crashes.
  """

  use GenServer
  require Logger

  # Path to the F# executable (using dotnet run for now, or compiled binary)
  @kms_cmd "dotnet"
  @kms_args ["run", "--project", "lib/cepaf/src/Cepaf/Cepaf.fsproj", "--", "kms", "server"]

  defstruct [:port, :request_queue, :cache_table]

  # --- API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_holon(id) do
    # L1 Cache Check (SC-PRF-050: < 50ms)
    case :ets.lookup(:kms_cache, id) do
      [{^id, holon}] ->
        {:ok, holon}

      [] ->
        call_kms("get_holon", %{id: id})
    end
  end

  def upsert_holon(holon_map) do
    # Write-through: Update DB then Cache
    with {:ok, _} <- call_kms("upsert_holon", holon_map) do
      # Invalidate cache to ensure consistency
      id = holon_map[:id] || holon_map["id"]
      if id, do: :ets.delete(:kms_cache, id)
      {:ok, :updated}
    end
  end

  def search_vectors(query_vec, limit \\ 10) do
    call_kms("search_vectors", %{query: query_vec, limit: limit})
  end

  def ping do
    call_kms("ping", %{})
  end

  # --- PRIVATE ---

  defp call_kms(command, args) do
    GenServer.call(__MODULE__, {:call, command, args}, 15_000)
  end

  # --- CALLBACKS ---

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)

    # Initialize L1 Cache
    :ets.new(:kms_cache, [:set, :public, :named_table, read_concurrency: true])

    # Use :line mode for JSON-RPC over Stdio
    port =
      Port.open(
        {:spawn_executable, System.find_executable(@kms_cmd)},
        [:binary, :use_stdio, :line, args: @kms_args]
      )

    {:ok, %__MODULE__{port: port, request_queue: :queue.new()}}
  end

  @impl true
  def handle_call({:call, command, args}, from, state) do
    payload = Jason.encode!(%{command: command, args: args}) <> "\n"
    Port.command(state.port, payload)

    # Enqueue caller (FIFO)
    updated_queue = :queue.in(from, state.request_queue)
    {:noreply, %{state | request_queue: updated_queue}}
  end

  @impl true
  def handle_info({_port, {:data, {:eol, line}}}, state) do
    # Handle response
    case :queue.out(state.request_queue) do
      {{:value, from}, new_queue} ->
        response = Jason.decode!(line)

        # Note: We could proactively cache 'get_holon' responses here if we tracked the request type.
        # For now, we rely on the next read to be uncached, or we could add request metadata to the queue.

        GenServer.reply(from, response)
        {:noreply, %{state | request_queue: new_queue}}

      {:empty, _} ->
        Logger.warning("[KMS.Client] Received unsolicited data: #{inspect(line)}")
        {:noreply, state}
    end
  end
end
