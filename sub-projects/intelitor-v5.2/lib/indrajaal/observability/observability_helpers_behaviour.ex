defmodule Indrajaal.Observability.ObservabilityHelpersBehaviour do
  @moduledoc """
  Behaviour definition for implementations.

  This behaviour defines the contract that all observability helper modules must implement
  to provide consistent monitoring, security, compliance, and integration capabilities
  across the Indrajaal platform.

  ## TDG Compliance
  This behaviour definition is generated following Test-Driven Generation methodology.
  All callback specifications are derived from comprehensive test _requirements in
  `test/indrajaal/observability/observability_helpers_behaviour_test.exs`.

  ## Date: 2025-09-04 02:08 CEST
  ## Pattern: EP062_MISSING_BEHAVIOUR_DEFINITION
  ## Purpose: Provide proper @behaviour definition for observability implementations

  ## Note on Utilities
  Common utility functions are available in `Indrajaal.Observability.Utils`
  module. This behaviour defines the contract for component-specific implementations.

  ## Core Observability Callbacks

  Implementing modules must provide monitoring initialization, metrics collection,
  health checking, and status reporting capabilities.

  ## Security and Compliance Callbacks

  Implementing modules must provide security constraint validation, compliance auditing,
  and data sensitivity classification capabilities.

  ## Documentation and Integration Callbacks

  Implementing modules must provide documentation generation, integration validation,
  and dashboard configuration capabilities.

  ## Implementation Examples

  ### SecurityMonitor Implementation
  ```elixir
  defmodule MySecurityMonitor do
    @behaviour Indrajaal.Observability.@impl true
    def initialize_monitoring(config) do
      # Initialize security monitoring with given configuration
      {:ok, %{component: :security_monitor, config: config, status: :initialized}}
    end

    @impl true
    def collect_metrics(component state) do
      # Collect current security metrics
      {:ok, %{threats_detected: 5, false_positives: 1, response_time_ms: 25}}
    end

    # ... implement all other _required callbacks
  end
  ```

  ### DataClassifier Implementation
  ```elixir
  defmodule MyDataClassifier do
    @behaviour Indrajaal.Observability.@impl true
    def initialize_monitoring(config) do
      {:ok, %{component: :data_classifier, ml_models: load_models(config)}}
    end

    @impl true
    def classify_data_sensitivity(data) do
      # Perform ML-based data classification
      {:ok, %{classification: :high, confidence: 0.95, pii_detected: true}}
    end

    # ... implement all other _required callbacks
  end
  ```
  """

  # ============================================================================
  # CORE OBSERVABILITY CALLBACKS
  # ============================================================================

  @doc """
  Initializes monitoring for a component with the given configuration.

  This callback must set up all necessary monitoring infrastructure, prepare
  metric collection systems, and return an initial component state that will
  be passed to subsequent callback invocations.

  ## Parameters
  - `config` - Configuration map containing monitoring parameters

  ## Returns
  - `{:ok, component_state}` - Successfully initialized monitoring with component state
  - `{:error, reason}` - Failed to initialize monitoring

  ## Required Configuration Keys
  The configuration map should contain component-specific settings such as:
  - `:monitoring_interval` - How often to collect metrics (seconds)
  - `:alert_thresholds` - Threshold values for alerting
  - `:component_name` - Name identifier for the component

  ## Component State
  The returned component state should contain:
  - `:component` - Component identifier atom
  - `:status` - Current status (`:initialized`, `:active`, `:stopped`)
  - `:config` - Stored configuration for later use
  """
  @callback initialize_monitoring(config :: map()) ::
              {:ok, component_state :: map()} | {:error, reason :: term()}

  @doc """
  Collects current metrics from the component.

  This callback must gather all relevant performance and operational metrics
  for the component and return them in a standardized format for analysis
  and dashboard display.

  ## Parameters
  - `component_state` - Current state of the component from initialize_monitoring/1

  ## Returns
  - `{:ok, metrics}` - Successfully collected metrics map
  - `{:error, reason}` - Failed to collect metrics

  ## Metrics Format
  The metrics map should contain performance indicators such as:
  - `:response_time_ms` - Average response time in milliseconds
  - `:throughput` - Operations per second
  - `:error_rate` - Error percentage (0.0 - 1.0)
  - `:cpu_usage` - CPU utilization percentage
  - Component-specific metrics (e.g., `:threats_detected` for security)
  """
  @callback collect_metrics(component_state :: map()) ::
              {:ok, metrics :: map()} | {:error, reason :: term()}

  @doc """
  Performs a health check on the component.

  This callback must evaluate the current health status of the component
  by checking critical subsystems and dependencies. It should provide
  detailed information about which checks passed or failed.

  ## Parameters
  - `component_state` - Current state of the component

  ## Returns
  - `{:ok, health_status}` - Health check completed successfully
  - `{:error, reason}` - Health check failed to execute

  ## Health Status Format
  The health status map should contain:
  - `:status` - Overall health (`:healthy`, `:degraded`, `:unhealthy`)
  - `:checks` - List of individual checks performed (optional)
  - `:details` - Additional diagnostic information (optional)
  """
  @callback check_health(component_state :: map()) ::
              {:ok, health_status :: map()} | {:error, reason :: term()}

  @doc """
  Gets the current operational status of the component.

  This callback must return comprehensive status information about the
  component including its current operational state, last activity,
  and any relevant operational metrics.

  ## Parameters
  - `component_state` - Current state of the component

  ## Returns
  - `{:ok, status_info}` - Successfully retrieved status information
  - `{:error, reason}` - Failed to retrieve status

  ## Status Information Format
  The status info map should contain:
  - `:component` - Component identifier atom
  - `:status` - Current operational status (`:active`, `:idle`, `:stopped`)
  - `:last_check` - DateTime of last activity (optional)
  - Component-specific status details
  """
  @callback get_status(component_state :: map()) ::
              {:ok, status_info :: map()} | {:error, reason :: term()}

  # ============================================================================
  # SECURITY AND COMPLIANCE CALLBACKS
  # ============================================================================

  @doc """
  Validates security constraints for the component.

  This callback must evaluate a list of security constraints and determine
  whether they are properly implemented and enforced by the component.
  It should identify any violations and provide recommendations.

  ## Parameters
  - `constraints` - List of security constraint atoms to validate

  ## Returns
  - `{:ok, validation_result}` - Validation completed successfully
  - `{:error, reason}` - Validation failed to execute

  ## Common Security Constraints
  - `:data_encryption` - Data encryption _requirements
  - `:access_control` - Access control mechanisms
  - `:audit_logging` - Audit trail _requirements
  - `:input_validation` - Input sanitization _requirements

  ## Validation Result Format
  - `:validated` - Number of constraints successfully validated
  - `:violations` - Number of constraint violations found
  - `:details` - Detailed violation information (optional)
  """
  @callback validate_security_constraints(constraints :: list()) ::
              {:ok, validation_result :: map()} | {:error, reason :: term()}

  @doc """
  Performs a compliance audit for the component.

  This callback must evaluate the component against specified compliance
  frameworks and return a comprehensive audit report with scores,
  findings, and recommendations.

  ## Parameters
  - `audit_config` - Configuration map specifying audit parameters

  ## Returns
  - `{:ok, audit_report}` - Audit completed successfully
  - `{:error, reason}` - Audit failed to execute

  ## Audit Configuration
  - `:frameworks` - List of compliance frameworks (`:sox`, `:gdpr`, `:hipaa`)
  - `:depth` - Audit depth (`:basic`, `:comprehensive`, `:detailed`)
  - `:focus_areas` - Specific areas to focus on (optional)

  ## Audit Report Format
  - `:compliance_score` - Overall compliance score (0.0 - 1.0)
  - `:findings` - List of compliance findings
  - `:recommendations` - List of improvement recommendations
  """
  @callback audit_compliance(audit_config :: map()) ::
              {:ok, audit_report :: map()} | {:error, reason :: term()}

  @doc """
  Classifies the sensitivity level of given data.

  This callback must analyze data content and classify its sensitivity
  level according to organizational data classification policies.
  It should identify PII, financial data, and other sensitive information.

  ## Parameters
  - `data` - Data map to analyze for sensitivity classification

  ## Returns
  - `{:ok, classification_result}` - Classification completed successfully
  - `{:error, reason}` - Classification failed to execute

  ## Classification Levels
  - `:low` - Public or non-sensitive data
  - `:medium` - Internal use data with limited sensitivity
  - `:high` - Sensitive data _requiring protection
  - `:critical` - Highly sensitive data (PII, financial, medical)

  ## Classification Result Format
  - `:classification` - Overall sensitivity level
  - `:confidence` - Confidence score (0.0 - 1.0) (optional)
  - `:pii_detected` - Whether PII was detected (optional)
  - `:fields_analyzed` - Number of fields analyzed
  """
  @callback classify_data_sensitivity(data :: map()) ::
              {:ok, classification_result :: map()} | {:error, reason :: term()}

  # ============================================================================
  # DOCUMENTATION AND INTEGRATION CALLBACKS
  # ============================================================================

  @doc """
  Generates documentation for the component.

  This callback must create comprehensive documentation for the component
  including API documentation, configuration guides, and operational
  procedures. The format and detail level can be customized via parameters.

  ## Parameters
  - `component_info` - Information map about the component to document

  ## Returns
  - `{:ok, documentation_result}` - Documentation generated successfully
  - `{:error, reason}` - Documentation generation failed

  ## Component Information
  - `:name` - Component name
  - `:version` - Component version
  - `:endpoints` - Number of API endpoints (if applicable)
  - `:metrics` - Number of metrics collected
  - `:dependencies` - List of dependencies (optional)

  ## Documentation Result Format
  - `:pages` - Number of documentation pages generated
  - `:sections` - Number of documentation sections
  - `:format` - Documentation format (`:markdown`, `:html`, `:pdf`)
  - `:location` - Where documentation was saved (optional)
  """
  @callback generate_documentation(component_info :: map()) ::
              {:ok, documentation_result :: map()} | {:error, reason :: term()}

  @doc """
  Validates integration connectivity and health.

  This callback must test all external integrations used by the component
  to ensure they are accessible, responsive, and functioning correctly.
  It should provide detailed information about each integration tested.

  ## Parameters
  - `integration_config` - Configuration for integration validation

  ## Returns
  - `{:ok, validation_result}` - Integration validation completed
  - `{:error, reason}` - Integration validation failed

  ## Integration Configuration
  - `:endpoints` - List of endpoint URLs to validate
  - `:timeout_ms` - Timeout for each validation attempt
  - `:retry_attempts` - Number of retry attempts for failed validations
  - `:auth_config` - Authentication configuration (optional)

  ## Validation Result Format
  - `:status` - Overall integration status (`:valid`, `:invalid`, `:degraded`)
  - `:endpoints_checked` - Number of endpoints successfully validated
  - `:latency_ms` - Average response latency
  - `:failures` - List of failed integrations (optional)
  """
  @callback validate_integration(integration_config :: map()) ::
              {:ok, validation_result :: map()} | {:error, reason :: term()}

  @doc """
  Builds dashboard configuration for the component.

  This callback must generate a dashboard configuration that can be used
  to create monitoring dashboards for the component. The configuration
  should specify widgets, panels, metrics, and refresh rates.

  ## Parameters
  - `dashboard_spec` - Specification for dashboard _requirements

  ## Returns
  - `{:ok, dashboard_config}` - Dashboard configuration built successfully
  - `{:error, reason}` - Dashboard configuration failed to build

  ## Dashboard Specification
  - `:component` - Component identifier for dashboard
  - `:metrics` - List of metrics to include in dashboard
  - `:refresh_interval` - How often to refresh dashboard data (seconds)
  - `:layout` - Dashboard layout preference (`:grid`, `:list`, `:custom`)

  ## Dashboard Configuration Format
  - `:widgets` - Number of dashboard widgets created
  - `:panels` - Number of dashboard panels configured
  - `:refresh_rate` - Configured refresh rate in seconds
  - `:config` - Detailed dashboard configuration (optional)
  """
  @callback build_dashboard_config(dashboard_spec :: map()) ::
              {:ok, dashboard_config :: map()} | {:error, reason :: term()}
end
