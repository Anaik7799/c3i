---- MODULE RustyVaultIntegration_Apalache ----
\* Apalache-specific MC wrapper with fully-bound CONSTANTS.
\* Uses literal strings (not symbolic) so no --cinit is required.

EXTENDS Naturals, Sequences, FiniteSets, TLC

VARIABLES
  \* @type: Str;
  vault_state,
  \* @type: Bool;
  kek_in_ram,
  \* @type: Seq([event: Str, ts: Int, ok: Bool, name: Str]);
  audit_log,
  \* @type: Int;
  clock,
  \* @type: Str -> Seq(Int);
  secret_versions,
  \* @type: Str -> Int;
  secret_fetched_at,
  \* @type: Bool;
  online,
  \* @type: Str -> Int;
  gcp_versions

A_Secrets      == {"anthropic_api_key", "openrouter_api_key", "telegram_token"}

A_MaxTtl       == [s \in A_Secrets |->
                     IF s = "telegram_token" THEN 30 ELSE 7]

A_Ttl          == [s \in A_Secrets |->
                     IF s = "telegram_token" THEN 3 ELSE 1]

A_RotationDays == [s \in A_Secrets |->
                     IF s = "telegram_token" THEN 365 ELSE 30]

A_MaxClock     == 5

INSTANCE RustyVaultIntegration WITH
  Secrets      <- A_Secrets,
  MaxTtl       <- A_MaxTtl,
  Ttl          <- A_Ttl,
  RotationDays <- A_RotationDays,
  MaxClock     <- A_MaxClock

====
