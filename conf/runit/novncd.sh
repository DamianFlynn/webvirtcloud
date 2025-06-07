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

# Get WebSocket port from settings
WS_PORT=${WS_PORT:-6080}

echo "Starting NoVNC daemon setup for port ${WS_PORT}..."

# Clean up any existing novncd processes
cleanup_novncd_processes

# Give a moment for any previous processes to fully terminate
sleep 2

echo "Starting NoVNC daemon on port ${WS_PORT}..."
exec chpst -u www-data:www-data python3 /srv/webvirtcloud/console/novncd --host=0.0.0.0 --port=${WS_PORT}
