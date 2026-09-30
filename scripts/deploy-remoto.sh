#!/usr/bin/env bash
# Porta de entrada do GitHub Actions no servidor.
#
# A chave SSH do pipeline é cadastrada com a opção command= apontando para este
# script. Assim, mesmo que a chave vaze, ela só consegue fazer uma coisa:
# pedir o deploy de uma imagem com tag no formato sha-xxxxxxx.
set -euo pipefail

PEDIDO="${SSH_ORIGINAL_COMMAND:-}"

if [[ "$PEDIDO" =~ ^deploy\ (sha-[0-9a-f]{7,40})$ ]]; then
  exec bash "$(dirname "$0")/deploy.sh" "${BASH_REMATCH[1]}"
fi

echo "Comando não permitido: '$PEDIDO'" >&2
exit 1
