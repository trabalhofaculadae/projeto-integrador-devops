#!/usr/bin/env bash
# Smoke test da imagem: sobe um contêiner temporário e confere se ele responde.
# Usado no pipeline antes de publicar a imagem. Também dá para rodar localmente:
#   ./scripts/smoke-test.sh projeto-devops:teste
set -euo pipefail

IMAGEM="${1:?uso: smoke-test.sh <imagem> [commit esperado]}"
COMMIT_ESPERADO="${2:-}"
NOME="smoke-test-$$"
PORTA=18080
URL="http://127.0.0.1:$PORTA"

falhar() {
  echo "FALHOU: $1"
  docker logs "$NOME" 2>&1 | tail -20 || true
  exit 1
}

docker run -d --name "$NOME" -p "$PORTA:80" "$IMAGEM" >/dev/null
trap 'docker rm -f "$NOME" >/dev/null 2>&1 || true' EXIT

echo "Aguardando o contêiner responder..."
for _ in $(seq 1 20); do
  curl -fsS "$URL/health" >/dev/null 2>&1 && break
  sleep 1
done

[ "$(curl -fsS "$URL/health")" = "ok" ] || falhar "/health não respondeu \"ok\""
echo "✓ /health responde ok"

curl -fsS "$URL/" | grep -q "DevOps e Computação em Nuvem" || falhar "a página inicial não mostra o nome da disciplina"
echo "✓ a página inicial mostra a disciplina"

docker exec "$NOME" nginx -t >/dev/null 2>&1 || falhar "a configuração do Nginx é inválida"
echo "✓ a configuração do Nginx é válida"

if [ -n "$COMMIT_ESPERADO" ]; then
  curl -fsS "$URL/version.json" | grep -q "$COMMIT_ESPERADO" || falhar "version.json não mostra o commit $COMMIT_ESPERADO"
  echo "✓ version.json mostra o commit $COMMIT_ESPERADO"
fi

echo "Smoke test OK"
