#!/bin/bash
export NO_TIMEOUT=true
export PATIENT_MODE=enabled  
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
export SKIP_ZENOH_NIF=0
export WALLABY_ENABLED=true
mix compile --warnings-as-errors --jobs 16 2>&1 | tee -a phase2_completion_check.log
