#!/bin/bash
exec 2>&1

# Change to the webvirtcloud directory
cd /srv/webvirtcloud

# Activate virtual environment
. venv/bin/activate

# Function to check if port is in use
check_port() {
    local port=$1
    netstat -tuln 2>/dev/null | grep -q ":${port} " && return 0 || return 1
}

# Function to kill processes using the port
cleanup_port() {
    local port=$1
    echo "Cleaning up processes using port ${port}..."
    
    # Find and kill processes using the port
    local pids=$(lsof -ti:${port} 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "Killing processes: $pids"
        kill -TERM $pids 2>/dev/null
        sleep 2
        # Force kill if still running
        kill -KILL $pids 2>/dev/null || true
    fi
}

# Function to wait for port to be free
wait_for_port_free() {
    local port=$1
    local max_wait=30
    local count=0
    
    while check_port $port; do
        if [ $count -ge $max_wait ]; then
            echo "Timeout waiting for port ${port} to be free"
            return 1
        fi
        echo "Port ${port} still in use, waiting... (${count}/${max_wait})"
        sleep 1
        count=$((count + 1))
    done
    return 0
}

# Get WebSocket port from settings
WS_PORT=${WS_PORT:-6080}

echo "Starting NoVNC daemon on port ${WS_PORT}..."

# Check if port is already in use
if check_port $WS_PORT; then
    echo "Port ${WS_PORT} is already in use!"
    
    # Try to cleanup existing processes
    cleanup_port $WS_PORT
    
    # Wait for port to be free
    if ! wait_for_port_free $WS_PORT; then
        echo "Failed to free port ${WS_PORT}, exiting"
        exit 1
    fi
fi

# Ensure only one instance of novncd is running
pkill -f "console/novncd" 2>/dev/null || true
sleep 2

echo "Starting NoVNC daemon..."
exec chpst -u www-data:www-data python3 /srv/webvirtcloud/console/novncd --host=0.0.0.0 --port=${WS_PORT}
