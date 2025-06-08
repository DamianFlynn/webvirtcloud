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

# Database Configuration
# Check if DATABASE_PATH environment variable is set, otherwise use default
DB_PATH="${DATABASE_PATH:-/srv/webvirtcloud/db.sqlite3}"
DB_DIR="$(dirname "$DB_PATH")"

echo "Database path: $DB_PATH"
echo "Database directory: $DB_DIR"

# Ensure database directory exists and has proper permissions
echo "Setting up database directory..."
mkdir -p "$DB_DIR"
chown -R www-data:www-data "$DB_DIR"
chmod 755 "$DB_DIR"

# Update Django settings to use the correct database path
if [ "$DATABASE_PATH" != "/srv/webvirtcloud/db.sqlite3" ]; then
    echo "Updating Django settings for custom database path..."
    sed -i "s|'NAME': BASE_DIR / 'db.sqlite3'|'NAME': '$DB_PATH'|g" /srv/webvirtcloud/webvirtcloud/settings.py
fi

# Database initialization - Check if database exists and is accessible
if [ ! -f "$DB_PATH" ] || [ ! -s "$DB_PATH" ]; then
    echo "Database not found or empty, initializing..."
    python3 manage.py makemigrations
    python3 manage.py migrate
    echo "Database initialized"
else
    echo "Existing database found, checking accessibility..."
    # Test database accessibility
    if python3 manage.py migrate --check 2>/dev/null; then
        echo "Database is accessible, running migrations..."
        python3 manage.py migrate
    else
        echo "Database not accessible, fixing permissions and reinitializing..."
        rm -f "$DB_PATH"
        python3 manage.py makemigrations
        python3 manage.py migrate
        echo "Database reinitialized"
    fi
fi

# Fix database file permissions after creation/migration
echo "Setting database permissions..."
if [ -f "$DB_PATH" ]; then
    chown www-data:www-data "$DB_PATH"
    chmod 664 "$DB_PATH"
    echo "Database permissions set"
fi

