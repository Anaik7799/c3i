defmodule Scripts.TaskAuthorizationValidatorTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @script "scripts/planning/task_authorization_validator.exs"
  @test_file "PROJECT_TODOLIST.md"

  setup do
    # Backup existing file
    if File.exists?(@test_file) do
      File.rename!(@test_file, @test_file <> ".bak_test")
    end

    on_exit(fn ->
      # Restore file
      if File.exists?(@test_file <> ".bak_test") do
        File.rename!(@test_file <> ".bak_test", @test_file)
      end

      # Ensure permissions are restored
      File.chmod(@test_file, 0o644)
    end)
  end

  # ==================== BASIC FUNCTIONALITY ====================

  test "returns error when no task is in progress" do
    File.write!(@test_file, """
    ### Task 1
    **Status**: pending
    """)

    {output, exit_code} = System.cmd("elixir", [@script])

    assert exit_code == 1
    assert output =~ "⛔ UNAUTHORIZED"
  end

  test "returns success when exactly one task is in progress" do
    File.write!(@test_file, """
    ### Task 1
    **Status**: in_progress | Priority: P1
    """)

    {output, exit_code} = System.cmd("elixir", [@script])

    assert exit_code == 0
    assert output =~ "✅ AUTHORIZED"
    assert output =~ "### Task 1"
  end

  # ==================== ROBUSTNESS & FLEXIBILITY ====================

  test "handles flexible whitespace in status line" do
    File.write!(@test_file, """
    ### Task Flexible
    **Status**:    in_progress    | Priority: P1
    """)

    {output, exit_code} = System.cmd("elixir", [@script])

    assert exit_code == 0
    assert output =~ "✅ AUTHORIZED"
  end

  test "handles case insensitivity in status value" do
    File.write!(@test_file, """
    ### Task Case
    **Status**: IN_PROGRESS
    """)

    {output, exit_code} = System.cmd("elixir", [@script])

    assert exit_code == 0
    assert output =~ "✅ AUTHORIZED"
  end

  test "handles orphaned status lines gracefully" do
    File.write!(@test_file, """
    **Status**: in_progress (Orphan)
    """)

    {output, exit_code} = System.cmd("elixir", [@script])

    assert exit_code == 0
    assert output =~ "Unknown Task"
  end

  # ==================== CHAOS & ERROR CONDITIONS ====================

  test "handles file permission errors (simulated)" do
    File.write!(@test_file, "content")
    # Remove all permissions
    File.chmod!(@test_file, 0o000)

    {output, exit_code} = System.cmd("elixir", [@script], stderr_to_stdout: true)

    # Restore permissions for cleanup
    File.chmod!(@test_file, 0o644)

    assert exit_code == 1
    assert output =~ "CRITICAL: Could not read"
  end

  test "handles garbage/binary content" do
    # Invalid UTF-8
    File.write!(@test_file, <<0xFF, 0xFE, 0xFD>>)

    # The script uses File.read (binary), so it won't crash on read, 
    # but String.split might choke or treat it as one line.
    # Actually, String functions in Elixir require UTF-8 valid binaries.
    # This checks if the script crashes or handles it.

    try do
      {output, exit_code} = System.cmd("elixir", [@script], stderr_to_stdout: true)
      # Unauthorized (no matches found)
      assert exit_code == 1
    rescue
      e -> flunk("Script crashed on binary input: #{inspect(e)}")
    end
  end

  test "handles empty file" do
    File.write!(@test_file, "")

    {output, exit_code} = System.cmd("elixir", [@script])

    assert exit_code == 1
    assert output =~ "⛔ UNAUTHORIZED"
  end

  # ==================== COMPLIANCE ENFORCEMENT ====================

  test "strict mode halts on multiple tasks" do
    File.write!(@test_file, """
    ### Task 1
    **Status**: in_progress
    ### Task 2
    **Status**: in_progress
    """)

    {output, exit_code} = System.cmd("elixir", [@script, "--strict"])

    assert exit_code == 2
    assert output =~ "VIOLATION"
    assert output =~ "Strict mode enabled: Halting"
  end
end
