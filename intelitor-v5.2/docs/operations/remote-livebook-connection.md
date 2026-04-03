# Remote Livebook Connection Guide

## Overview

Connect a Livebook instance running on Windows to the Indrajaal application running on a remote Linux server.

## Server Details

| Setting | Value |
|---------|-------|
| Server IP | `192.168.11.139` |
| Hostname | `vm-1.tail55d152.ts.net` |
| Erlang Cookie | `FSUDYIQDVBBYFIBWOGVU` |
| EPMD Port | `4369` |

## Step 1: Start Indrajaal with Remote Access Enabled

On the Linux server, start the Indrajaal application with distribution enabled:

```bash
cd /home/an/dev/ver/indrajaal-v5.2

# Option A: Using IP address (recommended for LAN)
iex --name indrajaal@192.168.11.139 \
    --cookie FSUDYIQDVBBYFIBWOGVU \
    --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105" \
    -S mix phx.server

# Option B: Using hostname (if DNS resolves)
iex --name indrajaal@vm-1.tail55d152.ts.net \
    --cookie FSUDYIQDVBBYFIBWOGVU \
    --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105" \
    -S mix phx.server
```

## Step 2: Configure Linux Firewall

Allow incoming connections on required ports:

```bash
# EPMD port (required)
sudo ufw allow 4369/tcp

# Erlang distribution ports (node-to-node communication)
sudo ufw allow 9100:9105/tcp

# Or with iptables:
sudo iptables -A INPUT -p tcp --dport 4369 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9100:9105 -j ACCEPT
```

## Step 3: Configure Windows Livebook

### 3.1 Start Livebook with Distribution

On your Windows PC, start Livebook with these environment variables:

**PowerShell:**
```powershell
$env:LIVEBOOK_COOKIE = "FSUDYIQDVBBYFIBWOGVU"
$env:LIVEBOOK_DEFAULT_RUNTIME = "attached:indrajaal@192.168.11.139:FSUDYIQDVBBYFIBWOGVU"
livebook server
```

**Command Prompt:**
```cmd
set LIVEBOOK_COOKIE=FSUDYIQDVBBYFIBWOGVU
set LIVEBOOK_DEFAULT_RUNTIME=attached:indrajaal@192.168.11.139:FSUDYIQDVBBYFIBWOGVU
livebook server
```

### 3.2 Manual Connection via Livebook UI

If you prefer to connect manually through the Livebook UI:

1. Open Livebook in your browser
2. Create a new notebook or open existing
3. Click **Runtime settings** (⚙️ icon in sidebar)
4. Select **Attached node**
5. Enter connection details:
   - **Name**: `indrajaal@192.168.11.139`
   - **Cookie**: `FSUDYIQDVBBYFIBWOGVU`
6. Click **Connect**

## Step 4: Verify Connection

Once connected, run this in a Livebook cell to verify:

```elixir
# Check node connectivity
Node.self()
#=> :livebook_xxxx@your-windows-hostname

Node.list()
#=> [:indrajaal@192.168.11.139]

# Access Indrajaal modules
Indrajaal.AI.PricingCache.list_models() |> Enum.take(5)

# Check system status
:observer.start()  # Opens graphical observer
```

## Troubleshooting

### Connection Refused

1. **Check EPMD is running on server:**
   ```bash
   epmd -names
   # Should show: indrajaal at port XXXXX
   ```

2. **Check firewall allows traffic:**
   ```bash
   sudo ufw status
   # or
   sudo iptables -L -n | grep -E "4369|9100"
   ```

3. **Test connectivity from Windows:**
   ```powershell
   Test-NetConnection -ComputerName 192.168.11.139 -Port 4369
   ```

### Cookie Mismatch

Ensure both sides use the exact same cookie. Check case sensitivity.

### DNS Resolution Issues

If using hostname fails, switch to IP address:
- Change `indrajaal@vm-1.tail55d152.ts.net` to `indrajaal@192.168.11.139`

### Windows Firewall

Windows Firewall may block Erlang distribution. Add exceptions:
1. Open Windows Defender Firewall
2. Allow `erl.exe` and `werl.exe` through firewall
3. Or add port rules for 4369 and 9100-9105

## Quick Start Script (Linux Server)

Create this script on the server:

```bash
#!/bin/bash
# /home/an/dev/ver/indrajaal-v5.2/scripts/tools/start_remote_iex.sh

cd /home/an/dev/ver/indrajaal-v5.2

export RELEASE_NODE="indrajaal@192.168.11.139"
export RELEASE_COOKIE="FSUDYIQDVBBYFIBWOGVU"

# Set database connection
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_dev"

echo "Starting Indrajaal with remote access..."
echo "Node: $RELEASE_NODE"
echo "Cookie: $RELEASE_COOKIE"
echo ""
echo "Connect from Windows Livebook:"
echo "  Node: indrajaal@192.168.11.139"
echo "  Cookie: FSUDYIQDVBBYFIBWOGVU"

iex --name indrajaal@192.168.11.139 \
    --cookie FSUDYIQDVBBYFIBWOGVU \
    --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105" \
    -S mix phx.server
```

## Example Livebook Cells

### Cell 1: Verify Connection
```elixir
IO.puts("Connected to: #{Node.self()}")
IO.puts("Peers: #{inspect(Node.list())}")
```

### Cell 2: Test AI Pricing Cache
```elixir
alias Indrajaal.AI.PricingCache

# List available models
models = PricingCache.list_models()
IO.puts("Cached models: #{length(models)}")

# Get pricing for Claude
case PricingCache.get_pricing("anthropic/claude-3.5-sonnet") do
  {:ok, pricing} ->
    IO.puts("Claude 3.5 Sonnet pricing:")
    IO.puts("  Input: $#{pricing.input}/1M tokens")
    IO.puts("  Output: $#{pricing.output}/1M tokens")
  {:error, :not_found} ->
    IO.puts("Model not in cache, refreshing...")
    PricingCache.refresh()
end
```

### Cell 3: Run AI Demo
```elixir
alias Indrajaal.AI.OpenRouterClient

messages = [%{role: "user", content: "Hello from Windows Livebook!"}]
{:ok, response} = OpenRouterClient.chat(messages, model: "meta-llama/llama-3.3-70b-instruct:free")
IO.puts(response)
```

## Security Notes

- The Erlang cookie acts as a shared secret - keep it confidential
- Consider using Tailscale for secure mesh networking instead of exposing ports
- In production, use TLS for Erlang distribution
