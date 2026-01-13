#!/bin/bash

# Mandrel Full Stack Startup Script
# Ensures clean startup of both MCP server and Command interface
# Supports configurable Frontend (default 3000) and Backend (default 3001) ports
#
# CODE CHANGES:
# - Frontend (React): Hot reload via react-scripts, changes appear instantly
# - Backend (Node/Express): Hot reload via nodemon, restarts on file save
# - Run this script to do a clean full restart if needed
#
# USAGE:
#   ./start-full-stack.sh                              # Use ports from .env.development
#   ./start-full-stack.sh --frontend-port 4000 --backend-port 4001  # Custom ports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Port Configuration - load from .env.development or use defaults
# Try to load from .env.development first, then fall back to defaults
if [ -f "mandrel-command/.env.development" ]; then
    FRONTEND_PORT=$(grep "^FRONTEND_PORT=" mandrel-command/.env.development | cut -d'=' -f2)
    BACKEND_PORT=$(grep "^BACKEND_PORT=" mandrel-command/.env.development | cut -d'=' -f2)
    echo -e "${BLUE}📄 Loaded ports from .env.development${NC}"
fi

# Use defaults if not set
FRONTEND_PORT=${FRONTEND_PORT:-3000}
BACKEND_PORT=${BACKEND_PORT:-3001}

# Parse command line arguments for ports
while [[ $# -gt 0 ]]; do
  case $1 in
    --frontend-port)
      FRONTEND_PORT="$2"
      shift 2
      ;;
    --backend-port)
      BACKEND_PORT="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting AIDIS Full Stack...${NC}"

# Step 1: Clean shutdown of any existing processes
echo -e "${YELLOW}🧹 Cleaning up existing processes...${NC}"

# 1. Remove lock files first (allows fresh start)
echo -e "${YELLOW}   Removing lock files...${NC}"
rm -f mcp-server/aidis.pid logs/mandrel.pid
echo -e "${YELLOW}   ✓ Lock files cleaned${NC}"

# 2. Kill by PID files (most reliable)
echo -e "${YELLOW}   Stopping by PID files...${NC}"
if [ -f "./run/mandrel-command.pid" ]; then
    PID=$(cat ./run/mandrel-command.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "${YELLOW}   Killing mandrel-command (PID: $PID)...${NC}"
        kill -9 "$PID" 2>/dev/null || true
    fi
    rm -f ./run/mandrel-command.pid
fi

if [ -f "./run/mandrel-mcp.pid" ]; then
    PID=$(cat ./run/mandrel-mcp.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "${YELLOW}   Killing mandrel-mcp (PID: $PID)...${NC}"
        kill -9 "$PID" 2>/dev/null || true
    fi
    rm -f ./run/mandrel-mcp.pid
fi

# 3. Kill only Mandrel-specific processes (safer approach)
echo -e "${YELLOW}   Killing Mandrel-specific processes...${NC}"
pkill -9 -f "tsx.*src/main\.ts" 2>/dev/null || true
pkill -9 -f "tsx.*src/server\.ts" 2>/dev/null || true
pkill -9 -f "mandrel-command.*npm.*dev" 2>/dev/null || true
pkill -9 -f "cd mandrel-command" 2>/dev/null || true

# 4. Free up common ports
echo -e "${YELLOW}   Freeing ports...${NC}"
for port in 8080 8081 3000 3001 3002; do
    if lsof -i ":$port" > /dev/null 2>&1; then
        PIDS=$(lsof -ti:"$port" 2>/dev/null)
        if [ -n "$PIDS" ]; then
            echo "$PIDS" | xargs kill -9 2>/dev/null || true
        fi
    fi
done

# 5. Wait for processes to fully terminate
echo -e "${YELLOW}   Waiting for processes to terminate...${NC}"
sleep 2

echo -e "${GREEN}   ✓ Mandrel processes cleaned${NC}"

# Step 2: Start Mandrel MCP Server (core system)
echo -e "${GREEN}🔧 Starting Mandrel MCP Server...${NC}"
./start-mandrel.sh

# Wait for MCP server to be ready
echo -e "${YELLOW}⏳ Waiting for MCP server to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ MCP Server is ready!${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ MCP Server failed to start${NC}"
        exit 1
    fi
done

# Step 3: Start AIDIS Command (admin interface)
echo -e "${GREEN}🎛️  Starting AIDIS Command Interface...${NC}"
cd mandrel-command

# Start in background and capture PID with port configuration
nohup env FRONTEND_PORT=$FRONTEND_PORT BACKEND_PORT=$BACKEND_PORT npm run dev:full > ../logs/mandrel-command.log 2>&1 &
COMMAND_PID=$!
echo $COMMAND_PID > ../run/mandrel-command.pid

echo -e "${GREEN}✅ Mandrel Command started (PID: $COMMAND_PID)${NC}"
echo -e "${YELLOW}   Frontend: http://localhost:$FRONTEND_PORT${NC}"
echo -e "${YELLOW}   Backend:  http://localhost:$BACKEND_PORT${NC}"

# Step 4: Wait for Command interface to be ready
echo -e "${YELLOW}⏳ Waiting for Command interface...${NC}"
for i in {1..60}; do
    if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Command interface is ready!${NC}"
        break
    fi
    sleep 1
done

# Step 5: Display status
echo ""
echo -e "${BLUE}🎯 Mandrel Full Stack Status:${NC}"
echo -e "   ${GREEN}🔧 MCP Server:${NC}           http://localhost:8080/health"
echo -e "   ${GREEN}🎛️  Command Backend API:${NC}  http://localhost:$BACKEND_PORT/api/health"
echo -e "   ${GREEN}🌐 Command Frontend:${NC}     http://localhost:$FRONTEND_PORT"
echo ""
echo -e "${YELLOW}📋 Logs:${NC}"
echo -e "   MCP Server:    tail -f logs/mandrel.log"
echo -e "   Command UI:    tail -f logs/mandrel-command.log"
echo ""
echo -e "${YELLOW}🛑 Stop Everything:${NC} ./stop-full-stack.sh"
echo ""
echo -e "${GREEN}✅ Mandrel Full Stack is running!${NC}"
echo -e "${YELLOW}   Access at: http://localhost:$FRONTEND_PORT${NC}"
echo ""