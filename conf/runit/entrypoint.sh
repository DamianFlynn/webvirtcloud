#!/bin/sh

echo "Starting WebVirtCloud initialization..."

# Change to the webvirtcloud directory
cd /srv/webvirtcloud

# Activate virtual environment
. venv/bin/activate

# Function to cleanup any existing web processes
cleanup_processes() {
    echo "Cleaning up any existing processes..."
    
    # Kill any existing gunicorn processes
    pkill -f "gunicorn.*webvirtcloud" 2>/dev/null || true
    
    # Kill any existing novncd processes
    pkill -f "console/novncd" 2>/dev/null || true
    
    # Kill any existing nginx processes
    pkill -f "nginx: master process" 2>/dev/null || true
    
    # Wait for processes to terminate and ports to be free
    sleep 5
    
    echo "Process cleanup complete"
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

# Check for critical missing static files and handle them
echo "Checking for missing static files..."

# Create missing directories if they don't exist
mkdir -p static/js/novnc/core
mkdir -p static/js/novnc/app/styles
mkdir -p static/js/novnc/vendor
mkdir -p static/fonts
mkdir -p static/js

# Handle missing noVNC files - these might be in a different location
if [ ! -f "static/js/novnc/core/rfb.js" ]; then
    echo "WARNING: rfb.js not found in expected location"
    # Try to find it elsewhere and copy
    find . -name "rfb.js" -not -path "./static/*" | head -1 | while read -r source; do
        if [ -n "$source" ]; then
            echo "Found rfb.js at $source, copying to static location"
            cp "$source" static/js/novnc/core/rfb.js
        fi
    done
fi

if [ ! -f "static/js/novnc/app/styles/lite.css" ]; then
    echo "WARNING: lite.css not found"
    # Check if base.css exists and can be used as fallback
    if [ -f "static/js/novnc/app/styles/base.css" ]; then
        echo "Using base.css as lite.css fallback"
        cp static/js/novnc/app/styles/base.css static/js/novnc/app/styles/lite.css
    else
        echo "Creating minimal lite.css"
        cat > static/js/novnc/app/styles/lite.css << 'EOF'
/* Minimal noVNC lite styles */
.noVNC_canvas {
    width: 100%;
    height: 100%;
}
EOF
    fi
fi

if [ ! -f "static/js/novnc/vendor/promise.js" ]; then
    echo "WARNING: promise.js not found"
    # Create a minimal promise polyfill if needed
    echo "Creating minimal promise.js stub"
    cat > static/js/novnc/vendor/promise.js << 'EOF'
// Minimal Promise polyfill stub
if (typeof Promise === 'undefined') {
    window.Promise = window.Promise || function() {};
}
EOF
fi

# Handle missing Chart.js
if [ ! -f "static/js/Chart.bundle.min.js" ]; then
    echo "WARNING: Chart.bundle.min.js not found"
    # Try to find it
    find . -name "Chart.bundle.min.js" -not -path "./static/*" | head -1 | while read -r source; do
        if [ -n "$source" ]; then
            echo "Found Chart.bundle.min.js at $source, copying to static location"
            cp "$source" static/js/Chart.bundle.min.js
        fi
    done
fi

# Handle missing Bootstrap icons
if [ ! -f "static/fonts/bootstrap-icons.woff2" ]; then
    echo "WARNING: Bootstrap icon fonts not found"
    # Try to find them
    find . -name "bootstrap-icons.woff*" -not -path "./static/*" | while read -r source; do
        if [ -n "$source" ]; then
            echo "Found bootstrap icon font at $source, copying to static location"
            cp "$source" static/fonts/
        fi
    done
fi

echo "Static file check completed"

# Fix static files and cache directory permissions
echo "Setting static files permissions..."
if [ -d "static" ]; then
    chown -R www-data:www-data static/
    chmod -R 755 static/
    
    # Create and set permissions for icon cache directory
    mkdir -p static/icon_cache
    chown www-data:www-data static/icon_cache
    chmod 755 static/icon_cache
    
    echo "Static files permissions set"
fi

# Ensure NoVNC service script exists and is executable
echo "Setting up NoVNC service..."
chmod +x /srv/webvirtcloud/console/novncd
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

# Handle ALLOWED_HOSTS environment variable - FIXED VERSION
if [ -n "$ALLOWED_HOSTS" ]; then
    echo "Configuring allowed hosts: $ALLOWED_HOSTS"
    # Convert comma-separated list to Python list format - escape single quotes properly
    HOSTS_LIST=$(echo "$ALLOWED_HOSTS" | sed "s/,/', '/g" | sed "s/^/['/" | sed "s/$/']/" )
    # Use | delimiter to avoid conflicts with slashes in the replacement
    sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = ${HOSTS_LIST}|" webvirtcloud/settings.py
    echo "Allowed hosts configured: $HOSTS_LIST"
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

# Test Django configuration and wait for database to be ready
echo "Testing Django configuration..."
max_attempts=5
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if python3 manage.py check --deploy 2>/dev/null; then
        echo "Django configuration is valid"
        break
    else
        attempt=$((attempt + 1))
        echo "Django configuration check failed (attempt $attempt/$max_attempts)"
        if [ $attempt -lt $max_attempts ]; then
            echo "Retrying in 10 seconds..."
            sleep 10
        else
            echo "Warning: Django configuration issues detected, but continuing..."
            python3 manage.py check --deploy || true
        fi
    fi
done

echo "WebVirtCloud initialization complete!"
echo "Waiting a moment for cleanup to finish..."
sleep 5
echo "Runit will now start the services..."

# Create a marker file to indicate initialization is complete
touch /tmp/webvirtcloud-initialized

echo "Services will be started by runit..."

exec "$@"