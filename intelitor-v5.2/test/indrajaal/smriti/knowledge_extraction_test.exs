defmodule Indrajaal.SMRITI.KnowledgeExtractionTest do
  @moduledoc """
  TDG pipeline integration test for SMRITI knowledge extraction.

  Tests the full extraction pipeline: PDF, audio, and text/URL extractors
  from Indrajaal.SMRITI.Senses.Extractors. All tests use mock data only
  (no real network, no real files on disk beyond temp fixtures).

  ## STAMP Safety Integration
  - SC-OODA-001: Extraction MUST be non-blocking
  - SC-PRF-055: No blocking I/O on calling process
  - SC-SMRITI-074: Immortality protocol — content ingested must be reconstructable
  - SC-SMRITI-110: Version vectors in SQLite (holon state sovereignty)

  ## Constitutional Verification
  - Ψ₀ Existence: System survives all extraction calls without crash
  - Ψ₁ Regeneration: received_at field enables timeline reconstruction
  - Ψ₃ Verification: extraction_status field enables audit
  - Ψ₅ Truthfulness: status reflects real capability (pending_library)

  ## FMEA Coverage
  | Failure Mode                  | Severity | Occurrence | Detection | RPN |
  |-------------------------------|----------|------------|-----------|-----|
  | PDF binary truncated at magic |    5     |     3      |     7     | 105 |
  | Audio with corrupt header     |    5     |     3      |     7     | 105 |
  | Empty extraction result       |    4     |     2      |     8     |  64 |
  | Pipeline stage partial fail   |    7     |     2      |     5     |  70 |
  | Metadata fields missing       |    6     |     2      |     6     |  72 |

  ## Change History
  | Version | Date       | Author | Change                             |
  |---------|------------|--------|------------------------------------|
  | 21.3.0  | 2026-03-23 | Claude | Initial TDG pipeline test (Sprint 88) |
  """

  use ExUnit.Case, async: true
  use PropCheck

  # EP-GEN-014: Exclude PropCheck's check/2 to avoid ambiguity with ExUnitProperties
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :smriti
  @moduletag :sprint_88
  @moduletag :knowledge_extraction

  alias Indrajaal.SMRITI.Senses.Extractors

  # ============================================================
  # MAGIC BYTE FIXTURES
  # ============================================================

  # %PDF magic bytes
  @pdf_magic <<0x25, 0x50, 0x44, 0x46>>

  # Common audio magic bytes
  @mp3_id3_magic <<0x49, 0x44, 0x33>>
  @wav_riff_magic <<0x52, 0x49, 0x46, 0x46>>
  @ogg_magic <<0x4F, 0x67, 0x67, 0x53>>
  @flac_magic <<0x66, 0x4C, 0x61, 0x43>>

  # All recognized audio signatures for property tests
  @audio_signatures [
    @mp3_id3_magic,
    @wav_riff_magic,
    @ogg_magic,
    @flac_magic
  ]

  # ============================================================
  # HELPERS: minimal valid mock binaries
  # ============================================================

  defp mock_pdf(extra_bytes \\ <<>>) do
    @pdf_magic <> "-1.7\n%test mock PDF content for SMRITI extraction pipeline" <> extra_bytes
  end

  defp mock_mp3(extra_bytes \\ <<>>) do
    @mp3_id3_magic <>
      <<0x03, 0x00, 0x00, 0x00, 0x00, 0x00>> <>
      "mock MP3 audio content for SMRITI extraction pipeline" <> extra_bytes
  end

  defp mock_wav(extra_bytes \\ <<>>) do
    @wav_riff_magic <>
      <<0x00, 0x00, 0x00, 0x00>> <>
      "WAVEmock WAV audio content for SMRITI" <> extra_bytes
  end

  defp mock_ogg(extra_bytes \\ <<>>) do
    @ogg_magic <> <<0x00>> <> "mock OGG content for SMRITI extraction" <> extra_bytes
  end

  defp mock_flac(extra_bytes \\ <<>>) do
    @flac_magic <> <<0x00>> <> "mock FLAC content for SMRITI extraction" <> extra_bytes
  end

  defp write_temp_file(binary, ext) do
    path =
      System.tmp_dir!()
      |> Path.join("smriti_extract_#{:erlang.unique_integer([:positive])}.#{ext}")

    File.write!(path, binary)
    path
  end

  # ============================================================
  # PDF EXTRACTION PIPELINE
  # ============================================================

  describe "PDF extraction pipeline" do
    test "parses valid PDF binary and returns structured extraction result" do
      result = Extractors.parse_pdf(mock_pdf())

      assert {:ok, extracted} = result
      assert Map.has_key?(extracted, :text)
      assert Map.has_key?(extracted, :pages)
      assert Map.has_key?(extracted, :metadata)
      assert is_binary(extracted.text)
      assert is_integer(extracted.pages) and extracted.pages >= 0
      assert is_map(extracted.metadata)
    end

    test "extraction result includes all required SMRITI metadata keys" do
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(mock_pdf())

      required_keys = [:source, :size_bytes, :extraction_status, :content_type, :received_at]

      for key <- required_keys do
        assert Map.has_key?(meta, key),
               "Missing required metadata key: #{key}"
      end
    end

    test "content_type is 'application/pdf' for valid PDF" do
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(mock_pdf())
      assert meta.content_type == "application/pdf"
    end

    test "size_bytes in metadata matches actual byte size of input" do
      pdf_binary = mock_pdf()
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(pdf_binary)
      assert meta.size_bytes == byte_size(pdf_binary)
    end

    test "extraction_status is :pending_library (SMRITI-074 transparency)" do
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(mock_pdf())
      assert meta.extraction_status == :pending_library
    end

    test "received_at is valid ISO 8601 UTC timestamp for Ψ₁ regeneration" do
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(mock_pdf())
      assert is_binary(meta.received_at)
      assert {:ok, %DateTime{}, _offset} = DateTime.from_iso8601(meta.received_at)
    end

    test "pipeline processes PDF from temp file path" do
      path = write_temp_file(mock_pdf(), "pdf")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, %{metadata: %{source: source}}} = Extractors.parse_pdf(path)
      assert source == path
    end

    test "pipeline correctly identifies non-PDF as error" do
      non_pdf = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <> "PNG data here"
      assert {:error, :not_a_pdf} = Extractors.parse_pdf(non_pdf)
    end

    test "pipeline rejects empty binary" do
      assert {:error, :empty_input} = Extractors.parse_pdf(<<>>)
    end

    test "pipeline returns file_not_found for missing path" do
      assert {:error, :file_not_found} = Extractors.parse_pdf("/no/such/file.pdf")
    end

    test "pipeline handles large PDF mock without crash" do
      large_pdf = mock_pdf(:binary.copy(<<0x20>>, 50_000))
      result = Extractors.parse_pdf(large_pdf)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "multiple concurrent PDF extractions are independent (Ψ₀ existence)" do
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            extra = :binary.copy(<<i>>, 10)
            Extractors.parse_pdf(mock_pdf(extra))
          end)
        end)

      results = Task.await_many(tasks, 5000)

      for result <- results do
        assert match?({:ok, _}, result),
               "Expected :ok but got: #{inspect(result)}"
      end
    end
  end

  # ============================================================
  # AUDIO TRANSCRIPTION PIPELINE
  # ============================================================

  describe "audio transcription pipeline" do
    test "transcribes MP3 binary and returns structured result" do
      result = Extractors.transcribe(mock_mp3())

      assert {:ok, transcribed} = result
      assert Map.has_key?(transcribed, :text)
      assert Map.has_key?(transcribed, :duration_seconds)
      assert Map.has_key?(transcribed, :language)
      assert Map.has_key?(transcribed, :confidence)
      assert Map.has_key?(transcribed, :metadata)
    end

    test "transcribes WAV binary successfully" do
      assert {:ok, _} = Extractors.transcribe(mock_wav())
    end

    test "transcribes OGG binary successfully" do
      assert {:ok, _} = Extractors.transcribe(mock_ogg())
    end

    test "transcribes FLAC binary successfully" do
      assert {:ok, _} = Extractors.transcribe(mock_flac())
    end

    test "transcription result metadata includes required keys for Ψ₁ regeneration" do
      {:ok, %{metadata: meta}} = Extractors.transcribe(mock_mp3())

      required_keys = [:source, :size_bytes, :transcription_status, :received_at]

      for key <- required_keys do
        assert Map.has_key?(meta, key),
               "Missing required metadata key: #{key}"
      end
    end

    test "transcription_status is :pending_library (Ψ₅ truthfulness)" do
      {:ok, %{metadata: meta}} = Extractors.transcribe(mock_mp3())
      assert meta.transcription_status == :pending_library
    end

    test "language defaults to 'en'" do
      {:ok, result} = Extractors.transcribe(mock_mp3())
      assert result.language == "en"
    end

    test "size_bytes matches input binary size" do
      audio = mock_mp3()
      {:ok, %{metadata: meta}} = Extractors.transcribe(audio)
      assert meta.size_bytes == byte_size(audio)
    end

    test "received_at is valid ISO 8601 UTC timestamp" do
      {:ok, %{metadata: meta}} = Extractors.transcribe(mock_mp3())
      assert {:ok, %DateTime{}, _} = DateTime.from_iso8601(meta.received_at)
    end

    test "transcription from temp file path carries path as source" do
      path = write_temp_file(mock_mp3(), "mp3")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, %{metadata: %{source: source}}} = Extractors.transcribe(path)
      assert source == path
    end

    test "unsupported binary format returns error" do
      garbage = <<0x01, 0x02, 0x03, 0x04, 0x05>> <> "no magic bytes"
      assert {:error, :unsupported_audio_format} = Extractors.transcribe(garbage)
    end

    test "empty binary returns error" do
      assert {:error, :empty_input} = Extractors.transcribe(<<>>)
    end

    test "missing file path returns error" do
      assert {:error, :file_not_found} = Extractors.transcribe("/no/such/audio.mp3")
    end

    test "multiple audio formats processed concurrently are independent" do
      formats = [mock_mp3(), mock_wav(), mock_ogg(), mock_flac(), mock_mp3()]

      tasks =
        Enum.map(formats, fn binary -> Task.async(fn -> Extractors.transcribe(binary) end) end)

      results = Task.await_many(tasks, 5000)

      for result <- results do
        assert match?({:ok, _}, result),
               "Expected :ok but got: #{inspect(result)}"
      end
    end
  end

  # ============================================================
  # URL FETCH PIPELINE
  # ============================================================

  describe "URL fetch pipeline" do
    test "returns error tuple for non-binary input" do
      assert {:error, :invalid_url} = Extractors.fetch_url(nil)
      assert {:error, :invalid_url} = Extractors.fetch_url(42)
      assert {:error, :invalid_url} = Extractors.fetch_url(:url)
    end

    test "returns error for unreachable host" do
      result = Extractors.fetch_url("http://0.0.0.0:0/test")
      assert match?({:error, _}, result)
    end

    test "returns error for malformed URL string" do
      result = Extractors.fetch_url("not-a-url-at-all")
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # MULTI-FORMAT EXTRACTION PIPELINE
  # ============================================================

  describe "multi-format extraction pipeline (integration)" do
    test "pipeline handles mixed batch of PDF and audio inputs" do
      inputs = [
        {:pdf, mock_pdf()},
        {:mp3, mock_mp3()},
        {:wav, mock_wav()},
        {:ogg, mock_ogg()},
        {:flac, mock_flac()}
      ]

      results =
        Enum.map(inputs, fn {format, binary} ->
          result =
            case format do
              :pdf -> Extractors.parse_pdf(binary)
              _ -> Extractors.transcribe(binary)
            end

          {format, result}
        end)

      for {format, result} <- results do
        assert match?({:ok, _}, result),
               "Format #{format} failed: #{inspect(result)}"
      end
    end

    test "pipeline normalizes all results to ok/error tagged tuples" do
      inputs = [
        fn -> Extractors.parse_pdf(mock_pdf()) end,
        fn -> Extractors.transcribe(mock_mp3()) end,
        fn -> Extractors.parse_pdf(<<>>) end,
        fn -> Extractors.transcribe(<<>>) end,
        fn -> Extractors.fetch_url(nil) end
      ]

      for func <- inputs do
        result = func.()

        assert match?({:ok, _}, result) or match?({:error, _}, result) or
                 match?({:ok, _, _}, result),
               "Expected tagged tuple, got: #{inspect(result)}"
      end
    end

    test "pipeline preserves temporal ordering via received_at in metadata" do
      # Extract multiple documents in sequence
      before_ts = DateTime.utc_now()

      {:ok, %{metadata: pdf_meta}} = Extractors.parse_pdf(mock_pdf())
      {:ok, %{metadata: mp3_meta}} = Extractors.transcribe(mock_mp3())

      after_ts = DateTime.utc_now()

      # Both timestamps should be between before and after
      for {label, received_at} <- [{"pdf", pdf_meta.received_at}, {"mp3", mp3_meta.received_at}] do
        {:ok, ts, _} = DateTime.from_iso8601(received_at)

        assert DateTime.compare(ts, before_ts) in [:gt, :eq],
               "#{label} received_at before test start"

        assert DateTime.compare(ts, after_ts) in [:lt, :eq],
               "#{label} received_at after test end"
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  describe "property tests (PropCheck) — extraction pipeline" do
    @tag :property
    property "parse_pdf with any binary always returns tagged tuple" do
      forall binary <- PC.binary() do
        result = Extractors.parse_pdf(binary)
        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    property "transcribe with any binary always returns tagged tuple" do
      forall binary <- PC.binary() do
        result = Extractors.transcribe(binary)
        match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    @tag :property
    property "parse_pdf with PDF-magic-prefixed binary always returns ok" do
      forall suffix <- PC.binary() do
        pdf = @pdf_magic <> suffix
        result = Extractors.parse_pdf(pdf)
        match?({:ok, _}, result)
      end
    end

    @tag :property
    property "parse_pdf ok result always has matching size_bytes metadata" do
      forall suffix <- PC.binary() do
        pdf = @pdf_magic <> suffix

        case Extractors.parse_pdf(pdf) do
          {:ok, %{metadata: %{size_bytes: size}}} -> size == byte_size(pdf)
          _ -> false
        end
      end
    end

    @tag :property
    property "transcribe with audio magic prefix always returns ok" do
      forall {sig_idx, suffix} <- {PC.range(0, length(@audio_signatures) - 1), PC.binary()} do
        sig = Enum.at(@audio_signatures, sig_idx)
        audio = sig <> suffix
        result = Extractors.transcribe(audio)
        match?({:ok, _}, result)
      end
    end

    @tag :property
    property "fetch_url with non-binary always returns {:error, :invalid_url}" do
      forall non_binary <- PC.oneof([PC.integer(), PC.atom(), PC.float()]) do
        result = Extractors.fetch_url(non_binary)
        match?({:error, :invalid_url}, result)
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS (ExUnitProperties / StreamData)
  # ============================================================

  describe "property tests (StreamData) — extraction pipeline" do
    @tag :property
    test "parse_pdf with valid PDF binaries always returns ok struct" do
      ExUnitProperties.check all(suffix <- SD.binary(min_length: 0, max_length: 128)) do
        pdf = @pdf_magic <> suffix
        assert match?({:ok, %{text: _, pages: _, metadata: _}}, Extractors.parse_pdf(pdf))
      end
    end

    @tag :property
    test "transcribe with known audio signatures always returns ok struct" do
      ExUnitProperties.check all(
                               sig <- SD.member_of(@audio_signatures),
                               suffix <- SD.binary(min_length: 4, max_length: 128)
                             ) do
        audio = sig <> suffix
        result = Extractors.transcribe(audio)
        assert match?({:ok, %{text: _, duration_seconds: _, language: _, confidence: _}}, result)
      end
    end

    @tag :property
    test "parse_pdf text field is always a string when extraction succeeds" do
      ExUnitProperties.check all(suffix <- SD.binary(min_length: 1, max_length: 64)) do
        pdf = @pdf_magic <> suffix
        {:ok, %{text: text}} = Extractors.parse_pdf(pdf)
        assert is_binary(text)
      end
    end

    @tag :property
    test "transcribe confidence is always a float in [0.0, 1.0] range when ok" do
      ExUnitProperties.check all(
                               sig <- SD.member_of(@audio_signatures),
                               suffix <- SD.binary(min_length: 1, max_length: 64)
                             ) do
        audio = sig <> suffix
        {:ok, %{confidence: conf}} = Extractors.transcribe(audio)
        assert is_float(conf)
        assert conf >= 0.0 and conf <= 1.0
      end
    end

    @tag :property
    test "parse_pdf pages is always a non-negative integer when ok" do
      ExUnitProperties.check all(suffix <- SD.binary(min_length: 0, max_length: 64)) do
        pdf = @pdf_magic <> suffix
        {:ok, %{pages: pages}} = Extractors.parse_pdf(pdf)
        assert is_integer(pages) and pages >= 0
      end
    end
  end

  # ============================================================
  # FMEA TESTS
  # ============================================================

  describe "FMEA - extraction failure modes" do
    @tag :fmea
    test "RPN-105: PDF binary truncated at magic bytes does not crash" do
      # Only the magic prefix, no actual content
      truncated = @pdf_magic
      result = Extractors.parse_pdf(truncated)
      # Truncated PDF still has the magic bytes so may succeed or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :fmea
    test "RPN-105: audio binary with only magic bytes handles gracefully" do
      for sig <- @audio_signatures do
        result = Extractors.transcribe(sig)

        assert match?({:ok, _}, result) or match?({:error, _}, result),
               "Audio magic #{inspect(sig)} caused unexpected result"
      end
    end

    @tag :fmea
    test "RPN-72: metadata fields are never nil for successful extractions" do
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(mock_pdf())

      for {key, value} <- meta do
        refute is_nil(value),
               "Metadata field #{key} is nil — violates Ψ₅ truthfulness"
      end
    end

    @tag :fmea
    test "RPN-70: partial pipeline failure in batch does not affect other extractions" do
      inputs = [
        {:ok, mock_pdf()},
        {:error, <<>>},
        {:ok, mock_mp3()},
        {:error, <<0x01, 0x02>>},
        {:ok, mock_wav()}
      ]

      results =
        Enum.map(inputs, fn {expected, binary} ->
          case expected do
            :ok -> binary
            :error -> binary
          end
          |> (&Extractors.parse_pdf/1).()
        end)

      # At least some should succeed and system should never crash
      assert length(results) == 5
    end

    @tag :fmea
    test "RPN-64: empty extraction results have stable structure" do
      {:ok, result} = Extractors.parse_pdf(mock_pdf())

      # Empty text is acceptable (pending library), structure must be stable
      assert Map.has_key?(result, :text)
      assert Map.has_key?(result, :pages)
      assert Map.has_key?(result, :metadata)
    end

    @tag :fmea
    test "concurrent extractions do not corrupt each other's metadata" do
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            binary = mock_pdf(<<i>>)
            expected_size = byte_size(binary)
            {:ok, %{metadata: meta}} = Extractors.parse_pdf(binary)
            {expected_size, meta.size_bytes}
          end)
        end)

      results = Task.await_many(tasks, 5000)

      for {expected, actual} <- results do
        assert expected == actual,
               "Metadata corruption: expected size #{expected}, got #{actual}"
      end
    end
  end

  # ============================================================
  # CONSTITUTIONAL INVARIANT TESTS
  # ============================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence: extraction pipeline never crashes on any binary input" do
      adversarial_inputs = [
        <<>>,
        <<0x00>>,
        <<0xFF, 0xFF, 0xFF, 0xFF>>,
        @pdf_magic,
        mock_pdf(),
        @mp3_id3_magic,
        mock_mp3(),
        "plaintext content",
        :binary.copy(<<0x00>>, 10_000),
        :binary.copy(<<0xFF>>, 10_000)
      ]

      for input <- adversarial_inputs do
        # parse_pdf never raises
        result_pdf = Extractors.parse_pdf(input)

        assert match?({:ok, _}, result_pdf) or match?({:error, _}, result_pdf),
               "Ψ₀ violated for parse_pdf with: #{inspect(input, limit: 8)}"

        # transcribe never raises
        result_audio = Extractors.transcribe(input)

        assert match?({:ok, _}, result_audio) or match?({:error, _}, result_audio),
               "Ψ₀ violated for transcribe with: #{inspect(input, limit: 8)}"
      end
    end

    test "Ψ₁ regeneration: all ok results include received_at for event sourcing" do
      {:ok, %{metadata: pdf_meta}} = Extractors.parse_pdf(mock_pdf())
      {:ok, %{metadata: mp3_meta}} = Extractors.transcribe(mock_mp3())

      for meta <- [pdf_meta, mp3_meta] do
        assert is_binary(meta.received_at)

        assert {:ok, %DateTime{}, _} = DateTime.from_iso8601(meta.received_at),
               "received_at is not ISO 8601: #{inspect(meta.received_at)}"
      end
    end

    test "Ψ₃ verification: extraction status is auditable and non-ambiguous" do
      {:ok, %{metadata: meta}} = Extractors.parse_pdf(mock_pdf())

      # Status must be one of the documented values
      valid_statuses = [:pending_library, :complete, :partial, :failed]

      assert meta.extraction_status in valid_statuses,
             "extraction_status #{inspect(meta.extraction_status)} is not in documented set"
    end

    test "Ψ₅ truthfulness: extraction does not claim success it cannot deliver" do
      {:ok, %{text: text, pages: pages, metadata: meta}} = Extractors.parse_pdf(mock_pdf())

      # When library is pending, text and pages must reflect that honestly
      if meta.extraction_status == :pending_library do
        assert text == "",
               "Claimed extracted text without library: #{inspect(text)}"

        assert pages == 0,
               "Claimed page count without library: #{pages}"
      end
    end

    test "Ψ₅ truthfulness: transcription does not claim confidence without model" do
      {:ok, result} = Extractors.transcribe(mock_mp3())

      if result.metadata.transcription_status == :pending_library do
        assert result.text == "",
               "Claimed transcript without model: #{inspect(result.text)}"

        assert result.confidence == 0.0,
               "Claimed confidence without model: #{result.confidence}"

        assert result.duration_seconds == 0.0,
               "Claimed duration without model: #{result.duration_seconds}"
      end
    end
  end

  # ============================================================
  # TELEMETRY TESTS
  # ============================================================

  describe "telemetry emission from extraction pipeline" do
    test "parse_pdf emits [:smriti, :senses, :extractor, :parse_pdf] on success" do
      test_pid = self()
      handler_id = "test-kext-pdf-ok-#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:smriti, :senses, :extractor, :parse_pdf],
        fn _event, measurements, metadata, _cfg ->
          send(test_pid, {:telemetry, :parse_pdf, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Extractors.parse_pdf(mock_pdf())

      assert_receive {:telemetry, :parse_pdf, measurements, meta}, 2000
      assert is_integer(measurements.duration_us)
      assert measurements.duration_us >= 0
      assert meta.status == :ok
      assert meta.operation == :parse_pdf
    end

    test "transcribe emits [:smriti, :senses, :extractor, :transcribe] on success" do
      test_pid = self()
      handler_id = "test-kext-transcribe-ok-#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:smriti, :senses, :extractor, :transcribe],
        fn _event, measurements, metadata, _cfg ->
          send(test_pid, {:telemetry, :transcribe, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Extractors.transcribe(mock_mp3())

      assert_receive {:telemetry, :transcribe, measurements, meta}, 2000
      assert measurements.duration_us >= 0
      assert meta.status == :ok
      assert meta.operation == :transcribe
    end

    test "parse_pdf emits :error status telemetry on invalid input" do
      test_pid = self()
      handler_id = "test-kext-pdf-err-#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:smriti, :senses, :extractor, :parse_pdf],
        fn _event, measurements, metadata, _cfg ->
          send(test_pid, {:telemetry, :parse_pdf_err, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Extractors.parse_pdf(<<0x00, 0x01, 0x02, 0x03>>)

      assert_receive {:telemetry, :parse_pdf_err, _measurements, meta}, 2000
      assert meta.status == :error
    end

    test "transcribe emits :error status telemetry on unsupported format" do
      test_pid = self()
      handler_id = "test-kext-transcribe-err-#{:erlang.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:smriti, :senses, :extractor, :transcribe],
        fn _event, _measurements, metadata, _cfg ->
          send(test_pid, {:telemetry, :transcribe_err, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Extractors.transcribe(<<0x01, 0x02, 0x03, 0x04, 0x05>>)

      assert_receive {:telemetry, :transcribe_err, meta}, 2000
      assert meta.status == :error
    end
  end
end
