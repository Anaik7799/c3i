# Robustness Gate

- score: **90**
- grade: **A**
- ts_nanos: `1777300027204810189`

## Checks
- saplan_ok: yes
- kms_ok: yes
- db_integrity_ok: yes
- foreign_keys_ok: yes
- wal_ok: yes
- zenoh_ok: yes
- fastembed_ok: yes
- utility_urls_ok: yes

## Alarms
- EMBED_LOW

## RETE-lite actions
- run scripts/pass8/p8_04_embed_backfill (MAX=2000)

## FMEA Top Risks
| mode | S | O | D | RPN | note |
|---|---:|---:|---:|---:|---|
| embedding coverage low | 7 | 7 | 6 | 294 | coverage below 50% |
| cost per session high | 8 | 2 | 6 | 96 | cost/session above $5 |
| wal disabled | 7 | 1 | 5 | 35 | journal_mode not wal |
| foreign key drift | 8 | 1 | 4 | 32 | foreign_key_check rows > 0 |
| customer path fail | 8 | 1 | 4 | 32 | one or more /c3i URLs failed |
| kms health fail | 10 | 1 | 3 | 30 | smriti pool unhealthy |
