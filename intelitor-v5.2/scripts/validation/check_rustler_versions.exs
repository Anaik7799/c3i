#!/usr/bin/env elixir
# TPS/Jidoka: Rustler Version Synchronization Check
# SC-NIF-004: Rustler Rust crate version MUST match Elixir hex version
# SC-NIF-005: CI MUST verify Cargo.toml rustler = mix.exs rustler
#
# Root Cause: Version drift between Rust and Elixir rustler causes compilation failure
# Prevention: This script validates version synchronization before build

defmodule RustlerVersionCheck do
  @moduledoc """
  Validates that Rustler versions are synchronized between:
  - mix.exs (Elixir hex package)
  - native/*/Cargo.toml (Rust crate)

  ## STAMP Constraints
  - SC-NIF-004: Versions MUST match
  - SC-NIF-005: CI MUST run this check
  - SC-NIF-007: Mismatch = P0 blocker
  """

  def run do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("SC-NIF-004/005: Rustler Version Synchronization Check")
    IO.puts("=" |> String.duplicate(60))

    # Get Elixir rustler version from mix.exs
    elixir_version = get_elixir_rustler_version()

    # Get Rust rustler versions from all Cargo.toml files
    rust_versions = get_rust_rustler_versions()

    IO.puts("\n[Elixir] mix.exs rustler version: #{elixir_version}")

    results =
      Enum.map(rust_versions, fn {path, version} ->
        IO.puts("[Rust] #{path}: #{version}")
        {path, version, versions_compatible?(elixir_version, version)}
      end)

    IO.puts("\n" <> String.duplicate("-", 60))

    failures = Enum.filter(results, fn {_, _, compatible} -> not compatible end)

    if failures == [] do
      IO.puts("✅ SC-NIF-004 PASS: All Rustler versions are synchronized")
      System.halt(0)
    else
      IO.puts("❌ SC-NIF-004 FAIL: Version mismatch detected!")
      IO.puts("\nMismatched files:")

      Enum.each(failures, fn {path, version, _} ->
        IO.puts("  - #{path}: #{version} (expected ~> #{elixir_version})")
      end)

      IO.puts("\n5-Level RCA:")
      IO.puts("  L1: Compilation fails with type mismatch")
      IO.puts("  L2: Rustler API changed between versions")
      IO.puts("  L3: Cargo.toml not updated when mix.exs updated")
      IO.puts("  L4: No automated version sync check")
      IO.puts("  L5: Missing SC-NIF-004 enforcement")

      IO.puts("\nFix: Update Cargo.toml to use rustler = \"#{major_minor(elixir_version)}\"")
      System.halt(1)
    end
  end

  defp get_elixir_rustler_version do
    mix_exs_path = Path.join(File.cwd!(), "mix.exs")

    case File.read(mix_exs_path) do
      {:ok, content} ->
        # Match {:rustler, "~> X.Y.Z"} or {:rustler, "X.Y.Z"}
        case Regex.run(~r/{:rustler,\s*"~?>?\s*([0-9]+\.[0-9]+\.?[0-9]*)"\s*}/, content) do
          [_, version] -> version
          nil -> "NOT FOUND"
        end

      {:error, _} ->
        "ERROR: Cannot read mix.exs"
    end
  end

  defp get_rust_rustler_versions do
    native_dir = Path.join(File.cwd!(), "native")

    if File.dir?(native_dir) do
      Path.wildcard(Path.join(native_dir, "*/Cargo.toml"))
      |> Enum.map(fn path ->
        version =
          case File.read(path) do
            {:ok, content} ->
              # Match rustler = "X.Y" or rustler = "X.Y.Z"
              case Regex.run(~r/rustler\s*=\s*"([0-9]+\.[0-9]+\.?[0-9]*)"/, content) do
                [_, version] -> version
                nil -> "NOT FOUND"
              end

            {:error, _} ->
              "ERROR: Cannot read file"
          end

        relative_path = Path.relative_to(path, File.cwd!())
        {relative_path, version}
      end)
    else
      []
    end
  end

  defp versions_compatible?(elixir_version, rust_version) do
    # Compare major.minor versions
    major_minor(elixir_version) == major_minor(rust_version)
  end

  defp major_minor(version) do
    case String.split(version, ".") do
      [major, minor | _] -> "#{major}.#{minor}"
      [major] -> major
      _ -> version
    end
  end
end

RustlerVersionCheck.run()
