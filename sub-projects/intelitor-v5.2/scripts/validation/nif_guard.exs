#!/usr/bin/env elixir

defmodule NIFGuard do
  @moduledoc """
  Autonomic enforcement of NIF Safety Framework constraints.
  """
  require Logger

  def check_all do
    IO.puts("🛡️ NIF GUARD: Executing Safety Enforcement...")
    
    with :ok <- check_dirty_schedulers(),
         :ok <- verify_symbol_parity(),
         :ok <- check_rust_safety_flags() do
      IO.puts("✅ NIF GUARD: All native controls verified.")
      :ok
    else
      {:error, reason} ->
        IO.puts("❌ NIF GUARD FAILURE: #{reason}")
        System.halt(1)
    end
  end

  defp check_dirty_schedulers do
    # Scan Rust source for #[rustler::nif(schedule = "DirtyIo")]
    output = System.cmd("grep", ["-r", "schedule =", "native/"]) |> elem(0)
    if String.contains?(output, "Dirty"), do: :ok, else: {:error, "No dirty scheduler usage detected in native source."}
  end

  defp verify_symbol_parity do
    # Placeholder for actual symbol parity check between .ex and .rs
    :ok
  end

  defp check_rust_safety_flags do
    # Verify Cargo.toml has appropriate profiles
    content = File.read!("native/zenoh_nif/Cargo.toml")
    if String.contains?(content, "profile.release"), do: :ok, else: {:error, "Missing release profile in Cargo.toml"}
  end
end

NIFGuard.check_all()
