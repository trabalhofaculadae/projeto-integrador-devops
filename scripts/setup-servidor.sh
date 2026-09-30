#!/usr/bin/env bash
# Prepara uma VPS Ubuntu nova para o projeto (rodar uma vez, como root).
#
# O que ele faz:
#   1. Atualiza o sistema
#   2. Instala o Docker pelo repositório oficial
#   3. Liga o firewall (UFW) deixando abertas só as portas 22, 80 e 443
#   4. Cria o usuário "deploy", que é quem roda os contêineres
#   5. Baixa o projeto do GitHub em /opt/projeto-devops e cria o .env
#   6. Cria a chave SSH exclusiva do GitHub Actions e mostra os Secrets
#   7. Se receber o domínio e o e-mail, preenche o .env e já sobe o ambiente
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/USUARIO/REPOSITORIO/main/scripts/setup-servidor.sh -o setup.sh
#   sudo bash setup.sh https://github.com/USUARIO/REPOSITORIO.git meusite.com.br meu@email.com
set -euo pipefail

REPO_URL="${1:?uso: sudo bash setup-servidor.sh <URL do repositório> [domínio] [e-mail]}"
DOMINIO="${2:-}"
EMAIL="${3:-}"
DIR=/opt/projeto-devops
USUARIO=deploy
MARCA_CHAVE="github-actions-deploy"

[ "$(id -u)" -eq 0 ] || { echo "Rode como root: sudo bash $0 $REPO_URL"; exit 1; }

echo "==> 1/7 Atualizando o sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl git ufw fail2ban

echo "==> 2/7 Instalando o Docker (repositório oficial)"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  CODINOME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODINOME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

echo "==> 3/7 Firewall: só SSH (22), HTTP (80) e HTTPS (443)"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable
systemctl enable --now fail2ban

echo "==> 4/7 Usuário de deploy"
if ! id "$USUARIO" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$USUARIO"
fi
groupadd -f docker
usermod -aG docker "$USUARIO"

echo "==> 5/7 Código do projeto em $DIR"
if [ ! -d "$DIR/.git" ]; then
  git clone "$REPO_URL" "$DIR"
fi
if [ ! -f "$DIR/.env" ]; then
  cp "$DIR/.env.example" "$DIR/.env"
  # Preenche a imagem a partir da URL do repositório: ghcr.io/usuario/repositorio
  CAMINHO="$(echo "$REPO_URL" | sed -E 's#^https://github.com/##; s#\.git$##' | tr '[:upper:]' '[:lower:]')"
  sed -i "s#^IMAGE=.*#IMAGE=ghcr.io/$CAMINHO#" "$DIR/.env"
fi
git -C "$DIR" config core.fileMode false
if [ -n "$DOMINIO" ]; then
  sed -i "s#^DOMAIN=.*#DOMAIN=$DOMINIO#; s#^MONITOR_DOMAIN=.*#MONITOR_DOMAIN=monitor.$DOMINIO#" "$DIR/.env"
fi
if [ -n "$EMAIL" ]; then
  sed -i "s#^ACME_EMAIL=.*#ACME_EMAIL=$EMAIL#" "$DIR/.env"
fi
chmod 600 "$DIR/.env"
chmod +x "$DIR"/scripts/*.sh
chown -R "$USUARIO:$USUARIO" "$DIR"

echo "==> 6/7 Chave SSH exclusiva do GitHub Actions"
SSH_DIR="/home/$USUARIO/.ssh"
install -d -m 700 -o "$USUARIO" -g "$USUARIO" "$SSH_DIR"
touch "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"
chown "$USUARIO:$USUARIO" "$SSH_DIR/authorized_keys"

IP="$(curl -fs -4 --max-time 10 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"

if grep -q "$MARCA_CHAVE" "$SSH_DIR/authorized_keys"; then
  echo "A chave do GitHub Actions já existe. Para gerar outra, apague a linha"
  echo "com \"$MARCA_CHAVE\" em $SSH_DIR/authorized_keys e rode o script de novo."
else
  TEMP="$(mktemp -d)"
  ssh-keygen -q -t ed25519 -N "" -C "$MARCA_CHAVE" -f "$TEMP/chave"
  # command= faz a chave só conseguir rodar o deploy-remoto.sh
  echo "command=\"bash $DIR/scripts/deploy-remoto.sh\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $(cat "$TEMP/chave.pub")" \
    >> "$SSH_DIR/authorized_keys"

  echo
  echo "================================================================"
  echo " Cadastre estes 3 Secrets no GitHub:"
  echo " Repositório > Settings > Secrets and variables > Actions > New repository secret"
  echo "================================================================"
  echo
  echo "Nome: SSH_HOST"
  echo "$IP"
  echo
  echo "Nome: SSH_KNOWN_HOSTS"
  echo "$IP $(cut -d' ' -f1,2 /etc/ssh/ssh_host_ed25519_key.pub)"
  echo
  echo "Nome: SSH_PRIVATE_KEY   (copie TODAS as linhas, inclusive BEGIN e END)"
  cat "$TEMP/chave"
  echo
  shred -u "$TEMP/chave" 2>/dev/null || rm -f "$TEMP/chave"
  rm -rf "$TEMP"
  echo "A chave privada foi apagada do servidor. Se perder, gere outra."
fi

echo
if [ -n "$DOMINIO" ] && [ -n "$EMAIL" ]; then
  echo "==> 7/7 Subindo o ambiente (app, caddy e uptime-kuma)"
  if (cd "$DIR" && runuser -u "$USUARIO" -- docker compose up -d); then
    echo
    echo "================================================================"
    echo " Pronto! Em cerca de 1 minuto, abra:"
    echo "   https://$DOMINIO            (aplicação)"
    echo "   https://monitor.$DOMINIO    (monitoramento: crie o login JÁ)"
    echo " Diagnóstico: cd $DIR && sudo -u $USUARIO ./scripts/status.sh"
    echo "================================================================"
  else
    echo "Não consegui subir o ambiente. Confira se a imagem no GHCR está pública"
    echo "e rode de novo: cd $DIR && sudo -u $USUARIO docker compose up -d"
  fi
else
  echo "================================================================"
  echo " Servidor pronto. Próximos passos:"
  echo "  1. Edite a configuração:   nano $DIR/.env"
  echo "  2. Suba o ambiente:        cd $DIR && sudo -u $USUARIO docker compose up -d"
  echo "  3. Confira:                sudo -u $USUARIO ./scripts/status.sh"
  echo "================================================================"
fi
