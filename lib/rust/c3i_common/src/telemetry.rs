/// Telemetry initialization for C3I Rust tools.
///
/// Provides a standard tracing subscriber with env-filter support.
/// Set RUST_LOG=debug (or info/warn/error) to control verbosity.

/// Initialize the tracing subscriber with env-filter.
///
/// If `verbose` is true, defaults to `debug` level; otherwise `warn`.
pub fn init_tracing(verbose: bool) {
    let default_level = if verbose { "debug" } else { "warn" };

    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(default_level));

    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .compact()
        .init();
}
