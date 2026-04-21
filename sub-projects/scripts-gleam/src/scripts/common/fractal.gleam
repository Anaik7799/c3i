//// scripts/common/fractal — fractal L0..L7 observability spans.
////
//// SC-SCRIPT-GLEAM-001 + SC-GLM-ZEN-001 (Zenoh OTel spans are mandatory).
//// Each span emission is forwarded through the `scripts_nif` Rust NIF which:
////   1. serialises the span to JSON,
////   2. publishes to Zenoh topic `indrajaal/<layer>/scripts/<name>`,
////   3. returns the JSON line so the caller can also log it locally.
////
//// The fractal layers follow the project's canonical taxonomy:
////
////   L0 constitutional     L4 system
////   L1 atomic debug       L5 cognitive
////   L2 component          L6 ecosystem
////   L3 transaction        L7 federation

import scripts/common/nif

pub type Layer {
  L0
  L1
  L2
  L3
  L4
  L5
  L6
  L7
}

pub fn layer_tag(l: Layer) -> String {
  case l {
    L0 -> "l0"
    L1 -> "l1"
    L2 -> "l2"
    L3 -> "l3"
    L4 -> "l4"
    L5 -> "l5"
    L6 -> "l6"
    L7 -> "l7"
  }
}

pub type Status {
  StatusOk
  StatusError
}

pub fn status_tag(s: Status) -> String {
  case s {
    StatusOk -> "ok"
    StatusError -> "error"
  }
}

/// A typed span record. Prefer `span/3` to the raw `emit/5`.
pub type Span {
  Span(layer: Layer, name: String, start_ns: Int, end_ns: Int, status: Status)
}

/// Emit a closed span. `attrs_json` may be `"{}"`.
pub fn emit(span: Span, attrs_json: String) -> String {
  let #(_, line) =
    nif.fractal_span_emit(
      layer_tag(span.layer),
      span.name,
      span.start_ns,
      span.end_ns,
      status_tag(span.status),
      attrs_json,
    )
  line
}

/// Convenience wrapper: time a function and emit a span around it.
pub fn span(
  layer: Layer,
  name: String,
  attrs_json: String,
  work: fn() -> Result(a, e),
) -> Result(a, e) {
  let start = nif.now_nanos()
  let result = work()
  let end_ns = nif.now_nanos()
  let s = case result {
    Ok(_) -> StatusOk
    Error(_) -> StatusError
  }
  let _ =
    emit(Span(layer: layer, name: name, start_ns: start, end_ns: end_ns, status: s), attrs_json)
  result
}
