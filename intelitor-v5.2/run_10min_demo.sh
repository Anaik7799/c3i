#!/usr/bin/env bash
dotnet fsi sa-mesh.fsx listen &
LISTENER_PID=$!
sleep 5
elixir scripts/demo/continuous_enterprise_demo_executor.exs --limit 20
kill $LISTENER_PID
