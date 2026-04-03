defmodule Indrajaal.OperationalExcellence.ClaudeScriptExecutorTest do
  use ExUnit.Case, async: false

  alias Indrajaal.OperationalExcellence.{ClaudeScriptExecutor, ClaudeSession, ClaudeActivity}

  setup do
    # Start __required processes
    {:ok, _} = start_supervised(ClaudeSession)
    {:ok, _} = start_supervised(ClaudeActivity)
    {:ok, _} = start_supervised(ClaudeScriptExecutor)

    # Create test script
    test_script = create_test_script()

    on_exit(fn ->
      File.rm(test_script)
    end)

    %{test_script: test_script}
  end

  describe "Script Validation (UCA-004 Pr__evention)" do
    test "validates script exists" do
      assert {:error, :script_not_found} =
               ClaudeScriptExecutor.validate_script("nonexistent.sh")
    end

    test "validates script extension", %{test_script: script} do
      # Valid extension
      assert :ok = ClaudeScriptExecutor.validate_script(script)

      # Invalid extension
      bad_script = "test.txt"
      File.write!(bad_script, "echo test")

      assert {:error, :invalid_extension} =
               ClaudeScriptExecutor.validate_script(bad_script)

      File.rm(bad_script)
    end

    test "detects dangerous script content" do
      dangerous_script = "dangerous.sh"
      File.write!(dangerous_script, "rm -rf /")

      assert {:error, :unsafe_script_content} =
               ClaudeScriptExecutor.validate_script(dangerous_script)

      File.rm(dangerous_script)
    end
  end

  describe "Script Execution with Claude Context" do
    test "executes safe script with valid __context", %{test_script: script} do
      # Create valid Claude __context
      claude_context = %{
        session_id: "test_session",
        framework_compliance: %{
          tdg: true,
          stamp: true,
          sopv51: true
        },
        permission_level: :developer
      }

      # Execute script
      assert {:ok, result} = ClaudeScriptExecutor.execute(script, %{}, claude_context)
      assert result.exit_code == 0
      assert String.contains?(result.output, "Test script executed")
    end

    test "pr__events execution without framework compliance", %{test_script: script} do
      # Missing framework compliance
      claude_context = %{
        session_id: "test_session",
        framework_compliance: %{},
        permission_level: :developer
      }

      assert {:error, :framework_compliance_violation} =
               ClaudeScriptExecutor.execute(script, %{}, claude_context)
    end

    test "enforces permission __requirements", %{test_script: script} do
      # Insufficient permissions
      claude_context = %{
        session_id: "test_session",
        framework_compliance: %{
          tdg: true,
          stamp: true,
          sopv51: true
        },
        # Too low for some scripts
        permission_level: :user
      }

      # This should work for low-risk scripts
      assert {:ok, _} = ClaudeScriptExecutor.execute(script, %{}, claude_context)
    end

    test "blocks dangerous parameters", %{test_script: script} do
      claude_context = valid_claude_context()

      dangerous_params = %{
        force: true,
        option: "--force"
      }

      assert {:error, :dangerous_parameters} =
               ClaudeScriptExecutor.execute(script, dangerous_params, claude_context)
    end
  end

  describe "Script Discovery and Listing" do
    test "lists available scripts" do
      scripts = ClaudeScriptExecutor.list_available_scripts()

      assert is_list(scripts)

      assert Enum.all?(scripts, fn s ->
               Map.has_key?(s, :path) and
                 Map.has_key?(s, :name) and
                 Map.has_key?(s, :category)
             end)
    end

    test "categorizes scripts correctly" do
      scripts = ClaudeScriptExecutor.list_available_scripts()

      container_scripts = Enum.filter(scripts, &(&1.category == :containers))
      assert length(container_scripts) > 0
    end
  end

  describe "Execution History and Activity Tracking" do
    test "tracks successful execution in activity log", %{test_script: script} do
      claude_context = valid_claude_context()

      # Get last activity before execution
      before_activity = ClaudeActivity.get_last_entry()

      # Execute script
      assert {:ok, _} = ClaudeScriptExecutor.execute(script, %{}, claude_context)

      # Wait for activity tracking
      Process.sleep(100)

      # Check activity was tracked
      after_activity = ClaudeActivity.get_last_entry()
      assert after_activity != before_activity
      assert after_activity.operation.type == :script_execution
    end

    test "retrieves script execution history", %{test_script: script} do
      claude_context = valid_claude_context()

      # Execute script multiple times
      {:ok, _} = ClaudeScriptExecutor.execute(script, %{}, claude_context)
      {:ok, _} = ClaudeScriptExecutor.execute(script, %{}, claude_context)

      # Get history
      history = ClaudeScriptExecutor.get_script_history(script)

      assert length(history) >= 2
      assert Enum.all?(history, &(&1.script_path == script))
    end
  end

  describe "Safety Features" do
    test "checks elevation __requirements" do
      # Low risk script shouldn't require elevation
      low_risk = "scripts/validation/test.sh"
      assert false == ClaudeScriptExecutor.__requires_elevation?(low_risk)
    end

    test "enforces execution timeout" do
      # Create slow script
      slow_script = "slow_test.sh"

      File.write!(slow_script, """
      #!/bin/bash
      echo "Starting slow script"
      sleep 400  # Longer than timeout
      echo "Should not reach here"
      """)

      File.chmod!(slow_script, 0o755)

      claude_context = valid_claude_context()

      # Should timeout
      assert {:error, _} = ClaudeScriptExecutor.execute(slow_script, %{}, claude_context)

      File.rm(slow_script)
    end
  end

  # Helper functions

  defp create_test_script do
    script_path = "test_script.sh"

    File.write!(script_path, """
    #!/bin/bash
    # Description: Test script for validation
    echo "Test script executed"
    echo "Frameworks: $FRAMEWORK_TDG $FRAMEWORK_STAMP"
    exit 0
    """)

    File.chmod!(script_path, 0o755)
    script_path
  end

  defp valid_claude_context do
    %{
      session_id: "test_session_#{System.unique_integer()}",
      framework_compliance: %{
        aee: true,
        sopv51: true,
        gde: true,
        phics: true,
        tps: true,
        stamp: true,
        tdg: true
      },
      permission_level: :developer
    }
  end
end
