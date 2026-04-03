defmodule Indrajaal.Analysis.ShannonAuditor do
  @moduledoc """
  Shannon Entropy Auditor for Biomorphic State Verification.

  WHAT: Measures information density and structural disorder (Entropy H).
  WHY: SC-MATH-006 mandates information theory checks for SIL-6 integrity.
  """

  require Logger

  @doc """
  Calculates Shannon Entropy for a binary or string.
  H(X) = -Σ P(x) log2 P(x)
  """
  def calculate_entropy(data) when is_binary(data) do
    if byte_size(data) == 0 do
      0.0
    else
      # 1. Frequency Map
      freqs =
        data
        |> :erlang.binary_to_list()
        |> Enum.reduce(%{}, fn byte, acc -> Map.update(acc, byte, 1, &(&1 + 1)) end)

      total = byte_size(data)

      # 2. Entropy Calculation
      entropy =
        freqs
        |> Map.values()
        |> Enum.reduce(0.0, fn count, acc ->
          p = count / total
          acc - p * :math.log2(p)
        end)

      entropy
    end
  end

  @doc """
  Audits a file and returns its information density metrics.
  """
  def audit_file(path) do
    case File.read(path) do
      {:ok, content} ->
        entropy = calculate_entropy(content)
        size = byte_size(content)
        # Theoretical max entropy for 8-bit data is 8.0
        density = entropy / 8.0

        %{
          path: path,
          entropy: Float.round(entropy, 4),
          density: Float.round(density, 4),
          size_bytes: size,
          timestamp: DateTime.utc_now()
        }

      {:error, reason} ->
        Logger.error("Failed to audit file #{path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Performs a fractal audit of a directory.
  """
  def audit_directory(dir_path) do
    files = Path.wildcard("#{dir_path}/**/*.{ex,exs,fs,rs}")

    results = Enum.map(files, &audit_file/1)

    avg_entropy =
      results
      |> Enum.map(& &1.entropy)
      |> Enum.sum()
      |> Kernel./(Enum.count(results))

    %{
      directory: dir_path,
      file_count: Enum.count(files),
      average_entropy: Float.round(avg_entropy, 4),
      system_homeostasis: if(avg_entropy < 7.5, do: :nominal, else: :high_disorder)
    }
  end
end
