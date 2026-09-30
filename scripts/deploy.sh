#!/usr/bin/env bash
# Deploy no servidor: troca a aplicação para uma nova versão da imagem.
# Se a versão nova não ficar saudável, volta sozinho para a anterior (rollback).
#
# Uso (no servidor, dentro da pasta do projeto):
#   ./scripts/deploy.sh sha-1a2b3c4
set -euo pipefail

cd "$(dirname "$0")/.."

NOVA_TAG="${1:?uso: deploy.sh <tag da imagem, ex.: sha-1a2b3c4>}"
LOG="deploy.log"

registrar() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

definir_tag() { sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$1/" .env; }

esperar_saudavel() {
  local id estado
  for _ in $(seq 1 30); do
    id="$(docker compose ps -q app)"
    estado="$(docker inspect -f '{{.State.Health.Status}}' "$id" 2>/dev/null || echo "?")"
    [ "$estado" = "healthy" ] && return 0
    sleep 2
  done
  return 1
}

[ -f .env ] || { registrar "ERRO: arquivo .env não encontrado"; exit 1; }
TAG_ANTERIOR="$(grep -E '^IMAGE_TAG=' .env | cut -d= -f2)"
registrar "Início do deploy: $TAG_ANTERIOR -> $NOVA_TAG"

# 1. Atualiza os arquivos de configuração (compose, Caddyfile) a partir do GitHub
git pull --ff-only --quiet 2>>"$LOG" || registrar "Aviso: git pull falhou; seguindo com a configuração atual"

# 2. Baixa a imagem nova ANTES de mexer na produção
if ! IMAGE_TAG="$NOVA_TAG" docker compose pull --quiet app; then
  registrar "ERRO: não consegui baixar a imagem $NOVA_TAG. Nada foi alterado."
  exit 1
fi

# 3. Troca o contêiner pela versão nova
definir_tag "$NOVA_TAG"
docker compose up -d --remove-orphans
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true

# 4. Confere se a versão nova está saudável
if esperar_saudavel; then
  registrar "OK: versão $NOVA_TAG no ar"
  docker image prune -f >/dev/null
  exit 0
fi

# 5. Rollback: a versão nova não ficou saudável
registrar "ERRO: $NOVA_TAG não ficou saudável. Voltando para $TAG_ANTERIOR"
definir_tag "$TAG_ANTERIOR"
docker compose up -d app
if esperar_saudavel; then
  registrar "Rollback concluído: $TAG_ANTERIOR no ar"
else
  registrar "ATENÇÃO: o rollback também falhou. Verifique com ./scripts/status.sh"
fi
exit 1
