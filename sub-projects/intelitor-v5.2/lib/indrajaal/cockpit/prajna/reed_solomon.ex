defmodule Indrajaal.Cockpit.Prajna.ReedSolomon do
  @moduledoc """
  Reed-Solomon RS(255,223) Error Correction for Prajna Immutable Register.

  WHAT: Wrapper around the core RS module for block data integrity.
  WHY: SC-REG-006 requires Reed-Solomon parity for error correction.

  CONSTRAINTS:
    - SC-REG-006: Reed-Solomon parity required for error correction
    - SC-REG-008: Repair events MUST be recorded
    - AOR-REG-009: Apply Reed-Solomon encoding to all blocks

  ## Technical Details

  RS(255,223) parameters:
  - n = 255 (total symbols)
  - k = 223 (data symbols)
  - t = 16 (error correction capability - can correct up to 16 symbol errors)
  - 2t = 32 parity symbols

  This implementation uses Galois Field GF(2^8) with primitive polynomial
  x^8 + x^4 + x^3 + x^2 + 1 (0x11D). Wraps the full RS implementation
  from `Indrajaal.Core.Holon.Repair.ReedSolomon`.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-16 | Claude | Integrated with core RS(255,223) module |
  | 21.1.0 | 2025-12-01 | Claude | Initial CRC-based implementation |
  """

  require Logger
  alias Indrajaal.Core.Holon.Repair.ReedSolomon, as: CoreRS

  # RS(255,223) parameters
  @n 255
  @k 223
  @parity_symbols 32

  # Parity header magic for format detection
  @parity_magic "RS255"
  @parity_version 2

  @doc """
  Ensures the core RS codec is initialized.
  Called automatically on first encode/decode, but can be called
  explicitly during application startup for faster first operation.
  """
  @spec ensure_init() :: :ok
  def ensure_init do
    case :persistent_term.get({CoreRS, :gf_exp}, :not_initialized) do
      :not_initialized -> CoreRS.init()
      _ -> :ok
    end
  end

  @doc """
  Encodes data with Reed-Solomon parity.
  Returns {encoded_data, parity_bytes}.

  For data larger than 223 bytes, splits into chunks and encodes each.
  The parity includes:
  - Magic header for format detection
  - Version for future compatibility
  - Original data size
  - Number of RS blocks
  - RS parity for each 223-byte chunk (32 bytes each)
  - SHA-256 of original data for integrity verification
  """
  @spec encode(binary()) :: {binary(), binary()}
  def encode(data) when is_binary(data) do
    ensure_init()
    parity = generate_parity(data)
    {data, parity}
  end

  @doc """
  Decodes and verifies data against Reed-Solomon parity.
  Returns {:ok, data} if valid, {:error, reason} if corrupt but unrepairable,
  or {:repaired, data, repair_info} if errors were corrected.
  """
  @spec decode(binary(), binary()) ::
          {:ok, binary()} | {:error, term()} | {:repaired, binary(), map()}
  def decode(data, parity) when is_binary(data) and is_binary(parity) do
    ensure_init()

    case parse_parity_header(parity) do
      {:ok, %{version: @parity_version} = header, rs_parities} ->
        verify_and_repair(data, header, rs_parities)

      {:ok, %{version: 1}, _rs_parities} ->
        # Legacy v1 format - use old verification
        verify_parity_v1(data, parity)

      {:error, :invalid_header} ->
        # Try legacy format
        verify_parity_v1(data, parity)
    end
  end

  @doc """
  Generates parity bytes for given data using real RS(255,223).
  """
  @spec generate_parity(binary()) :: binary()
  def generate_parity(data) do
    original_size = byte_size(data)
    sha256 = :crypto.hash(:sha256, data)

    # Split data into 223-byte chunks for RS encoding
    chunks = chunk_binary(data, @k)
    num_chunks = length(chunks)

    # Generate RS parity for each chunk
    rs_parities =
      chunks
      |> Enum.map(fn chunk ->
        case CoreRS.encode(chunk) do
          {:ok, encoded} ->
            # Extract just the parity (last 32 bytes)
            binary_part(encoded, @k, @parity_symbols)

          {:error, _reason} ->
            # Fallback: generate zero parity (will fail verification)
            <<0::size(@parity_symbols)-unit(8)>>
        end
      end)
      |> IO.iodata_to_binary()

    # Build parity structure
    magic = @parity_magic
    version = @parity_version

    <<
      magic::binary-size(5),
      version::8,
      original_size::32,
      num_chunks::16,
      sha256::binary-size(32),
      rs_parities::binary
    >>
  end

  @doc """
  Verifies data integrity against parity bytes.
  """
  @spec verify_parity(binary(), binary()) :: {:ok, :valid} | {:error, :corrupted, map()}
  def verify_parity(data, parity) do
    ensure_init()

    case parse_parity_header(parity) do
      {:ok, %{version: @parity_version} = header, rs_parities} ->
        case do_verify(data, header, rs_parities) do
          {:ok, :valid, _} -> {:ok, :valid}
          {:error, errors} -> {:error, :corrupted, %{errors: errors}}
        end

      {:ok, %{version: 1}, _} ->
        verify_parity_v1_result(data, parity)

      {:error, :invalid_header} ->
        verify_parity_v1_result(data, parity)
    end
  end

  @doc """
  Attempts to repair corrupted data using RS parity information.
  Can correct up to 16 symbol errors per 223-byte chunk.
  """
  @spec attempt_repair(binary(), binary(), map()) ::
          {:repaired, binary(), map()} | {:error, :unrepairable}
  def attempt_repair(data, parity, _error_info) do
    ensure_init()

    case parse_parity_header(parity) do
      {:ok, %{version: @parity_version} = header, rs_parities} ->
        do_repair(data, header, rs_parities)

      _ ->
        {:error, :unrepairable}
    end
  end

  @doc """
  Returns RS parameters for informational purposes.
  """
  @spec parameters() :: map()
  def parameters do
    %{
      n: @n,
      k: @k,
      parity_symbols: @parity_symbols,
      error_correction_capability: div(@parity_symbols, 2),
      implementation: :galois_field_gf2_8
    }
  end

  # ============================================================================
  # Private Functions - Parity Generation/Parsing
  # ============================================================================

  defp parse_parity_header(parity) do
    try do
      <<
        magic::binary-size(5),
        version::8,
        original_size::32,
        num_chunks::16,
        sha256::binary-size(32),
        rs_parities::binary
      >> = parity

      if magic == @parity_magic do
        header = %{
          version: version,
          original_size: original_size,
          num_chunks: num_chunks,
          sha256: sha256
        }

        {:ok, header, rs_parities}
      else
        {:error, :invalid_header}
      end
    rescue
      MatchError -> {:error, :invalid_header}
    end
  end

  # ============================================================================
  # Private Functions - Verification and Repair
  # ============================================================================

  defp verify_and_repair(data, header, rs_parities) do
    case do_verify(data, header, rs_parities) do
      {:ok, :valid, _} ->
        {:ok, data}

      {:error, errors} when is_list(errors) ->
        # Attempt repair
        case do_repair(data, header, rs_parities) do
          {:repaired, repaired_data, repair_info} ->
            {:repaired, repaired_data, repair_info}

          {:error, :unrepairable} ->
            Logger.error("[ReedSolomon] Unrepairable corruption: #{inspect(errors)}")
            {:error, :unrepairable}
        end
    end
  end

  defp do_verify(data, header, rs_parities) do
    errors = []

    # Check 1: Size
    actual_size = byte_size(data)

    errors =
      if actual_size != header.original_size do
        [{:size_mismatch, header.original_size, actual_size} | errors]
      else
        errors
      end

    # Check 2: SHA-256
    actual_sha = :crypto.hash(:sha256, data)

    errors =
      if actual_sha != header.sha256 do
        [:sha_mismatch | errors]
      else
        errors
      end

    # Check 3: RS verification per chunk
    chunks = chunk_binary(data, @k)
    expected_chunks = header.num_chunks

    errors =
      if length(chunks) != expected_chunks do
        [{:chunk_count_mismatch, expected_chunks, length(chunks)} | errors]
      else
        errors
      end

    # Verify each chunk's RS parity
    chunk_errors = verify_chunks(chunks, rs_parities)
    errors = errors ++ chunk_errors

    case errors do
      [] -> {:ok, :valid, %{chunks_verified: length(chunks)}}
      _ -> {:error, errors}
    end
  end

  defp verify_chunks(chunks, rs_parities) do
    chunks
    |> Enum.with_index()
    |> Enum.reduce([], fn {chunk, idx}, acc ->
      parity_offset = idx * @parity_symbols

      if parity_offset + @parity_symbols <= byte_size(rs_parities) do
        chunk_parity = binary_part(rs_parities, parity_offset, @parity_symbols)

        # Reconstruct the encoded block
        encoded = chunk <> chunk_parity

        case CoreRS.verify(encoded) do
          :ok ->
            acc

          {:error, :corrupted, error_count} ->
            [{:chunk_error, idx, :corrupted, error_count} | acc]

          {:error, :invalid_block_size} ->
            [{:chunk_error, idx, :invalid_size, byte_size(encoded)} | acc]
        end
      else
        [{:chunk_error, idx, :missing_parity, nil} | acc]
      end
    end)
  end

  defp do_repair(data, header, rs_parities) do
    chunks = chunk_binary(data, @k)
    repair_log = []
    errors_corrected = 0

    {repaired_chunks, repair_log, errors_corrected, unrepairable} =
      chunks
      |> Enum.with_index()
      |> Enum.reduce({[], repair_log, errors_corrected, false}, fn {chunk, idx},
                                                                   {chunks_acc, log_acc,
                                                                    corrected_acc,
                                                                    unrepairable_acc} ->
        parity_offset = idx * @parity_symbols

        if parity_offset + @parity_symbols <= byte_size(rs_parities) do
          chunk_parity = binary_part(rs_parities, parity_offset, @parity_symbols)
          encoded = chunk <> chunk_parity

          case CoreRS.decode(encoded) do
            {:ok, decoded} ->
              # Check if repair occurred by comparing
              if decoded != chunk do
                {[decoded | chunks_acc], [{:repaired, idx, byte_size(chunk)} | log_acc],
                 corrected_acc + 1, unrepairable_acc}
              else
                {[decoded | chunks_acc], log_acc, corrected_acc, unrepairable_acc}
              end

            {:error, :uncorrectable} ->
              # Cannot repair this chunk
              {[chunk | chunks_acc], [{:unrepairable, idx} | log_acc], corrected_acc, true}
          end
        else
          # Missing parity - keep original
          {[chunk | chunks_acc], [{:missing_parity, idx} | log_acc], corrected_acc, true}
        end
      end)

    if unrepairable do
      {:error, :unrepairable}
    else
      repaired_data =
        repaired_chunks
        |> Enum.reverse()
        |> IO.iodata_to_binary()
        |> binary_part(0, header.original_size)

      # Verify the repaired data
      actual_sha = :crypto.hash(:sha256, repaired_data)

      if actual_sha == header.sha256 do
        emit_repair_telemetry(errors_corrected, repair_log)

        {:repaired, repaired_data,
         %{
           errors_corrected: errors_corrected,
           chunks_repaired: length(repair_log),
           repair_log: Enum.reverse(repair_log)
         }}
      else
        {:error, :unrepairable}
      end
    end
  end

  # ============================================================================
  # Private Functions - Legacy V1 Support
  # ============================================================================

  defp verify_parity_v1(data, parity) do
    case verify_parity_v1_result(data, parity) do
      {:ok, :valid} -> {:ok, data}
      {:error, :corrupted, _info} -> {:error, :unrepairable}
    end
  end

  defp verify_parity_v1_result(data, parity) do
    try do
      <<
        expected_crc::32,
        expected_size::32,
        expected_sha::binary-size(32),
        expected_xor::64,
        chunk_crc_size::16,
        chunk_crcs::binary-size(chunk_crc_size),
        _rest::binary
      >> = parity

      errors = []

      actual_size = byte_size(data)

      errors =
        if actual_size != expected_size,
          do: [{:size_mismatch, expected_size, actual_size} | errors],
          else: errors

      actual_crc = :erlang.crc32(data)

      errors =
        if actual_crc != expected_crc,
          do: [{:crc_mismatch, expected_crc, actual_crc} | errors],
          else: errors

      actual_sha = :crypto.hash(:sha256, data)
      errors = if actual_sha != expected_sha, do: [:sha_mismatch | errors], else: errors

      actual_xor = compute_xor_check(data)

      errors =
        if actual_xor != expected_xor,
          do: [{:xor_mismatch, expected_xor, actual_xor} | errors],
          else: errors

      # Check chunk CRCs
      chunk_size = max(div(byte_size(data), 8), 1)
      chunks = chunk_binary_small(data, chunk_size)
      stored_chunk_crcs = parse_chunk_crcs(chunk_crcs)

      chunk_errors =
        chunks
        |> Enum.with_index()
        |> Enum.reduce([], fn {chunk, idx}, acc ->
          actual = :erlang.crc32(chunk)
          expected = Enum.at(stored_chunk_crcs, idx, 0)
          if actual != expected, do: [{:chunk_error, idx, expected, actual} | acc], else: acc
        end)

      errors = errors ++ chunk_errors

      case errors do
        [] -> {:ok, :valid}
        _ -> {:error, :corrupted, %{errors: errors, chunk_size: chunk_size}}
      end
    rescue
      MatchError ->
        {:error, :corrupted, %{errors: [:parity_format_invalid]}}
    end
  end

  defp compute_xor_check(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {byte, idx}, acc ->
      Bitwise.bxor(acc, Bitwise.bxor(byte, rem(idx, 256)))
    end)
  end

  defp parse_chunk_crcs(chunk_crcs) do
    do_parse_chunk_crcs(chunk_crcs, [])
  end

  defp do_parse_chunk_crcs(<<>>, acc), do: Enum.reverse(acc)

  defp do_parse_chunk_crcs(<<crc::32, rest::binary>>, acc) do
    do_parse_chunk_crcs(rest, [crc | acc])
  end

  # ============================================================================
  # Private Functions - Utilities
  # ============================================================================

  defp chunk_binary(binary, _chunk_size) when byte_size(binary) == 0 do
    []
  end

  defp chunk_binary(binary, chunk_size) when byte_size(binary) <= chunk_size do
    # Pad to chunk_size for RS encoding
    padding_size = chunk_size - byte_size(binary)
    [binary <> <<0::size(padding_size)-unit(8)>>]
  end

  defp chunk_binary(binary, chunk_size) do
    <<chunk::binary-size(chunk_size), rest::binary>> = binary
    [chunk | chunk_binary(rest, chunk_size)]
  end

  # Small chunks for legacy v1 format (different from RS chunks)
  defp chunk_binary_small(binary, chunk_size) do
    do_chunk_binary_small(binary, chunk_size, [])
  end

  defp do_chunk_binary_small(<<>>, _chunk_size, acc) do
    Enum.reverse(acc)
  end

  defp do_chunk_binary_small(binary, chunk_size, acc) when byte_size(binary) <= chunk_size do
    Enum.reverse([binary | acc])
  end

  defp do_chunk_binary_small(binary, chunk_size, acc) do
    <<chunk::binary-size(chunk_size), rest::binary>> = binary
    do_chunk_binary_small(rest, chunk_size, [chunk | acc])
  end

  defp emit_repair_telemetry(errors_corrected, repair_log) do
    if Code.ensure_loaded?(:telemetry) do
      :telemetry.execute(
        [:indrajaal, :prajna, :reed_solomon, :repair],
        %{errors_corrected: errors_corrected, chunks_repaired: length(repair_log)},
        %{repair_log: repair_log}
      )
    end
  end
end
