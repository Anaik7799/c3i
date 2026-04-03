defmodule Indrajaal.Cockpit.Proprioceptive.Heatmap do
  @moduledoc """
  Entropy Heatmap - Visual Entropy Distribution for v20.0.0

  Implements heatmap generation for entropy visualization:
  - Spatial entropy mapping
  - Color gradient generation
  - Cell aggregation
  - Animation support

  ## Heatmap Model

  Grid-based entropy visualization:
  - Each cell represents a subsystem/component
  - Color intensity = entropy level
  - Animation shows temporal evolution

  ## Color Scheme (Thermal)
  - Blue (cold): Low entropy, stable
  - Green: Normal entropy
  - Yellow: Elevated entropy
  - Red (hot): High entropy, chaotic

  ## STAMP Constraints
  - SC-HMP-001: Heatmap update < 50ms
  - SC-HMP-002: Color mapping MUST be consistent
  - SC-HMP-003: Grid size MUST be configurable
  - SC-HMP-004: Historical snapshots MUST be available
  """

  use GenServer
  require Logger

  @type cell_id :: String.t()
  @type entropy_level :: float()
  @type color :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @type cell :: %{
          id: cell_id(),
          row: non_neg_integer(),
          col: non_neg_integer(),
          entropy: entropy_level(),
          color: color(),
          label: String.t(),
          metadata: map()
        }

  @type heatmap :: %{
          id: String.t(),
          rows: non_neg_integer(),
          cols: non_neg_integer(),
          cells: [cell()],
          timestamp: DateTime.t(),
          config: map()
        }

  @type state :: %{
          current: heatmap() | nil,
          history: [heatmap()],
          cell_mapping: map(),
          config: map()
        }

  # Default grid size
  @default_rows 10
  @default_cols 10

  # Max history snapshots
  @max_history 100

  # Update interval (ms)
  @update_interval 1_000

  # Color gradient (blue → green → yellow → red)
  @color_gradient [
    # Blue - low
    {0.0, {0, 0, 255}},
    # Green - normal
    {0.33, {0, 255, 0}},
    # Yellow - elevated
    {0.66, {255, 255, 0}},
    # Red - high
    {1.0, {255, 0, 0}}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current heatmap.
  """
  @spec current() :: heatmap() | nil
  def current do
    GenServer.call(__MODULE__, :current)
  end

  @doc """
  Updates a cell's entropy value.
  """
  @spec update_cell(cell_id(), entropy_level()) :: :ok
  def update_cell(cell_id, entropy) do
    GenServer.cast(__MODULE__, {:update_cell, cell_id, entropy})
  end

  @doc """
  Updates multiple cells at once.
  """
  @spec update_cells([{cell_id(), entropy_level()}]) :: :ok
  def update_cells(updates) do
    GenServer.cast(__MODULE__, {:update_cells, updates})
  end

  @doc """
  Registers a cell in the heatmap.
  """
  @spec register_cell(cell_id(), non_neg_integer(), non_neg_integer(), String.t()) :: :ok
  def register_cell(cell_id, row, col, label \\ "") do
    GenServer.cast(__MODULE__, {:register_cell, cell_id, row, col, label})
  end

  @doc """
  Gets historical heatmap at index.
  """
  @spec history(non_neg_integer()) :: heatmap() | nil
  def history(index) do
    GenServer.call(__MODULE__, {:history, index})
  end

  @doc """
  Gets all history.
  """
  @spec all_history() :: [heatmap()]
  def all_history do
    GenServer.call(__MODULE__, :all_history)
  end

  @doc """
  Renders heatmap as ASCII art.
  """
  @spec render_ascii() :: String.t()
  def render_ascii do
    GenServer.call(__MODULE__, :render_ascii)
  end

  @doc """
  Renders heatmap as JSON for web UI.
  """
  @spec render_json() :: map()
  def render_json do
    GenServer.call(__MODULE__, :render_json)
  end

  @doc """
  Maps entropy value to color.
  """
  @spec entropy_to_color(entropy_level()) :: color()
  def entropy_to_color(entropy) do
    # Clamp to [0, 1]
    clamped = max(0.0, min(1.0, entropy))

    # Find gradient segment
    {lower_t, lower_color, upper_t, upper_color} = find_gradient_segment(clamped)

    # Interpolate
    t = (clamped - lower_t) / max(upper_t - lower_t, 0.001)
    interpolate_color(lower_color, upper_color, t)
  end

  @doc """
  Gets heatmap statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    rows = Keyword.get(opts, :rows, @default_rows)
    cols = Keyword.get(opts, :cols, @default_cols)

    # Initialize empty heatmap
    initial_heatmap = create_empty_heatmap(rows, cols)

    state = %{
      current: initial_heatmap,
      history: [],
      cell_mapping: %{},
      stats: %{
        updates: 0,
        snapshots: 0,
        last_update: nil
      },
      config: %{
        rows: rows,
        cols: cols,
        max_history: Keyword.get(opts, :max_history, @max_history),
        auto_snapshot: Keyword.get(opts, :auto_snapshot, true)
      }
    }

    # Schedule periodic snapshots
    if state.config.auto_snapshot do
      Process.send_after(self(), :snapshot, @update_interval)
    end

    Logger.info("🔥 Heatmap service started (#{rows}x#{cols} grid)")

    {:ok, state}
  end

  @impl true
  def handle_call(:current, _from, state) do
    {:reply, state.current, state}
  end

  @impl true
  def handle_call({:history, index}, _from, state) do
    heatmap = Enum.at(state.history, index)
    {:reply, heatmap, state}
  end

  @impl true
  def handle_call(:all_history, _from, state) do
    {:reply, state.history, state}
  end

  @impl true
  def handle_call(:render_ascii, _from, state) do
    ascii = render_heatmap_ascii(state.current)
    {:reply, ascii, state}
  end

  @impl true
  def handle_call(:render_json, _from, state) do
    json = render_heatmap_json(state.current)
    {:reply, json, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        grid_size: {state.config.rows, state.config.cols},
        registered_cells: map_size(state.cell_mapping),
        history_count: length(state.history),
        avg_entropy: calculate_avg_entropy(state.current)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:update_cell, cell_id, entropy}, state) do
    new_current = update_cell_entropy(state.current, cell_id, entropy, state.cell_mapping)
    new_stats = %{state.stats | updates: state.stats.updates + 1, last_update: DateTime.utc_now()}
    {:noreply, %{state | current: new_current, stats: new_stats}}
  end

  @impl true
  def handle_cast({:update_cells, updates}, state) do
    new_current =
      Enum.reduce(updates, state.current, fn {cell_id, entropy}, heatmap ->
        update_cell_entropy(heatmap, cell_id, entropy, state.cell_mapping)
      end)

    new_stats = %{
      state.stats
      | updates: state.stats.updates + length(updates),
        last_update: DateTime.utc_now()
    }

    {:noreply, %{state | current: new_current, stats: new_stats}}
  end

  @impl true
  def handle_cast({:register_cell, cell_id, row, col, label}, state) do
    new_mapping = Map.put(state.cell_mapping, cell_id, {row, col, label})
    {:noreply, %{state | cell_mapping: new_mapping}}
  end

  @impl true
  def handle_info(:snapshot, state) do
    # Save current heatmap to history
    snapshot = %{state.current | id: generate_id(), timestamp: DateTime.utc_now()}

    new_history =
      [snapshot | state.history]
      |> Enum.take(state.config.max_history)

    new_stats = %{state.stats | snapshots: state.stats.snapshots + 1}

    # Schedule next snapshot
    Process.send_after(self(), :snapshot, @update_interval)

    {:noreply, %{state | history: new_history, stats: new_stats}}
  end

  # Private helpers

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  defp create_empty_heatmap(rows, cols) do
    cells =
      for row <- 0..(rows - 1), col <- 0..(cols - 1) do
        %{
          id: "cell_#{row}_#{col}",
          row: row,
          col: col,
          entropy: 0.0,
          color: entropy_to_color(0.0),
          label: "",
          metadata: %{}
        }
      end

    %{
      id: generate_id(),
      rows: rows,
      cols: cols,
      cells: cells,
      timestamp: DateTime.utc_now(),
      config: %{}
    }
  end

  defp update_cell_entropy(heatmap, cell_id, entropy, cell_mapping) do
    # Find cell position
    {row, col, _label} = Map.get(cell_mapping, cell_id, find_cell_by_id(heatmap, cell_id))

    new_cells =
      Enum.map(heatmap.cells, fn cell ->
        if cell.row == row and cell.col == col do
          %{cell | entropy: entropy, color: entropy_to_color(entropy)}
        else
          cell
        end
      end)

    %{heatmap | cells: new_cells, timestamp: DateTime.utc_now()}
  end

  defp find_cell_by_id(heatmap, cell_id) do
    case Enum.find(heatmap.cells, fn c -> c.id == cell_id end) do
      nil -> {0, 0, ""}
      cell -> {cell.row, cell.col, cell.label}
    end
  end

  defp find_gradient_segment(value) do
    segments =
      @color_gradient
      |> Enum.chunk_every(2, 1, :discard)

    segment =
      Enum.find(segments, fn [{lower_t, _}, {upper_t, _}] ->
        value >= lower_t and value <= upper_t
      end)

    case segment do
      [{lower_t, lower_color}, {upper_t, upper_color}] ->
        {lower_t, lower_color, upper_t, upper_color}

      nil ->
        # Default to last segment
        last_segments = Enum.take(segments, -1)

        [{lt, lc}, {ut, uc}] =
          last_segments |> List.first() || [{0.0, {0, 0, 255}}, {1.0, {255, 0, 0}}]

        {lt, lc, ut, uc}
    end
  end

  defp interpolate_color({r1, g1, b1}, {r2, g2, b2}, t) do
    r = round(r1 + (r2 - r1) * t)
    g = round(g1 + (g2 - g1) * t)
    b = round(b1 + (b2 - b1) * t)
    {r, g, b}
  end

  defp render_heatmap_ascii(nil), do: "No heatmap data"

  defp render_heatmap_ascii(heatmap) do
    # Build grid
    grid =
      Enum.reduce(heatmap.cells, %{}, fn cell, acc ->
        Map.put(acc, {cell.row, cell.col}, cell.entropy)
      end)

    # Render rows
    rows =
      for row <- 0..(heatmap.rows - 1) do
        cols =
          for col <- 0..(heatmap.cols - 1) do
            entropy = Map.get(grid, {row, col}, 0.0)
            entropy_to_char(entropy)
          end

        Enum.join(cols, "")
      end

    """
    ┌#{String.duplicate("─", heatmap.cols)}┐
    #{Enum.map_join(rows, "\n", fn r -> "│#{r}│" end)}
    └#{String.duplicate("─", heatmap.cols)}┘
    Legend: ░ low | ▒ normal | ▓ elevated | █ high
    """
  end

  defp entropy_to_char(entropy) do
    cond do
      entropy < 0.25 -> "░"
      entropy < 0.50 -> "▒"
      entropy < 0.75 -> "▓"
      true -> "█"
    end
  end

  defp render_heatmap_json(nil), do: %{error: "No heatmap data"}

  defp render_heatmap_json(heatmap) do
    %{
      id: heatmap.id,
      rows: heatmap.rows,
      cols: heatmap.cols,
      timestamp: DateTime.to_iso8601(heatmap.timestamp),
      cells:
        Enum.map(heatmap.cells, fn cell ->
          %{
            id: cell.id,
            row: cell.row,
            col: cell.col,
            entropy: cell.entropy,
            color: color_to_hex(cell.color),
            label: cell.label
          }
        end),
      stats: %{
        min_entropy: heatmap.cells |> Enum.map(& &1.entropy) |> Enum.min(fn -> 0.0 end),
        max_entropy: heatmap.cells |> Enum.map(& &1.entropy) |> Enum.max(fn -> 0.0 end),
        avg_entropy: calculate_avg_entropy(heatmap)
      }
    }
  end

  defp color_to_hex({r, g, b}) do
    r_str = Integer.to_string(r, 16)
    r_hex = r_str |> String.pad_leading(2, "0")
    g_str = Integer.to_string(g, 16)
    g_hex = g_str |> String.pad_leading(2, "0")
    b_str = Integer.to_string(b, 16)
    b_hex = b_str |> String.pad_leading(2, "0")
    "##{r_hex}#{g_hex}#{b_hex}"
  end

  defp calculate_avg_entropy(nil), do: 0.0

  defp calculate_avg_entropy(heatmap) do
    entropies = Enum.map(heatmap.cells, & &1.entropy)

    if Enum.empty?(entropies) do
      0.0
    else
      Enum.sum(entropies) / length(entropies)
    end
  end
end
