#!/bin/sh
sed -i "s|CSRF_TRUSTED_ORIGINS = $$'http://localhost'$$|CSRF_TRUSTED_ORIGINS = ['http://localhost','http://${CURRENT_IP}']|" webvirtcloud/settings.py
exec "$@"
