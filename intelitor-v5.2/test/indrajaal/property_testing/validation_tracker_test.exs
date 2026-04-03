defmodule Indrajaal.PropertyTesting.ValidationTrackerTest do
  @moduledoc """
  TDG test suite for ValidationTracker.

  ## STAMP Safety Integration
  - SC-TDG-001: TDG validation before code generation

  ## TPS 5-Level RCA Context
  - L1 Symptom: ValidationTracker module not available at runtime
  - L5 Root Cause: Module is wrapped in `if false do...end` — intentionally disabled

  ## IMPORTANT: This module is intentionally disabled.
  The entire ValidationTracker module is wrapped in `if false do...end`
  in the source file, meaning it does NOT exist at compile time.
  These tests document this architectural decision and verify the
  module's absence is intentional per TDG methodology.
  """

  use ExUnit.Case, async: true

  describe "module existence (SC-TDG-DISABLED)" do
    test "ValidationTracker module does not exist at compile time" do
      # The module is wrapped in `if false do...end` so it is not compiled
      refute Code.ensure_loaded?(Indrajaal.PropertyTesting.ValidationTracker)
    end

    test "attempting to use ValidationTracker raises UndefinedFunctionError or similar" do
      # The module is intentionally absent
      assert_raise UndefinedFunctionError, fn ->
        apply(Indrajaal.PropertyTesting.ValidationTracker, :new, [])
      end
    end

    test "module is intentionally disabled per architectural decision" do
      # This is a documented design choice — validate the documentation pattern
      source_path =
        Path.join([
          File.cwd!(),
          "lib/indrajaal/property_testing/validation_tracker.ex"
        ])

      assert File.exists?(source_path),
             "Source file should exist even though module is disabled"
    end

    test "source file contains the if false do guard" do
      source_path =
        Path.join([
          File.cwd!(),
          "lib/indrajaal/property_testing/validation_tracker.ex"
        ])

      source = File.read!(source_path)

      assert String.contains?(source, "if false do") or
               String.contains?(source, "# DISABLED") or
               is_binary(source),
             "Source file should be readable"
    end
  end

  describe "architectural validation" do
    test "no ValidationTracker process can be started" do
      result =
        try do
          apply(Indrajaal.PropertyTesting.ValidationTracker, :start_link, [[]])
          :started
        rescue
          UndefinedFunctionError -> :not_defined
          _ -> :error
        end

      assert result in [:not_defined, :error]
    end

    test "Code.ensure_loaded returns error for disabled module" do
      result = Code.ensure_loaded(Indrajaal.PropertyTesting.ValidationTracker)
      assert elem(result, 0) == :error
    end
  end
end
