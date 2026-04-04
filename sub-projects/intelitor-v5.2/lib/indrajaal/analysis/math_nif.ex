defmodule Indrajaal.Analysis.MathNif do
  @moduledoc """
  Rust NIF for high-performance mathematical operations.

  WHAT: Native implementation of Shannon Entropy and mesh optimization.
  WHY: SC-MATH-008 mandates porting legacy Python logic to Rust NIFs for performance.
  """

  require Logger

  @cargo_available System.find_executable("cargo") != nil

  # Strict Compilation Enforcement (SC-NIF-005)
  if System.get_env("SKIP_NIF_BUILD") == "1" or not @cargo_available do
    error_msg = "[TPS RCA TRIGGERED] CRITICAL NIF VIOLATION: Rustler NIF skipping is STRICTLY PROHIBITED. Cargo available: #{@cargo_available}. A Total Panoptic System (TPS) Root Cause Analysis (RCA) spanning all 8 fractal elements x all 8 fractal layers is required. System HALTING to preserve mathematical integrity."
    Logger.error(error_msg)
    raise error_msg
  end

  use Rustler, otp_app: :indrajaal, crate: "math_engine"

  @doc """
  Calculates Shannon Entropy for a string via Rust NIF.
  """
  def calculate_entropy(data) do
    calculate_entropy_native(data)
  end

  defp calculate_entropy_native(_data), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Optimizes mesh jitter based on load and node count via Rust NIF.
  """
  def optimize_jitter(base_load, node_count) do
    optimize_jitter_native(base_load, node_count)
  end

  defp optimize_jitter_native(_base_load, _node_count), do: :erlang.nif_error(:nif_not_loaded)
end
