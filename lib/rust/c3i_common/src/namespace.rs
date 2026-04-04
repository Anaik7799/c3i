/// Fractal namespace key expression builder per SC-ZMOF-001.
///
/// All ZMOF topics follow the pattern: `indrajaal/l{layer}/{domain}/{suffix}`
/// matching the fractal layer hierarchy defined in CLAUDE.md §2.6.

/// Build a fractal namespace key expression.
///
/// # Examples
/// ```
/// use c3i_common::namespace::fractal_key;
/// assert_eq!(fractal_key(7, "fmea", "directives/L0"), "indrajaal/l7/fmea/directives/L0");
/// assert_eq!(fractal_key(1, "regression", "summary"), "indrajaal/l1/regression/summary");
/// ```
pub fn fractal_key(layer: u8, domain: &str, suffix: &str) -> String {
    format!("indrajaal/l{layer}/{domain}/{suffix}")
}

/// Build an OoZ (OTel-over-Zenoh) span key expression.
///
/// Spans are published to `indrajaal/otel/span/{layer}/{entity_id}`.
pub fn ooz_span_key(layer: u8, entity_id: &str) -> String {
    format!("indrajaal/otel/span/l{layer}/{entity_id}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fractal_key_format() {
        assert_eq!(
            fractal_key(7, "fmea", "directives/L0_CONSTITUTIONAL"),
            "indrajaal/l7/fmea/directives/L0_CONSTITUTIONAL"
        );
    }

    #[test]
    fn test_fractal_key_all_layers() {
        for layer in 0..=7 {
            let key = fractal_key(layer, "test", "check");
            assert!(key.starts_with(&format!("indrajaal/l{layer}/")));
        }
    }

    #[test]
    fn test_ooz_span_key_format() {
        assert_eq!(
            ooz_span_key(1, "browser_regression"),
            "indrajaal/otel/span/l1/browser_regression"
        );
    }
}
