defmodule Indrajaal.Cockpit.Prajna.Guardian.CircuitBreaker do
  @moduledoc """
  Circuit breaker for Guardian operations.
  STAMP: SC-SIL4-001
  """
  use GenServer
  require Logger

  @threshold 3
  @reset_timeout 30_000

  defstruct [:failures, :state, :last_failure]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{failures: 0, state: :closed, last_failure: nil},
      name: __MODULE__
    )
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def check do
    GenServer.call(__MODULE__, :check)
  end

  def report_success do
    GenServer.cast(__MODULE__, :report_success)
  end

  def report_failure do
    GenServer.cast(__MODULE__, :report_failure)
  end

  @impl true
  def handle_call(:check, _from, %{state: :open, last_failure: last} = state) do
    if DateTime.diff(DateTime.utc_now(), last, :millisecond) > @reset_timeout do
      {:reply, :half_open, %{state | state: :half_open}}
    else
      {:reply, :open, state}
    end
  end

  def handle_call(:check, _from, state), do: {:reply, state.state, state}

  @impl true
  def handle_cast(:report_success, state) do
    {:noreply, %{state | failures: 0, state: :closed}}
  end

  def handle_cast(:report_failure, state) do
    new_failures = state.failures + 1
    new_state = if new_failures >= @threshold, do: :open, else: state.state

    if new_state == :open and state.state != :open do
      Logger.warning("Circuit Breaker TRIPPED")
    end

    {:noreply,
     %{state | failures: new_failures, state: new_state, last_failure: DateTime.utc_now()}}
  end
end
