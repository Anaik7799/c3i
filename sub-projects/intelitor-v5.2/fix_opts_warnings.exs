#!/usr/bin/env elixir

# Systematic Opts Warning Fixer
# Following TPS methodology for batch processing

files_to_fix = [
  "lib/indrajaal/cache/warmer.ex:62",
  "lib/indrajaal/changes/trace_operation.ex:38",
  "lib/indrajaal/compliance/forensic_audit_trail.ex:25",
  "lib/indrajaal/compliance/regulatory_reporting_automation.ex:142",
  "lib/indrajaal/container_compliance_enhanced.ex:47",
  "lib/indrajaal/core/validations/ensure_primary_organization.ex:10",
  "lib/indrajaal/deployment/acceleration_engine.ex:214"
]

IO.puts("🔧 Starting systematic opts warning elimination...")

Enum.each(files_to_fix, fn file_info ->
  [file_path, line_str] = String.split(file_info, ":")
  line_num = String.to_integer(line_str)

  IO.puts("📝 Processing: #{file_path}:#{line_num}")

  if File.exists?(file_path) do
    content = File.read!(file_path)
    lines = String.split(content, "\n", parts: :infinity)

    if line_num <= length(lines) do
      target_line = Enum.at(lines, line_num - 1)

      # Fix pattern: replace " opts" with "_opts" in function definitions
      fixed_line =
        cond do
          String.contains?(target_line, "def init( opts)") ->
            String.replace(target_line, "def init( opts)", "def init(_opts)")

          String.contains?(target_line, "def change(changeset,  opts,") ->
            String.replace(
              target_line,
              "def change(changeset,  opts,",
              "def change(changeset, _opts,"
            )

          String.contains?(target_line, "def validate(changeset,  opts,") ->
            String.replace(
              target_line,
              "def validate(changeset,  opts,",
              "def validate(changeset, _opts,"
            )

          true ->
            target_line
        end

      if fixed_line != target_line do
        updated_lines = List.replace_at(lines, line_num - 1, fixed_line)
        File.write!(file_path, Enum.join(updated_lines, "\n"))
        IO.puts("✅ Fixed: #{file_path}:#{line_num}")
      else
        IO.puts("⚠️  Pattern not found: #{file_path}:#{line_num}")
      end
    else
      IO.puts("❌ Invalid line number: #{file_path}:#{line_num}")
    end
  else
    IO.puts("❌ File not found: #{file_path}")
  end
end)

IO.puts("🎯 Systematic opts warning elimination completed!")
