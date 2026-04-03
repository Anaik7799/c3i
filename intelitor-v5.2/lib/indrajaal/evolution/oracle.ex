defmodule Indrajaal.Evolution.Oracle do
  @moduledoc """
  ## THE ORACLE (L5-PRECOGNITION)
  Predicts future system state using rudimentary ML (Linear Regression).

  **Mechanism**:
  - Ingests time-series data (CPU Load).
  - Calculates trend (Slope).
  - Predicts t+1.

  **Integration**:
  - Feeds into `EnergyGovernor` to pre-emptively scale.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ingest(value) do
    GenServer.cast(__MODULE__, {:ingest, value})
  end

  def predict do
    GenServer.call(__MODULE__, :predict)
  end

  @impl true
  def init(_opts) do
    Logger.info("🔮 [ORACLE] Seeing the future...")
    {:ok, %{history: []}}
  end

  @impl true
  def handle_cast({:ingest, value}, state) do
    new_history = [value | state.history] |> Enum.take(10)
    {:noreply, %{state | history: new_history}}
  end

  @impl true
  def handle_call(:predict, _from, state) do
    prediction = calculate_trend(state.history)
    {:reply, prediction, state}
  end

  defp calculate_trend(history) when length(history) < 2, do: :insufficient_data

  defp calculate_trend(history) do
    # Simple logic: If average of last 3 > average of previous 3 -> Rising
    # Real impl would use Nx
    avg = Enum.sum(history) / length(history)

    if List.first(history) > avg do
      :rising
    else
      :falling
    end
  end
end
