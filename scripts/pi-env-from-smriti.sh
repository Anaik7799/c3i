#!/usr/bin/env bash
# Pi-mono .env generator from Smriti.db (SC-PI-003, SC-XHOLON-001)
# Reads all keys from the central Smriti authority and writes Pi's .env
set -euo pipefail

SMRITI_DB="/home/an/dev/ver/c3i/data/smriti/Smriti.db"
PI_ENV="/home/an/dev/ver/c3i/sub-projects/pi-mono/.env"

get_pref() {
    sqlite3 "$SMRITI_DB" "SELECT value FROM UserPreferences WHERE key='$1';" 2>/dev/null || echo ""
}

echo "# Pi-mono Environment Configuration" > "$PI_ENV"
echo "# Auto-generated from Smriti.db on $(date -Iseconds)" >> "$PI_ENV"
echo "# Regenerate: ./scripts/pi-env-from-smriti.sh" >> "$PI_ENV"
echo "" >> "$PI_ENV"

# LLM Keys
ANTHROPIC=$(get_pref anthropic_api_key)
OPENROUTER=$(get_pref openrouter_api_key)
HF=$(get_pref hf_token)
GITHUB=$(get_pref github_token)
FIRECRAWL=$(get_pref firecrawl_api_key)
TELEGRAM_TOKEN=$(get_pref telegram_token)
TELEGRAM_CHAT=$(get_pref telegram_chat_id)

[ -n "$ANTHROPIC" ] && echo "ANTHROPIC_API_KEY=$ANTHROPIC" >> "$PI_ENV"
[ -n "$OPENROUTER" ] && echo "OPENROUTER_API_KEY=$OPENROUTER" >> "$PI_ENV"
[ -n "$HF" ] && echo "HF_TOKEN=$HF" >> "$PI_ENV"
[ -n "$GITHUB" ] && echo "GITHUB_TOKEN=$GITHUB" >> "$PI_ENV"
[ -n "$FIRECRAWL" ] && echo "FIRECRAWL_API_KEY=$FIRECRAWL" >> "$PI_ENV"

# Google ADC
ADC="$HOME/.config/gcloud/application_default_credentials.json"
[ -f "$ADC" ] && echo "GOOGLE_APPLICATION_CREDENTIALS=$ADC" >> "$PI_ENV"

# Ollama
echo "OLLAMA_HOST=http://localhost:11434" >> "$PI_ENV"

# C3I Integration
echo "ZENOH_ROUTER_ENDPOINT=tcp/localhost:7447" >> "$PI_ENV"
echo "SMRITI_DB_PATH=$SMRITI_DB" >> "$PI_ENV"

# Telegram
[ -n "$TELEGRAM_TOKEN" ] && echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN" >> "$PI_ENV"
[ -n "$TELEGRAM_CHAT" ] && echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT" >> "$PI_ENV"

# Pi config
echo "PI_CODING_AGENT=true" >> "$PI_ENV"
echo "PI_OFFLINE=0" >> "$PI_ENV"

echo "✅ Pi .env written to $PI_ENV ($(wc -l < "$PI_ENV") lines)"
echo "   ANTHROPIC=$([ -n "$ANTHROPIC" ] && echo '✓' || echo '✗') OPENROUTER=$([ -n "$OPENROUTER" ] && echo '✓' || echo '✗') HF=$([ -n "$HF" ] && echo '✓' || echo '✗') GITHUB=$([ -n "$GITHUB" ] && echo '✓' || echo '✗') GOOGLE_ADC=$([ -f "$ADC" ] && echo '✓' || echo '✗') FIRECRAWL=$([ -n "$FIRECRAWL" ] && echo '✓' || echo '✗')"
