// STAMP: SC-OTEL-001, SC-OBS-001
// AOR: AOR-OTEL-001
// Criticality: Level 2 (HIGH) - Observability and Distributed Tracing
//
// This module provides the OpenTelemetry-compatible tracing and metrics
// bridge for Gleam. It wraps the standard Erlang `telemetry` library
// to ensure seamless integration with the BEAM ecosystem.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list

// ============================================================================
// Semantic Conventions
// ============================================================================

pub const container_name = "container.name"

pub const container_id = "container.id"

pub const operation_type = "cepaf.operation.type"

pub const operation_status = "cepaf.operation.status"

pub const error_type = "error.type"

pub const health_status = "container.health.status"

// ============================================================================
// FFI Definitions for Erlang Telemetry
// ============================================================================

/// Represents a metric measurement (e.g., duration, count).
pub type Measurements =
  Dict(String, Float)

/// Represents the metadata/tags associated with an event.
pub type Metadata =
  Dict(String, String)

// Erlang FFI: telemetry:execute(EventName, Measurements, Metadata)
@external(erlang, "telemetry", "execute")
fn erl_telemetry_execute(
  event_name: List(dynamic.Dynamic),
  measurements: dynamic.Dynamic,
  metadata: dynamic.Dynamic,
) -> Nil

@external(erlang, "cepaf_gleam_ffi", "identity")
fn to_dynamic(a: a) -> Dynamic

// ============================================================================
// Tracing & Metrics API
// ============================================================================

/// Start a new span/activity. In BEAM telemetry, this is typically represented
/// by a `:start` event, followed by a `:stop` or `:exception` event.
pub fn start_span(name: List(String), tags: Metadata) -> Nil {
  let event_name = build_event_name(name, "start")
  erl_telemetry_execute(
    event_name,
    to_dynamic(dict.from_list([#("system_time", 0.0)])),
    // Placeholder for actual time
    to_dynamic(tags),
  )
}

/// Stop a span successfully.
pub fn stop_span(name: List(String), duration_ms: Float, tags: Metadata) -> Nil {
  let event_name = build_event_name(name, "stop")
  let tags_with_status = dict.insert(tags, operation_status, "success")

  erl_telemetry_execute(
    event_name,
    to_dynamic(dict.from_list([#("duration_ms", duration_ms)])),
    to_dynamic(tags_with_status),
  )
}

/// Stop a span with an error.
pub fn error_span(
  name: List(String),
  duration_ms: Float,
  err_type: String,
  tags: Metadata,
) -> Nil {
  let event_name = build_event_name(name, "exception")
  let error_tags =
    tags
    |> dict.insert(operation_status, "error")
    |> dict.insert(error_type, err_type)

  erl_telemetry_execute(
    event_name,
    to_dynamic(dict.from_list([#("duration_ms", duration_ms)])),
    to_dynamic(error_tags),
  )
}

/// Helper to construct Erlang atom lists for telemetry events (e.g., [:cepaf, :podman, :start]).
fn build_event_name(base: List(String), suffix: String) -> List(Dynamic) {
  list.append(base, [suffix])
  |> list.map(string_to_atom_dynamic)
}

// Wrapper to simplify the 2-arity Erlang BIF call
fn string_to_atom_dynamic(s: String) -> Dynamic {
  // Using utf8 encoding
  string_to_atom_dynamic_impl(s, "utf8")
}

@external(erlang, "erlang", "binary_to_atom")
fn string_to_atom_dynamic_impl(s: String, encoding: String) -> Dynamic
