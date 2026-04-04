//! # Hysteresis Controller for Health Checks
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Container Orchestration) |
//! | Element   | Ignition / Boot / Verification |
//! | Feature   | Flapping Mitigation |
//!
//! ## STAMP
//! - FMEA RPN 192 Mitigation (Health Flapping / Spurious Restarts)
//! - SC-SIL4-001: Safety functions MUST fail to safe state
//! - SC-OPT-002: Health check exponential backoff integration
//! - SC-VAL-003: FPPS consensus verification robustness
//!
//! This module provides a stateful `HysteresisController` that wraps raw boolean
//! health probes. Instead of a single `true` or `false` instantly changing the
//! perceived system state, the controller requires N-consecutive successes to
//! transition to `Healthy`, and M-consecutive failures to transition to `Unhealthy`.
//!
//! ## Usage
//! ```rust
//! use crate::hysteresis::{HysteresisController, DEFAULT_CONFIG};
//!
//! let mut controller = HysteresisController::new(DEFAULT_CONFIG);
//! controller.apply_check(true);
//! controller.apply_check(true);
//! controller.apply_check(true);
//!
//! assert!(controller.is_stable_healthy());
//! ```

use std::collections::VecDeque;
use std::fmt;

/// Configuration for the Hysteresis Controller.
///
/// Defines the thresholds for state transitions and the window size for
/// historical health percentage calculations.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HysteresisConfig {
    /// Number of consecutive successful checks required to transition to Healthy
    pub required_successes: usize,
    /// Number of consecutive failed checks required to transition to Unhealthy
    pub required_failures: usize,
    /// Maximum number of historical checks to retain for percentage calculation
    pub history_window: usize,
}

/// A fast-acting configuration suitable for non-critical services where
/// immediate responsiveness is preferred over absolute stability.
/// Transitions state with just 1 consecutive event.
pub const AGGRESSIVE_CONFIG: HysteresisConfig = HysteresisConfig {
    required_successes: 1,
    required_failures: 1,
    history_window: 10,
};

/// The standard configuration used for most container health checks.
/// Requires 3 successes to be considered healthy, allowing brief transient
/// failures without causing a complete state change immediately.
/// Mitigates FMEA RPN 192 (Health Flapping).
pub const DEFAULT_CONFIG: HysteresisConfig = HysteresisConfig {
    required_successes: 3,
    required_failures: 2,
    history_window: 20,
};

/// A slow-acting configuration for safety-critical services (e.g., database)
/// that must absolutely be stable before accepting traffic, and shouldn't
/// flap down on minor latency spikes.
pub const CONSERVATIVE_CONFIG: HysteresisConfig = HysteresisConfig {
    required_successes: 5,
    required_failures: 3,
    history_window: 50,
};

/// Represents the stable state of a monitored component.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ComponentState {
    /// Initial state before sufficient checks have been performed
    Unknown,
    /// Component has passed the required consecutive successes
    Healthy,
    /// Component has failed the required consecutive failures
    Unhealthy,
}

impl fmt::Display for ComponentState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ComponentState::Unknown => write!(f, "Unknown"),
            ComponentState::Healthy => write!(f, "Healthy"),
            ComponentState::Unhealthy => write!(f, "Unhealthy"),
        }
    }
}

/// The stateful hysteresis controller.
///
/// Wraps a continuous stream of raw boolean checks and applies the configured
/// thresholds to yield a stabilized health state.
#[derive(Debug, Clone)]
pub struct HysteresisController {
    config: HysteresisConfig,
    history: VecDeque<bool>,
    state: ComponentState,
    current_consecutive_successes: usize,
    current_consecutive_failures: usize,
    total_checks: usize,
}

impl HysteresisController {
    /// Creates a new `HysteresisController` with the provided configuration.
    pub fn new(config: HysteresisConfig) -> Self {
        Self {
            history: VecDeque::with_capacity(config.history_window),
            config,
            state: ComponentState::Unknown,
            current_consecutive_successes: 0,
            current_consecutive_failures: 0,
            total_checks: 0,
        }
    }

