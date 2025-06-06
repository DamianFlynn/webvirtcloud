#!/bin/sh

echo "Starting WebVirtCloud initialization..."

# Change to the webvirtcloud directory
cd /srv/webvirtcloud

# Activate virtual environment
. venv/bin/activate

# Function to check if port is in use
check_port() {
    netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0 || return 1
}

# Function to cleanup any existing processes
cleanup_processes() {
    echo "Cleaning up any existing WebVirtCloud processes..."
    
    # Kill any existing gunicorn processes
    pkill -f "gunicorn.*webvirtcloud" 2>/dev/null || true
    
    # Kill any existing novncd processes
    pkill -f "console/novncd" 2>/dev/null || true
    
    # Wait a moment for processes to terminate
    sleep 3
    
    # Clean up ports if still in use
    local web_port=${WS_PORT:-6080}
    if check_port $web_port; then
        echo "Forcefully cleaning up port $web_port"
        lsof -ti:$web_port 2>/dev/null | xargs kill -9 2>/dev/null || true
    fi
}

# Cleanup any existing processes first
cleanup_processes

# Database initialization - Only run if database doesn't exist or is empty
if [ ! -f "db.sqlite3" ] || [ ! -s "db.sqlite3" ]; then
    echo "Database not found or empty, initializing..."
    python3 manage.py makemigrations
    python3 manage.py migrate
    echo "Database initialized"
else
    echo "Existing database found, running migrations..."
    python3 manage.py migrate
fi

# Fix database file permissions
echo "Setting database permissions..."
if [ -f "db.sqlite3" ]; then
    chown www-data:www-data db.sqlite3
    chmod 664 db.sqlite3
    echo "Database permissions set"
fi

# Static files - Always collect to ensure noVNC files are present
echo "Collecting static files..."
python3 manage.py collectstatic --noinput --clear
echo "Static files collected"

# Verify critical noVNC files exist
echo "Verifying noVNC files..."
if [ ! -f "static/js/novnc/core/rfb.js" ]; then
    echo "WARNING: rfb.js not found in static files"
    # Try to find it in the source and copy manually
    if [ -f "static/js/novnc/core/rfb.js" ]; then
        echo "Found rfb.js, copying to correct location"
    fi
fi

if [ ! -f "static/js/novnc/app/styles/lite.css" ]; then
    echo "WARNING: lite.css not found"
    # Check if base.css exists and can be used
    if [ -f "static/js/novnc/app/styles/base.css" ]; then
        echo "Using base.css instead of lite.css"
        ln -sf base.css static/js/novnc/app/styles/lite.css
    fi
fi

# List static directory structure for debugging
echo "Static directory structure:"
find static/js/novnc -type f -name "*.js" -o -name "*.css" | head -20

