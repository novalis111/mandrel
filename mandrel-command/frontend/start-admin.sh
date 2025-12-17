#!/bin/bash

# Start Mandrel Command Admin UI on ports 3001 (frontend) + 3002 (backend)
# Opens browser to the correct URL

set -e

cd "$(dirname "$0")"

echo "🚀 Starting Mandrel Command Admin UI..."
echo "  Frontend: http://localhost:3001"
echo "  Backend:  http://localhost:3002"
echo ""

# Kill any existing processes on these ports
echo "🧹 Cleaning up existing processes..."
lsof -ti :3001 2>/dev/null | xargs kill -9 2>/dev/null || true
lsof -ti :3002 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 1

# Start backend in background
echo "🔧 Starting backend on port 3002..."
cd backend
PORT=3002 npm run dev > /tmp/mandrel-backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# Wait for backend to be ready
echo "⏳ Waiting for backend to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:3002/health > /dev/null 2>&1; then
    echo "✅ Backend is ready!"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ Backend failed to start"
    kill $BACKEND_PID 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# Start frontend
echo "🌐 Starting frontend on port 3001..."
BROWSER=chrome PORT=3001 npm start &
FRONTEND_PID=$!

# Wait a moment for frontend to start
sleep 3

# Open browser if not already opening
if ! pgrep -f "google-chrome\|chromium" > /dev/null 2>&1; then
  echo "🌍 Opening browser..."
  xdg-open http://localhost:3001 2>/dev/null || open http://localhost:3001 2>/dev/null || true
fi

echo ""
echo "✅ Admin UI is running:"
echo "   🌐 Frontend: http://localhost:3001"
echo "   🔧 Backend:  http://localhost:3002"
echo ""
echo "📋 Logs:"
echo "   Backend: tail -f /tmp/mandrel-backend.log"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Wait for frontend
wait $FRONTEND_PID
