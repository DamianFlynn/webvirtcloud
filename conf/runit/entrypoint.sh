#!/bin/sh
sed -i "s|CSRF_TRUSTED_ORIGINS.*|CSRF_TRUSTED_ORIGINS = ['http://localhost','http://${CURRENT_IP}',]|" webvirtcloud/settings.py
exec "$@"
