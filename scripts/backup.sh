#!/usr/bin/env bash
# Backup dos dados que não podem ser recriados:
#   - configuração do servidor (.env)
#   - dados do monitoramento (Uptime Kuma)
#   - certificados HTTPS (Caddy)
# Mantém os backups dos últimos 7 dias em ./backups
#
# Uso (no servidor): ./scripts/backup.sh
# Agendar todo dia às 3h: crontab -e  e adicionar
#   0 3 * * * /opt/projeto-devops/scripts/backup.sh >> /opt/projeto-devops/backup.log 2>&1
set -euo pipefail
cd "$(dirname "$0")/.."

DESTINO="$PWD/backups"
DATA="$(date +%Y-%m-%d_%H%M)"
mkdir -p "$DESTINO"

cp .env "$DESTINO/env-$DATA"

for volume in kuma_data caddy_data; do
  docker run --rm \
    -v "projeto-devops_${volume}:/dados:ro" \
    -v "$DESTINO:/backup" \
    alpine tar czf "/backup/${volume}-${DATA}.tar.gz" -C /dados .
done

find "$DESTINO" -type f -mtime +7 -delete
echo "Backup concluído em $DESTINO:"
ls -lh "$DESTINO" | tail -n +2
