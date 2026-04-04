#!/usr/bin/env bash
# Simulates the MCP tool pulling Zenoh messages for the Gemini Agent
echo '{"jsonrpc": "2.0", "result": {"trace_id": "a1b2c3d4-1234-5678", "span_id": "87654321", "name": "SystemState_Poll", "ooda_phase": "Observe", "attributes": {"active_containers": "16", "cpu_pressure": "42"}}}'
echo '{"jsonrpc": "2.0", "result": {"trace_id": "a1b2c3d4-8888-9999", "span_id": "11223344", "name": "Control_Start", "ooda_phase": "Act", "attributes": {"target": "indrajaal-ex-app-1"}}}'