    /// Feeds a new raw health check result into the controller.
    /// Updates internal state machines and historical window.
    pub fn apply_check(&mut self, is_healthy: bool) {
        self.total_checks += 1;

        // Manage sliding window history
        if self.history.len() >= self.config.history_window {
            self.history.pop_front();
        }
        self.history.push_back(is_healthy);

        // Update consecutive counters
        if is_healthy {
            self.current_consecutive_successes += 1;
            self.current_consecutive_failures = 0;
        } else {
            self.current_consecutive_failures += 1;
            self.current_consecutive_successes = 0;
        }

        // State transition logic based on current stable state
        match self.state {
            ComponentState::Unknown => {
                // From unknown, we can go to either Healthy or Unhealthy depending on which threshold is hit first
                if self.current_consecutive_successes >= self.config.required_successes {
                    self.state = ComponentState::Healthy;
                } else if self.current_consecutive_failures >= self.config.required_failures {
                    self.state = ComponentState::Unhealthy;
                }
            }
            ComponentState::Healthy => {
                // Already healthy, wait for failures to degrade
                if self.current_consecutive_failures >= self.config.required_failures {
                    self.state = ComponentState::Unhealthy;
                }
            }
            ComponentState::Unhealthy => {
                // Already unhealthy, wait for successes to recover
                if self.current_consecutive_successes >= self.config.required_successes {
                    self.state = ComponentState::Healthy;
                }
            }
        }
    }

    /// Returns `true` if the component is currently in the `Healthy` stable state.
    /// This is the primary method to gate boolean checks.
    pub fn is_stable_healthy(&self) -> bool {
        self.state == ComponentState::Healthy
    }

    /// Returns the percentage (0.0 to 100.0) of successful checks within the current window.
    pub fn health_percentage(&self) -> f64 {
        if self.history.is_empty() {
            return 0.0;
        }
        let healthy_count = self.history.iter().filter(|&&h| h).count();
        (healthy_count as f64 / self.history.len() as f64) * 100.0
    }

    /// Returns the current consecutive successes count.
    pub fn consecutive_successes(&self) -> usize {
        self.current_consecutive_successes
    }

    /// Returns the current consecutive failures count.
    pub fn consecutive_failures(&self) -> usize {
        self.current_consecutive_failures
    }

    /// Returns the total number of checks processed.
    pub fn total_checks(&self) -> usize {
        self.total_checks
    }

    /// Returns the current stabilized component state.
    pub fn state(&self) -> ComponentState {
        self.state
    }

