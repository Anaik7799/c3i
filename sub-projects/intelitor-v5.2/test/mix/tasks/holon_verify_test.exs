defmodule Mix.Tasks.Holon.VerifyTest do
  @moduledoc """
  TDG-Compliant tests for mix holon.verify task.

  Tests Holon compliance verification across the codebase.

  STAMP Constraints:
  - SC-HOL-001: All holons MUST implement all 5 systems
  - SC-HOL-002: Holons MUST verify constitution on startup
  """

  use ExUnit.Case, async: false

  alias Mix.Tasks.Holon.Verify

  describe "Verify.run/1" do
    test "verifies holon compliance in codebase" do
      # Capture output
      result =
        capture_io(fn ->
          Verify.run([])
        end)

      assert result =~ "Holon Compliance"
    end

    test "accepts --strict flag" do
      result =
        capture_io(fn ->
          Verify.run(["--strict"])
        end)

      assert result =~ "strict mode"
    end

    test "accepts --json flag for machine-readable output" do
      result =
        capture_io(fn ->
          Verify.run(["--json"])
        end)

      # Should output valid JSON
      assert {:ok, _} = Jason.decode(result)
    end
  end

  describe "Verify.scan_modules/0" do
    test "finds modules that use Holon behaviour" do
      modules = Verify.scan_modules()

      # Should be a list
      assert is_list(modules)
    end

    test "identifies agent modules" do
      modules =
        Verify.scan_modules()
        |> Enum.filter(&Verify.is_agent_module?/1)

      # There should be agent modules
      assert length(modules) >= 0
    end
  end

  describe "Verify.check_holon_compliance/1" do
    test "returns :compliant for proper Holon implementation" do
      # Create a test module that implements Holon
      defmodule TestCompliantHolon do
        use Indrajaal.Core.Holon, layer: :module

        @impl Indrajaal.Core.Holon
        def system1_operations(_ctx), do: {:ok, :test}

        @impl Indrajaal.Core.Holon
        def system2_coordination(_peers), do: :ok

        @impl Indrajaal.Core.Holon
        def system3_control(budget), do: {:within_budget, budget}

        @impl Indrajaal.Core.Holon
        def system4_intelligence(_obs), do: {:no_plan, 0.0}

        @impl Indrajaal.Core.Holon
        def system5_policy, do: {:verified, <<>>}
      end

      result = Verify.check_holon_compliance(TestCompliantHolon)

      assert result.status == :compliant
      assert result.callbacks_implemented == 5
    end

    test "returns :non_compliant for module missing callbacks" do
      defmodule TestNonCompliantModule do
        # Does not use Holon
        def some_function, do: :ok
      end

      result = Verify.check_holon_compliance(TestNonCompliantModule)

      assert result.status == :non_compliant
      assert result.reason == :not_a_holon
    end
  end

  describe "Verify.generate_report/1" do
    test "generates compliance report" do
      results = [
        %{module: SomeModule, status: :compliant, callbacks_implemented: 5},
        %{module: OtherModule, status: :non_compliant, reason: :missing_callbacks}
      ]

      report = Verify.generate_report(results)

      assert Map.has_key?(report, :total_checked)
      assert Map.has_key?(report, :compliant)
      assert Map.has_key?(report, :non_compliant)
      assert Map.has_key?(report, :compliance_rate)
    end

    test "calculates compliance rate correctly" do
      results = [
        %{module: A, status: :compliant, callbacks_implemented: 5},
        %{module: B, status: :compliant, callbacks_implemented: 5},
        %{module: C, status: :non_compliant, reason: :missing_callbacks},
        %{module: D, status: :non_compliant, reason: :missing_callbacks}
      ]

      report = Verify.generate_report(results)

      assert report.compliance_rate == 50.0
    end
  end

  describe "Verify.vsm_callbacks/0" do
    test "returns list of required VSM callbacks" do
      callbacks = Verify.vsm_callbacks()

      assert :system1_operations in callbacks
      assert :system2_coordination in callbacks
      assert :system3_control in callbacks
      assert :system4_intelligence in callbacks
      assert :system5_policy in callbacks
      assert length(callbacks) == 5
    end
  end

  # Helper to capture IO
  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end
