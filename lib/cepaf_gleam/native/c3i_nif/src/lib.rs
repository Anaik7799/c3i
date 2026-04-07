//! # c3i_nif — Unified C3I NIF for BEAM/Gleam MCP
//!
//! Consolidates all MCP tool implementations as Rust NIFs:
//! - Planning (7 NIFs): task CRUD on Smriti.db
//! - System (5 NIFs): health, dashboard, immune, zenoh, verification
//! - Knowledge (1 NIF): search Smriti.db knowledge tables
//! - Verification (1 NIF): run gleam check
//!
//! All NIFs use DirtyCpu scheduling to avoid blocking BEAM schedulers.
//! All return JSON strings for zero-impedance Gleam FFI.
//!
//! STAMP: SC-MCP-001, SC-TODO-001, SC-ARCH-SPLIT-003, SC-NIF-001, SC-ZMOF-005

mod db;
mod knowledge;
mod planning;
mod system;
mod verification;

rustler::init!("c3i_nif");