# Fix static files and cache directory permissions
echo "Setting static files permissions..."
if [ -d "static" ]; then
    chown -R www-data:www-data static/
    chmod -R 755 static/
    
    # Create and set permissions for icon cache directory
    mkdir -p static/icon_cache
    chown www-data:www-data static/icon_cache
    chmod 755 static/icon_cache
    
    # Ensure noVNC static files have proper permissions
    if [ -d "static/js" ]; then
        chmod -R 644 static/js/*.js 2>/dev/null || true
        chmod -R 644 static/css/*.css 2>/dev/null || true
    fi
    
    echo "Static files permissions set"
fi

# Ensure NoVNC service directory and script exist
echo "Setting up NoVNC service..."
if [ ! -d "/etc/service/novnc" ]; then
    mkdir -p /etc/service/novnc
fi

# Make sure the novncd script is executable and has proper permissions
chmod +x /srv/webvirtcloud/console/novncd
chmod +x /etc/service/novnc/run 2>/dev/null || true

echo "NoVNC service configured"

# SSH Key Management - Only generate if keys don't exist
if [ ! -f /var/www/.ssh/id_rsa ]; then
    echo "No existing SSH key found, generating new keypair..."
    
    # Ensure directory exists and has proper permissions
    sudo mkdir -p /var/www/.ssh
    sudo chown www-data:www-data /var/www/.ssh
    sudo chmod 700 /var/www/.ssh
    
    # Generate SSH key as www-data user with proper permissions
    if sudo -u www-data ssh-keygen -q -N "" -f /var/www/.ssh/id_rsa; then
        # Create SSH config
        cat > /var/www/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel QUIET
EOF
        
        sudo chown www-data:www-data /var/www/.ssh/config
        sudo chmod 600 /var/www/.ssh/config
        
        echo "New SSH keypair generated"
        echo "Public key:"
        echo "====================="
        cat /var/www/.ssh/id_rsa.pub
        echo "====================="
    else
        echo "Failed to generate SSH key, but continuing..."
    fi
else
    echo "Existing SSH key found, skipping key generation"
fi

# Fix logging permissions and create required log directories
echo "Setting up logging permissions..."
touch /srv/webvirtcloud/webvirtcloud.log
chown www-data:www-data /srv/webvirtcloud/webvirtcloud.log
chmod 664 /srv/webvirtcloud/webvirtcloud.log

# Ensure the logs directory structure exists with proper permissions
if [ -d "/var/log" ]; then
    # Create nginx logs directory
    mkdir -p /var/log/nginx
    chown -R www-data:www-data /var/log/nginx
    chmod -R 755 /var/log/nginx
    
    # Create webvirtcloud logs if they don't exist
    chown -R www-data:www-data /var/log/webvirtcloud* 2>/dev/null || true
    chmod -R 664 /var/log/webvirtcloud* 2>/dev/null || true
    
    echo "Log directories created and permissions set"
fi

# Handle CSRF Trusted Origins with support for HTTPS domains
if [ -n "$CURRENT_IP" ]; then
    echo "Configuring CSRF trusted origins for: $CURRENT_IP"
    DOMAIN_PORT="$CURRENT_IP"
    
    # Create CSRF trusted origins list supporting both HTTP and HTTPS
    if echo "$DOMAIN_PORT" | grep -q ":443"; then
        # HTTPS configuration
        DOMAIN=$(echo "$DOMAIN_PORT" | cut -d: -f1)
        CSRF_ORIGINS="['https://${DOMAIN}','http://localhost','http://127.0.0.1']"
    elif echo "$DOMAIN_PORT" | grep -q ":80"; then
        # HTTP configuration  
        DOMAIN=$(echo "$DOMAIN_PORT" | cut -d: -f1)
        CSRF_ORIGINS="['http://${DOMAIN}','https://${DOMAIN}','http://localhost','http://127.0.0.1']"
    else
        # Custom port configuration
        CSRF_ORIGINS="['http://${DOMAIN_PORT}','https://${DOMAIN_PORT}','http://localhost','http://127.0.0.1']"
    fi
    
    sed -i "s|CSRF_TRUSTED_ORIGINS.*|CSRF_TRUSTED_ORIGINS = ${CSRF_ORIGINS}|" webvirtcloud/settings.py
    echo "CSRF origins configured: $CSRF_ORIGINS"
fi

# Handle WebSocket Public Host
if [ -n "$WS_PUBLIC_HOST" ]; then
    echo "Configuring WebSocket public host: $WS_PUBLIC_HOST"
    sed -i "s|WS_PUBLIC_HOST = None|WS_PUBLIC_HOST = \"${WS_PUBLIC_HOST}\"|" webvirtcloud/settings.py
fi

# Handle WebSocket Public Port
if [ -n "$WS_PUBLIC_PORT" ]; then
    echo "Configuring WebSocket public port: $WS_PUBLIC_PORT"
    sed -i "s|WS_PUBLIC_PORT = 6080|WS_PUBLIC_PORT = ${WS_PUBLIC_PORT}|" webvirtcloud/settings.py
fi

# Handle WebSocket Public Path - ensure it ends with /
if [ -n "$WS_PUBLIC_PATH" ]; then
    echo "Configuring WebSocket public path: $WS_PUBLIC_PATH"
    # Ensure path starts and ends with /
    WS_PATH_CLEAN=$(echo "$WS_PUBLIC_PATH" | sed 's|^/*||' | sed 's|/*$||')
    WS_PATH_FORMATTED="/${WS_PATH_CLEAN}/"
    sed -i "s|WS_PUBLIC_PATH = \"/novncd/\"|WS_PUBLIC_PATH = \"${WS_PATH_FORMATTED}\"|" webvirtcloud/settings.py
fi

# Handle WebSocket Host
if [ -n "$WS_HOST" ]; then
    echo "Configuring WebSocket host: $WS_HOST"
    sed -i "s|WS_HOST = \"0.0.0.0\"|WS_HOST = \"${WS_HOST}\"|" webvirtcloud/settings.py
fi

# Handle WebSocket Port
if [ -n "$WS_PORT" ]; then
    echo "Configuring WebSocket port: $WS_PORT"
    sed -i "s|WS_PORT = 6080|WS_PORT = ${WS_PORT}|" webvirtcloud/settings.py
fi

# Handle Debug mode
if [ -n "$DEBUG" ]; then
    echo "Configuring debug mode: $DEBUG"
    sed -i "s|DEBUG = False|DEBUG = ${DEBUG}|" webvirtcloud/settings.py
fi

echo "WebVirtCloud initialization complete!"

exec "$@"