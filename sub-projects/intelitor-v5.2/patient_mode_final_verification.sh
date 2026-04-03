#!/bin/bash
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16"
mix compile --verbose 2>&1 | tee -a final_mainline_compilation_verification.log