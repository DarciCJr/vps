#!/bin/bash
# Gera /var/www/html/status.json com dados gerais do servidor.
# Rodado via cron a cada minuto.

UPTIME=$(uptime -p | sed 's/up //')
MEMORY=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
DISK=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " usado)"}')
LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)

# Espaço real do disco C: do Windows (diferente do disco "virtual" do WSL acima).
# Foi a falta de espaço aqui que corrompeu o WSL — esse é o número que importa de verdade.
WIN_DISK="indisponível"
WIN_DISK_BAIXO=false
if command -v powershell.exe >/dev/null 2>&1; then
  WIN_RAW=$(powershell.exe -NoProfile -Command '$d=Get-PSDrive C; "{0},{1}" -f [math]::Round($d.Used/1GB,1), [math]::Round(($d.Used+$d.Free)/1GB,1)' 2>/dev/null | tr -d '\r')
  if [ -n "$WIN_RAW" ]; then
    WIN_USED=$(echo "$WIN_RAW" | cut -d',' -f1)
    WIN_TOTAL=$(echo "$WIN_RAW" | cut -d',' -f2)
    WIN_FREE=$(echo "$WIN_TOTAL - $WIN_USED" | bc 2>/dev/null)
    WIN_DISK="${WIN_USED}GB / ${WIN_TOTAL}GB"
    if [ -n "$WIN_FREE" ] && (( $(echo "$WIN_FREE < 5" | bc -l 2>/dev/null || echo 0) )); then
      WIN_DISK_BAIXO=true
    fi
  fi
fi

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
  "load": "$LOAD",
  "memory": "$MEMORY",
  "disk": "$DISK",
  "win_disk": "$WIN_DISK",
  "win_disk_baixo": $WIN_DISK_BAIXO,
  "public_ip": "$PUBLIC_IP",
  "apache": $APACHE,
  "cloudflared": $CLOUDFLARED,
  "docker": $DOCKER,
  "containers": $CONTAINERS,
  "ram_test": $RAM_TEST,
  "updated_at": "$UPDATED_AT"
}
JSON
