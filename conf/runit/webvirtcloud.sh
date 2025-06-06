#!/bin/bash
exec 2>&1

# Change to the webvirtcloud directory
cd /srv/webvirtcloud

# Activate virtual environment
. venv/bin/activate

# Wait for database to be ready
echo "Waiting for database to be ready..."
python3 manage.py migrate --check 2>/dev/null || {
    echo "Running database migrations..."
    python3 manage.py migrate
}

echo "Starting WebVirtCloud application server..."
exec chpst -u www-data:www-data gunicorn webvirtcloud.wsgi:application -c /srv/webvirtcloud/gunicorn.conf.py
