---- MODULE RustyVaultIntegration_MC ----
\* Model-checking wrapper for RustyVaultIntegration.
\* TLC's .cfg cannot bind CONSTANTS to function literals, so this
\* wrapper defines the per-secret functions concretely.

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
  \* @type: Str;
  anthropic_api_key,
  \* @type: Str;
  openrouter_api_key,
  \* @type: Str;
  telegram_token,
  \* @type: Int;
  MaxClock

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

MC_Secrets      == {anthropic_api_key, openrouter_api_key, telegram_token}

MC_MaxTtl       == [s \in MC_Secrets |->
                     IF s = telegram_token THEN 30 ELSE 7]

MC_Ttl          == [s \in MC_Secrets |->
                     IF s = telegram_token THEN 3 ELSE 1]

MC_RotationDays == [s \in MC_Secrets |->
                     IF s = telegram_token THEN 365 ELSE 30]

INSTANCE RustyVaultIntegration WITH
  Secrets      <- MC_Secrets,
  MaxTtl       <- MC_MaxTtl,
  Ttl          <- MC_Ttl,
  RotationDays <- MC_RotationDays,
  MaxClock     <- MaxClock

====
