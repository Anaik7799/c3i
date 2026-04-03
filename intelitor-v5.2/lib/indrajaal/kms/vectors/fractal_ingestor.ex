defmodule Indrajaal.KMS.Vectors.FractalIngestor do
  @moduledoc """
  Autonomic Semantic Ingestor for 100% Substrate Coverage.

  WHAT: Recursively crawls the filesystem and vectorizes all source code.
  WHY: SC-SING-006 mandates 100% semantic saturation for Universal Intelligence.
  """

  use GenServer
  require Logger

  alias Indrajaal.KMS
  alias Indrajaal.KMS.Vectors

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type ingestor_state :: %{
          root_dir: String.t(),
          batch_size: integer(),
          interval_ms: integer(),
          active: boolean(),
          ingested_count: integer()
        }

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an immediate semantic crawl of the substrate.
  """
  def crawl_now do
    GenServer.cast(__MODULE__, :crawl)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[KMS.FractalIngestor] Initializing Semantic Saturation Agent")

    state = %{
      root_dir: Keyword.get(opts, :root_dir, "lib"),
      batch_size: Keyword.get(opts, :batch_size, 10),
      interval_ms: Keyword.get(opts, :interval_ms, :timer.minutes(5)),
      active: true,
      ingested_count: 0
    }

    # Delay start to allow system stabilization
    Process.send_after(self(), :crawl_tick, :timer.seconds(10))

    {:ok, state}
  end

  @impl true
  def handle_cast(:crawl, state) do
    new_state = perform_ingest_batch(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:crawl_tick, state) do
    new_state = perform_ingest_batch(state)
    schedule_next_crawl(state.interval_ms)
    {:noreply, new_state}
  end

  # ============================================================
  # INGESTION LOGIC
  # ============================================================

  defp perform_ingest_batch(state) do
    Logger.debug("[KMS.FractalIngestor] Identifying un-vectorized holons...")

    # 1. Discover all source files
    all_files = Path.wildcard("#{state.root_dir}/**/*.{ex,exs,fs,rs}")

    # 2. Identify missing files (Compare filesystem vs Vector index)
    # In production, this would be a single efficient SQL query
    missing_files = filter_unvectorized_files(all_files)

    # 3. Process a batch
    batch = Enum.take(missing_files, state.batch_size)

    Enum.each(batch, &vectorize_file/1)

    %{state | ingested_count: state.ingested_count + length(batch)}
  end

  defp filter_unvectorized_files(files) do
    # Simple check: does a holon exist for this path?
    Enum.filter(files, fn path ->
      holon_id = "hln_src_" <> (path |> String.replace("/", "_") |> String.replace(".", "_"))

      case KMS.get_holon(holon_id) do
        {:ok, _} -> false
        _ -> true
      end
    end)
  end

  defp vectorize_file(path) do
    try do
      content = File.read!(path)
      holon_id = "hln_src_" <> (path |> String.replace("/", "_") |> String.replace(".", "_"))

      KMS.create_holon(%{
        id: holon_id,
        name: Path.basename(path),
        type: :source_code,
        payload: %{content: content, path: path, vectorized: true}
      })

      # Use synthetic embedding for now (Sprint 71)
      # Later wired to local/remote LLM via Synapse
      embedding = generate_synthetic_embedding(content)
      Vectors.store_embedding(holon_id, embedding, model: "voyage-3-synthetic")

      Logger.info("[KMS.FractalIngestor] ✓ Vectorized: #{path}")
    rescue
      e -> Logger.error("[KMS.FractalIngestor] ❌ Failed to vectorize #{path}: #{inspect(e)}")
    end
  end

  defp generate_synthetic_embedding(text) do
    hash = :crypto.hash(:sha256, text)
    seed = :erlang.binary_to_list(hash) |> Enum.sum()
    :rand.seed(:exsss, {seed, seed, seed})
    Enum.map(1..1024, fn _ -> :rand.uniform() - 0.5 end)
  end

  defp schedule_next_crawl(interval) do
    Process.send_after(self(), :crawl_tick, interval)
  end
end
