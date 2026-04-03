defmodule Indrajaal.Agents.PanopticSupervisor do
  @moduledoc """
  High-assurance Supervisor Agent for the SIL-6 Biomorphic Mesh.
  Maintains homeostasis by orchestrating the F# orchestrator binary.
  """

  use GenServer
  require Logger

  # 30 seconds
  @poll_interval 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Panoptic Supervisor Agent INITIATED.")
    send(self(), :monitor_homeostasis)
    {:ok, %{status: :starting, last_check: nil}}
  end

  @impl true
  def handle_info(:monitor_homeostasis, state) do
    Logger.debug("Executing biomorphic health probe...")

    case check_mesh_status() do
      :ok ->
        Logger.info("Homeostasis verified. SIL-6 Mesh stable.")
        schedule_next_check()
        {:noreply, %{state | status: :stable, last_check: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.error("SUBSTRATE DRIFT DETECTED: #{reason}. Initiating Panoptic Ignition...")
        ignite_mesh()
        schedule_next_check()
        {:noreply, %{state | status: :recovering, last_check: DateTime.utc_now()}}
    end
  end

  defp check_mesh_status do
    # Call F# binary
    case System.cmd("./sa-mesh", ["status"]) do
      {output, 0} ->
        if String.contains?(output, "Quorum: ACHIEVED") do
          :ok
        else
          {:error, "Quorum lost"}
        end

      {_, _} ->
        {:error, "Substrate unreachable"}
    end
  end

  defp ignite_mesh do
    Logger.warning("Triggering Panoptic Ignition Sequence via F# binary...")

    Task.start(fn ->
      System.cmd("./sa-mesh", ["ignite"])
    end)
  end

  defp schedule_next_check do
    Process.send_after(self(), :monitor_homeostasis, @poll_interval)
  end
end
