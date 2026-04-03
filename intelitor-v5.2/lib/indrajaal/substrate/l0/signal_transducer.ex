defmodule Indrajaal.Substrate.L0.SignalTransducer do
  @moduledoc """
  ## Design Intent
  L0 substrate signal transducer — pure functional module for converting between
  signal representations. No GenServer, no side effects. All functions are
  referentially transparent and composable.

  Supported conversions:
    - `analog_to_digital/3`  — sample an analog float into an N-bit integer
    - `digital_to_analog/3`  — reconstruct a float from an N-bit integer
    - `normalize/3`          — linearly rescale a value from [in_min, in_max] to [0.0, 1.0]
    - `denormalize/3`        — inverse of normalize, from [0.0, 1.0] to [out_min, out_max]
    - `raw_to_normalized/4`  — compose normalize and clamp
    - `quantize/2`           — round a float to the nearest step
    - `pack_signals/1`       — pack a list of normalized floats into a binary
    - `unpack_signals/2`     — unpack a binary back into a list of normalized floats

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-FSH-070: Parsers pure and composable — ENFORCED (Elixir equivalent)
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  @type signal :: float()
  @type normalized :: float()
  @type digital :: non_neg_integer()
  @type bits :: pos_integer()

  # ---------------------------------------------------------------------------
  # Analog ↔ Digital
  # ---------------------------------------------------------------------------

  @doc """
  Convert an analog float in [v_min, v_max] to an N-bit unsigned integer.

      iex> SignalTransducer.analog_to_digital(2.5, 0.0, 5.0, 8)
      127
  """
  @spec analog_to_digital(signal(), signal(), signal(), bits()) :: digital()
  def analog_to_digital(value, v_min, v_max, bits)
      when is_float(value) and is_float(v_min) and is_float(v_max) and
             is_integer(bits) and bits > 0 and v_max > v_min do
    max_val = :math.pow(2, bits) - 1
    clamped = clamp_float(value, v_min, v_max)
    trunc((clamped - v_min) / (v_max - v_min) * max_val)
  end

  @doc """
  Reconstruct an analog float from an N-bit integer.

      iex> SignalTransducer.digital_to_analog(127, 0.0, 5.0, 8)
      2.4804...
  """
  @spec digital_to_analog(digital(), signal(), signal(), bits()) :: signal()
  def digital_to_analog(digital, v_min, v_max, bits)
      when is_integer(digital) and digital >= 0 and
             is_float(v_min) and is_float(v_max) and
             is_integer(bits) and bits > 0 and v_max > v_min do
    max_val = :math.pow(2, bits) - 1
    v_min + digital / max_val * (v_max - v_min)
  end

  # ---------------------------------------------------------------------------
  # Normalization
  # ---------------------------------------------------------------------------

  @doc """
  Linearly rescale `value` from [in_min, in_max] to [0.0, 1.0].
  Values outside the input range are clamped.
  """
  @spec normalize(signal(), signal(), signal()) :: normalized()
  def normalize(value, in_min, in_max)
      when is_float(value) and is_float(in_min) and is_float(in_max) and in_max > in_min do
    clamped = clamp_float(value, in_min, in_max)
    (clamped - in_min) / (in_max - in_min)
  end

  @doc """
  Inverse normalize — map `value` from [0.0, 1.0] to [out_min, out_max].
  """
  @spec denormalize(normalized(), signal(), signal()) :: signal()
  def denormalize(value, out_min, out_max)
      when is_float(value) and is_float(out_min) and is_float(out_max) and out_max > out_min do
    clamped = clamp_float(value, 0.0, 1.0)
    out_min + clamped * (out_max - out_min)
  end

  @doc """
  Normalize with explicit clamp — convenience wrapper.
  """
  @spec raw_to_normalized(number(), number(), number(), number()) :: normalized()
  def raw_to_normalized(value, in_min, in_max, clamp_to \\ 1.0) do
    v = value / 1.0
    in_mn = in_min / 1.0
    in_mx = in_max / 1.0
    result = normalize(v, in_mn, in_mx)
    clamp_float(result, 0.0, clamp_to / 1.0)
  end

  # ---------------------------------------------------------------------------
  # Quantization
  # ---------------------------------------------------------------------------

  @doc """
  Round `value` to the nearest `step`.

      iex> SignalTransducer.quantize(1.7, 0.5)
      1.5
  """
  @spec quantize(signal(), float()) :: signal()
  def quantize(value, step) when is_float(value) and is_float(step) and step > 0.0 do
    Float.round(value / step) * step
  end

  # ---------------------------------------------------------------------------
  # Binary packing
  # ---------------------------------------------------------------------------

  @doc """
  Pack a list of normalized floats (each in [0.0, 1.0]) into a binary
  using 16-bit fixed-point representation (65535 = 1.0).
  """
  @spec pack_signals([normalized()]) :: binary()
  def pack_signals(signals) when is_list(signals) do
    Enum.reduce(signals, <<>>, fn v, acc ->
      clamped = clamp_float(v / 1.0, 0.0, 1.0)
      encoded = trunc(clamped * 65_535)
      acc <> <<encoded::unsigned-integer-16>>
    end)
  end

  @doc """
  Unpack a binary produced by `pack_signals/1` into a list of floats.
  `count` is the expected number of signals.
  """
  @spec unpack_signals(binary(), pos_integer()) :: [normalized()]
  def unpack_signals(binary, count) when is_binary(binary) and is_integer(count) and count > 0 do
    do_unpack(binary, count, [])
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec clamp_float(float(), float(), float()) :: float()
  defp clamp_float(v, lo, hi), do: max(lo, min(hi, v))

  defp do_unpack(_, 0, acc), do: Enum.reverse(acc)

  defp do_unpack(<<v::unsigned-integer-16, rest::binary>>, count, acc) do
    do_unpack(rest, count - 1, [v / 65_535.0 | acc])
  end

  defp do_unpack(_, _count, acc), do: Enum.reverse(acc)
end