# Static files - Always collect to ensure noVNC files are present
echo "Collecting static files..."
# Remove any existing static files first to ensure clean state
rm -rf static/*
python3 manage.py collectstatic --noinput --clear
echo "Static files collected"

# Check for critical missing static files and handle them
echo "Verifying critical static files..."

# Install websockify which contains noVNC files
echo "Installing websockify to get noVNC static files..."
pip3 install websockify

# Find and copy noVNC files from websockify installation
WEBSOCKIFY_PATH=$(find venv/lib -name "websockify" -type d 2>/dev/null | head -1)
if [ -n "$WEBSOCKIFY_PATH" ] && [ -d "$WEBSOCKIFY_PATH/web" ]; then
    echo "Found noVNC files in websockify, copying to static directory..."
    mkdir -p static/js/novnc
    cp -r "$WEBSOCKIFY_PATH/web"/* static/js/novnc/ 2>/dev/null || true
    # Ensure core files are in the right location
    if [ -d "static/js/novnc/core" ]; then
        echo "noVNC core files copied successfully"
    fi
fi

# Verify critical files exist after copying
missing_files=""
[ ! -f "static/js/novnc/core/rfb.js" ] && missing_files="$missing_files rfb.js"
[ ! -f "static/js/novnc/app/styles/lite.css" ] && missing_files="$missing_files lite.css"
[ ! -f "static/js/Chart.bundle.min.js" ] && missing_files="$missing_files Chart.bundle.min.js"
[ ! -f "static/fonts/bootstrap-icons.woff2" ] && missing_files="$missing_files bootstrap-icons.woff2"

if [ -n "$missing_files" ]; then
    echo "WARNING: Missing static files: $missing_files"
    echo "These files may cause UI issues but won't prevent startup"
fi

echo "Static file verification completed"

# Fix static files and cache directory permissions
echo "Setting static files permissions..."ll missing
if [ -d "static" ]; then/novnc/core/rfb.js" ]; then
    chown -R www-data:www-data static/fallback..."
    chmod -R 755 static/js/novnc/core
        cat > static/js/novnc/core/rfb.js << 'EOF'
    # Create and set permissions for icon cache directory
    mkdir -p static/icon_cacheB fallback - noVNC may not work properly');
    chown www-data:www-data static/icon_cache
    chmod 755 static/icon_cacheerly loaded'); 
    
    echo "Static files permissions set"
fi  fi
fi
# Ensure NoVNC service script exists and is executable
echo "Setting up NoVNC service..."
chmod +x /srv/webvirtcloud/console/novncd ]; then
echo "NoVNC service configured".min.js not found"
    # Create empty fallback
# SSH Key Management - Only generate if keys don't exist
if [ ! -f /var/www/.ssh/id_rsa ]; thenic/js/Chart.bundle.min.js
    echo "No existing SSH key found, generating new keypair..."
    
    # Ensure directory exists and has proper permissions
    sudo mkdir -p /var/www/.sshap-icons.woff2" ]; then
    sudo chown www-data:www-data /var/www/.sshound"
    sudo chmod 700 /var/www/.ssh
    # Create empty files to prevent 404s
    # Generate SSH key as www-data user with proper permissions
    if sudo -u www-data ssh-keygen -q -N "" -f /var/www/.ssh/id_rsa; then
        # Create SSH config
        cat > /var/www/.ssh/config << 'EOF'
Host *le missing noVNC CSS and other files
    StrictHostKeyChecking nopp/styles/lite.css" ]; then
    UserKnownHostsFile /dev/nullfound"
    LogLevel QUIETc/js/novnc/app/styles
EOF cat > static/js/novnc/app/styles/lite.css << 'EOF'
        al noVNC CSS fallback */
        sudo chown www-data:www-data /var/www/.ssh/config
        sudo chmod 600 /var/www/.ssh/config
        
        echo "New SSH keypair generated"
        echo "Public key:"
        echo "====================="omise.js" ]; then
        cat /var/www/.ssh/id_rsa.pubund"
        echo "====================="
    else> static/js/novnc/vendor/promise.js << 'EOF'
        echo "Failed to generate SSH key, but continuing..." support
    fiindow.Promise) {
elseconsole.warn('Promise polyfill needed but not available');
    echo "Existing SSH key found, skipping key generation"
fiF
fi
# Fix logging permissions and create required log directories
echo "Setting up logging permissions...""
touch /srv/webvirtcloud/webvirtcloud.log
chown www-data:www-data /srv/webvirtcloud/webvirtcloud.log
chmod 664 /srv/webvirtcloud/webvirtcloud.log
if [ -d "static" ]; then
# Ensure the logs directory structure exists with proper permissions
if [ -d "/var/log" ]; then
    # Create nginx logs directory
    mkdir -p /var/log/nginxsions for icon cache directory
    chown -R www-data:www-data /var/log/nginx
    chmod -R 755 /var/log/nginxtic/icon_cache
    chmod 755 static/icon_cache
    echo "Log directories created and permissions set"
fi  echo "Static files permissions set"
fi
# Handle CSRF Trusted Origins with support for HTTPS domains
if [ -n "$CURRENT_IP" ]; then exists and is executable
    echo "Configuring CSRF trusted origins for: $CURRENT_IP"
    DOMAIN_PORT="$CURRENT_IP"nsole/novncd
     "NoVNC service configured"
    # Create CSRF trusted origins list supporting both HTTP and HTTPS
    if echo "$DOMAIN_PORT" | grep -q ":443"; thent exist
        # HTTPS configurationa ]; then
        DOMAIN=$(echo "$DOMAIN_PORT" | cut -d: -f1) keypair..."
        CSRF_ORIGINS="['https://${DOMAIN}','http://localhost','http://127.0.0.1']"
    elif echo "$DOMAIN_PORT" | grep -q ":80"; thenssions
        # HTTP configuration  h
        DOMAIN=$(echo "$DOMAIN_PORT" | cut -d: -f1)
        CSRF_ORIGINS="['http://${DOMAIN}','https://${DOMAIN}','http://localhost','http://127.0.0.1']"
    else
        # Custom port configurationuser with proper permissions
        CSRF_ORIGINS="['http://${DOMAIN_PORT}','https://${DOMAIN_PORT}','http://localhost','http://127.0.0.1']"
    fi  # Create SSH config
        cat > /var/www/.ssh/config << 'EOF'
    sed -i "s|CSRF_TRUSTED_ORIGINS.*|CSRF_TRUSTED_ORIGINS = ${CSRF_ORIGINS}|" webvirtcloud/settings.py
    echo "CSRF origins configured: $CSRF_ORIGINS"
fi  UserKnownHostsFile /dev/null
    LogLevel QUIET
# Handle ALLOWED_HOSTS environment variable - FIXED VERSION
if [ -n "$ALLOWED_HOSTS" ]; then
    echo "Configuring allowed hosts: $ALLOWED_HOSTS"onfig
    # Convert comma-separated list to Python list format - escape single quotes properly
    HOSTS_LIST=$(echo "$ALLOWED_HOSTS" | sed "s/,/', '/g" | sed "s/^/['/" | sed "s/$/']/" )
    # Use | delimiter to avoid conflicts with slashes in the replacement
    sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = ${HOSTS_LIST}|" webvirtcloud/settings.py
    echo "Allowed hosts configured: $HOSTS_LIST"
fi      cat /var/www/.ssh/id_rsa.pub
        echo "====================="
# Handle WebSocket Public Host
if [ -n "$WS_PUBLIC_HOST" ]; thenSSH key, but continuing..."
    echo "Configuring WebSocket public host: $WS_PUBLIC_HOST"
    sed -i "s|WS_PUBLIC_HOST = None|WS_PUBLIC_HOST = \"${WS_PUBLIC_HOST}\"|" webvirtcloud/settings.py
fi  echo "Existing SSH key found, skipping key generation"
fi
# Handle WebSocket Public Port
if [ -n "$WS_PUBLIC_PORT" ]; thenate required log directories
    echo "Configuring WebSocket public port: $WS_PUBLIC_PORT"
    sed -i "s|WS_PUBLIC_PORT = 6080|WS_PUBLIC_PORT = ${WS_PUBLIC_PORT}|" webvirtcloud/settings.py
fiown www-data:www-data /srv/webvirtcloud/webvirtcloud.log
chmod 664 /srv/webvirtcloud/webvirtcloud.log
# Handle WebSocket Public Path - ensure it ends with /
if [ -n "$WS_PUBLIC_PATH" ]; thenture exists with proper permissions
    echo "Configuring WebSocket public path: $WS_PUBLIC_PATH"
    # Ensure path starts and ends with /
    WS_PATH_CLEAN=$(echo "$WS_PUBLIC_PATH" | sed 's|^/*||' | sed 's|/*$||')
    WS_PATH_FORMATTED="/${WS_PATH_CLEAN}/"inx
    sed -i "s|WS_PUBLIC_PATH = \"/novncd/\"|WS_PUBLIC_PATH = \"${WS_PATH_FORMATTED}\"|" webvirtcloud/settings.py
fi  
    echo "Log directories created and permissions set"
# Handle WebSocket Host
if [ -n "$WS_HOST" ]; then
    echo "Configuring WebSocket host: $WS_HOST"HTTPS domains
    sed -i "s|WS_HOST = \"0.0.0.0\"|WS_HOST = \"${WS_HOST}\"|" webvirtcloud/settings.py
fi  echo "Configuring CSRF trusted origins for: $CURRENT_IP"
    DOMAIN_PORT="$CURRENT_IP"
# Handle WebSocket Port
if [ -n "$WS_PORT" ]; thenorigins list supporting both HTTP and HTTPS
    echo "Configuring WebSocket port: $WS_PORT"en
    sed -i "s|WS_PORT = 6080|WS_PORT = ${WS_PORT}|" webvirtcloud/settings.py
fi      DOMAIN=$(echo "$DOMAIN_PORT" | cut -d: -f1)
        CSRF_ORIGINS="['https://${DOMAIN}','http://localhost','http://127.0.0.1']"
# Handle Debug modeAIN_PORT" | grep -q ":80"; then
if [ -n "$DEBUG" ]; thention  
    echo "Configuring debug mode: $DEBUG"t -d: -f1)
    sed -i "s|DEBUG = False|DEBUG = ${DEBUG}|" webvirtcloud/settings.pyocalhost','http://127.0.0.1']"
