#!/bin/bash
cd /home/an/dev/ver/c3i
export SIMULATOR_TELEGRAM_URL=http://localhost:8081/botmock
export SIMULATOR_GCHAT_URL=http://localhost:8082

echo "Starting simulators..."
python3 scripts/tests/telegram_simulator.py > scripts/tests/telegram.log 2>&1 &
PID_TEL=$!
python3 scripts/tests/gchat_simulator.py > scripts/tests/gchat.log 2>&1 &
PID_GCH=$!

echo "Starting sa-plan-daemon..."
cd sub-projects/c3i
cargo run --bin sa-plan-daemon -- daemon > ../../scripts/tests/planning.log 2>&1 &
PID_PLAN=$!

echo "Waiting for daemon to boot..."
sleep 5

echo "Running integration test..."
cd ../../
python3 scripts/tests/integration_test.py
TEST_EXIT=$?

echo "Cleaning up..."
kill $PID_PLAN $PID_GCH $PID_TEL
exit $TEST_EXIT
