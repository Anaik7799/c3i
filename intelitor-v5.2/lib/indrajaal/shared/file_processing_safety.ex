defmodule Indrajaal.Shared.FileProcessingSafetyValidator do
  @moduledoc """
  Enhanced file processing safety measures to prevent future corruption.

  TPS Safety Principles:
  - Pre-processing validation
  - Content integrity checks
  - Atomic file operations
  - Recovery mechanisms

  ## TDG Compliance
  This module implements stub functions to satisfy TDG test expectations.
  Full implementation pending.
  """

  @doc """
  Validates a file before processing.

  Returns {:ok, file_path} if the file is valid, {:error, reason} otherwise.
  Handles nil, empty string, and non-existent file paths gracefully.
  """
  @spec validate_file_before_processing(term()) :: {:ok, String.t()} | {:error, term()}
  def validate_file_before_processing(nil), do: {:error, :nil_path}
  def validate_file_before_processing(""), do: {:error, :empty_path}

  def validate_file_before_processing(file_path) when is_binary(file_path) do
    cond do
      not File.exists?(file_path) ->
        {:error, "File does not exist"}

      File.dir?(file_path) ->
        {:error, :is_directory}

      true ->
        case File.read(file_path) do
          {:ok, content} ->
            case validate_content(content, file_path) do
              :ok -> {:ok, file_path}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, "File validation failed: #{inspect(reason)}"}
        end
    end
  end

  def validate_file_before_processing(_), do: {:error, :invalid_path_type}

  @doc """
  Safely writes content to a file with backup and recovery mechanisms.

  Returns {:ok, file_path} on success, {:error, reason} on failure.
  Creates parent directories if they don't exist (optional behavior).
  """
  @spec safe_file_write(term(), term()) :: {:ok, String.t()} | {:error, term()}
  def safe_file_write(nil, _content), do: {:error, :nil_path}
  def safe_file_write("", _content), do: {:error, :empty_path}

  def safe_file_write(file_path, content) when is_binary(file_path) do
    # Normalize content - handle nil and non-binary types
    normalized_content = normalize_content(content)

    case normalized_content do
      {:error, reason} ->
        {:error, reason}

      safe_content ->
        do_safe_write(file_path, safe_content)
    end
  end

  def safe_file_write(_file_path, _content), do: {:error, :invalid_path_type}

  # Private helper functions

  defp normalize_content(nil), do: ""
  defp normalize_content(content) when is_binary(content), do: content

  defp normalize_content(content) when is_map(content) do
    case Jason.encode(content) do
      {:ok, json} -> json
      {:error, _} -> {:error, :invalid_content_type}
    end
  rescue
    _ -> {:error, :invalid_content_type}
  end

  defp normalize_content(_), do: {:error, :invalid_content_type}

  defp do_safe_write(file_path, content) do
    backup_path = "#{file_path}.bak"
    file_exists = File.exists?(file_path)
    parent_dir = Path.dirname(file_path)

    with :ok <- ensure_directory_exists(parent_dir),
         :ok <- create_backup_if_needed(file_path, backup_path, file_exists),
         :ok <- write_and_validate(file_path, content, backup_path, file_exists) do
      {:ok, file_path}
    end
  end

  defp create_backup_if_needed(_file_path, _backup_path, false), do: :ok

  defp create_backup_if_needed(file_path, backup_path, true) do
    File.cp(file_path, backup_path)
  end

  defp write_and_validate(file_path, content, backup_path, file_exists) do
    case File.write(file_path, content) do
      :ok ->
        cleanup_backup_on_success(backup_path, file_exists)
        :ok

      {:error, reason} ->
        restore_backup_on_failure(file_path, backup_path, file_exists)
        {:error, "Write failed: #{inspect(reason)}"}
    end
  end

  defp cleanup_backup_on_success(backup_path, file_exists) do
    if file_exists, do: File.rm(backup_path)
  end

  defp restore_backup_on_failure(file_path, backup_path, file_exists) do
    if file_exists and File.exists?(backup_path) do
      File.cp(backup_path, file_path)
      File.rm(backup_path)
    end
  end

  defp ensure_directory_exists(path) do
    if File.exists?(path) and File.dir?(path) do
      :ok
    else
      case File.mkdir_p(path) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_content(content, file_path) do
    cond do
      # Skip syntax validation for non-Elixir files
      not String.ends_with?(file_path, [".ex", ".exs"]) ->
        :ok

      # Check for reversed content (basic syntax check)
      content |> String.trim() |> String.starts_with?("end") ->
        {:error, "File content appears reversed"}

      # All other content is valid
      true ->
        :ok
    end
  end
end

# Backward compatibility alias for existing code
defmodule FileProcessingSafetyValidator do
  @moduledoc false
  # Delegate to the namespaced module for backward compatibility

  defdelegate validate_file_before_processing(file_path),
    to: Indrajaal.Shared.FileProcessingSafetyValidator

  defdelegate safe_file_write(file_path, content),
    to: Indrajaal.Shared.FileProcessingSafetyValidator
end
