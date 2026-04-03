defmodule Indrajaal.SMRITI.Senses.Extractors do
  @moduledoc """
  L1: Sensory Extractors for SMRITI.
  Handles fetching and normalizing content from external sources.

  ## WHAT
  Provides extraction functions for web URLs, PDFs, and audio files.
  Content is normalized into a uniform structure for downstream
  SMRITI ingestion.

  ## WHY
  SMRITI's sensory layer must accept heterogeneous input formats.
  Centralized extractors ensure consistent error handling, telemetry,
  and metadata enrichment before content enters the knowledge graph.

  ## CONSTRAINTS
  - SC-OODA-001: Extraction MUST be non-blocking (caller Task.start or async)
  - SC-PRF-055: No blocking I/O on the calling process
  - parse_pdf/1 and transcribe/1 require external libraries for real
    processing; they validate input and return structured responses
    indicating readiness, pending library integration.

  ## Change History
  | Version | Date       | Author | Change                          |
  |---------|------------|--------|---------------------------------|
  | 21.2.1  | 2026-03-20 | Claude | Implement parse_pdf/transcribe  |
  | 21.0.0  | 2026-01-01 | Team   | Initial module                  |
  """

  require Logger

  @version "21.2.1"
  @last_modified "2026-03-20"

  # ── Supported input types ──────────────────────────────────────────────────

  # PDF magic bytes: %PDF
  @pdf_magic <<0x25, 0x50, 0x44, 0x46>>

  # Common audio magic bytes
  # MP3 ID3 tag, raw MP3 frame sync, WAV RIFF, OGG, FLAC, M4A/AAC ftyp
  @audio_signatures [
    <<0x49, 0x44, 0x33>>,
    <<0xFF, 0xFB>>,
    <<0xFF, 0xF3>>,
    <<0xFF, 0xF2>>,
    <<0x52, 0x49, 0x46, 0x46>>,
    <<0x4F, 0x67, 0x67, 0x53>>,
    <<0x66, 0x4C, 0x61, 0x43>>,
    <<0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70>>
  ]

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Fetches content from a URL.
  Returns `{:ok, content, metadata}` or `{:error, reason}`.
  """
  @spec fetch_url(String.t()) :: {:ok, term(), map()} | {:error, term()}
  def fetch_url(url) when is_binary(url) do
    Logger.info("[SMRITI.Senses] Fetching URL: #{url}")

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body, %{source: url, type: :web}}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def fetch_url(_), do: {:error, :invalid_url}

  @doc """
  Parses a PDF file and extracts text content and metadata.

  Accepts either a file path (string) or raw binary content.

  Returns:
    `{:ok, %{text: String.t(), pages: non_neg_integer(), metadata: map()}}`
    or `{:error, reason}`

  ## Implementation Note
  Full PDF text extraction requires an external library such as
  `pdftotext` (Poppler CLI), a Rust NIF, or the `pdf_ex` hex package.
  This implementation validates the input, confirms the file is a PDF,
  and returns a structured response indicating the file was received.
  Real page-count and text extraction will be enabled once the PDF
  library dependency is added to mix.exs.

  ## Examples

      iex> Extractors.parse_pdf("/path/to/document.pdf")
      {:ok, %{text: "", pages: 0, metadata: %{source: "...", size_bytes: 1024, ...}}}

      iex> Extractors.parse_pdf("/nonexistent.pdf")
      {:error, :file_not_found}

  """
  @spec parse_pdf(String.t() | binary()) ::
          {:ok, %{text: String.t(), pages: non_neg_integer(), metadata: map()}}
          | {:error, atom() | String.t()}
  def parse_pdf(input) when is_binary(input) do
    start_ts = System.monotonic_time(:microsecond)

    result =
      cond do
        # File path given — must exist on disk
        printable_string?(input) and byte_size(input) < 4096 ->
          parse_pdf_from_path(input)

        # Raw binary — check magic bytes
        true ->
          parse_pdf_from_binary(input)
      end

    elapsed_us = System.monotonic_time(:microsecond) - start_ts
    emit_telemetry(:parse_pdf, result, elapsed_us)
    result
  end

  def parse_pdf(nil), do: {:error, :invalid_input}
  def parse_pdf(_), do: {:error, :invalid_input}

  @doc """
  Transcribes an audio file to text.

  Accepts either a file path (string) or raw binary content.

  Returns:
    `{:ok, %{text: String.t(), duration_seconds: number(), language: String.t(), confidence: float()}}`
    or `{:error, reason}`

  ## Implementation Note
  Full audio transcription requires an external service or library
  such as OpenAI Whisper, Vosk, or a Rust NIF. This implementation
  validates the input, confirms the file is an audio format, and
  returns a structured response indicating the file was received.
  Real transcription will be enabled once the audio library
  dependency is configured.

  ## Examples

      iex> Extractors.transcribe("/path/to/recording.mp3")
      {:ok, %{text: "", duration_seconds: 0.0, language: "en", confidence: 0.0}}

      iex> Extractors.transcribe("/nonexistent.mp3")
      {:error, :file_not_found}

  """
  @spec transcribe(String.t() | binary()) ::
          {:ok,
           %{
             text: String.t(),
             duration_seconds: float(),
             language: String.t(),
             confidence: float()
           }}
          | {:error, atom() | String.t()}
  def transcribe(input) when is_binary(input) do
    start_ts = System.monotonic_time(:microsecond)

    result =
      cond do
        printable_string?(input) and byte_size(input) < 4096 ->
          transcribe_from_path(input)

        true ->
          transcribe_from_binary(input)
      end

    elapsed_us = System.monotonic_time(:microsecond) - start_ts
    emit_telemetry(:transcribe, result, elapsed_us)
    result
  end

  def transcribe(nil), do: {:error, :invalid_input}
  def transcribe(_), do: {:error, :invalid_input}

  # ── Private: parse_pdf helpers ─────────────────────────────────────────────

  defp parse_pdf_from_path(path) do
    case File.read(path) do
      {:ok, binary} ->
        parse_pdf_from_binary(binary, path)

      {:error, :enoent} ->
        Logger.warning("[SMRITI.Senses.Extractors] parse_pdf: file not found: #{path}")
        {:error, :file_not_found}

      {:error, reason} ->
        Logger.warning("[SMRITI.Senses.Extractors] parse_pdf: read error #{reason}: #{path}")
        {:error, reason}
    end
  end

  defp parse_pdf_from_binary(binary, source \\ "<binary>") do
    size = byte_size(binary)

    if size == 0 do
      {:error, :empty_input}
    else
      case detect_pdf(binary) do
        :not_pdf ->
          Logger.warning("[SMRITI.Senses.Extractors] parse_pdf: not a PDF (no %PDF header)")
          {:error, :not_a_pdf}

        :pdf ->
          Logger.info(
            "[SMRITI.Senses.Extractors] parse_pdf: PDF received (#{size} bytes), " <>
              "real extraction requires PDF library — returning structured stub"
          )

          # ⚠️ ESCAPE HATCH: Real PDF parsing requires pdftotext (Poppler CLI),
          # pdf_ex hex package, or a Rust NIF. Validate input is real PDF,
          # return structured response so callers can handle gracefully.
          {:ok,
           %{
             text: "",
             pages: 0,
             metadata: %{
               source: source,
               size_bytes: size,
               extraction_status: :pending_library,
               extraction_note:
                 "Add pdftotext CLI or pdf_ex dependency to enable full extraction",
               content_type: "application/pdf",
               received_at: DateTime.utc_now() |> DateTime.to_iso8601()
             }
           }}
      end
    end
  end

  # ── Private: transcribe helpers ────────────────────────────────────────────

  defp transcribe_from_path(path) do
    case File.read(path) do
      {:ok, binary} ->
        transcribe_from_binary(binary, path)

      {:error, :enoent} ->
        Logger.warning("[SMRITI.Senses.Extractors] transcribe: file not found: #{path}")
        {:error, :file_not_found}

      {:error, reason} ->
        Logger.warning("[SMRITI.Senses.Extractors] transcribe: read error #{reason}: #{path}")
        {:error, reason}
    end
  end

  defp transcribe_from_binary(binary, source \\ "<binary>") do
    size = byte_size(binary)

    if size == 0 do
      {:error, :empty_input}
    else
      case detect_audio(binary) do
        :not_audio ->
          Logger.warning(
            "[SMRITI.Senses.Extractors] transcribe: unrecognised audio format " <>
              "(no known magic bytes)"
          )

          {:error, :unsupported_audio_format}

        :audio ->
          Logger.info(
            "[SMRITI.Senses.Extractors] transcribe: audio received (#{size} bytes), " <>
              "real transcription requires Whisper/Vosk — returning structured stub"
          )

          # ⚠️ ESCAPE HATCH: Real transcription requires OpenAI Whisper API,
          # Vosk NIF, or a local model runner. Input validated as audio binary.
          # Returns structured response so callers can handle gracefully.
          {:ok,
           %{
             text: "",
             duration_seconds: 0.0,
             language: "en",
             confidence: 0.0,
             metadata: %{
               source: source,
               size_bytes: size,
               transcription_status: :pending_library,
               transcription_note:
                 "Configure OPENROUTER_API_KEY or Vosk NIF to enable transcription",
               received_at: DateTime.utc_now() |> DateTime.to_iso8601()
             }
           }}
      end
    end
  end

  # ── Private: format detection ──────────────────────────────────────────────

  @spec detect_pdf(binary()) :: :pdf | :not_pdf
  defp detect_pdf(<<@pdf_magic, _rest::binary>>), do: :pdf
  defp detect_pdf(_), do: :not_pdf

  @spec detect_audio(binary()) :: :audio | :not_audio
  defp detect_audio(binary) do
    if Enum.any?(@audio_signatures, fn sig ->
         sig_size = byte_size(sig)
         binary_size = byte_size(binary)

         if binary_size >= sig_size do
           :binary.longest_common_prefix([binary, sig]) == sig_size
         else
           false
         end
       end) do
      :audio
    else
      :not_audio
    end
  end

  # ── Private: helpers ───────────────────────────────────────────────────────

  # A "printable string" is a path-like binary: all bytes are printable ASCII
  # or common path characters. This distinguishes "/path/to/file.pdf" from
  # raw binary content.
  @spec printable_string?(binary()) :: boolean()
  defp printable_string?(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(fn byte -> byte >= 0x20 and byte <= 0x7E end)
  end

  # ── Private: telemetry ─────────────────────────────────────────────────────

  defp emit_telemetry(operation, result, elapsed_us) do
    status =
      case result do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end

    :telemetry.execute(
      [:smriti, :senses, :extractor, operation],
      %{duration_us: elapsed_us},
      %{operation: operation, status: status, version: @version, last_modified: @last_modified}
    )
  end
end
