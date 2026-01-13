#!/bin/bash

# Mandrel Waterproof Process Killer
# Force-kills all Mandrel-related processes and cleans up all locks

cd "$(dirname "$0")" || exit 1

echo "🧹 Force-killing all Mandrel processes and locks..."

# 1. Remove all lock files
rm -f mcp-server/aidis.pid
rm -f logs/mandrel.pid
echo "🔓 All lock files removed"

# 2. Kill all Mandrel MCP server processes
pkill -9 -f "tsx.*src/main\.ts" 2>/dev/null || true
pkill -9 -f "tsx.*src/server\.ts" 2>/dev/null || true
pkill -9 -f "node.*mcp-server" 2>/dev/null || true
echo "💀 MCP server processes killed"

# 3. Kill any other Mandrel-related processes
pkill -9 -f "mandrel" 2>/dev/null || true
pkill -9 -f "aidis" 2>/dev/null || true
echo "💀 Other Mandrel processes killed"

# 4. Free up common ports
for port in 8080 8081 8082 8083 8084; do
    if lsof -i ":$port" > /dev/null 2>&1; then
        PIDS=$(lsof -ti:"$port" 2>/dev/null)
        if [ -n "$PIDS" ]; then
            echo "🔧 Freeing port $port"
            echo "$PIDS" | xargs kill -9 2>/dev/null || true
        fi
    fi
done

echo "✅ All Mandrel processes and locks terminated"
