#!/bin/sh
set -e

# 获取公网IP（带重试机制）
get_public_ip() {
  MAX_RETRIES=3
  RETRY_DELAY=5
  for i in $(seq 1 $MAX_RETRIES); do
    PUBLIC_IP=$(curl -s --fail ifconfig.me 2>/dev/null || curl -s --fail ipinfo.io/ip)
    [ -n "$PUBLIC_IP" ] && break
    sleep $RETRY_DELAY
  done
  [ -z "$PUBLIC_IP" ] && echo "ERROR: Failed to get public IP" >&2 && exit 1
  echo "$PUBLIC_IP"
}

# 修改配置文件
modify_settings() {
  TARGET_FILE="./webvirtcloud/settings.py"
  NEW_ENTRY="'http://${PUBLIC_IP}'"
  
  # 检查是否已存在该IP
  if grep -q "$NEW_ENTRY" "$TARGET_FILE"; then
    echo "IP entry already exists, no changes needed"
    return
  fi

  # 使用sed直接修改文件（兼容原有条目）
  sed -i "/CSRF_TRUSTED_ORIGINS = $$/ {     s/\[/'&http:\/\/${PUBLIC_IP}',/;  # 添加新IP到数组开头     s/'\[//;                           # 修正数组格式     s/$$/\]/;                          # 防止误删闭合括号
  }" "$TARGET_FILE"

  # 验证修改结果
  if ! grep -q "$NEW_ENTRY" "$TARGET_FILE"; then
    echo "ERROR: Failed to modify settings.py" >&2
    exit 1
  fi
}

# 主执行流程
PUBLIC_IP=$(get_public_ip)
modify_settings

# 执行原始命令
exec "$@"
