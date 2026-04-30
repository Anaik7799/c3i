# Robustness Gate

- score: **60**
- grade: **C**
- ts_nanos: `1777556341341913749`

## Checks
- saplan_ok: yes
- kms_ok: yes
- db_integrity_ok: no
- foreign_keys_ok: yes
- wal_ok: yes
- zenoh_ok: yes
- fastembed_ok: yes
- utility_urls_ok: yes

## Alarms
- EMBED_LOW
- DB_INTEGRITY_FAIL

## RETE-lite actions
- freeze writes, backup smriti.db, run integrity remediation
- run scripts/pass8/p8_04_embed_backfill (MAX=2000)

## FMEA Top Risks
| mode | S | O | D | RPN | note |
|---|---:|---:|---:|---:|---|
| embedding coverage low | 7 | 7 | 6 | 294 | coverage below 50% |
| db integrity failure | 10 | 8 | 2 | 160 | integrity_check != ok |
| cost per session high | 8 | 2 | 6 | 96 | cost/session above $5 |
| wal disabled | 7 | 1 | 5 | 35 | journal_mode not wal |
| foreign key drift | 8 | 1 | 4 | 32 | foreign_key_check rows > 0 |
| customer path fail | 8 | 1 | 4 | 32 | one or more /c3i URLs failed |
