#!/bin/bash
exec 2>&1

# Change to the webvirtcloud directory
cd /srv/webvirtcloud

# Activate virtual environment
. venv/bin/activate

# Function to cleanup any existing novncd processes
cleanup_novncd_processes() {
    echo "Cleaning up any existing novncd processes..."
    
    # Find and kill only novncd processes
    local pids=$(pgrep -f "console/novncd" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "Found existing novncd processes: $pids"
        kill -TERM $pids 2>/dev/null
        sleep 3
        
        # Force kill if still running
        local remaining=$(pgrep -f "console/novncd" 2>/dev/null)
        if [ -n "$remaining" ]; then
            echo "Force killing remaining novncd processes: $remaining"
            kill -KILL $remaining 2>/dev/null || true
            sleep 2
        fi
    else
        echo "No existing novncd processes found"
    fi
}

# Function to wait for port to be free
wait_for_novnc_port_free() {
    local port=$1
    local max_wait=30
    local wait_time=0
    
    echo "Waiting for noVNC port $port to be free..."
    while netstat -tln | grep -q ":$port " && [ $wait_time -lt $max_wait ]; do
        echo "Port $port still in use, waiting..."
        local pid=$(lsof -ti:$port 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            echo "Killing process $pid using port $port"
            kill -TERM $pid 2>/dev/null || true
            sleep 2
        fi
        sleep 1
        wait_time=$((wait_time + 3))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        echo "Warning: Port $port still in use after ${max_wait}s"
        return 1
    else
        echo "Port $port is now free"
        return 0
    fi
}

# Get WebSocket port from settings
WS_PORT=${WS_PORT:-6080}

echo "Starting NoVNC daemon setup for port ${WS_PORT}..."

# Clean up any existing novncd processes
cleanup_novncd_processes

# Wait for port to be free
wait_for_novnc_port_free ${WS_PORT}

echo "Starting NoVNC daemon on port ${WS_PORT}..."
exec chpst -u www-data:www-data python3 /srv/webvirtcloud/console/novncd --host=0.0.0.0 --port=${WS_PORT}
