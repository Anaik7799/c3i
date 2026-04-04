#![deny(warnings, unused_imports, dead_code)]

//! C3I Common — shared infrastructure for Rust CLI tools.
//!
//! Provides ZMOF (Zenoh-MCP-OTel Fractal) publishing, fractal namespace
//! construction, Allium rule evaluation stubs, and telemetry initialization.

pub mod allium;
pub mod namespace;
pub mod telemetry;
pub mod zmof;
