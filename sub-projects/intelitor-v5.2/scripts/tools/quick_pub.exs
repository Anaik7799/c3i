# Zenoh Publishing Utility
Mix.install([{:jason, "~> 1.4"}])

defmodule ZenohPub do
  def publish(key, payload) do
    # SC-ZEN-001: Use native ZenohSession if available
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohSession) do
      Indrajaal.Observability.ZenohSession.publish(key, payload)
    else
      # Manual FFI if needed, but easier to just use the system module if loaded
      # For a standalone script, we'll just log it since we don't have the full app running
      IO.puts("[STUB] Would publish to #{key}: #{payload}")
      :ok
    end
  end
end

[key, payload] = System.argv()
ZenohPub.publish(key, payload)
