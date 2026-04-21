//// scripts/common/metrics — typed metrics API backed by scripts_nif.
////
//// SC-SCRIPT-MET-001. Publishes every counter/histogram update to
//// `indrajaal/metrics/scripts/<metric>/<label>` via the in-process Zenoh
//// session so downstream prom-style scrapers or Zenoh subscribers can
//// aggregate without polling any HTTP endpoint.

import scripts/common/nif

/// Increment a counter by `by` (typically 1). Returns the new total.
pub fn counter_inc(metric: String, label: String, by: Int) -> Int {
  let #(_, n) = nif.metrics_counter_inc(metric, label, by)
  n
}

/// Observe a value in a histogram. Returns the new sample count.
pub fn histogram_observe(metric: String, label: String, value: Float) -> Int {
  let #(_, n) = nif.metrics_histogram_observe(metric, label, value)
  n
}

/// Snapshot all counters + histograms as JSON.
pub fn snapshot() -> String {
  let #(_, s) = nif.metrics_snapshot()
  s
}
