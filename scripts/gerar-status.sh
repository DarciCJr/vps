#!/bin/bash
# Gera /var/www/html/status.json com dados gerais do servidor.
# Rodado via cron a cada minuto.

UPTIME=$(uptime -p | sed 's/up //')
MEMORY=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
DISK=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " usado)"}')

is_active() {
  systemctl is-active --quiet "$1" && echo true || echo false
}

APACHE=$(is_active apache2)
CLOUDFLARED=$(is_active cloudflared)
DOCKER=$(is_active docker)

CONTAINERS="[]"
if command -v docker >/dev/null 2>&1; then
  CONTAINERS=$(docker ps -a --format '{{.Names}}|{{.State}}' 2>/dev/null | \
    awk -F'|' '{printf "{\"name\":\"%s\",\"up\":%s},", $1, ($2=="running"?"true":"false")}' | \
    sed 's/,$//')
  CONTAINERS="[$CONTAINERS]"
fi

PUBLIC_IP=$(curl -s --max-time 8 https://ifconfig.me || echo "indisponível")
UPDATED_AT=$(date '+%d/%m/%Y %H:%M:%S')

RAM_TEST_FILE="/var/www/html/ram-test.json"
if [ -f "$RAM_TEST_FILE" ]; then
  RAM_TEST=$(cat "$RAM_TEST_FILE")
else
  RAM_TEST='{"status":"nunca_testado"}'
fi

cat > /var/www/html/status.json << JSON
{
  "uptime": "$UPTIME",
  "memory": "$MEMORY",
  "disk": "$DISK",
  "public_ip": "$PUBLIC_IP",
  "apache": $APACHE,
  "cloudflared": $CLOUDFLARED,
  "docker": $DOCKER,
  "containers": $CONTAINERS,
  "ram_test": $RAM_TEST,
  "updated_at": "$UPDATED_AT"
}
JSON
