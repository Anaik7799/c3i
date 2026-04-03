defmodule Indrajaal.SMRITI.Senses.ExtractorsTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.SMRITI.Senses.Extractors.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation per Ω₄
  - FPPS Validation: 5-method consensus verification of extraction contracts

  ## STAMP Safety Integration
  - SC-OODA-001: Extraction MUST be non-blocking (no blocking I/O on caller)
  - SC-PRF-055: No blocking I/O on the calling process
  - SC-SMRITI-080: Input validation gates before processing

  ## Constitutional Verification
  - Ψ₀ Existence: System continues to exist when invalid inputs are supplied
  - Ψ₁ Regeneration: Metadata always includes received_at for reconstruction
  - Ψ₃ Verification: Content-type and extraction_status fields enable auditability
  - Ψ₅ Truthfulness: extraction_status :pending_library is honest about capability

  ## Founder's Directive Alignment
  - Ω₀.1: Extraction layer is the sensory input enabling SMRITI knowledge growth

  ## TPS 5-Level RCA Context
  - L1 Symptom: Extraction returning unexpected errors or incorrect results
  - L5 Root Cause: Magic-byte detection logic failing to discriminate formats

  ## FMEA Coverage
  | Failure Mode              | Severity | Occurrence | Detection | RPN |
  |---------------------------|----------|------------|-----------|-----|
  | Non-PDF passed as PDF     |    6     |     4      |     3     |  72 |
  | Non-audio passed as audio |    6     |     4      |     3     |  72 |
  | Empty binary input        |    4     |     3      |     8     |  96 |
  | Non-binary parse_pdf arg  |    5     |     2      |     9     |  90 |
  | File not found            |    5     |     3      |     8     | 120 |
  """

  use ExUnit.Case, async: true
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check/2 to avoid ambiguity with ExUnitProperties
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :sprint_54

  alias Indrajaal.SMRITI.Senses.Extractors

  # ============================================================
  # PDF MAGIC BYTES AND AUDIO SIGNATURES (mirrors the module)
  # ============================================================

  # %PDF magic bytes
  @pdf_magic <<0x25, 0x50, 0x44, 0x46>>

  # ID3-tagged MP3 magic bytes
  @mp3_id3_magic <<0x49, 0x44, 0x33>>

  # WAV RIFF magic bytes
  @wav_riff_magic <<0x52, 0x49, 0x46, 0x46>>

  # OGG magic bytes
  @ogg_magic <<0x4F, 0x67, 0x67, 0x53>>

  # FLAC magic bytes
  @flac_magic <<0x66, 0x4C, 0x61, 0x43>>

  # ============================================================
  # HELPERS
  # ============================================================

  defp minimal_pdf_binary do
    # Minimal valid PDF binary starting with %PDF magic
    @pdf_magic <> "-1.4 minimal test content"
  end

  defp minimal_mp3_binary do
    @mp3_id3_magic <> <<0x03, 0x00, 0x00, 0x00, 0x00, 0x00>> <> "audio content"
  end

  defp minimal_wav_binary do
    @wav_riff_magic <> <<0x00, 0x00, 0x00, 0x00>> <> "WAVE" <> "audio content"
  end

  defp minimal_ogg_binary do
    @ogg_magic <> <<0x00>> <> "OGG content follows"
  end

  defp minimal_flac_binary do
    @flac_magic <> <<0x00>> <> "FLAC metadata"
  end

  # ============================================================
  # parse_pdf/1 — HAPPY PATHS
  # ============================================================

  describe "parse_pdf/1 with raw binary" do
    test "accepts valid PDF binary and returns structured ok tuple" do
      binary = minimal_pdf_binary()
      result = Extractors.parse_pdf(binary)

      assert {:ok, %{text: text, pages: pages, metadata: metadata}} = result
      assert is_binary(text)
      assert is_integer(pages)
      assert pages >= 0
      assert is_map(metadata)
    end

    test "metadata contains required keys for Ψ₁ regeneration" do
      binary = minimal_pdf_binary()
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(binary)

      assert Map.has_key?(metadata, :source)
      assert Map.has_key?(metadata, :size_bytes)
      assert Map.has_key?(metadata, :extraction_status)
      assert Map.has_key?(metadata, :content_type)
      assert Map.has_key?(metadata, :received_at)
    end

    test "metadata source is '<binary>' when raw binary is given" do
      binary = minimal_pdf_binary()
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(binary)

      assert metadata.source == "<binary>"
    end

    test "metadata size_bytes equals byte_size of input" do
      binary = minimal_pdf_binary()
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(binary)

      assert metadata.size_bytes == byte_size(binary)
    end

    test "metadata content_type is 'application/pdf' for valid PDF" do
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(minimal_pdf_binary())

      assert metadata.content_type == "application/pdf"
    end

    test "extraction_status is :pending_library (Ψ₅ truthfulness)" do
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(minimal_pdf_binary())

      assert metadata.extraction_status == :pending_library
    end

    test "received_at is a valid ISO 8601 timestamp" do
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(minimal_pdf_binary())

      assert is_binary(metadata.received_at)
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(metadata.received_at)
    end
  end

  # ============================================================
  # parse_pdf/1 — ERROR CASES
  # ============================================================

  describe "parse_pdf/1 error cases" do
    test "returns {:error, :not_a_pdf} for non-PDF binary" do
      # PNG magic bytes
      non_pdf = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> "not a pdf"
      assert {:error, :not_a_pdf} = Extractors.parse_pdf(non_pdf)
    end

    test "returns {:error, :empty_input} for empty binary" do
      assert {:error, :empty_input} = Extractors.parse_pdf(<<>>)
    end

    test "returns {:error, :file_not_found} for nonexistent path" do
      assert {:error, :file_not_found} = Extractors.parse_pdf("/nonexistent/path/document.pdf")
    end

    test "returns {:error, :invalid_input} for nil" do
      assert {:error, :invalid_input} = Extractors.parse_pdf(nil)
    end

    test "returns {:error, :invalid_input} for integer" do
      assert {:error, :invalid_input} = Extractors.parse_pdf(42)
    end

    test "returns {:error, :invalid_input} for list" do
      assert {:error, :invalid_input} = Extractors.parse_pdf([:pdf])
    end

    test "returns {:error, :invalid_input} for atom" do
      assert {:error, :invalid_input} = Extractors.parse_pdf(:pdf)
    end
  end

  # ============================================================
  # parse_pdf/1 — FILE PATH HAPPY PATH (temp file)
  # ============================================================

  describe "parse_pdf/1 with file path" do
    test "reads a real PDF file from disk and returns ok" do
      # Write a minimal PDF to a temp file
      path =
        System.tmp_dir!() |> Path.join("smriti_test_#{:erlang.unique_integer([:positive])}.pdf")

      File.write!(path, minimal_pdf_binary())

      on_exit(fn -> File.rm(path) end)

      result = Extractors.parse_pdf(path)
      assert {:ok, %{metadata: %{source: ^path}}} = result
    end

    test "metadata source equals the file path given" do
      path =
        System.tmp_dir!()
        |> Path.join("smriti_src_test_#{:erlang.unique_integer([:positive])}.pdf")

      binary = minimal_pdf_binary()
      File.write!(path, binary)
      on_exit(fn -> File.rm(path) end)

      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(path)
      assert metadata.source == path
    end

    test "returns error for path pointing to non-PDF file" do
      path =
        System.tmp_dir!() |> Path.join("smriti_notpdf_#{:erlang.unique_integer([:positive])}.pdf")

      # Write PNG bytes to a file with .pdf extension
      File.write!(path, <<0x89, 0x50, 0x4E, 0x47>> <> "this is not a pdf")
      on_exit(fn -> File.rm(path) end)

      assert {:error, :not_a_pdf} = Extractors.parse_pdf(path)
    end
  end

  # ============================================================
  # transcribe/1 — HAPPY PATHS
  # ============================================================

  describe "transcribe/1 with raw binary" do
    test "accepts MP3 (ID3) binary and returns structured ok tuple" do
      result = Extractors.transcribe(minimal_mp3_binary())

      assert {:ok, %{text: text, duration_seconds: dur, language: lang, confidence: conf}} =
               result

      assert is_binary(text)
      assert is_float(dur)
      assert is_binary(lang)
      assert is_float(conf)
    end

    test "accepts WAV binary and returns ok" do
      assert {:ok, _} = Extractors.transcribe(minimal_wav_binary())
    end

    test "accepts OGG binary and returns ok" do
      assert {:ok, _} = Extractors.transcribe(minimal_ogg_binary())
    end

    test "accepts FLAC binary and returns ok" do
      assert {:ok, _} = Extractors.transcribe(minimal_flac_binary())
    end

    test "metadata contains required keys for Ψ₁ regeneration" do
      {:ok, result} = Extractors.transcribe(minimal_mp3_binary())

      assert Map.has_key?(result, :metadata)
      metadata = result.metadata
      assert Map.has_key?(metadata, :source)
      assert Map.has_key?(metadata, :size_bytes)
      assert Map.has_key?(metadata, :transcription_status)
      assert Map.has_key?(metadata, :received_at)
    end

    test "transcription_status is :pending_library (Ψ₅ truthfulness)" do
      {:ok, %{metadata: metadata}} = Extractors.transcribe(minimal_mp3_binary())

      assert metadata.transcription_status == :pending_library
    end

    test "language defaults to 'en'" do
      {:ok, %{language: lang}} = Extractors.transcribe(minimal_mp3_binary())
      assert lang == "en"
    end

    test "metadata size_bytes equals byte_size of input" do
      binary = minimal_mp3_binary()
      {:ok, %{metadata: metadata}} = Extractors.transcribe(binary)

      assert metadata.size_bytes == byte_size(binary)
    end

    test "received_at is a valid ISO 8601 timestamp" do
      {:ok, %{metadata: metadata}} = Extractors.transcribe(minimal_mp3_binary())

      assert is_binary(metadata.received_at)
      assert {:ok, _dt, _offset} = DateTime.from_iso8601(metadata.received_at)
    end
  end

  # ============================================================
  # transcribe/1 — ERROR CASES
  # ============================================================

  describe "transcribe/1 error cases" do
    test "returns {:error, :unsupported_audio_format} for random binary" do
      # Random bytes with no recognizable audio signature
      garbage = <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08>> <> "some data here"
      assert {:error, :unsupported_audio_format} = Extractors.transcribe(garbage)
    end

    test "returns {:error, :unsupported_audio_format} for PDF binary" do
      # PDF is not audio
      assert {:error, :unsupported_audio_format} = Extractors.transcribe(minimal_pdf_binary())
    end

    test "returns {:error, :empty_input} for empty binary" do
      assert {:error, :empty_input} = Extractors.transcribe(<<>>)
    end

    test "returns {:error, :file_not_found} for nonexistent path" do
      assert {:error, :file_not_found} = Extractors.transcribe("/nonexistent/path/audio.mp3")
    end

    test "returns {:error, :invalid_input} for nil" do
      assert {:error, :invalid_input} = Extractors.transcribe(nil)
    end

    test "returns {:error, :invalid_input} for integer" do
      assert {:error, :invalid_input} = Extractors.transcribe(42)
    end

    test "returns {:error, :invalid_input} for atom" do
      assert {:error, :invalid_input} = Extractors.transcribe(:mp3)
    end
  end

  # ============================================================
  # transcribe/1 — FILE PATH
  # ============================================================

  describe "transcribe/1 with file path" do
    test "reads a real audio file from disk and returns ok" do
      path =
        System.tmp_dir!()
        |> Path.join("smriti_audio_test_#{:erlang.unique_integer([:positive])}.mp3")

      File.write!(path, minimal_mp3_binary())
      on_exit(fn -> File.rm(path) end)

      assert {:ok, _} = Extractors.transcribe(path)
    end

    test "metadata source equals the file path given" do
      path =
        System.tmp_dir!()
        |> Path.join("smriti_audio_src_#{:erlang.unique_integer([:positive])}.mp3")

      File.write!(path, minimal_mp3_binary())
      on_exit(fn -> File.rm(path) end)

      {:ok, %{metadata: metadata}} = Extractors.transcribe(path)
      assert metadata.source == path
    end
  end

  # ============================================================
  # fetch_url/1 — ERROR CASES (no network in tests)
  # ============================================================

  describe "fetch_url/1 invalid input" do
    test "returns {:error, :invalid_url} for non-binary input" do
      assert {:error, :invalid_url} = Extractors.fetch_url(nil)
      assert {:error, :invalid_url} = Extractors.fetch_url(42)
      assert {:error, :invalid_url} = Extractors.fetch_url(:url)
    end

    test "returns an error tuple for unreachable URL" do
      # An obviously non-routable URL in unit tests
      result = Extractors.fetch_url("http://0.0.0.0:0/nonexistent")
      assert match?({:error, _}, result)
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  describe "property tests (PropCheck)" do
    @tag :property
    property "parse_pdf with any non-PDF binary returns error or ok" do
      # All results must be tagged tuples
      forall binary <- PC.binary() do
        result = Extractors.parse_pdf(binary)
        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    property "transcribe with any binary returns error or ok tagged tuple" do
      forall binary <- PC.binary() do
        result = Extractors.transcribe(binary)
        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    property "parse_pdf with valid PDF binary always returns ok" do
      forall suffix <- PC.binary() do
        pdf = @pdf_magic <> suffix
        result = Extractors.parse_pdf(pdf)
        match?({:ok, _}, result)
      end
    end

    @tag :property
    property "parse_pdf result metadata size_bytes matches input for raw binary" do
      forall suffix <- PC.binary() do
        pdf = @pdf_magic <> suffix
        {:ok, %{metadata: %{size_bytes: size}}} = Extractors.parse_pdf(pdf)
        size == byte_size(pdf)
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (ExUnitProperties / StreamData)
  # ============================================================

  describe "property tests (StreamData)" do
    @tag :property
    test "parse_pdf result is always a tagged tuple for valid PDF binaries" do
      ExUnitProperties.check all(suffix <- SD.binary(min_length: 0, max_length: 256)) do
        pdf = @pdf_magic <> suffix
        result = Extractors.parse_pdf(pdf)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    test "transcribe result is always a tagged tuple for any non-empty binary" do
      ExUnitProperties.check all(binary <- SD.binary(min_length: 1, max_length: 512)) do
        result = Extractors.transcribe(binary)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    test "fetch_url returns tagged tuple for any string input" do
      ExUnitProperties.check all(
                               url <-
                                 SD.one_of([
                                   SD.constant("http://0.0.0.0:0/fail"),
                                   SD.string(:printable, min_length: 1, max_length: 50)
                                 ])
                             ) do
        result = Extractors.fetch_url(url)
        assert match?({:ok, _, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    test "parse_pdf with audio binary returns :not_a_pdf error" do
      audio_signatures = [
        @mp3_id3_magic,
        @wav_riff_magic,
        @ogg_magic,
        @flac_magic
      ]

      ExUnitProperties.check all(
                               sig <- SD.member_of(audio_signatures),
                               suffix <- SD.binary(min_length: 4, max_length: 64)
                             ) do
        audio_binary = sig <> suffix
        result = Extractors.parse_pdf(audio_binary)
        assert match?({:error, :not_a_pdf}, result)
      end
    end

    @tag :property
    test "transcribe with valid audio signatures always returns ok" do
      audio_signatures = [
        @mp3_id3_magic,
        @wav_riff_magic,
        @ogg_magic,
        @flac_magic
      ]

      ExUnitProperties.check all(
                               sig <- SD.member_of(audio_signatures),
                               suffix <- SD.binary(min_length: 4, max_length: 64)
                             ) do
        audio_binary = sig <> suffix
        result = Extractors.transcribe(audio_binary)
        assert match?({:ok, _}, result)
      end
    end
  end

  # ============================================================
  # FMEA TESTS
  # ============================================================

  describe "FMEA - failure modes" do
    @tag :fmea
    test "parse_pdf does not crash on very large binary" do
      # 1 MB of PDF-magic-prefixed data
      large_payload = @pdf_magic <> :binary.copy(<<0x00>>, 1_000_000)
      result = Extractors.parse_pdf(large_payload)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "transcribe does not crash on very large binary" do
      large_payload = @mp3_id3_magic <> :binary.copy(<<0x00>>, 1_000_000)
      result = Extractors.transcribe(large_payload)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "parse_pdf handles single-byte binary gracefully" do
      result = Extractors.parse_pdf(<<0x25>>)
      # Single byte that starts with % but is not a full PDF header
      assert match?({:error, :not_a_pdf}, result)
    end

    @tag :fmea
    test "fetch_url handles non-binary argument per Ψ₀ existence" do
      # System must not crash on invalid input
      assert {:error, :invalid_url} = Extractors.fetch_url(nil)
      assert {:error, :invalid_url} = Extractors.fetch_url(123)
      assert {:error, :invalid_url} = Extractors.fetch_url(%{url: "x"})
    end

    @tag :fmea
    test "transcribe does not crash with null bytes in binary" do
      binary = @mp3_id3_magic <> <<0x00, 0x00, 0x00>>
      result = Extractors.transcribe(binary)
      assert match?({:ok, _}, result)
    end
  end

  # ============================================================
  # CONSTITUTIONAL INVARIANT TESTS
  # ============================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence: parse_pdf never raises on any binary input" do
      inputs = [
        <<>>,
        <<0x00>>,
        @pdf_magic,
        minimal_pdf_binary(),
        "not a pdf at all",
        :binary.copy(<<0xFF>>, 100)
      ]

      for input <- inputs do
        result = Extractors.parse_pdf(input)

        assert match?({:ok, _}, result) or match?({:error, _}, result),
               "Expected tagged tuple for input: #{inspect(input, limit: 10)}"
      end
    end

    test "Ψ₀ existence: transcribe never raises on any binary input" do
      inputs = [
        <<>>,
        <<0x00>>,
        @mp3_id3_magic,
        minimal_mp3_binary(),
        "not audio",
        :binary.copy(<<0xFF>>, 50)
      ]

      for input <- inputs do
        result = Extractors.transcribe(input)

        assert match?({:ok, _}, result) or match?({:error, _}, result),
               "Expected tagged tuple for input: #{inspect(input, limit: 10)}"
      end
    end

    test "Ψ₁ regeneration: parse_pdf ok result always includes received_at for timeline reconstruction" do
      {:ok, %{metadata: metadata}} = Extractors.parse_pdf(minimal_pdf_binary())
      assert is_binary(metadata.received_at)
      # received_at must be parseable for event sourcing / holon regeneration
      assert {:ok, %DateTime{}, _} = DateTime.from_iso8601(metadata.received_at)
    end

    test "Ψ₁ regeneration: transcribe ok result always includes received_at" do
      {:ok, %{metadata: metadata}} = Extractors.transcribe(minimal_mp3_binary())
      assert is_binary(metadata.received_at)
      assert {:ok, %DateTime{}, _} = DateTime.from_iso8601(metadata.received_at)
    end

    test "Ψ₅ truthfulness: parse_pdf never claims extraction succeeded without library" do
      {:ok, %{text: text, pages: pages, metadata: metadata}} =
        Extractors.parse_pdf(minimal_pdf_binary())

      # text is empty because real extraction is pending
      assert text == ""
      # pages is 0 because real extraction is pending
      assert pages == 0
      # status honestly reports pending
      assert metadata.extraction_status == :pending_library
    end

    test "Ψ₅ truthfulness: transcribe never claims real transcription occurred" do
      {:ok, result} = Extractors.transcribe(minimal_mp3_binary())

      # text is empty because real transcription is pending
      assert result.text == ""
      # duration is 0.0 because real parsing is pending
      assert result.duration_seconds == 0.0
      # confidence is 0.0 because no real model ran
      assert result.confidence == 0.0
      assert result.metadata.transcription_status == :pending_library
    end
  end

  # ============================================================
  # TELEMETRY TESTS
  # ============================================================

  describe "telemetry emission" do
    test "parse_pdf emits telemetry event on success" do
      test_pid = self()

      :telemetry.attach(
        "test-parse-pdf-ok-#{:erlang.unique_integer()}",
        [:smriti, :senses, :extractor, :parse_pdf],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :parse_pdf, measurements, metadata})
        end,
        nil
      )

      Extractors.parse_pdf(minimal_pdf_binary())

      assert_receive {:telemetry, :parse_pdf, measurements, meta}, 1000
      assert is_integer(measurements.duration_us)
      assert measurements.duration_us >= 0
      assert meta.operation == :parse_pdf
      assert meta.status == :ok
    end

    test "parse_pdf emits telemetry event on error" do
      test_pid = self()

      :telemetry.attach(
        "test-parse-pdf-err-#{:erlang.unique_integer()}",
        [:smriti, :senses, :extractor, :parse_pdf],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :parse_pdf_err, measurements, metadata})
        end,
        nil
      )

      Extractors.parse_pdf(<<0x00, 0x00, 0x00>>)

      assert_receive {:telemetry, :parse_pdf_err, measurements, meta}, 1000
      assert meta.status == :error
      assert measurements.duration_us >= 0
    end

    test "transcribe emits telemetry event on success" do
      test_pid = self()

      :telemetry.attach(
        "test-transcribe-ok-#{:erlang.unique_integer()}",
        [:smriti, :senses, :extractor, :transcribe],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, :transcribe, measurements, metadata})
        end,
        nil
      )

      Extractors.transcribe(minimal_mp3_binary())

      assert_receive {:telemetry, :transcribe, measurements, meta}, 1000
      assert meta.operation == :transcribe
      assert meta.status == :ok
      assert measurements.duration_us >= 0
    end
  end
end
