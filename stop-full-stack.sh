#!/bin/bash

# Mandrel Full Stack Shutdown Script
# Gracefully stops both MCP server and Command interface

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛑 Stopping Mandrel Full Stack...${NC}"

# Step 1: Stop Command Interface
echo -e "${YELLOW}🎛️  Stopping Command Interface...${NC}"
if [ -f "run/mandrel-command.pid" ]; then
    COMMAND_PID=$(cat run/mandrel-command.pid)
    if ps -p "$COMMAND_PID" > /dev/null 2>&1; then
        echo -e "   Stopping (PID: $COMMAND_PID)..."
        kill -TERM "$COMMAND_PID" 2>/dev/null || true
        
        # Wait for graceful shutdown
        for i in {1..10}; do
            if ! ps -p "$COMMAND_PID" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if ps -p "$COMMAND_PID" > /dev/null 2>&1; then
            echo -e "   Force stopping..."
            kill -9 "$COMMAND_PID" 2>/dev/null || true
        fi
    fi
    rm -f "run/mandrel-command.pid"
fi

# Kill remaining Command UI processes
pkill -9 -f "mandrel-command.*npm.*dev" 2>/dev/null || true
pkill -9 -f "nodemon" 2>/dev/null || true
pkill -9 -f "concurrently" 2>/dev/null || true

echo -e "${GREEN}✅ Command Interface stopped${NC}"

# Step 2: Stop MCP Server (uses the waterproof stop script)
echo -e "${YELLOW}🔧 Stopping MCP Server...${NC}"
./stop-mandrel.sh

echo -e "${GREEN}✅ Mandrel Full Stack stopped successfully${NC}"
