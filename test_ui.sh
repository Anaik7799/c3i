#!/bin/bash
URL="http://vm-1.tail55d152.ts.net:4100"
PAGES=("/" "/dashboard" "/planning" "/immune" "/knowledge" "/zenoh" "/cockpit" "/verification" "/substrate" "/metabolic" "/podman" "/mcp" "/kms" "/telemetry" "/integrity" "/evolution" "/biomorphic" "/homeostasis" "/bicameral" "/singularity")
APIS=("/api/v1/pages" "/api/v1/dashboard" "/api/v1/planning" "/api/v1/immune" "/api/v1/knowledge" "/api/v1/zenoh" "/api/v1/verification" "/api/cockpit/nodes" "/api/v1/substrate" "/api/v1/metabolic" "/api/v1/podman" "/api/v1/mcp" "/api/v1/kms" "/api/v1/telemetry" "/api/v1/integrity" "/api/v1/evolution" "/api/v1/biomorphic" "/api/v1/homeostasis" "/api/v1/bicameral" "/api/v1/singularity" "/api/v1/guardian/pending" "/ag-ui/health" "/ag-ui/state")

echo "--- Testing HTML Pages ---"
for PAGE in "${PAGES[@]}"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL$PAGE")
    if [ "$STATUS" -eq 200 ]; then
        echo "✅ $PAGE : $STATUS"
    else
        echo "❌ $PAGE : $STATUS"
    fi
done

echo "--- Testing JSON APIs ---"
for API in "${APIS[@]}"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL$API")
    CONTENT_TYPE=$(curl -sI "$URL$API" | grep -i "content-type" | awk '{print $2}' | tr -d '\r')
    if [ "$STATUS" -eq 200 ]; then
        echo "✅ $API : $STATUS ($CONTENT_TYPE)"
    else
        echo "❌ $API : $STATUS"
    fi
done
