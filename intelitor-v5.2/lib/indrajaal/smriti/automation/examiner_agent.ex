defmodule Indrajaal.Smriti.Automation.ExaminerAgent do
  use GenServer
  require Logger
  alias Indrajaal.Smriti.Immune.SM2Algorithm

  @moduledoc """
  L3: Examiner Agent.
  Runs the Spaced Repetition System (SRS) loop.
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def review(holon_id, quality) do
    GenServer.call(__MODULE__, {:review, holon_id, quality})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:review, holon_id, quality}, _from, state) do
    # 1. Fetch Holon SRS state (simulated)
    current_state = %{repetitions: 0, ease_factor: 2.5, interval: 0}

    # 2. Calculate next schedule using SM2 algorithm
    result =
      SM2Algorithm.next_step(
        quality,
        current_state.repetitions,
        current_state.interval,
        current_state.ease_factor
      )

    next_date = result.next_review

    Logger.info("[Examiner] Reviewed #{holon_id}. Next review: #{next_date}")

    # 3. Update Holon (Placeholder)

    {:reply, {:ok, next_date}, state}
  end
end
