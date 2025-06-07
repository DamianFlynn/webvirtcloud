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

# Function to check if our novncd process is running
check_novncd_running() {
    pgrep -f "console/novncd" >/dev/null 2>&1
}

# Function to kill only novncd processes
cleanup_novncd_processes() {
    local port=$1
    echo "Looking for existing novncd processes..."
    
    # Find and kill only novncd processes
    local pids=$(pgrep -f "console/novncd" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo "Found novncd processes: $pids"
        kill -TERM $pids 2>/dev/null
        sleep 3
        
        # Force kill if still running
        local remaining=$(pgrep -f "console/novncd" 2>/dev/null)
        if [ -n "$remaining" ]; then
            echo "Force killing remaining novncd processes: $remaining"
            kill -KILL $remaining 2>/dev/null || true
        fi
    else
        echo "No existing novncd processes found"
    fi
    
    # If port is still in use by something else, try to identify what
    if check_port $port; then
        echo "Port ${port} still in use after novncd cleanup. Checking what's using it..."
        lsof -ti:${port} 2>/dev/null | while read pid; do
            echo "Process $pid is using port ${port}:"
            ps -p $pid -o pid,cmd 2>/dev/null || echo "Process $pid no longer exists"
        done
    fi
}

# Function to wait for port to be free with timeout
wait_for_port_free() {
    local port=$1
    local max_wait=15  # Reduced timeout since we're more targeted now
    local count=0
    
    while check_port $port; do
        if [ $count -ge $max_wait ]; then
            echo "Timeout waiting for port ${port} to be free after ${max_wait} seconds"
            echo "Attempting to identify and kill processes using port ${port}..."
            
            # More aggressive cleanup as last resort
            local pids=$(lsof -ti:${port} 2>/dev/null)
            if [ -n "$pids" ]; then
                echo "Force killing processes using port ${port}: $pids"
                kill -KILL $pids 2>/dev/null || true
                sleep 2
            fi
            
            # Final check
            if check_port $port; then
                echo "ERROR: Unable to free port ${port}. Continuing anyway..."
                return 1
            fi
            break
        fi
        echo "Port ${port} still in use, waiting... (${count}/${max_wait})"
        sleep 1
        count=$((count + 1))
    done
    return 0
}

# Get WebSocket port from settings
WS_PORT=${WS_PORT:-6080}

echo "Starting NoVNC daemon setup for port ${WS_PORT}..."

# Clean up any existing novncd processes first
cleanup_novncd_processes $WS_PORT

# Wait for port to be free
wait_for_port_free $WS_PORT

# Double-check that novncd isn't already running
if check_novncd_running; then
    echo "WARNING: novncd process still detected after cleanup"
    cleanup_novncd_processes $WS_PORT
    wait_for_port_free $WS_PORT
fi

# Final verification before starting
if check_port $WS_PORT; then
    echo "WARNING: Port ${WS_PORT} is still in use, but starting novncd anyway"
    echo "This may cause connection issues"
else
    echo "Port ${WS_PORT} is free, starting novncd"
fi

echo "Starting NoVNC daemon..."
exec chpst -u www-data:www-data python3 /srv/webvirtcloud/console/novncd --host=0.0.0.0 --port=${WS_PORT}
