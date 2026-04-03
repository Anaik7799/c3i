defmodule Indrajaal.Instrumentation.ErrorDetection do
  @moduledoc """
  State Change Instrumentation for Error Detection

  Provides comprehensive instrumentation to catch error conditions and
  deviations immediately during runtime. Covers:
  - EP-GEN-014 compliance monitoring
  - Header extraction validation
  - Fingerprint entropy analysis
  - State transition verification

  STAMP Compliance: SC-VAL-001, SC-CMP-025, SC-AGT-CODE-025
  FORMAL SPECS: comprehensive_error_model.wl, .qnt, .agda
  """

  require Logger

  @doc """
  Instrument header extraction to detect spacing bugs.

  ## STAMP Constraint: SC-SEC-044 (Security Check)
  ## Formal Invariant: INV-HEADER-1 (No spaces in header names)
  """
  @spec instrument_header_extraction(atom(), String.t(), String.t()) ::
          :ok | {:error, :spacing_bug}
  def instrument_header_extraction(atom_name, header_name, value) do
    has_spacing_bug = String.contains?(header_name, " ")
    empty_value = value == ""

    metrics = %{
      atom_name: atom_name,
      header_name: header_name,
      has_spacing_bug: has_spacing_bug,
      value_empty: empty_value,
      value_length: String.length(value),
      timestamp: System.system_time(:nanosecond)
    }

    metadata = %{
      file: "session_security.ex",
      function: "get_header_value/2",
      caller: inspect(self())
    }

    :telemetry.execute(
      [:indrajaal, :instrumentation, :header_extraction],
      metrics,
      metadata
    )

    if has_spacing_bug do
      Logger.warning(
        "SPACING BUG DETECTED in header extraction",
        atom_name: atom_name,
        header_name: header_name,
        expected: remove_spaces(header_name)
      )

      :telemetry.execute(
        [:indrajaal, :instrumentation, :header_spacing_bug],
        %{atom_name: atom_name, header_name: header_name},
        metadata
      )

      {:error, :spacing_bug}
    else
      :ok
    end
  end

  @doc """
  Instrument fingerprint generation to detect entropy issues.

  ## STAMP Constraint: SC-SEC-047 (Encryption)
  ## Formal Invariant: INV-FP-1 (Fingerprint determinism)
  """
  @spec instrument_fingerprint_generation(list(), String.t()) :: :ok | {:warning, :low_entropy}
  def instrument_fingerprint_generation(components, fingerprint) do
    empty_count = Enum.count(components, &(&1 == ""))
    total_count = length(components)
    entropy_ratio = (total_count - empty_count) / total_count

    metrics = %{
      fingerprint_length: String.length(fingerprint),
      empty_components: empty_count,
      total_components: total_count,
      entropy_ratio: Float.round(entropy_ratio, 3),
      timestamp: System.system_time(:nanosecond)
    }

    metadata = %{
      fingerprint_hash: String.slice(fingerprint, 0, 16),
      file: "session_security.ex",
      function: "generate_fingerprint/1"
    }

    :telemetry.execute(
      [:indrajaal, :instrumentation, :fingerprint_generated],
      metrics,
      metadata
    )

    # Alert if entropy is too low (> 2 empty components out of 7)
    if empty_count > 2 do
      Logger.warning(
        "LOW ENTROPY FINGERPRINT detected",
        empty_components: empty_count,
        total_components: total_count,
        entropy_ratio: entropy_ratio
      )

      :telemetry.execute(
        [:indrajaal, :instrumentation, :low_entropy_fingerprint],
        %{empty_count: empty_count, entropy_ratio: entropy_ratio},
        metadata
      )

      {:warning, :low_entropy}
    else
      :ok
    end
  end

  @doc """
  Instrument EP-GEN-014 compliance check.

  ## STAMP Constraint: SC-CMP-025 (0 Warnings)
  ## Formal Invariant: INV-EP014-1, INV-EP014-2
  """
  @spec check_ep014_compliance(String.t(), keyword()) :: :compliant | {:violation, list()}
  def check_ep014_compliance(module_code, opts \\ []) do
    file_path = Keyword.get(opts, :file_path, "unknown")

    checks = [
      {:propcheck, String.contains?(module_code, "use PropCheck")},
      {:exunitproperties, String.contains?(module_code, "import ExUnitProperties")},
      {:except_clause, String.contains?(module_code, "except:")},
      {:pc_alias, String.contains?(module_code, "alias PropCheck.BasicTypes, as: PC")},
      {:sd_alias, String.contains?(module_code, "alias StreamData, as: SD")},
      {:check_all, String.contains?(module_code, "check all(")}
    ]

    has_propcheck = Keyword.get(checks, :propcheck)
    has_exunitprops = Keyword.get(checks, :exunitproperties)
    has_except = Keyword.get(checks, :except_clause)
    has_check_all = Keyword.get(checks, :check_all)

    violations = []

    # Violation 1: Both frameworks without except clause
    violations =
      if has_propcheck and has_exunitprops and not has_except do
        [
          {:missing_except_clause,
           "Both PropCheck and ExUnitProperties imported without except: clause"}
          | violations
        ]
      else
        violations
      end

    # Violation 2: check all() without ExUnitProperties import
    violations =
      if has_check_all and not has_exunitprops do
        [{:missing_import, "check all() used without import ExUnitProperties"} | violations]
      else
        violations
      end

    # Violation 3: Both frameworks without aliases
    violations =
      if has_propcheck and has_exunitprops and
           not (Keyword.get(checks, :pc_alias) or Keyword.get(checks, :sd_alias)) do
        [{:missing_aliases, "Both frameworks imported without PC/SD aliases"} | violations]
      else
        violations
      end

    metrics = %{
      file_path: file_path,
      has_propcheck: has_propcheck,
      has_exunitproperties: has_exunitprops,
      has_except_clause: has_except,
      has_check_all: has_check_all,
      violations_count: length(violations),
      timestamp: System.system_time(:nanosecond)
    }

    if length(violations) > 0 do
      :telemetry.execute(
        [:indrajaal, :instrumentation, :ep014_violation],
        metrics,
        %{violations: violations}
      )

      Logger.warning(
        "EP-GEN-014 VIOLATION detected",
        file: file_path,
        violations: violations
      )

      {:violation, violations}
    else
      :telemetry.execute(
        [:indrajaal, :instrumentation, :ep014_compliant],
        metrics,
        %{}
      )

      :compliant
    end
  end

  @doc """
  Instrument state transition for verification.

  ## STAMP Constraint: SC-AGT-018 (No Deadlocks)
  ## Formal Invariant: State machine transitions
  """
  @spec instrument_state_transition(atom(), any(), any(), any()) :: :ok
  def instrument_state_transition(entity, old_state, new_state, context \\ %{}) do
    transition_valid = validate_transition(entity, old_state, new_state)

    metrics = %{
      entity: entity,
      old_state: old_state,
      new_state: new_state,
      transition_valid: transition_valid,
      timestamp: System.system_time(:nanosecond)
    }

    metadata =
      Map.merge(context, %{
        caller: inspect(self()),
        entity: entity
      })

    :telemetry.execute(
      [:indrajaal, :instrumentation, :state_transition],
      metrics,
      metadata
    )

    unless transition_valid do
      Logger.warning(
        "INVALID STATE TRANSITION detected",
        entity: entity,
        from: old_state,
        to: new_state
      )

      :telemetry.execute(
        [:indrajaal, :instrumentation, :invalid_state_transition],
        metrics,
        metadata
      )
    end

    :ok
  end

  @doc """
  Attach telemetry handlers for error detection.
  """
  def attach_handlers do
    handlers = [
      {:header_extraction, [:indrajaal, :instrumentation, :header_extraction],
       &handle_header_extraction/4},
      {:spacing_bug, [:indrajaal, :instrumentation, :header_spacing_bug], &handle_spacing_bug/4},
      {:fingerprint, [:indrajaal, :instrumentation, :fingerprint_generated],
       &handle_fingerprint/4},
      {:low_entropy, [:indrajaal, :instrumentation, :low_entropy_fingerprint],
       &handle_low_entropy/4},
      {:ep014_violation, [:indrajaal, :instrumentation, :ep014_violation],
       &handle_ep014_violation/4},
      {:state_transition, [:indrajaal, :instrumentation, :state_transition],
       &handle_state_transition/4}
    ]

    Enum.each(handlers, fn {id, event, handler} ->
      :telemetry.attach(
        "error-detection-#{id}",
        event,
        handler,
        %{}
      )
    end)

    :ok
  end

  # Private functions

  defp remove_spaces(str) do
    String.replace(str, " ", "")
  end

  defp validate_transition(:session, old, new) do
    valid_transitions = %{
      :created => [:active, :terminated],
      :active => [:validated, :rotated, :terminated, :expired],
      :validated => [:active],
      :rotated => [:active],
      :terminated => [],
      :expired => []
    }

    new in Map.get(valid_transitions, old, [])
  end

  defp validate_transition(:ep014, old, new) do
    valid_transitions = %{
      :no_property_tests => [:propcheck_only, :exunitprops_only],
      :propcheck_only => [:both_no_except, :both_with_except],
      :exunitprops_only => [:both_no_except],
      :both_no_except => [:both_with_except, :compile_error],
      :both_with_except => [:fully_compliant],
      :fully_compliant => [:compile_success],
      :compile_error => [],
      :compile_success => []
    }

    new in Map.get(valid_transitions, old, [])
  end

  defp validate_transition(_entity, _old, _new), do: true

  # Telemetry handlers

  defp handle_header_extraction(_event, metrics, _metadata, _config) do
    if metrics.has_spacing_bug do
      Logger.debug("Header extraction with spacing bug detected")
    end
  end

  defp handle_spacing_bug(_event, metrics, _metadata, _config) do
    Logger.error("CRITICAL: Header spacing bug in #{metrics.atom_name}")
  end

  defp handle_fingerprint(_event, metrics, _metadata, _config) do
    if metrics.entropy_ratio < 0.7 do
      Logger.warning("Low entropy fingerprint: #{metrics.entropy_ratio}")
    end
  end

  defp handle_low_entropy(_event, metrics, _metadata, _config) do
    Logger.error("CRITICAL: Low entropy fingerprint - #{metrics.empty_count} empty components")
  end

  defp handle_ep014_violation(_event, metrics, metadata, _config) do
    Logger.error(
      "EP-GEN-014 Violation in #{metrics.file_path}: #{length(metadata.violations)} violations"
    )
  end

  defp handle_state_transition(_event, metrics, _metadata, _config) do
    unless metrics.transition_valid do
      Logger.error(
        "Invalid state transition: #{metrics.entity} #{metrics.old_state} -> #{metrics.new_state}"
      )
    end
  end
end
