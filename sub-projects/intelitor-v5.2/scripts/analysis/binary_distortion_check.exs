#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}, {:msgpax, "~> 2.3"}])

# 🚀 BINARY DISTORTION CHECK - SIL-6 INFORMATION THEORY
# ======================================================
# Purpose: Compare JSON vs MessagePack payload sizes for mesh state.

defmodule DistortionCheck do
  def run do
    IO.puts("📊 Checking Semantic Distortion...")
    
    # Standard 100-node topology update payload
    payload = %{
      "type" => "topology_update",
      "nodes" => Enum.map(1..100, fn i -> 
        %{
          "id" => "node-#{i}",
          "status" => "active",
          "metrics" => %{
            "cpu" => 0.45,
            "mem" => 0.72,
            "uptime" => 3600
          },
          "version" => "21.3.0"
        }
      end),
      "timestamp" => DateTime.to_iso8601(DateTime.utc_now())
    }

    json_data = Jason.encode!(payload)
    msgpack_iolist = Msgpax.pack!(payload)

    json_size = byte_size(json_data)
    msgpack_size = IO.iodata_length(msgpack_iolist)
    
    reduction = (1 - (msgpack_size / json_size)) * 100

    IO.puts("JSON Size: #{json_size} bytes")
    IO.puts("MsgPack Size: #{msgpack_size} bytes")
    IO.puts("Reduction: #{Float.round(reduction, 2)}%")
    
    if reduction >= 37.0 do
      IO.puts("✅ SUCCESS: Meets the 37% distortion reduction goal.")
    else
      IO.puts("❌ FAILURE: Reduction #{Float.round(reduction, 2)}% is insufficient.")
    end
  end
end

DistortionCheck.run()
