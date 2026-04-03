#!/usr/bin/env elixir
# KMS Test Logger
# WHAT: Serializes test results to JSONL for IKE Analytics.
# SCHEMAS: SC-KMS-008

defmodule KMSLogger do
  def log(test_type, result, metrics \\ %{}) do
    entry = %{
      id: UUID.uuid4(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      test_type: test_type,
      result: result, # :pass | :fail
      metrics: metrics,
      environment: %{
        os: "linux",
        runtime: "podman",
        topology: "fractal-mesh"
      },
      meta: %{
        compliance: "SIL-6 Biomorphic",
        verified_by: "CyberneticArchitect"
      }
    }

    # Using manual JSON construction to avoid dependency issues in minimal env
    json = build_json(entry)
    
    File.write!("data/kms/test_runs/results.jsonl", json <> "\n", [:append])
    IO.puts(">>> [KMS] Test result archived: #{entry.id}")
  end

  defp build_json(map) do
    # Minimal JSON builder
    fields = Enum.map(map, fn {k, v} -> 
      "\"#{k}\": #{encode(v)}" 
    end)
    "{" <> Enum.join(fields, ",") <> "}"
  end

  defp encode(v) when is_map(v), do: build_json(v)
  defp encode(v) when is_atom(v), do: "\"#{v}\""
  defp encode(v) when is_binary(v), do: "\"#{v}\""
  defp encode(v) when is_number(v), do: "#{v}"
  defp encode(_), do: "\"unknown\""
  
  # UUID helper
  defmodule UUID do
    def uuid4 do
      bin = :crypto.strong_rand_bytes(16)
      <<u0::48, _::4, u1::12, _::2, u2::62>> = bin
      <<u0::48, 4::4, u1::12, 2::2, u2::62>>
      |> Base.encode16(case: :lower)
    end
  end
end

# CLI Entrypoint
[type, result, score] = System.argv()
KMSLogger.log(type, String.to_atom(result), %{score: String.to_integer(score)})
