#!/usr/bin/env bash
# Diagnóstico rápido do ambiente. Responde às perguntas do monitoramento:
#   A aplicação está online? O servidor está funcionando?
#   Os contêineres estão funcionando? Aconteceu algum erro?
#
# Uso (no servidor): ./scripts/status.sh
cd "$(dirname "$0")/.." || exit 1

DOMAIN="$(grep -E '^DOMAIN=' .env 2>/dev/null | cut -d= -f2)"

echo "== 1. A aplicação está online?"
if curl -fs -o /dev/null -w "   https://$DOMAIN/health -> HTTP %{http_code} em %{time_total}s\n" --max-time 10 "https://$DOMAIN/health"; then
  echo "   Versão no ar: $(curl -fsS --max-time 10 "https://$DOMAIN/version.json" | grep commitCurto | tr -d ' ",')"
else
  echo "   FORA DO AR (ou DNS/HTTPS com problema)"
fi

echo
echo "== 2. O servidor está funcionando?"
echo "   Ligado há: $(uptime -p)"
echo "   Carga (1/5/15 min): $(cut -d' ' -f1-3 /proc/loadavg)"
free -h | awk 'NR==2 {print "   Memória: " $3 " usados de " $2}'
df -h / | awk 'NR==2 {print "   Disco: " $3 " usados de " $2 " (" $5 ")"}'

echo
echo "== 3. Os contêineres estão funcionando?"
docker compose ps --format "   {{.Service}}: {{.Status}}"

echo
echo "== 4. Últimas linhas de log"
docker compose logs --tail 5 --no-log-prefix app caddy 2>&1 | sed 's/^/   /'

echo
echo "== 5. Últimos deploys"
tail -n 5 deploy.log 2>/dev/null | sed 's/^/   /' || echo "   (nenhum deploy registrado ainda)"
