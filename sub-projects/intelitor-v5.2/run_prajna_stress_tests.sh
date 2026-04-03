#!/usr/bin/env bash
set -euo pipefail

# Run Prajna stress tests and save output
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_ENV=test \
mix test test/indrajaal/cockpit/prajna/stress_test.exs --max-failures 5 2>&1 | tee prajna_stress_test_output.txt
