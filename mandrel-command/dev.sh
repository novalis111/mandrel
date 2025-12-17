#!/bin/bash

# Mandrel Command Development Server Launcher
# Supports configurable Frontend (default 3000) and Backend (default 3001) ports

set -e

# Parse arguments for custom ports
FRONTEND_PORT=${FRONTEND_PORT:-3001}
BACKEND_PORT=${BACKEND_PORT:-3002}
SKIP_BANNER=${SKIP_BANNER:-false}

# Function to print banner
print_banner() {
  if [ "$SKIP_BANNER" != "true" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         Mandrel Command - Development Environment             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Frontend Port:  $FRONTEND_PORT  (http://localhost:$FRONTEND_PORT)"
    echo "Backend Port:   $BACKEND_PORT  (http://localhost:$BACKEND_PORT)"
    echo "Database:       localhost:5432 (aidis_production)"
    echo ""
    echo "Starting services..."
    echo ""
  fi
}

# Parse command line arguments
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
    --skip-banner)
      SKIP_BANNER="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo ""
      echo "Usage: ./dev.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --frontend-port PORT    Frontend port (default: 3001)"
      echo "  --backend-port PORT     Backend port (default: 3002)"
      echo "  --skip-banner           Don't print startup banner"
      echo ""
      exit 1
      ;;
  esac
done

print_banner

# Export ports for npm scripts
export FRONTEND_PORT
export BACKEND_PORT

# Start both services
npm run dev:full
