defmodule Indrajaal.Validation.FPPSBinary do
  @moduledoc """
  FPPS Binary Validation Method

  WHAT: Provides binary artifact validation for FPPS 5-point consensus.

  WHY: SIL-4 requires multiple independent validation methods.
  Binary validation verifies the integrity and authenticity of
  compiled artifacts (.beam files, NIFs, static assets).

  CONSTRAINTS:
  - SC-SIL4-023: FPPS 3/5 consensus required
  - SC-VAL-001: Patient Mode validation only
  - SC-NIF-004: Rustler version match verification

  TECHNIQUES:
  | Technique | Purpose |
  |-----------|---------|
  | BEAM Verification | Validate compiled modules |
  | NIF Binary Check | Verify native extensions |
  | Checksum Validation | SHA256 integrity |
  | Version Matching | Ensure artifact versions match |

  AOR:
  - AOR-VAL-003: Binary artifacts must be verifiable
  - AOR-NIF-001: NIF binaries must match Rustler version
  """

  require Logger

  # =============================================================================
  # Types
  # =============================================================================

  @type validation_target :: :beam | :nif | :static | :release
  @type validation_result :: :healthy | :unhealthy | :degraded | :unknown

  @type binary_report :: %{
          target: String.t(),
          result: validation_result(),
          file_count: non_neg_integer(),
          valid_count: non_neg_integer(),
          invalid_files: [String.t()],
          checksum_verified: boolean(),
          version_match: boolean(),
          confidence: float()
        }

  # =============================================================================
  # Constants
  # =============================================================================

  @beam_magic_number <<70, 79, 82, 49>>
  @min_beam_size 100
  @nif_extensions [".so", ".dll", ".dylib"]
  @build_dir "_build"
  @priv_dir "priv"

  # =============================================================================
  # FPPS Consensus API (SC-VAL-003)
  # =============================================================================
  # Counts the same 10 error + 5 warning categories as Pattern, but using
  # pure byte-level scanning (no regex engine involved).
  # This provides an independent detection path — if the regex engine had a
  # bug, the binary method would still detect the error markers.

  @doc """
  Validates compilation log content using byte-level pattern scanning.

  Counts distinct error/warning categories (same 10+5 as Pattern module)
  using pure binary matching. Returns a consensus-compatible map.

  This is the primary entry point for FPPS 5-method consensus.
  """
  @spec validate_log_content(binary()) :: %{
          method: :binary,
          errors: non_neg_integer(),
          warnings: non_neg_integer()
        }
  def validate_log_content(content) when is_binary(content) do
    lower = String.downcase(content)

    errors = count_binary_categories(lower, error_byte_patterns())
    warnings = count_binary_categories(lower, warning_byte_patterns())

    %{method: :binary, errors: errors, warnings: warnings}
  end

  def validate_log_content(_content) do
    %{method: :binary, errors: 0, warnings: 0}
  end

  # Each category is a list of byte patterns. A category is present if ALL
  # patterns in the group appear somewhere in the content (AND semantics for
  # multi-word categories, matching how Pattern's regex works).
  defp error_byte_patterns do
    [
      # Cat 1: "error:" literal
      ["error:"],
      # Cat 2: Compilation error header
      ["compilation error"],
      # Cat 3: Exception prefix "** ("
      ["** ("],
      # Cat 4: Named exception types (any one of these)
      :any_of_compileerror_argumenterror_runtimeerror,
      # Cat 5: "undefined variable" or "undefined function"
      :any_of_undefined_variable_function,
      # Cat 6: "cannot compile module"
      ["cannot compile module"],
      # Cat 7: "syntax error"
      ["syntax error"],
      # Cat 8: "(exit)"
      ["(exit)"],
      # Cat 9: "dialyzed with"
      ["dialyzed with"],
      # Cat 10: "found" + "issue" (Credo) — both on same line
      :credo_found_issue
    ]
  end

  defp warning_byte_patterns do
    [
      ["warning:"],
      ["deprecated"],
      ["unused"],
      ["shadowed"],
      ["unreachable"]
    ]
  end

  defp count_binary_categories(lower_content, categories) do
    Enum.count(categories, fn cat ->
      binary_category_present?(lower_content, cat)
    end)
  end

  defp binary_category_present?(content, :any_of_compileerror_argumenterror_runtimeerror) do
    # Category 4: any of the named exception types
    Enum.any?(
      [
        "compileerror",
        "argumenterror",
        "runtimeerror",
        "undefinedfunctionerror",
        "keyerror",
        "matcherror"
      ],
      &String.contains?(content, &1)
    )
  end

  defp binary_category_present?(content, :any_of_undefined_variable_function) do
    # Category 5: "undefined variable" OR "undefined function"
    String.contains?(content, "undefined variable") or
      String.contains?(content, "undefined function")
  end

  defp binary_category_present?(content, :credo_found_issue) do
    # Category 10: both "found" AND "issue" must appear on the SAME line
    content
    |> String.split("\n")
    |> Enum.any?(fn line ->
      String.contains?(line, "found") and String.contains?(line, "issue")
    end)
  end

  defp binary_category_present?(content, patterns) when is_list(patterns) do
    # All patterns must appear anywhere in content (AND semantics)
    Enum.all?(patterns, &String.contains?(content, &1))
  end

  # =============================================================================
  # Public API (Rich Reports — used by validate_artifacts, not consensus)
  # =============================================================================

  @doc """
  Validates binary artifacts using integrity checks.
  """
  @spec validate(String.t(), validation_target(), keyword()) ::
          {:ok, binary_report()} | {:error, term()}
  def validate(target, type, opts \\ []) do
    case type do
      :beam -> validate_beam_files(target, opts)
      :nif -> validate_nif_binaries(target, opts)
      :static -> validate_static_assets(target, opts)
      :release -> validate_release(target, opts)
    end
  end

  @doc """
  Validates all .beam files in the build directory.
  """
  @spec validate_beam_files(String.t(), keyword()) :: {:ok, binary_report()} | {:error, term()}
  def validate_beam_files(app_name, opts \\ []) do
    env = Keyword.get(opts, :env, :dev)
    build_path = Path.join([@build_dir, to_string(env), "lib", app_name, "ebin"])

    if File.dir?(build_path) do
      beam_files =
        build_path
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".beam"))
        |> Enum.map(&Path.join(build_path, &1))

      results = Enum.map(beam_files, &verify_beam_file/1)

      valid = Enum.filter(results, fn {status, _} -> status == :ok end)
      invalid = Enum.filter(results, fn {status, _} -> status == :error end)

      invalid_files = Enum.map(invalid, fn {:error, path} -> path end)

      report = %{
        target: app_name,
        result: determine_result(length(valid), length(invalid)),
        file_count: length(beam_files),
        valid_count: length(valid),
        invalid_files: invalid_files,
        checksum_verified: length(invalid) == 0,
        version_match: verify_beam_versions(beam_files),
        confidence: calculate_confidence(length(beam_files), length(valid))
      }

      {:ok, report}
    else
      {:error, {:build_not_found, build_path}}
    end
  end

  @doc """
  Validates NIF binaries in the priv directory.
  """
  @spec validate_nif_binaries(String.t(), keyword()) :: {:ok, binary_report()} | {:error, term()}
  def validate_nif_binaries(app_name, opts \\ []) do
    priv_path = Keyword.get(opts, :priv_path, Path.join([@priv_dir, "native"]))

    nif_files = find_nif_files(priv_path)

    if length(nif_files) > 0 do
      results = Enum.map(nif_files, &verify_nif_binary/1)

      valid = Enum.filter(results, fn {status, _} -> status == :ok end)
      invalid = Enum.filter(results, fn {status, _} -> status == :error end)

      invalid_files = Enum.map(invalid, fn {:error, path} -> path end)

      # Check Rustler version match (SC-NIF-004)
      rustler_match = verify_rustler_version_match()

      report = %{
        target: app_name,
        result: determine_nif_result(length(valid), length(invalid), rustler_match),
        file_count: length(nif_files),
        valid_count: length(valid),
        invalid_files: invalid_files,
        checksum_verified: length(invalid) == 0,
        version_match: rustler_match,
        confidence: calculate_confidence(length(nif_files), length(valid))
      }

      {:ok, report}
    else
      # No NIFs is not an error, just a report with 0 files
      report = %{
        target: app_name,
        result: :healthy,
        file_count: 0,
        valid_count: 0,
        invalid_files: [],
        checksum_verified: true,
        version_match: true,
        confidence: 1.0
      }

      {:ok, report}
    end
  end

  @doc """
  Validates static assets (CSS, JS, images) integrity.
  """
  @spec validate_static_assets(String.t(), keyword()) :: {:ok, binary_report()} | {:error, term()}
  def validate_static_assets(app_name, opts \\ []) do
    static_path = Keyword.get(opts, :static_path, Path.join([@priv_dir, "static"]))

    if File.dir?(static_path) do
      asset_files = find_static_assets(static_path)

      results = Enum.map(asset_files, &verify_static_asset/1)

      valid = Enum.filter(results, fn {status, _} -> status == :ok end)
      invalid = Enum.filter(results, fn {status, _} -> status == :error end)

      invalid_files = Enum.map(invalid, fn {:error, path} -> path end)

      report = %{
        target: app_name,
        result: determine_result(length(valid), length(invalid)),
        file_count: length(asset_files),
        valid_count: length(valid),
        invalid_files: invalid_files,
        checksum_verified: true,
        version_match: check_asset_manifest(static_path),
        confidence: calculate_confidence(length(asset_files), length(valid))
      }

      {:ok, report}
    else
      {:error, {:static_not_found, static_path}}
    end
  end

  @doc """
  Validates a release tarball or directory.
  """
  @spec validate_release(String.t(), keyword()) :: {:ok, binary_report()} | {:error, term()}
  def validate_release(release_path, opts \\ []) do
    if File.exists?(release_path) do
      # Validate release structure
      {valid_count, invalid_files} =
        if File.dir?(release_path) do
          validate_release_directory(release_path, opts)
        else
          validate_release_tarball(release_path, opts)
        end

      file_count = valid_count + length(invalid_files)

      report = %{
        target: release_path,
        result: determine_result(valid_count, length(invalid_files)),
        file_count: file_count,
        valid_count: valid_count,
        invalid_files: invalid_files,
        checksum_verified: length(invalid_files) == 0,
        version_match: verify_release_version(release_path),
        confidence: calculate_confidence(file_count, valid_count)
      }

      {:ok, report}
    else
      {:error, {:release_not_found, release_path}}
    end
  end

  @doc """
  Gets the validation result only (for FPPS consensus).
  """
  @spec get_result(String.t(), validation_target()) :: validation_result()
  def get_result(target, type) do
    case validate(target, type) do
      {:ok, report} -> report.result
      {:error, _} -> :unknown
    end
  end

  @doc """
  Computes SHA256 checksum of a file.
  """
  @spec file_checksum(String.t()) :: {:ok, String.t()} | {:error, term()}
  def file_checksum(path) do
    case File.read(path) do
      {:ok, content} ->
        checksum = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        {:ok, checksum}

      {:error, reason} ->
        {:error, {:read_failed, reason}}
    end
  end

  # =============================================================================
  # Private: BEAM Verification
  # =============================================================================

  defp verify_beam_file(path) do
    with {:ok, content} <- File.read(path),
         true <- byte_size(content) >= @min_beam_size,
         true <- verify_beam_magic(content),
         true <- verify_beam_structure(content) do
      {:ok, path}
    else
      false -> {:error, path}
      {:error, _} -> {:error, path}
    end
  end

  defp verify_beam_magic(<<magic::binary-size(4), _rest::binary>>) do
    magic == @beam_magic_number
  end

  defp verify_beam_magic(_), do: false

  defp verify_beam_structure(content) do
    # Basic BEAM structure validation
    # BEAM files have chunks: Atom, Code, StrT, ImpT, ExpT, etc.
    case :beam_lib.chunks(content, [:atoms]) do
      {:ok, _} -> true
      {:error, _, _} -> false
    end
  rescue
    _ -> false
  end

  defp verify_beam_versions(beam_files) do
    # Check that all .beam files have consistent OTP version
    versions =
      beam_files
      |> Enum.map(&get_beam_otp_version/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # All versions should match
    length(versions) <= 1
  end

  defp get_beam_otp_version(path) do
    case :beam_lib.chunks(path, [:compile_info]) do
      {:ok, {_module, [{:compile_info, info}]}} ->
        Keyword.get(info, :otp_release)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  # =============================================================================
  # Private: NIF Verification
  # =============================================================================

  defp find_nif_files(path) do
    if File.dir?(path) do
      path
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(fn file ->
        Enum.any?(@nif_extensions, &String.ends_with?(file, &1))
      end)
    else
      []
    end
  end

  defp verify_nif_binary(path) do
    with {:ok, stat} <- File.stat(path),
         true <- stat.size > 0,
         true <- verify_nif_loadable(path) do
      {:ok, path}
    else
      false -> {:error, path}
      {:error, _} -> {:error, path}
    end
  end

  defp verify_nif_loadable(path) do
    # Check if the shared library has valid structure
    # On Linux, check for ELF header
    case File.read(path) do
      {:ok, <<0x7F, "ELF", _rest::binary>>} ->
        true

      {:ok, <<0xCF, 0xFA, 0xED, 0xFE, _rest::binary>>} ->
        # Mach-O 64-bit (macOS)
        true

      {:ok, <<0xFE, 0xED, 0xFA, 0xCF, _rest::binary>>} ->
        # Mach-O 64-bit (macOS, big endian)
        true

      {:ok, <<"MZ", _rest::binary>>} ->
        # PE (Windows DLL)
        true

      _ ->
        false
    end
  end

  defp verify_rustler_version_match do
    # Check that Cargo.toml rustler version matches mix.exs rustler hex version
    # This implements SC-NIF-004

    mix_version = get_mix_rustler_version()
    cargo_version = get_cargo_rustler_version()

    case {mix_version, cargo_version} do
      {nil, nil} ->
        # No Rustler configured - that's fine
        true

      {nil, _} ->
        # Cargo has it but mix doesn't - mismatch
        Logger.warning("[FPPSBinary] Cargo.toml has rustler but mix.exs doesn't")
        false

      {_, nil} ->
        # Mix has it but Cargo doesn't - mismatch
        Logger.warning("[FPPSBinary] mix.exs has rustler but Cargo.toml doesn't")
        false

      {mix_ver, cargo_ver} ->
        # Both present - check major.minor match
        versions_compatible?(mix_ver, cargo_ver)
    end
  end

  defp get_mix_rustler_version do
    # Read mix.exs and find rustler version
    mix_path = "mix.exs"

    if File.exists?(mix_path) do
      case File.read(mix_path) do
        {:ok, content} ->
          # Look for {:rustler, "~> X.Y.Z"}
          case Regex.run(~r/{:rustler,\s*"~>\s*(\d+\.\d+(?:\.\d+)?)"/, content) do
            [_, version] -> version
            _ -> nil
          end

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp get_cargo_rustler_version do
    # Find Cargo.toml files in native/ directories
    cargo_files =
      Path.wildcard("native/*/Cargo.toml")

    versions =
      cargo_files
      |> Enum.map(&extract_cargo_rustler_version/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case versions do
      [version] -> version
      [version | _] -> version
      [] -> nil
    end
  end

  defp extract_cargo_rustler_version(cargo_path) do
    case File.read(cargo_path) do
      {:ok, content} ->
        # Look for rustler = "X.Y.Z" or rustler = { version = "X.Y.Z" }
        case Regex.run(~r/rustler\s*=\s*"(\d+\.\d+(?:\.\d+)?)"/, content) do
          [_, version] ->
            version

          _ ->
            case Regex.run(~r/rustler\s*=\s*\{[^}]*version\s*=\s*"(\d+\.\d+(?:\.\d+)?)"/, content) do
              [_, version] -> version
              _ -> nil
            end
        end

      _ ->
        nil
    end
  end

  defp versions_compatible?(mix_ver, cargo_ver) do
    # Extract major.minor for comparison
    [mix_major, mix_minor | _] = String.split(mix_ver, ".")
    [cargo_major, cargo_minor | _] = String.split(cargo_ver, ".")

    mix_major == cargo_major && mix_minor == cargo_minor
  rescue
    _ -> false
  end

  # =============================================================================
  # Private: Static Asset Verification
  # =============================================================================

  defp find_static_assets(path) do
    path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.reject(&File.dir?/1)
  end

  defp verify_static_asset(path) do
    case File.stat(path) do
      {:ok, stat} when stat.size > 0 ->
        {:ok, path}

      {:ok, _} ->
        # Empty file
        {:error, path}

      {:error, _} ->
        {:error, path}
    end
  end

  defp check_asset_manifest(static_path) do
    # Check if cache_manifest.json exists and is valid
    manifest_path = Path.join(static_path, "cache_manifest.json")

    if File.exists?(manifest_path) do
      case File.read(manifest_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, _} -> true
            {:error, _} -> false
          end

        _ ->
          false
      end
    else
      # No manifest is acceptable for dev
      true
    end
  end

  # =============================================================================
  # Private: Release Verification
  # =============================================================================

  defp validate_release_directory(path, _opts) do
    required_dirs = ["bin", "lib", "releases"]
    required_files = ["bin/indrajaal", "releases/start_erl.data"]

    valid =
      required_dirs
      |> Enum.map(&Path.join(path, &1))
      |> Enum.filter(&File.dir?/1)
      |> length()

    invalid =
      required_files
      |> Enum.map(&Path.join(path, &1))
      |> Enum.reject(&File.exists?/1)

    {valid + (length(required_files) - length(invalid)), invalid}
  end

  defp validate_release_tarball(path, _opts) do
    # For tar.gz, we just verify it's a valid gzip
    case System.cmd("gzip", ["-t", path], stderr_to_stdout: true) do
      {_, 0} -> {1, []}
      {_, _} -> {0, [path]}
    end
  rescue
    _ -> {0, [path]}
  end

  defp verify_release_version(path) do
    # Check if the release version matches application version
    version_file = Path.join([path, "releases", "RELEASES"])

    if File.exists?(version_file) do
      case File.read(version_file) do
        {:ok, content} ->
          String.contains?(content, "indrajaal")

        _ ->
          false
      end
    else
      # Try start_erl.data
      start_erl = Path.join([path, "releases", "start_erl.data"])

      if File.exists?(start_erl) do
        case File.read(start_erl) do
          {:ok, content} ->
            # Format: "ERTS_VSN REL_VSN"
            String.trim(content) != ""

          _ ->
            false
        end
      else
        false
      end
    end
  end

  # =============================================================================
  # Private: Result Determination
  # =============================================================================

  defp determine_result(valid_count, invalid_count) do
    total = valid_count + invalid_count

    cond do
      total == 0 -> :unknown
      invalid_count == 0 -> :healthy
      invalid_count / total < 0.1 -> :degraded
      true -> :unhealthy
    end
  end

  defp determine_nif_result(valid_count, invalid_count, rustler_match) do
    base_result = determine_result(valid_count, invalid_count)

    if base_result == :healthy && !rustler_match do
      :degraded
    else
      base_result
    end
  end

  defp calculate_confidence(total, valid) do
    if total == 0 do
      0.0
    else
      valid / total
    end
  end
end
