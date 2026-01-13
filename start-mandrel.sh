#!/bin/bash

# Mandrel Waterproof Process Starter
# Replaces SystemD service with bulletproof process management

cd "$(dirname "$0")" || exit 1

echo "🚀 Starting Mandrel MCP Server..."

# 1. Ensure directories exist
mkdir -p logs run

# 2. Clean stale lock files and PID files before startup
rm -f mcp-server/aidis.pid
rm -f logs/mandrel.pid
echo "🧹 Cleaned stale lock files"

# 3. Kill any existing Mandrel processes (insurance)
EXISTING=$(ps aux | grep -E "tsx.*src/main\.ts|tsx.*src/server\.ts" | grep -v grep | awk '{print $2}')
if [ -n "$EXISTING" ]; then
    echo "⚠️  Found existing Mandrel process, killing: $EXISTING"
    echo "$EXISTING" | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# 4. Start Mandrel MCP server with direct STDIO for MCP protocol
cd mcp-server || exit 1

echo "📦 Starting MCP server..."
npx tsx src/main.ts > ../logs/mandrel.log 2>&1 &
MANDREL_PID=$!

# Save PID for management
echo "$MANDREL_PID" > ../logs/mandrel.pid

# 5. Wait and verify startup
sleep 3

if ps -p "$MANDREL_PID" > /dev/null 2>&1; then
    echo "✅ Mandrel MCP Server started successfully (PID: $MANDREL_PID)"
    echo "📋 Logs: tail -f logs/mandrel.log"
    
    # Check for startup errors in log
    if grep -q "ERROR\|already running\|Failed" ../logs/mandrel.log 2>/dev/null; then
        echo "⚠️  Warnings found in startup logs:"
        grep "ERROR\|already running\|Failed" ../logs/mandrel.log | head -5
    fi
    
    # Check port registry for actual assigned port
    sleep 2
    if [ -f ../run/port-registry.json ]; then
        ACTUAL_PORT=$(grep -o '"port":[0-9]*' ../run/port-registry.json | head -1 | cut -d':' -f2)
        if [ -n "$ACTUAL_PORT" ]; then
            echo "🏥 Health: curl http://localhost:${ACTUAL_PORT}/healthz"
        else
            echo "🏥 Health: curl http://localhost:8080/healthz (fallback)"
        fi
    else
        echo "🏥 Health: curl http://localhost:8080/healthz (fallback)"
    fi
    
    echo "🛑 Stop: ./stop-mandrel.sh"
    echo "💀 Force kill: ./kill-mandrel.sh"
else
    echo "❌ Failed to start Mandrel"
    echo "📋 Check logs: tail logs/mandrel.log"
    tail -20 ../logs/mandrel.log
    rm -f ../logs/mandrel.pid
    exit 1
fi
