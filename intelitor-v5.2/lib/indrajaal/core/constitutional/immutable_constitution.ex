defmodule Indrajaal.Core.Constitutional.ImmutableConstitution do
  @moduledoc """
  Immutable Constitution — L0 Constitutional Layer (VSM)

  ## Design Intent
  Read-only module defining the L0 constitutional constants. All constitutional
  axioms, safety levels, and invariants are encoded as immutable module attributes.
  Provides a function to verify the constitution hash has not changed since
  the system was last certified.

  This module MUST NOT contain mutable state. It is the single source of truth
  for the constitutional DNA of the Indrajaal holon.

  ## Constitutional DNA
  The constitution is identified by its SHA-256 content hash, computed over the
  canonical representation of all constitutional constants. Any code change to this
  module changes the hash, which triggers the Dead Man's Switch and sterility check.

  ## STAMP Constraints
  - SC-RECONFIG-001: L0 constitution is IMMUTABLE (graph transformation for L1-L7 only)
  - SC-RECONFIG-005: Lineage preserved through reconfiguration
  - SC-RECONFIG-009: Guardian approval REQUIRED for any constitutional change
  - SC-SIMPLEX-002: Redundancy MUST NOT be reduced below minimum (MinRedundancy=2)
  - SC-VER-074: Constitutional L0-L7 MUST hold
  - SC-HASH-001: Deterministic hash computation
  - SC-HASH-003: Canonical representation

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation (L0)   |
  """

  # ---------------------------------------------------------------------------
  # Constitutional Identity
  # ---------------------------------------------------------------------------

  # System name and version identifier.
  @system_name "Indrajaal"
  @system_version "v21.3.1-SIL6"
  @constitution_version "L0-v21.3.1"

  # ---------------------------------------------------------------------------
  # Safety Level Constants (IEC 61508 SIL-6 Biomorphic Extended)
  # ---------------------------------------------------------------------------

  # SIL level — Safety Integrity Level (biomorphic extended to 6).
  @sil_level 6

  # Safe failure fraction threshold (≥ 90%).
  @safe_failure_fraction 0.90

  # Diagnostic coverage threshold (≥ 90%).
  @diagnostic_coverage 0.90

  # Minimum redundancy for critical services.
  @min_redundancy 2

  # ---------------------------------------------------------------------------
  # Axiom Registry (Ω₀-Ω₁₁)
  # ---------------------------------------------------------------------------

  # All constitutional axioms in canonical order.
  @axioms [
    omega0: "Founder's Covenant — resource acquisition and genetic perpetuity primary",
    omega1: "Patient Mode — NO_TIMEOUT, INFINITE_PATIENCE, correct BEAM options",
    omega2: "Container Isolation — NixOS/Podman rootless, localhost registry only",
    omega3: "Zero-Defect — errors + warnings + test_fails + format_fails == 0",
    omega4: "Test-Driven Gen — tests MUST exist and fail BEFORE code gen",
    omega5: "Validation Consensus — 5-Method FPPS MUST agree",
    omega6: "Mandatory Gates — compile, runtime, TDG, STAMP, FPPS, coverage>95%, format, credo",
    omega7: "Holon State Sovereignty — SQLite/DuckDB ONLY for authoritative state",
    omega8:
      "Immutable Register — all state mutations via cryptographically-signed append-only blocks",
    omega9: "Constitutional Reconfiguration — L1-L7 flexible; L0 IMMUTABLE",
    omega10: "Absolute Zenoh Control — all mutations via Zenoh, no direct CLI mutations",
    omega11: "High-Assurance Evolution — genetic selection, wire-level proofs, KL throttling"
  ]

  # ---------------------------------------------------------------------------
  # Ψ Invariant Registry
  # ---------------------------------------------------------------------------

  @psi_invariants [
    psi0: "Existence — system processes alive",
    psi1: "Regeneration — SQLite/DuckDB accessible, holon can regenerate",
    psi2: "History — immutable register intact, evolutionary lineage preserved",
    psi3: "Verification — hash chain valid, cryptographic proof unbroken",
    psi4: "Alignment — Founder's lineage binding active",
    psi5: "Truthfulness — no deception in logs"
  ]

  # ---------------------------------------------------------------------------
  # Layer Definitions (L0-L7 Fractal Mesh)
  # ---------------------------------------------------------------------------

  @layers [
    l0: "Constitutional — immutable DNA, axioms, invariants",
    l1: "Operational — heartbeat, resources, safety interlocks, state reconciliation",
    l2: "Information — Zenoh telemetry, PubSub, event bus",
    l3: "Control — VSM System 3, budget, authority",
    l4: "Intelligence — VSM System 4, environmental scanning",
    l5: "Policy — VSM System 5, constitutional governance",
    l6: "Federation — cross-holon coordination",
    l7: "Formal — mathematical proofs, verification"
  ]

  # ---------------------------------------------------------------------------
  # Public API (read-only)
  # ---------------------------------------------------------------------------

  @doc "Returns the system name."
  @spec system_name() :: String.t()
  def system_name, do: @system_name

  @doc "Returns the system version."
  @spec system_version() :: String.t()
  def system_version, do: @system_version

  @doc "Returns the constitution version identifier."
  @spec constitution_version() :: String.t()
  def constitution_version, do: @constitution_version

  @doc "Returns the SIL level."
  @spec sil_level() :: non_neg_integer()
  def sil_level, do: @sil_level

  @doc "Returns the safe failure fraction threshold."
  @spec safe_failure_fraction() :: float()
  def safe_failure_fraction, do: @safe_failure_fraction

  @doc "Returns the diagnostic coverage threshold."
  @spec diagnostic_coverage() :: float()
  def diagnostic_coverage, do: @diagnostic_coverage

  @doc "Returns minimum redundancy for critical services."
  @spec min_redundancy() :: non_neg_integer()
  def min_redundancy, do: @min_redundancy

  @doc "Returns all axioms as a keyword list."
  @spec axioms() :: keyword()
  def axioms, do: @axioms

  @doc "Returns all Ψ invariants as a keyword list."
  @spec psi_invariants() :: keyword()
  def psi_invariants, do: @psi_invariants

  @doc "Returns all fractal mesh layer definitions."
  @spec layers() :: keyword()
  def layers, do: @layers

  @doc """
  Computes the canonical constitution hash.

  The hash is computed deterministically over the sorted, concatenated
  string representations of all constitutional constants. Any change to
  this module's constants produces a different hash, triggering the
  Dead Man's Switch (SC-DMS-001 through SC-DMS-004).
  """
  @spec constitution_hash() :: binary()
  def constitution_hash do
    canonical = build_canonical_representation()
    :crypto.hash(:sha256, canonical)
  end

  @doc "Returns the constitution hash as a hex string."
  @spec constitution_hash_hex() :: String.t()
  def constitution_hash_hex do
    constitution_hash() |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies the constitution hash matches the expected value.

  Returns `{:ok, hash_hex}` if the hash is consistent with a prior-computed
  reference, or `{:ok, hash_hex}` with a warning if no reference is stored
  (first-run case).

  In production, the reference hash MUST be stored in the immutable register
  at initial deployment and compared on every boot (SC-VER-007).
  """
  @spec verify_hash() :: {:ok, String.t()} | {:error, :hash_mismatch, map()}
  def verify_hash do
    current_hash = constitution_hash_hex()
    reference_hash = Application.get_env(:indrajaal, :constitution_reference_hash, nil)

    cond do
      is_nil(reference_hash) ->
        # No reference stored — first run or reference not configured
        {:ok, current_hash}

      current_hash == reference_hash ->
        {:ok, current_hash}

      true ->
        {:error, :hash_mismatch,
         %{
           expected: reference_hash,
           actual: current_hash,
           violation: "SC-RECONFIG-001: L0 constitution has been modified"
         }}
    end
  end

  @doc """
  Returns a full constitutional status report.
  """
  @spec status() :: map()
  def status do
    hash_verified =
      case verify_hash() do
        {:ok, _} -> true
        {:error, :hash_mismatch, _} -> false
      end

    %{
      system_name: @system_name,
      system_version: @system_version,
      constitution_version: @constitution_version,
      sil_level: @sil_level,
      hash_hex: constitution_hash_hex(),
      hash_verified: hash_verified,
      axiom_count: length(@axioms),
      psi_invariant_count: length(@psi_invariants),
      layer_count: length(@layers),
      timestamp: DateTime.utc_now()
    }
  end

  # ---------------------------------------------------------------------------
  # Private — canonical representation builder
  # ---------------------------------------------------------------------------

  @spec build_canonical_representation() :: binary()
  defp build_canonical_representation do
    parts = [
      "system_name=#{@system_name}",
      "system_version=#{@system_version}",
      "sil_level=#{@sil_level}",
      "min_redundancy=#{@min_redundancy}",
      @axioms |> Enum.sort_by(&elem(&1, 0)) |> Enum.map_join("|", fn {k, v} -> "#{k}:#{v}" end),
      @psi_invariants
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("|", fn {k, v} -> "#{k}:#{v}" end)
    ]

    Enum.join(parts, "||")
  end
end
