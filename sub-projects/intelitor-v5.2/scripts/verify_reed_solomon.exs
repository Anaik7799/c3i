#!/usr/bin/env elixir
# Quick verification script for Reed-Solomon implementation

Mix.install([])

# Load the module
Code.require_file("lib/indrajaal/core/holon/repair/reed_solomon.ex")

alias Indrajaal.Core.Holon.Repair.ReedSolomon

IO.puts("=== Reed-Solomon RS(255,223) Verification ===\n")

# Initialize
IO.puts("1. Initializing GF(2^8) tables...")
:ok = ReedSolomon.init()
IO.puts("✓ Initialization successful\n")

# Test 1: Basic encoding/decoding
IO.puts("2. Testing basic encode/decode...")
data = :crypto.strong_rand_bytes(223)
{:ok, encoded} = ReedSolomon.encode(data)
{:ok, decoded} = ReedSolomon.decode(encoded)

if decoded == data do
  IO.puts("✓ Encode/decode successful (223 bytes)")
else
  IO.puts("✗ Encode/decode failed")
  System.halt(1)
end

# Test 2: Short data with padding
IO.puts("\n3. Testing short data with padding...")
short_data = :crypto.strong_rand_bytes(100)
{:ok, encoded_short} = ReedSolomon.encode(short_data)
{:ok, decoded_short} = ReedSolomon.decode(encoded_short)

if binary_part(decoded_short, 0, 100) == short_data do
  IO.puts("✓ Short data encoding successful (100 bytes)")
else
  IO.puts("✗ Short data encoding failed")
  System.halt(1)
end

# Test 3: Verify valid block
IO.puts("\n4. Testing verification of valid block...")

case ReedSolomon.verify(encoded) do
  :ok ->
    IO.puts("✓ Verification successful")

  {:error, :corrupted, _} ->
    IO.puts("✗ False positive corruption detected")
    System.halt(1)
end

# Test 4: Single error correction
IO.puts("\n5. Testing single-byte error correction...")
<<before::binary-size(100), byte::8, after_bytes::binary>> = encoded
corrupted = before <> <<Bitwise.bxor(byte, 0xFF)>> <> after_bytes

case ReedSolomon.decode(corrupted) do
  {:ok, corrected} ->
    if corrected == data do
      IO.puts("✓ Single error corrected successfully")
    else
      IO.puts("✗ Correction produced wrong data")
      System.halt(1)
    end

  {:error, reason} ->
    IO.puts("✗ Failed to correct single error: #{inspect(reason)}")
    System.halt(1)
end

# Test 5: Block size validation
IO.puts("\n6. Testing validation...")

case ReedSolomon.encode(:crypto.strong_rand_bytes(224)) do
  {:error, :data_too_large} ->
    IO.puts("✓ Data size validation works")

  {:ok, _} ->
    IO.puts("✗ Failed to reject oversized data")
    System.halt(1)
end

case ReedSolomon.decode(:crypto.strong_rand_bytes(200)) do
  {:error, :invalid_block_size} ->
    IO.puts("✓ Block size validation works")

  {:ok, _} ->
    IO.puts("✗ Failed to reject invalid block size")
    System.halt(1)
end

IO.puts("\n=== All verification tests passed! ===")
IO.puts("\nReed-Solomon RS(255,223) implementation is functional.")
IO.puts("- Encoding: ✓")
IO.puts("- Decoding: ✓")
IO.puts("- Verification: ✓")
IO.puts("- Error Correction: ✓")
IO.puts("- Validation: ✓")
