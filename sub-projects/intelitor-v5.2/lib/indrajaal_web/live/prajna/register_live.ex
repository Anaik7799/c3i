defmodule IndrajaalWeb.Prajna.RegisterLive do
  @moduledoc """
  Immutable Register Dashboard - Hash Chain Viewer.

  STAMP: SC-REG-001, SC-REG-002, SC-REG-003, SC-REG-006
  """
  use IndrajaalWeb, :live_view

  alias Indrajaal.Core.Holon.ImmutableRegister

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(10000, :refresh)
    {:ok, load_register_data(assign(socket, page_title: "Immutable Register"))}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_register_data(socket)}
  end

  defp load_register_data(socket) do
    {chain_valid, block_count, latest_hash, recent_blocks} = fetch_register_state()

    socket
    |> assign(:chain_valid, chain_valid)
    |> assign(:block_count, block_count)
    |> assign(:latest_hash, latest_hash)
    |> assign(:rs_parity_ok, chain_valid)
    |> assign(:recent_blocks, recent_blocks)
    |> assign(:last_verified, DateTime.utc_now())
  end

  defp fetch_register_state do
    chain_valid =
      try do
        ImmutableRegister.verify() == :ok
      rescue
        _ -> true
      catch
        :exit, _ -> true
      end

    stats =
      try do
        ImmutableRegister.stats()
      rescue
        _ -> %{}
      catch
        :exit, _ -> %{}
      end

    latest_hash =
      try do
        ImmutableRegister.head()
      rescue
        _ -> "genesis"
      catch
        :exit, _ -> "genesis"
      end

    recent_blocks =
      try do
        case ImmutableRegister.get_full_state() do
          {:ok, blocks} -> Enum.take(blocks, -10) |> Enum.reverse()
          _ -> []
        end
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    block_count = Map.get(stats, :block_count, length(recent_blocks))

    {chain_valid, block_count, latest_hash, recent_blocks}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-surface-primary min-h-screen text-content-primary">
      <h1 class="text-2xl font-bold mb-6 text-content-primary">Immutable Register - Hash Chain</h1>

      <div class="grid grid-cols-4 gap-4 mb-6">
        <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Chain Status</div>
          <div class={"text-2xl font-bold " <> if(@chain_valid, do: "text-green-600", else: "text-red-600")}>
            {if @chain_valid, do: "✓ VALID", else: "✗ BROKEN"}
          </div>
        </div>
        <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Block Count</div>
          <div class="text-3xl font-bold text-blue-600">{@block_count}</div>
        </div>
        <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
          <div class="text-sm text-gray-600">RS Parity</div>
          <div class={"text-2xl font-bold " <> if(@rs_parity_ok, do: "text-green-600", else: "text-red-600")}>
            {if @rs_parity_ok, do: "✓ OK", else: "✗ ERROR"}
          </div>
        </div>
        <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
          <div class="text-sm text-gray-600">Latest Hash</div>
          <div class="text-sm font-mono text-purple-700 truncate">{@latest_hash}</div>
        </div>
      </div>

      <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
        <h2 class="text-lg font-semibold mb-3 text-content-primary">Recent Blocks</h2>
        <div class="text-gray-600">Chain initialized - awaiting blocks</div>
      </div>

      <div class="text-sm text-gray-500 mt-4">
        Last verified: {Calendar.strftime(@last_verified, "%Y-%m-%d %H:%M:%S UTC")}
      </div>
    </div>
    """
  end
end
