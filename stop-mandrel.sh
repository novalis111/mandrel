#!/bin/bash

# Mandrel Waterproof Process Stopper
# Gracefully stops Mandrel MCP server with comprehensive cleanup

cd "$(dirname "$0")" || exit 1

echo "🛑 Stopping Mandrel MCP Server..."

# 1. Clean up lock file first (allows fresh start)
if [ -f "mcp-server/aidis.pid" ]; then
    PID_FROM_LOCK=$(cat mcp-server/aidis.pid 2>/dev/null)
    rm -f mcp-server/aidis.pid
    echo "🔓 Lock file removed"
fi

# 2. Try graceful shutdown via PID file
if [ -f logs/mandrel.pid ]; then
    PID=$(cat logs/mandrel.pid)
    
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "🛑 Stopping Mandrel (PID: $PID)"
        kill "$PID" 2>/dev/null || true
        
        # Wait for graceful shutdown
        sleep 2
        
        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "⚡ Forcing shutdown..."
            kill -9 "$PID" 2>/dev/null || true
        fi
    else
        echo "⚠️  Process $PID not found (stale PID file)"
    fi
    
    rm -f logs/mandrel.pid
fi

# 3. Kill any orphaned Mandrel processes
ORPHANED=$(ps aux | grep -E "tsx.*src/main\.ts|tsx.*src/server\.ts" | grep -v grep | awk '{print $2}')
if [ -n "$ORPHANED" ]; then
    echo "🧹 Killing orphaned processes: $ORPHANED"
    echo "$ORPHANED" | xargs kill -9 2>/dev/null || true
fi

# 4. Free up ports
for port in 8080 8081 8082 8083 8084; do
    if lsof -i ":$port" > /dev/null 2>&1; then
        PID_ON_PORT=$(lsof -ti:"$port" 2>/dev/null)
        if [ -n "$PID_ON_PORT" ]; then
            echo "🔧 Freeing port $port (PID: $PID_ON_PORT)"
            kill -9 "$PID_ON_PORT" 2>/dev/null || true
        fi
    fi
done

echo "✅ Mandrel stopped and cleaned up"
