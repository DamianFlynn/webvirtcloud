#!/bin/sh

echo "Starting WebVirtCloud initialization..."

# Change to the webvirtcloud directory
cd /srv/webvirtcloud

# Activate virtual environment
. venv/bin/activate

# Database initialization - Only run if database doesn't exist or is empty
if [ ! -f "db.sqlite3" ] || [ ! -s "db.sqlite3" ]; then
    echo "Database not found or empty, initializing..."
    python3 manage.py makemigrations
    python3 manage.py migrate
    chown www-data:www-data db.sqlite3
    echo "Database initialized"
else
    echo "Existing database found, running migrations..."
    python3 manage.py migrate
    chown www-data:www-data db.sqlite3
fi

# Static files - Only collect if static directory is empty or missing
if [ ! -d "static" ] || [ -z "$(ls -A static 2>/dev/null)" ]; then
    echo "Static files not found, collecting..."
    python3 manage.py collectstatic --noinput
    chown -R www-data:www-data static
    echo "Static files collected"
else
    echo "Static files found, skipping collection"
fi

# SSH Key Management - Only generate if keys don't exist
if [ ! -f /var/www/.ssh/id_rsa ]; then
    echo "No existing SSH key found, generating new keypair..."
    mkdir -p /var/www/.ssh
    chown www-data:www-data /var/www/.ssh
    chmod 700 /var/www/.ssh
    
    # Generate SSH key as www-data user
    sudo -u www-data ssh-keygen -q -N "" -f /var/www/.ssh/id_rsa
    
    # Create SSH config
    cat > /var/www/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel QUIET
EOF
    
    chown www-data:www-data /var/www/.ssh/config
    chmod 600 /var/www/.ssh/config
    
    echo "New SSH keypair generated"
    echo "Public key:"
    echo "====================="
    cat /var/www/.ssh/id_rsa.pub
    echo "====================="
else
    echo "Existing SSH key found, skipping key generation"
fi

# Ensure proper permissions on existing keys (in case they were mounted)
chown -R www-data:www-data /var/www/.ssh
chmod 700 /var/www/.ssh
chmod 600 /var/www/.ssh/id_rsa /var/www/.ssh/id_rsa.pub 2>/dev/null || true
chmod 600 /var/www/.ssh/config 2>/dev/null || true

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

# Handle WebSocket Public Path
if [ -n "$WS_PUBLIC_PATH" ]; then
    echo "Configuring WebSocket public path: $WS_PUBLIC_PATH"
    sed -i "s|WS_PUBLIC_PATH = \"/novncd/\"|WS_PUBLIC_PATH = \"/${WS_PUBLIC_PATH}\"|" webvirtcloud/settings.py
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