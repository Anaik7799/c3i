defmodule Indrajaal.Analysis.MathNif do
  @moduledoc """
  Rust NIF for high-performance mathematical operations.

  WHAT: Native implementation of Shannon Entropy and mesh optimization.
  WHY: SC-MATH-008 mandates porting legacy Python logic to Rust NIFs for performance.
  """

  require Logger

  @cargo_available System.find_executable("cargo") != nil

  # Conditional Compilation (SC-NIF-005)
  # If SKIP_NIF_BUILD is set or cargo is missing, we bypass Rustler entirely to prevent container boot failure.
  if System.get_env("SKIP_NIF_BUILD") == "1" or not @cargo_available do
    Logger.warning("[MathNif] SKIP_NIF_BUILD active or cargo missing. Bypassing Rustler macro.")
  else
    use Rustler, otp_app: :indrajaal, crate: "math_engine"
  end

  @doc """
  Calculates Shannon Entropy for a string via Rust NIF.
  """
  def calculate_entropy(data) do
    # Fallback logic remains the same
    try do
      calculate_entropy_native(data)
    rescue
      _ -> calculate_entropy_elixir(data)
    end
  end

  # Define native stubs separately so they don't conflict with macro injection
  defp calculate_entropy_native(_data), do: :erlang.nif_error(:nif_not_loaded)

  defp calculate_entropy_elixir(data) do
    char_list = String.to_charlist(data)
    len = length(char_list)

    if len == 0 do
      0.0
    else
      frequencies = Enum.frequencies(char_list)

      frequencies
      |> Map.values()
      |> Enum.map(fn count ->
        p = count / len
        -p * :math.log2(p)
      end)
      |> Enum.sum()
    end
  end

  @doc """
  Optimizes mesh jitter based on load and node count via Rust NIF.
  """
  def optimize_jitter(base_load, node_count) do
    try do
      optimize_jitter_native(base_load, node_count)
    rescue
      _ -> base_load * (1.0 + node_count * 0.05)
    end
  end

  defp optimize_jitter_native(_base_load, _node_count), do: :erlang.nif_error(:nif_not_loaded)
end