    /// Returns the configuration currently in use.
    pub fn config(&self) -> &HysteresisConfig {
        &self.config
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initial_state() {
        let controller = HysteresisController::new(DEFAULT_CONFIG);
        assert_eq!(controller.state(), ComponentState::Unknown);
        assert!(!controller.is_stable_healthy());
        assert_eq!(controller.health_percentage(), 0.0);
    }

    #[test]
    fn test_transition_to_healthy_default() {
        let mut controller = HysteresisController::new(DEFAULT_CONFIG); // Requires 3 successes

        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Unknown);

        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Unknown);

        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Healthy);
        assert!(controller.is_stable_healthy());

        assert_eq!(controller.health_percentage(), 100.0);
    }

    #[test]
    fn test_transition_to_unhealthy_default() {
        let mut controller = HysteresisController::new(DEFAULT_CONFIG); // Requires 2 failures

        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unknown);

        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
        assert!(!controller.is_stable_healthy());

        assert_eq!(controller.health_percentage(), 0.0);
    }

    #[test]
    fn test_flapping_mitigation() {
        let mut controller = HysteresisController::new(DEFAULT_CONFIG); // 3 successes, 2 failures

        // Go Healthy
        controller.apply_check(true);
        controller.apply_check(true);
        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Healthy);

        // Single failure should not flap to Unhealthy
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Healthy);

        // Recovery
        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Healthy);

        // Now two failures in a row
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Healthy);
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
    }

    #[test]
    fn test_health_percentage_window() {
        let config = HysteresisConfig {
            required_successes: 1,
            required_failures: 1,
            history_window: 4,
        };
        let mut controller = HysteresisController::new(config);

        controller.apply_check(true);
        controller.apply_check(true);
        assert_eq!(controller.health_percentage(), 100.0);

        controller.apply_check(false);
        controller.apply_check(false);
        assert_eq!(controller.health_percentage(), 50.0); // 2 out of 4

        // Push older successes out of the window (window size is 4)
        controller.apply_check(false);
        // Window: [T, F, F, F]
        assert_eq!(controller.health_percentage(), 25.0);

        controller.apply_check(false);
        // Window: [F, F, F, F]
        assert_eq!(controller.health_percentage(), 0.0);
    }

    #[test]
    fn test_aggressive_config() {
        let mut controller = HysteresisController::new(AGGRESSIVE_CONFIG);

        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Healthy);

        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
    }

    #[test]
    fn test_conservative_config() {
        let mut controller = HysteresisController::new(CONSERVATIVE_CONFIG); // 5 succ, 3 fail

        for _ in 0..4 {
            controller.apply_check(true);
            assert_eq!(controller.state(), ComponentState::Unknown);
        }
        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Healthy);

        controller.apply_check(false);
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Healthy); // Not enough failures

        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
    }

    #[test]
    fn test_display_trait() {
        assert_eq!(format!("{}", ComponentState::Unknown), "Unknown");
        assert_eq!(format!("{}", ComponentState::Healthy), "Healthy");
        assert_eq!(format!("{}", ComponentState::Unhealthy), "Unhealthy");
    }

    #[test]
    fn test_long_running_stability() {
        let mut controller = HysteresisController::new(DEFAULT_CONFIG);
        // Simulate 100 successful checks
        for _ in 0..100 {
            controller.apply_check(true);
        }
        assert_eq!(controller.state(), ComponentState::Healthy);
        assert_eq!(controller.consecutive_successes(), 100);
        assert_eq!(controller.consecutive_failures(), 0);
        assert_eq!(controller.total_checks(), 100);
        assert_eq!(controller.health_percentage(), 100.0);

        // A single failure should not change state
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Healthy);
        assert_eq!(controller.consecutive_successes(), 0);
        assert_eq!(controller.consecutive_failures(), 1);
        assert_eq!(controller.total_checks(), 101);

        // Window is 20. 19 successes and 1 failure
        assert_eq!(controller.health_percentage(), 95.0);

        // Another failure drops it to unhealthy
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
        assert_eq!(controller.consecutive_failures(), 2);
        assert_eq!(controller.health_percentage(), 90.0);
    }

    #[test]
    fn test_config_accessors() {
        let controller = HysteresisController::new(DEFAULT_CONFIG);
        assert_eq!(controller.config().required_successes, 3);
        assert_eq!(controller.config().required_failures, 2);
        assert_eq!(controller.config().history_window, 20);
    }

    #[test]
    fn test_unknown_to_unhealthy_transition() {
        let mut controller = HysteresisController::new(DEFAULT_CONFIG);
        // Default requires 2 failures to go unhealthy
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unknown);
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
    }

    #[test]
    fn test_unhealthy_to_healthy_transition() {
        let mut controller = HysteresisController::new(DEFAULT_CONFIG);
        controller.apply_check(false);
        controller.apply_check(false);
        assert_eq!(controller.state(), ComponentState::Unhealthy);

        // Default requires 3 successes to recover
        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Unhealthy);
        controller.apply_check(true);
        assert_eq!(controller.state(), ComponentState::Healthy);
    }
}
