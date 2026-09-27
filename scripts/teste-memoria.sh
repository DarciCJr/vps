#!/bin/bash
# Testa 200MB de memória livre em busca de erros (memtester).
# Não afeta o resto do sistema — só usa um pedaço da RAM livre por alguns segundos.
# Rodado 1x por dia via cron (é um teste "pesado" pra rodar a cada minuto).

RESULTADO="/var/www/html/ram-test.json"

if ! command -v memtester >/dev/null 2>&1; then
  echo '{"status":"indisponivel","motivo":"memtester nao instalado"}' > "$RESULTADO"
  exit 0
fi

SAIDA=$(sudo memtester 200M 1 2>&1)

if echo "$SAIDA" | grep -q "FAILURE"; then
  STATUS="falhou"
elif echo "$SAIDA" | tail -1 | grep -q "Done"; then
  STATUS="ok"
else
  STATUS="incompleto"
fi

DATA=$(date '+%d/%m/%Y %H:%M:%S')

cat > "$RESULTADO" << JSON
{
  "status": "$STATUS",
  "testado_em": "$DATA"
}
JSON
