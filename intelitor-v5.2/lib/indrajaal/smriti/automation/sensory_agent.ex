defmodule Indrajaal.Smriti.Automation.SensoryAgent do
  use GenServer
  require Logger
  alias Indrajaal.Smriti.Senses.IngestionPipeline

  @moduledoc """
  L3: Sensory Agent.
  OODA Loop for content ingestion: Detects content type, assigns priority, schedules processing.
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def process(content, source) do
    GenServer.cast(__MODULE__, {:process, content, source})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, content, source}, state) do
    # 1. Observe: Receive input
    # 2. Orient: Detect type
    type = detect_type(content, source)
    priority = assign_priority(type)

    Logger.info("[SensoryAgent] Processing #{type} from #{source} (P#{priority})")

    # 3. Decide: Schedule
    # 4. Act: Push to Pipeline
    IngestionPipeline.ingest(content, %{type: type, source: source, priority: priority})

    {:noreply, state}
  end

  defp detect_type(_content, source) do
    cond do
      String.ends_with?(source, ".pdf") -> :pdf
      String.starts_with?(source, "http") -> :web
      true -> :text
    end
  end

  defp assign_priority(:web), do: :p3
  defp assign_priority(:pdf), do: :p2
  defp assign_priority(:text), do: :p1
end
