#!/bin/bash

# AIDIS Full Stack Startup Script
# Ensures clean startup of both MCP server and Command interface
# Supports configurable Frontend (default 3000) and Backend (default 3001) ports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Port Configuration (can be overridden via environment or arguments)
FRONTEND_PORT=${FRONTEND_PORT:-3001}
BACKEND_PORT=${BACKEND_PORT:-3002}

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
if [ -f "./kill-all-aidis.sh" ]; then
    ./kill-all-aidis.sh
    sleep 2
else
    echo "⚠️  kill-all-aidis.sh not found, manual cleanup..."
    pkill -f "aidis" 2>/dev/null || true
    pkill -f "tsx.*server" 2>/dev/null || true
    pkill -f "nodemon" 2>/dev/null || true
    pkill -f "ts-node" 2>/dev/null || true
    sleep 2
fi

# Step 2: Start AIDIS MCP Server (core system)
echo -e "${GREEN}🔧 Starting AIDIS MCP Server...${NC}"
./start-aidis.sh

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