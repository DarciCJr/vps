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
POWERSHELL="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
if [ -x "$POWERSHELL" ]; then
  WIN_RAW=$("$POWERSHELL" -NoProfile -Command '$d=Get-PSDrive C; "{0};{1}" -f [math]::Round($d.Used/1GB,1), [math]::Round(($d.Used+$d.Free)/1GB,1)' 2>/dev/null | tr -d '\r')
  if [ -n "$WIN_RAW" ]; then
    WIN_USED=$(echo "$WIN_RAW" | cut -d';' -f1 | tr ',' '.')
    WIN_TOTAL=$(echo "$WIN_RAW" | cut -d';' -f2 | tr ',' '.')
    WIN_FREE=$(echo "$WIN_TOTAL - $WIN_USED" | bc 2>/dev/null)
    WIN_DISK="${WIN_USED}GB / ${WIN_TOTAL}GB"
    if [ -n "$WIN_FREE" ] && (( $(echo "$WIN_FREE < 5" | bc -l 2>/dev/null || echo 0) )); then
      WIN_DISK_BAIXO=true
    fi
  fi
fi

# Placa de vídeo (GPU) — uso, VRAM e temperatura em tempo real.
GPU_USO="indisponível"
GPU_VRAM="indisponível"
GPU_TEMP="indisponível"
# Caminho absoluto: o cron roda com PATH mínimo e não acha o nvidia-smi do WSL.
NVIDIA_SMI="/usr/lib/wsl/lib/nvidia-smi"
[ -x "$NVIDIA_SMI" ] || NVIDIA_SMI=$(command -v nvidia-smi 2>/dev/null)
if [ -n "$NVIDIA_SMI" ] && [ -x "$NVIDIA_SMI" ]; then
  GPU_RAW=$("$NVIDIA_SMI" --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
  if [ -n "$GPU_RAW" ]; then
    GPU_UTIL=$(echo "$GPU_RAW" | cut -d',' -f1 | xargs)
    GPU_MEM_USADA=$(echo "$GPU_RAW" | cut -d',' -f2 | xargs)
    GPU_MEM_TOTAL=$(echo "$GPU_RAW" | cut -d',' -f3 | xargs)
    GPU_TEMP_RAW=$(echo "$GPU_RAW" | cut -d',' -f4 | xargs)
    GPU_USO="${GPU_UTIL}%"
    GPU_VRAM="${GPU_MEM_USADA}MB / ${GPU_MEM_TOTAL}MB"
    GPU_TEMP="${GPU_TEMP_RAW}°C"
  fi
fi

# Pentes de memória RAM instalados — confirma que todos os pentes físicos
# estão sendo reconhecidos pelo Windows (útil após o susto de hardware).
RAM_PENTES="indisponível"
if [ -x "$POWERSHELL" ]; then
  RAM_RAW=$("$POWERSHELL" -NoProfile -Command '$m = Get-CimInstance Win32_PhysicalMemory; "{0};{1}" -f $m.Count, [math]::Round(($m | Measure-Object -Property Capacity -Sum).Sum/1GB,0)' 2>/dev/null | tr -d '\r')
  if [ -n "$RAM_RAW" ]; then
    RAM_QTD=$(echo "$RAM_RAW" | cut -d';' -f1)
    RAM_TOTAL_GB=$(echo "$RAM_RAW" | cut -d';' -f2)
    RAM_PENTES="${RAM_QTD} pente(s) — ${RAM_TOTAL_GB}GB no total"
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
  "gpu_uso": "$GPU_USO",
  "gpu_vram": "$GPU_VRAM",
  "gpu_temp": "$GPU_TEMP",
  "ram_pentes": "$RAM_PENTES",
  "public_ip": "$PUBLIC_IP",
  "apache": $APACHE,
  "cloudflared": $CLOUDFLARED,
  "docker": $DOCKER,
  "containers": $CONTAINERS,
  "ram_test": $RAM_TEST,
  "updated_at": "$UPDATED_AT"
}
JSON
