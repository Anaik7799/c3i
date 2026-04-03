#!/bin/bash

# 🔍 Indrajaal Demo Status Check
# Comprehensive validation of demo environment

echo "🔍 Indrajaal Demo Environment Status Check"
echo "=========================================="
echo ""

# Check container status
echo "📦 Container Status:"
echo "-------------------"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10

echo ""
echo "🌐 Service Connectivity:"
echo "------------------------"

# Check database
if pg_isready -h localhost -p 5433 -U postgres -d indrajaal_demo >/dev/null 2>&1; then
    echo "✅ PostgreSQL Database: Connected (localhost:5433)"
else
    echo "❌ PostgreSQL Database: Not accessible (localhost:5433)"
fi

# Check Redis
if redis-cli -p 6379 ping >/dev/null 2>&1; then
    echo "✅ Redis Cache: Connected (localhost:6379)"
else
    echo "❌ Redis Cache: Not accessible (localhost:6379)"
fi

# Check Phoenix
if curl -f http://localhost:4000/health --max-time 5 >/dev/null 2>&1; then
    echo "✅ Phoenix Application: Running (http://localhost:4000)"
else
    echo "❌ Phoenix Application: Not running (http://localhost:4000)"
fi

# Check Prometheus
if curl -f http://localhost:9090/-/healthy --max-time 5 >/dev/null 2>&1; then
    echo "✅ Prometheus: Running (http://localhost:9090)"
else
    echo "❌ Prometheus: Not running (http://localhost:9090)"
fi

# Check Grafana
if curl -f http://localhost:3000/api/health --max-time 5 >/dev/null 2>&1; then
    echo "✅ Grafana: Running (http://localhost:3000)"
else
    echo "❌ Grafana: Not running (http://localhost:3000)"
fi

echo ""
echo "📊 System Resources:"
echo "-------------------"
echo "🖥️  CPU Usage: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//')"
echo "💾 Memory Usage: $(free -h | awk '/^Mem:/ {printf "%.1fG/%.1fG (%.0f%%)\n", $3/1024/1024/1024, $2/1024/1024/1024, $3*100/$2}')"
echo "💿 Disk Usage: $(df -h . | awk 'NR==2 {printf "%s/%s (%s)\n", $3, $2, $5}')"

echo ""
echo "🔗 Demo Access URLs:"
echo "-------------------"
echo "🚀 Main Application:     http://localhost:4000"
echo "📊 Prometheus Metrics:   http://localhost:9090"
echo "📈 Grafana Dashboards:   http://localhost:3000"
echo "   └─ Login: admin / demo_admin_password"
echo ""

# Check data directories
echo "📁 Data Directory Status:"
echo "-------------------------"
for dir in data/postgres data/redis data/tmp data/grafana data/prometheus; do
    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
        echo "✅ $dir: $size"
    else
        echo "❌ $dir: Missing"
    fi
done

echo ""
echo "🎯 Demo Readiness Assessment:"
echo "=============================="

# Count running services
running_count=0
total_count=5

pg_isready -h localhost -p 5433 -U postgres -d indrajaal_demo >/dev/null 2>&1 && ((running_count++))
redis-cli -p 6379 ping >/dev/null 2>&1 && ((running_count++))
curl -f http://localhost:4000/health --max-time 5 >/dev/null 2>&1 && ((running_count++))
curl -f http://localhost:9090/-/healthy --max-time 5 >/dev/null 2>&1 && ((running_count++))
curl -f http://localhost:3000/api/health --max-time 5 >/dev/null 2>&1 && ((running_count++))

percentage=$((running_count * 100 / total_count))

if [ $percentage -ge 80 ]; then
    echo "🟢 DEMO READY: $running_count/$total_count services running ($percentage%)"
    echo "   ✅ Demo environment is ready for testing"
elif [ $percentage -ge 40 ]; then
    echo "🟡 PARTIAL: $running_count/$total_count services running ($percentage%)"
    echo "   ⚠️  Some services need attention"
else
    echo "🔴 NOT READY: $running_count/$total_count services running ($percentage%)"
    echo "   ❌ Demo environment needs setup"
fi

echo ""
echo "📋 Quick Actions:"
echo "----------------"
echo "• Start containers:  ./start_demo_containers.sh"
echo "• View logs:         podman logs <container-name>"
echo "• Stop all:          podman stop \$(podman ps -q)"
echo "• Clean up:          podman system prune"