fi  else
        # Custom port configuration
# Test Django configuration and wait for database to be readyAIN_PORT}','http://localhost','http://127.0.0.1']"
echo "Testing Django configuration..."
max_attempts=5
attempt=0i "s|CSRF_TRUSTED_ORIGINS.*|CSRF_TRUSTED_ORIGINS = ${CSRF_ORIGINS}|" webvirtcloud/settings.py
while [ $attempt -lt $max_attempts ]; do_ORIGINS"
    if python3 manage.py check --deploy 2>/dev/null; then
        echo "Django configuration is valid"
        breakWED_HOSTS environment variable - FIXED VERSION
    else"$ALLOWED_HOSTS" ]; then
        attempt=$((attempt + 1))sts: $ALLOWED_HOSTS"
        echo "Django configuration check failed (attempt $attempt/$max_attempts)"roperly
        if [ $attempt -lt $max_attempts ]; then/,/', '/g" | sed "s/^/['/" | sed "s/$/']/" )
            echo "Retrying in 10 seconds..."h slashes in the replacement
            sleep 10D_HOSTS = \[\]|ALLOWED_HOSTS = ${HOSTS_LIST}|" webvirtcloud/settings.py
        elselowed hosts configured: $HOSTS_LIST"
            echo "Warning: Django configuration issues detected, but continuing..."
            python3 manage.py check --deploy || true
        fiebSocket Public Host
    fin "$WS_PUBLIC_HOST" ]; then
doneecho "Configuring WebSocket public host: $WS_PUBLIC_HOST"
    sed -i "s|WS_PUBLIC_HOST = None|WS_PUBLIC_HOST = \"${WS_PUBLIC_HOST}\"|" webvirtcloud/settings.py
echo "WebVirtCloud initialization complete!"
echo "Waiting a moment for cleanup to finish..."
sleep 5e WebSocket Public Port
echo "Runit will now start the services..."
    echo "Configuring WebSocket public port: $WS_PUBLIC_PORT"
# Create a marker file to indicate initialization is completeLIC_PORT}|" webvirtcloud/settings.py
touch /tmp/webvirtcloud-initialized

echo "Services will be started by runit..."ends with /
if [ -n "$WS_PUBLIC_PATH" ]; then
# Install additional packages that might provide missing static files"Configuring WebSocket public path: $WS_PUBLIC_PATH"




exec "$@""pip3 install --no-cache-dir novnc websockify || trueecho "Installing additional static file dependencies..."    # Ensure path starts and ends with /
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