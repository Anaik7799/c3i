#!/bin/bash
# Verify SigNoz deployment health
# Usage: ./verify-deployment.sh

echo "🔍 SigNoz Deployment Verification"
echo "════════════════════════════════════════════════════════════════"
echo ""

FAILED=0
PASSED=0

# Check container status
check_container() {
    local name=$1
    echo -n "Checking $name... "
    if podman ps --filter "name=$name" --filter "status=running" | grep -q "$name"; then
        echo "✅ Running"
        ((PASSED++))
        return 0
    else
        echo "❌ Not running"
        ((FAILED++))
        return 1
    fi
}

# Check endpoint health
check_endpoint() {
    local name=$1
    local url=$2
    echo -n "Checking $name endpoint... "
    if curl -sf "$url" > /dev/null 2>&1; then
        echo "✅ Accessible"
        ((PASSED++))
        return 0
    else
        echo "❌ Not accessible"
        ((FAILED++))
        return 1
    fi
}

# Container checks
echo "Container Status:"
check_container "signoz-clickhouse"
check_container "signoz-otel-collector"
check_container "signoz-query-service"
check_container "signoz-frontend"
echo ""

# Endpoint checks
echo "Endpoint Health:"
check_endpoint "OTLP HTTP" "http://localhost:4318"
check_endpoint "Health Check" "http://localhost:13133"
check_endpoint "Metrics" "http://localhost:8888/metrics"
check_endpoint "Frontend" "http://localhost:3301"
check_endpoint "Query Service" "http://localhost:8081"
echo ""

# Network check
echo "Network Status:"
echo -n "Checking signoz-network... "
if podman network inspect signoz-network > /dev/null 2>&1; then
    echo "✅ Exists"
    ((PASSED++))
else
    echo "❌ Not found"
    ((FAILED++))
fi
echo ""

# Database check
echo "Database Status:"
echo -n "Checking ClickHouse database... "
if podman exec signoz-clickhouse clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
    echo "✅ Accessible"
    ((PASSED++))
else
    echo "❌ Not accessible"
    ((FAILED++))
fi

echo -n "Checking signoz database... "
if podman exec signoz-clickhouse clickhouse-client --query "SHOW DATABASES" | grep -q "signoz"; then
    echo "✅ Exists"
    ((PASSED++))
else
    echo "❌ Not found"
    ((FAILED++))
fi

echo -n "Checking tables... "
TABLE_COUNT=$(podman exec signoz-clickhouse clickhouse-client --query "SHOW TABLES FROM signoz" | wc -l)
if [ "$TABLE_COUNT" -ge 3 ]; then
    echo "✅ $TABLE_COUNT tables found"
    ((PASSED++))
else
    echo "❌ Only $TABLE_COUNT tables found (expected 3+)"
    ((FAILED++))
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "Summary:"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 All checks passed! Deployment is healthy."
    exit 0
else
    echo "⚠️  Some checks failed. See above for details."
    exit 1
fi
