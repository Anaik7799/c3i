#!/bin/bash
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+fnu +S 16"
mix compile --verbose 2>&1 | tee -a final_patient_mode_verification.log