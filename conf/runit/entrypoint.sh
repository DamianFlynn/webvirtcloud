#!/bin/sh

# Handle CSRF Trusted Origins with support for HTTPS domains
if [ -n "$CURRENT_IP" ]; then
    # Extract domain and port from CURRENT_IP
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
fi

# Handle WebSocket Public Host
if [ -n "$WS_PUBLIC_HOST" ]; then
    sed -i "s|WS_PUBLIC_HOST = None|WS_PUBLIC_HOST = \"${WS_PUBLIC_HOST}\"|" webvirtcloud/settings.py
fi

# Handle WebSocket Public Port
if [ -n "$WS_PUBLIC_PORT" ]; then
    sed -i "s|WS_PUBLIC_PORT = 6080|WS_PUBLIC_PORT = ${WS_PUBLIC_PORT}|" webvirtcloud/settings.py
fi

# Handle WebSocket Public Path
if [ -n "$WS_PUBLIC_PATH" ]; then
    sed -i "s|WS_PUBLIC_PATH = \"/novncd/\"|WS_PUBLIC_PATH = \"/${WS_PUBLIC_PATH}\"|" webvirtcloud/settings.py
fi

# Handle WebSocket Host
if [ -n "$WS_HOST" ]; then
    sed -i "s|WS_HOST = \"0.0.0.0\"|WS_HOST = \"${WS_HOST}\"|" webvirtcloud/settings.py
fi

# Handle WebSocket Port
if [ -n "$WS_PORT" ]; then
    sed -i "s|WS_PORT = 6080|WS_PORT = ${WS_PORT}|" webvirtcloud/settings.py
fi

# Handle Debug mode
if [ -n "$DEBUG" ]; then
    sed -i "s|DEBUG = False|DEBUG = ${DEBUG}|" webvirtcloud/settings.py
fi

exec "$@"