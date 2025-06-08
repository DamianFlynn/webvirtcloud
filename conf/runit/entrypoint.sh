#!/bin/bash
exec 2>&1

echo "Starting WebVirtCloud initialization..."

# Function to cleanup any existing processes
cleanup_processes() {
    echo "Cleaning up any existing processes..."
    
    # Kill any existing gunicorn processes
    pkill -f "gunicorn" 2>/dev/null || true
    
    # Kill any existing novncd processes
    pkill -f "console/novncd" 2>/dev/null || true
    
    # Kill any nginx processes
    pkill -f "nginx" 2>/dev/null || true
    
    # Wait for processes to terminate
    sleep 2
    
    echo "Process cleanup complete"
}

# Function to wait for port to be free
wait_for_port_free() {
    local port=$1
    local max_wait=30
    local wait_time=0
    
    while netstat -tln | grep -q ":$port " && [ $wait_time -lt $max_wait ]; do
        echo "Port $port still in use, waiting..."
        sleep 1
        wait_time=$((wait_time + 1))
    done
    
    if [ $wait_time -ge $max_wait ]; then
        echo "Warning: Port $port still in use after ${max_wait}s"
        return 1
    else
        echo "Port $port is now free"
        return 0
    fi
}

# Initial cleanup
cleanup_processes

# Database configuration
DATABASE_PATH=${DATABASE_PATH:-/srv/webvirtcloud/db.sqlite3}
DATABASE_DIR=$(dirname "$DATABASE_PATH")

echo "Database path: $DATABASE_PATH"
echo "Database directory: $DATABASE_DIR"

# Create database directory if it doesn't exist
if [ ! -d "$DATABASE_DIR" ]; then
    echo "Setting up database directory..."
    mkdir -p "$DATABASE_DIR"
    chown -R www-data:www-data "$DATABASE_DIR"
    chmod 755 "$DATABASE_DIR"
fi

# Update Django settings to use custom database path if different from default
if [ "$DATABASE_PATH" != "/srv/webvirtcloud/db.sqlite3" ]; then
    echo "Updating Django settings for custom database path..."
    sed -i "s|'NAME': BASE_DIR / 'db.sqlite3'|'NAME': '$DATABASE_PATH'|" /srv/webvirtcloud/webvirtcloud/settings.py
fi

# Initialize database if it doesn't exist or is empty
if [ ! -f "$DATABASE_PATH" ] || [ ! -s "$DATABASE_PATH" ]; then
    echo "Database not found or empty, initializing..."
    cd /srv/webvirtcloud
    . venv/bin/activate
    python3 manage.py makemigrations
    python3 manage.py migrate
    python3 manage.py loaddata admin/fixtures/users.json
    echo "Database initialized"
else
    echo "Database already exists, skipping initialization"
fi

# Set proper database permissions
echo "Setting database permissions..."
chown -R www-data:www-data "$DATABASE_DIR"
chmod 644 "$DATABASE_PATH" 2>/dev/null || true

# Collect static files
echo "Collecting static files..."
cd /srv/webvirtcloud
. venv/bin/activate
python3 manage.py collectstatic --noinput
echo "Static files collected"

# Verify critical static files exist
echo "Verifying critical static files..."
cd /srv/webvirtcloud

# Install websockify to get noVNC static files
echo "Installing websockify to get noVNC static files..."
pip3 install websockify

# List of critical static files to check
CRITICAL_FILES=(
    "static/js/spice-html5/main.js"
    "static/js/novnc/app/ui.js"
    "static/js/rfb.js"
    "static/css/lite.css"
    "static/js/Chart.bundle.min.js"
    "static/fonts/bootstrap-icons.woff2"
)

MISSING_FILES=()
for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$(basename "$file")")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "WARNING: Missing static files: " "${MISSING_FILES[@]}"
    echo "These files may cause UI issues but won't prevent startup"
else
    echo "All critical static files found"
fi

echo "Static file verification completed"

# Set static files permissions
echo "Setting static files permissions..."
chown -R www-data:www-data /srv/webvirtcloud/static

# Create SSH directory for www-data user if it doesn't exist
if [ ! -d /var/www/.ssh ]; then
    echo "Setting up SSH directory..."
    mkdir -p /var/www/.ssh
    chown www-data:www-data /var/www/.ssh
    chmod 700 /var/www/.ssh
    
    # Generate SSH key if it doesn't exist
    if [ ! -f /var/www/.ssh/id_rsa ]; then
        echo "Generating SSH key for www-data..."
        sudo -u www-data ssh-keygen -t rsa -b 4096 -f /var/www/.ssh/id_rsa -N "" -C "webvirtcloud@container"
    fi
    
    # Create SSH config
    if [ ! -f /var/www/.ssh/config ]; then
        echo "Creating SSH config..."
        cat > /var/www/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel=ERROR
EOF
        chown www-data:www-data /var/www/.ssh/config
        chmod 600 /var/www/.ssh/config
    fi
fi

# Set up environment variables for Django
export DJANGO_SETTINGS_MODULE=webvirtcloud.settings

# Update Django settings based on environment variables
SETTINGS_FILE="/srv/webvirtcloud/webvirtcloud/settings.py"

# Update ALLOWED_HOSTS if provided
if [ -n "$ALLOWED_HOSTS" ]; then
    echo "Updating ALLOWED_HOSTS..."
    # Convert comma-separated list to Python list format
    HOSTS_LIST=$(echo "$ALLOWED_HOSTS" | sed "s/,/','/g" | sed "s/^/'/" | sed "s/$/'/" | sed "s/','/', '/g")
    sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = [$HOSTS_LIST]/" "$SETTINGS_FILE"
fi

# Update other WebVirtCloud specific settings
if [ -n "$WS_HOST" ]; then
    sed -i "s/WS_HOST = .*/WS_HOST = '$WS_HOST'/" "$SETTINGS_FILE"
fi

if [ -n "$WS_PORT" ]; then
    sed -i "s/WS_PORT = .*/WS_PORT = $WS_PORT/" "$SETTINGS_FILE"
fi

if [ -n "$WS_PUBLIC_HOST" ]; then
    sed -i "s/WS_PUBLIC_HOST = .*/WS_PUBLIC_HOST = '$WS_PUBLIC_HOST'/" "$SETTINGS_FILE"
fi

if [ -n "$WS_PUBLIC_PORT" ]; then
    sed -i "s/WS_PUBLIC_PORT = .*/WS_PUBLIC_PORT = $WS_PUBLIC_PORT/" "$SETTINGS_FILE"
fi

if [ -n "$WS_PUBLIC_PATH" ]; then
    sed -i "s|WS_PUBLIC_PATH = .*|WS_PUBLIC_PATH = '$WS_PUBLIC_PATH'|" "$SETTINGS_FILE"
fi

# Handle nginx daemon directive properly
echo "Configuring nginx..."
NGINX_CONF="/etc/nginx/nginx.conf"

# Remove any existing daemon directives to avoid conflicts
sed -i '/^daemon/d' "$NGINX_CONF"

# Add daemon off at the beginning of the main context (after any comments)
sed -i '1a daemon off;' "$NGINX_CONF"

# Ensure nginx configuration is valid
nginx -t
if [ $? -ne 0 ]; then
    echo "ERROR: nginx configuration is invalid"
    exit 1
fi

# Wait for ports to be free before starting services
wait_for_port_free 80
wait_for_port_free "${WS_PORT:-6080}"

echo "WebVirtCloud initialization completed successfully"

# Create a marker file to indicate initialization is complete
touch /tmp/webvirtcloud-initialized

echo "Services will be started by runit..."

exec "$@"