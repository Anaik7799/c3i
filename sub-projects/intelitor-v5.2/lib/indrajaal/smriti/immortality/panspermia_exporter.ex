defmodule Indrajaal.SMRITI.Immortality.PanspermiaExporter do
  @moduledoc """
  Exports the System DNA as a Self-Extracting Shell Script.
  Dependency: /bin/sh, base64, tar.
  """

  @critical_paths ~w(lib config priv/repo/migrations mix.exs mix.lock)
  @exclusion_patterns ~w(*.secret .env* _build deps .git)

  def export_dna(output_path) do
    # 1. Create a temporary archive
    archive_path = Path.join(System.tmp_dir!(), "dna_#{:os.system_time(:seconds)}.tar.gz")

    args =
      ["-czf", archive_path] ++
        Enum.map(@exclusion_patterns, &"--exclude=#{&1}") ++ @critical_paths

    case System.cmd("tar", args, stderr_to_stdout: true) do
      {_, 0} ->
        # 2. Read and Base64 encode
        blob = File.read!(archive_path) |> Base.encode64()

        # 3. Create the Shell Script
        script_content = """
        #!/bin/sh
        # SMRITI SELF-EXTRACTING DNA ARCHIVE
        # Generated: #{DateTime.utc_now()}
        # 
        # INSTRUCTIONS: Run 'sh system_dna.sh' to extract source code to current directory.

        echo "Initializing SMRITI Rehydration..."

        # Locate the payload start (line after __PAYLOAD__)
        PAYLOAD_LINE=$(awk '/^__PAYLOAD__/ {print NR + 1; exit 0; }' $0)

        # Decode and Extract
        tail -n +$PAYLOAD_LINE $0 | base64 -d | tar -xz

        if [ $? -eq 0 ]; then
          echo "✅ SYSTEM RECONSTRUCTED."
          echo "Run 'mix deps.get && mix compile' to boot."
        else
          echo "❌ EXTRACTION FAILED."
          exit 1
        fi

        exit 0
        __PAYLOAD__
        """

        # Append Blob
        full_content = script_content <> blob

        File.write(output_path, full_content)
        File.chmod(output_path, 0o755)
        File.rm(archive_path)

        {:ok, output_path, byte_size(blob)}

      {error_msg, _} ->
        {:error, "Tarball creation failed: #{error_msg}"}
    end
  end
end
