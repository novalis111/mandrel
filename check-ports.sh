#!/bin/bash

# Port Discovery and Health Check Utility
# Shows what's running on standard Mandrel ports

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FRONTEND_PORT=${FRONTEND_PORT:-3001}
BACKEND_PORT=${BACKEND_PORT:-3002}
MCP_PORT=${MCP_PORT:-8080}
BRIDGE_PORT=${BRIDGE_PORT:-8081}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Mandrel Services - Port Status & Health Check         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_port() {
  local port=$1
  local name=$2
  local url=$3
  
  if lsof -i :$port > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Port $port ($name)"
    
    if [ -n "$url" ]; then
      if timeout 2 curl -s "$url" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Responding${NC}: $url"
      else
        echo -e "  ${YELLOW}⚠ Not responding${NC}: $url"
      fi
    fi
  else
    echo -e "${RED}✗${NC} Port $port ($name) - ${RED}NOT RUNNING${NC}"
  fi
  echo ""
}

echo -e "${YELLOW}Services:${NC}"
check_port $FRONTEND_PORT "Frontend (React)" "http://localhost:$FRONTEND_PORT"
check_port $BACKEND_PORT "Backend (API)" "http://localhost:$BACKEND_PORT/api/health"
check_port $MCP_PORT "MCP Server" "http://localhost:$MCP_PORT/mcp/tools/mandrel_ping"
check_port $BRIDGE_PORT "HTTP Bridge" "http://localhost:$BRIDGE_PORT/health"

echo -e "${YELLOW}Connected Services (if running):${NC}"

# Check database connection
echo -e "${BLUE}Database:${NC}"
if psql -d aidis_production -c "SELECT 'Connected' as status;" 2>/dev/null | grep -q "Connected"; then
  echo -e "  ${GREEN}✓ PostgreSQL (localhost:5432)${NC}"
  echo -e "    Database: aidis_production"
else
  echo -e "  ${RED}✗ PostgreSQL${NC} - Not accessible or not running"
fi
echo ""

echo -e "${YELLOW}Configuration:${NC}"
echo "  Frontend Port:   $FRONTEND_PORT"
echo "  Backend Port:    $BACKEND_PORT"
echo "  MCP Server:      $MCP_PORT"
echo "  HTTP Bridge:     $BRIDGE_PORT"
echo ""

echo -e "${YELLOW}Usage:${NC}"
echo "  FRONTEND_PORT=4000 BACKEND_PORT=4001 ./check-ports.sh"
echo ""

echo -e "${YELLOW}Start Services:${NC}"
echo "  ./start-full-stack.sh                              # Default ports"
echo "  ./start-full-stack.sh --frontend-port 4000 --backend-port 4001"
echo ""
