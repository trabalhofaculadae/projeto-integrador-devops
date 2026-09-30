# Documentação do Projeto Integrador — Cloud & DevOps

Disciplina: **DevOps e Computação em Nuvem** · Ciência da Computação · 2026.2 · Prof. Claudio Castelo

> Os campos marcados com ⚠️ precisam ser preenchidos com os dados reais do nosso ambiente.

**Sumário**

1. [Descrição da aplicação](#1-descrição-da-aplicação)
2. [Arquitetura do ambiente](#2-arquitetura-do-ambiente)
3. [Tecnologias utilizadas](#3-tecnologias-utilizadas)
4. [Estrutura do projeto](#4-estrutura-do-projeto)
5. [Processo de instalação](#5-processo-de-instalação)
6. [Processo de deploy](#6-processo-de-deploy)
7. [Configuração do Docker](#7-configuração-do-docker)
8. [Configuração do DNS](#8-configuração-do-dns)
9. [Configuração do HTTPS](#9-configuração-do-https)
10. [Processo de CI/CD](#10-processo-de-cicd)
11. [Monitoramento](#11-monitoramento)
12. [Procedimentos básicos de recuperação](#12-procedimentos-básicos-de-recuperação)

---

## 1. Descrição da aplicação

Uma página web simples que mostra o nome da disciplina e o nome completo de todos os integrantes do grupo. A página também mostra:

- **se a aplicação está online**: ela consulta o endereço `/health` do próprio servidor;
- **qual versão está no ar**: o commit do Git e a data do build, lidos de `/version.json`.

Com isso, dá para ver na própria página que um deploy aconteceu: depois de um `git push`, o código do commit no rodapé muda sozinho.

| Endereço | O que retorna |
|---|---|
| `/` | Página inicial |
| `/health` | `ok` quando a aplicação está funcionando (usado pelo Docker, pelo pipeline e pelo monitoramento) |
| `/version.json` | Commit e data do build da versão publicada |

Os dados da página (disciplina, professor e integrantes) ficam em um único arquivo, `app/src/dados.json`. O build preenche a página com eles.

---

## 2. Arquitetura do ambiente

```
                        ┌──────────────────────────┐
  Desenvolvedor ──push──▶ GitHub (repositório)     │
                        │   └─ GitHub Actions ─────┼──▶ GHCR (imagens Docker)
                        └───────────┬──────────────┘            │
                                    │ SSH (deploy)              │ docker pull
                                    ▼                           ▼
  Usuário ──https──▶ DNS ──▶ ┌────────────────── VPS Ubuntu ──────────────────┐
                             │ Firewall UFW: libera só 22, 80 e 443           │
                             │                                                │
                             │  caddy (80/443) ──▶ app (Nginx + site)         │
                             │        └─────────▶ uptime-kuma (monitoramento) │
                             └────────────────────────────────────────────────┘
```

### Ambiente de nuvem

| Item | Valor |
|---|---|
| Provedor | ⚠️ Hostinger (VPS) |
| Plano | ⚠️ ex.: KVM 1 |
| Sistema operacional | ⚠️ Ubuntu 24.04 LTS |
| Recursos da máquina | ⚠️ vCPU: __ · RAM: __ GB · Disco: __ GB |
| IP público | ⚠️ ___.___.___.___ |
| Domínio da aplicação | ⚠️ |
| Domínio do monitoramento | ⚠️ monitor.______ |
| Localização do datacenter | ⚠️ |

Para conferir os recursos direto no servidor:

```bash
cat /etc/os-release   # sistema operacional
nproc                 # quantidade de CPUs
free -h               # memória RAM
df -h /               # disco
curl -4 ifconfig.me   # IP público
```

### Portas utilizadas

| Porta | Protocolo | Quem usa | Aberta para a internet? |
|---|---|---|---|
| 22 | TCP | SSH (administração e deploy) | Sim (só com chave ou senha) |
| 80 | TCP | Caddy: redireciona para HTTPS e valida o certificado | Sim |
| 443 | TCP e UDP | Caddy: HTTPS (HTTP/2 e HTTP/3) | Sim |
| 80 | TCP | Contêiner `app` (Nginx) | **Não**, só na rede interna do Docker |
| 3001 | TCP | Contêiner `uptime-kuma` | **Não**, só na rede interna do Docker |

### Forma de acesso ao ambiente

- **Administração:** SSH, com `ssh root@IP_DO_SERVIDOR` (ou com o usuário administrativo do grupo).
- **Deploy automático:** o GitHub Actions entra por SSH como o usuário `deploy`, com uma chave exclusiva. Essa chave só pode executar `scripts/deploy-remoto.sh` (opção `command=` no `authorized_keys`).
- **Monitoramento:** pelo navegador, em `https://monitor.SEU-DOMINIO`, com usuário e senha.

---

## 3. Tecnologias utilizadas

| Tecnologia | Para que usamos |
|---|---|
| **Git e GitHub** | Versionamento do código e colaboração (branches e Pull Requests) |
| **GitHub Actions** | Pipeline de CI/CD e monitoramento externo |
| **Node.js 22** | Build do site e testes automatizados (sem dependências externas) |
| **Docker** | Empacotar a aplicação em uma imagem que roda igual em qualquer lugar |
| **Docker Compose** | Descrever e subir os serviços do servidor (app, caddy e uptime-kuma) |
| **GitHub Container Registry (GHCR)** | Guardar as imagens Docker da aplicação |
| **Nginx** | Servidor web dentro do contêiner da aplicação |
| **Caddy** | Proxy reverso com HTTPS automático (Let's Encrypt) |
| **Uptime Kuma** | Painel de monitoramento e alertas |
| **Ubuntu Linux** | Sistema operacional do servidor |
| **UFW e Fail2ban** | Firewall e bloqueio de tentativas de invasão por SSH |

---

## 4. Estrutura do projeto

```
.
├── app/
│   ├── src/
│   │   ├── dados.json        Disciplina, professor e integrantes
│   │   ├── index.html        Modelo da página (com campos {{...}})
│   │   ├── style.css         Estilo da página
│   │   └── app.js            Mostra o status e a versão na página
│   ├── tests/site.test.js    Testes automatizados
│   ├── build.js              Gera o site em app/dist/
│   ├── nginx.conf            Configuração do Nginx
│   └── package.json          Comandos npm run build e npm test
├── caddy/Caddyfile           Proxy reverso e HTTPS
├── scripts/
│   ├── setup-servidor.sh     Prepara a VPS
│   ├── deploy.sh             Deploy com rollback automático
│   ├── deploy-remoto.sh      Porta de entrada do pipeline no servidor
│   ├── smoke-test.sh         Teste da imagem Docker
│   ├── status.sh             Diagnóstico do ambiente
│   └── backup.sh             Backup dos dados
├── .github/workflows/
│   ├── ci-cd.yml             Pipeline de CI/CD
│   └── monitoramento.yml     Verificação externa a cada 30 minutos
├── Dockerfile
├── docker-compose.yml        Produção
├── docker-compose.local.yml  Desenvolvimento local
├── .env.example              Modelo do .env do servidor
├── .gitignore
└── .dockerignore
```

---

## 5. Processo de instalação

### 5.1 No computador (desenvolvimento)

Pré-requisitos: Git, Docker Desktop e Node.js 22.

```bash
git clone https://github.com/trabalhofaculadae/projeto-integrador-devops.git
cd projeto-integrador-devops
docker compose -f docker-compose.local.yml up --build
# abrir http://localhost:8080
```

### 5.2 No servidor (produção)

1. Criar a VPS com **Ubuntu 24.04** e acessar por SSH como root.
2. Rodar o script de preparação, informando o domínio e o e-mail. Ele instala o Docker, liga o firewall, cria o usuário `deploy`, baixa o projeto, gera a chave do pipeline, preenche o `.env` e sobe o ambiente:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/trabalhofaculadae/projeto-integrador-devops/main/scripts/setup-servidor.sh -o setup.sh
   sudo bash setup.sh https://github.com/trabalhofaculadae/projeto-integrador-devops.git SEU-DOMINIO seu@email.com
   ```

3. Cadastrar no GitHub os 3 Secrets que o script mostra no final (`SSH_HOST`, `SSH_KNOWN_HOSTS` e `SSH_PRIVATE_KEY`).
4. Conferir o arquivo de configuração gerado (e ajustar, se precisar):

   ```bash
   nano /opt/projeto-devops/.env
   ```

   | Variável | Exemplo | Para que serve |
   |---|---|---|
   | `IMAGE` | `ghcr.io/trabalhofaculadae/projeto-integrador-devops` | Imagem da aplicação (o script já preenche) |
   | `IMAGE_TAG` | `latest` | Versão em produção (o deploy atualiza) |
   | `DOMAIN` | `meusite.com.br` | Domínio da aplicação |
   | `MONITOR_DOMAIN` | `monitor.meusite.com.br` | Domínio do monitoramento |
   | `ACME_EMAIL` | `email@exemplo.com` | E-mail para a Let's Encrypt |

5. Se o `.env` for alterado, recriar o ambiente e conferir:

   ```bash
   cd /opt/projeto-devops
   sudo -u deploy docker compose up -d
   sudo -u deploy ./scripts/status.sh
   ```

---

## 6. Processo de deploy

O deploy é **automático**: acontece a cada push na branch `main`, pelo pipeline (seção 10). No servidor, quem faz o trabalho é o `scripts/deploy.sh`:

1. Atualiza os arquivos de configuração com `git pull`.
2. **Baixa a imagem nova antes de mexer na produção.** Se não conseguir, para e não altera nada.
3. Grava a nova versão no `.env` (`IMAGE_TAG=sha-xxxxxxx`) e troca o contêiner com `docker compose up -d`.
4. Espera o contêiner ficar **saudável** (healthcheck).
5. Se não ficar saudável em 60 segundos, **volta para a versão anterior** (rollback) e o pipeline falha.

Cada deploy fica registrado em `/opt/projeto-devops/deploy.log`.

**Deploy manual** (por exemplo, se o GitHub Actions estiver fora do ar):

```bash
cd /opt/projeto-devops
sudo -u deploy ./scripts/deploy.sh sha-1a2b3c4   # tag de uma imagem publicada no GHCR
```

**Por que o deploy é seguro:** o GitHub Actions usa uma chave SSH criada só para ele. No servidor, essa chave está presa ao script `deploy-remoto.sh` (opção `command=` do `authorized_keys`), que aceita um único formato de pedido: `deploy sha-<commit>`. Se a chave vazar, ela não abre um terminal nem executa outros comandos.

---

## 7. Configuração do Docker

### 7.1 Dockerfile (imagem da aplicação)

A imagem é construída em **duas etapas** (multi-stage build):

| Etapa | Imagem base | O que faz |
|---|---|---|
| `build` | `node:22-alpine` | Gera o site (`npm run build`) e roda os testes (`npm test`). Se um teste falhar, a imagem não é criada. |
| final | `nginx:1.27-alpine` | Recebe só o site pronto e a configuração do Nginx. Não leva o Node, então fica pequena (cerca de 70 MB). |

A imagem tem um **HEALTHCHECK**: a cada 30 segundos o Docker acessa `/health` dentro do contêiner e marca o contêiner como `healthy` ou `unhealthy`.

Boas práticas aplicadas: imagens `alpine` (enxutas), versões fixas (`node:22`, `nginx:1.27`, e não `latest`), `.dockerignore` para não copiar `.git` e `.env`, nenhum segredo dentro da imagem, e uma função por contêiner.

### 7.2 Docker Compose (produção)

| Serviço | Imagem | Portas publicadas | Volume |
|---|---|---|---|
| `app` | `ghcr.io/.../projeto-integrador-devops:<tag>` | nenhuma | nenhum (o contêiner é descartável) |
| `caddy` | `caddy:2-alpine` | 80, 443/tcp e 443/udp | `caddy_data` (certificados) |
| `uptime-kuma` | `louislam/uptime-kuma:1` | nenhuma | `kuma_data` (monitores e histórico) |

Os três serviços ficam na rede interna `web`. O Caddy encontra os outros pelo nome (`app:80`, `uptime-kuma:3001`). Todos usam `restart: unless-stopped`: se o contêiner cair ou o servidor reiniciar, ele volta sozinho.

> **Cuidado com Docker e UFW:** portas publicadas com `ports:` no Docker passam por fora das regras do UFW. Por isso só o Caddy publica portas, e só as que o firewall também libera (80 e 443).

### 7.3 Comandos úteis

```bash
docker compose ps                  # serviços e status (healthy / unhealthy)
docker compose logs -f app         # logs da aplicação em tempo real
docker compose pull app            # baixa a imagem configurada no .env
docker compose up -d               # cria/atualiza os contêineres
docker compose restart app         # reinicia a aplicação
docker images                      # imagens baixadas no servidor
```

---

## 8. Configuração do DNS

**Domínio → DNS → IP/Servidor → Aplicação**

1. O usuário digita o **domínio** no navegador.
2. O **DNS** traduz o domínio para o **IP público da VPS**, através de um registro do tipo **A**.
3. O acesso chega ao **servidor** nas portas 80/443, onde o **Caddy** atende.
4. O Caddy encaminha para o contêiner da **aplicação**.

Registros criados no painel de DNS (⚠️ preencher com os dados reais):

| Tipo | Nome | Valor | Para quê |
|---|---|---|---|
| A | `@` (ou o subdomínio escolhido) | ⚠️ IP da VPS | Aplicação |
| A | `monitor` | ⚠️ IP da VPS | Painel de monitoramento |

Provedor do DNS: ⚠️ (ex.: Cloudflare, Hostinger ou Registro.br)

> **Se o DNS estiver na Cloudflare:** deixe os registros como **"DNS only"** (nuvem cinza) para o Caddy conseguir emitir o certificado. Depois, se quiser usar o proxy da Cloudflare (nuvem laranja), configure o SSL/TLS da Cloudflare no modo **Full (strict)**.

Como demonstrar que o DNS funciona:

```bash
nslookup SEU-DOMINIO          # deve responder o IP da VPS
dig +short SEU-DOMINIO A      # (Linux/Mac) mesmo teste, só com o IP
```

---

## 9. Configuração do HTTPS

O HTTPS é feito pelo **Caddy**, com certificados **Let's Encrypt** emitidos e renovados automaticamente. A configuração fica em `caddy/Caddyfile`:

```
{$DOMAIN} {
    reverse_proxy app:80
}
```

- Na primeira vez que sobe, o Caddy prova para a Let's Encrypt que controla o domínio (desafio pela porta 80) e recebe um **certificado SSL/TLS válido**.
- O certificado é **renovado sozinho** antes de vencer e fica guardado no volume `caddy_data`.
- Todo acesso por `http://` é **redirecionado** para `https://` (código 308).
- O Caddy envia o cabeçalho **HSTS** (`Strict-Transport-Security`), que faz o navegador usar sempre HTTPS. Ele também remove o cabeçalho `Server`.

Como verificar o certificado:

```bash
curl -vI https://SEU-DOMINIO 2>&1 | grep -E "subject|issuer|expire"
```

No navegador: clique no **cadeado** → "A conexão é segura" → "O certificado é válido".

---

## 10. Processo de CI/CD

Arquivo: `.github/workflows/ci-cd.yml`

```
git push ─▶ 1. Build e testes ─▶ 2. Imagem Docker ──────────────────────────▶ 3. Deploy
            • npm run build      • docker build                               • SSH no servidor
            • npm test           • smoke test (sobe o contêiner e testa)      • deploy.sh (com rollback)
                                 • docker push para o GHCR (sha-xxxxxxx e latest) • confere a versão no ar
```

| Quando | O que roda |
|---|---|
| Pull Request para a `main` | Só o job 1 (CI): valida o código antes do merge |
| Push na `main` | Os 3 jobs (CI + CD) |
| Manual (botão "Run workflow") | Os 3 jobs |

**Tags das imagens:** cada imagem recebe a tag `sha-<7 primeiros caracteres do commit>` (por exemplo, `sha-1a2b3c4`) e também `latest`. O deploy usa sempre a tag do commit, para saber exatamente qual versão está no ar e poder voltar para qualquer uma delas.

**"Falhar cedo":** se o build, um teste ou o smoke test falhar, o pipeline para ali e fica vermelho. A imagem não é publicada e a produção continua com a versão anterior.

### Configuração no GitHub

**Secrets** (Settings → Secrets and variables → Actions → Secrets):

| Nome | Conteúdo |
|---|---|
| `SSH_HOST` | IP da VPS |
| `SSH_KNOWN_HOSTS` | Identidade do servidor (evita conectar num servidor falso) |
| `SSH_PRIVATE_KEY` | Chave privada exclusiva do pipeline |

**Variables** (mesma tela, aba Variables):

| Nome | Valor |
|---|---|
| `DOMAIN` | Domínio da aplicação |
| `DEPLOY_ENABLED` | `true` (liga o job de deploy) |

O `GITHUB_TOKEN`, usado para publicar a imagem no GHCR, é criado automaticamente pelo GitHub a cada execução. O workflow pede só a permissão necessária: `packages: write`.

### Como demonstrar

1. Alterar um texto em `app/src/index.html`, fazer `git commit` e `git push`.
2. Acompanhar na aba **Actions** os 3 jobs ficarem verdes.
3. Atualizar a página: o **commit no rodapé** passa a ser o do push.
4. Para mostrar o CI barrando um erro: repetir um nome em `app/src/dados.json` (o teste "sem nomes repetidos" falha), ou trocar o `FROM` do Dockerfile por uma imagem que não existe. O pipeline fica vermelho e o site continua na versão anterior.

---

## 11. Monitoramento

Usamos **três camadas**:

| Camada | Ferramenta | O que verifica |
|---|---|---|
| Dentro do contêiner | **HEALTHCHECK do Docker** | A cada 30 s acessa `/health`. O status aparece em `docker compose ps` |
| No servidor | **Uptime Kuma** (`https://monitor.SEU-DOMINIO`) | Disponibilidade da aplicação, tempo de resposta, validade do certificado e histórico |
| Fora do servidor | **GitHub Actions** (`monitoramento.yml`) | A cada 30 minutos, uma máquina externa acessa o site. Se falhar, o GitHub avisa por e-mail |

### Monitores configurados no Uptime Kuma

| Monitor | Tipo | Alvo |
|---|---|---|
| Aplicação (HTTPS público) | HTTP(s) | `https://SEU-DOMINIO/health` |
| Contêiner app (rede interna) | HTTP(s) | `http://app/health` |
| Página inicial | HTTP(s) - Palavra-chave | `https://SEU-DOMINIO` contendo `DevOps e Computação em Nuvem` |
| Certificado HTTPS | (opção "Notificar expiração do certificado" no monitor HTTPS) | aviso antes de vencer |

### Respondendo às perguntas do monitoramento

| Pergunta | Como responder |
|---|---|
| **A aplicação está online?** | Painel do Uptime Kuma, ou `curl https://SEU-DOMINIO/health` → `ok` |
| **O servidor está funcionando?** | O workflow externo verde no GitHub, `ssh` respondendo, e `./scripts/status.sh` (uptime, memória e disco) |
| **O contêiner está funcionando?** | `docker compose ps` mostra `Up (healthy)`, e o monitor "Contêiner app" no Kuma |
| **Como identificar uma indisponibilidade?** | O Kuma marca o monitor em vermelho e envia um alerta. O workflow externo falha e o GitHub manda e-mail. O `status.sh` e o `docker compose logs` mostram a causa |

O script `scripts/status.sh` junta todas essas respostas num comando só.

---

## 12. Procedimentos básicos de recuperação

| Problema | O que fazer |
|---|---|
| **Versão nova com defeito** | O `deploy.sh` já volta sozinho para a anterior. Para voltar manualmente a qualquer versão: `sudo -u deploy ./scripts/deploy.sh sha-<commit antigo>` |
| **Site fora do ar** | `./scripts/status.sh` → `docker compose ps` → `docker compose logs --tail 50 app caddy` → `docker compose up -d` |
| **Contêiner parado ou unhealthy** | `docker compose restart app`. Se continuar, ver os logs e fazer rollback |
| **Servidor reiniciou** | Nada: o Docker inicia com o sistema, e os serviços têm `restart: unless-stopped` |
| **Certificado HTTPS com erro** | Conferir se o DNS aponta para a VPS e se as portas 80/443 estão abertas. Ver `docker compose logs caddy`. Depois, `docker compose restart caddy` |
| **Disco cheio** | `df -h` e `docker system df`. Limpar imagens antigas: `docker image prune -a` (cuidado: remove as imagens usadas para rollback) |
| **Pipeline sem conseguir entrar no servidor** | Conferir os Secrets `SSH_HOST`, `SSH_KNOWN_HOSTS` e `SSH_PRIVATE_KEY`. Fazer o deploy manual enquanto isso |
| **Perda do servidor** | Criar uma VPS nova, rodar o `setup-servidor.sh`, restaurar o `.env` e os volumes do backup, apontar o DNS para o novo IP |

### Backup

O `scripts/backup.sh` salva o `.env`, os dados do Uptime Kuma e os certificados em `/opt/projeto-devops/backups`, e guarda os últimos 7 dias. Para agendar todo dia às 3h (`crontab -e` como usuário `deploy`):

```
0 3 * * * /opt/projeto-devops/scripts/backup.sh >> /opt/projeto-devops/backup.log 2>&1
```

O **código** não precisa de backup no servidor: ele está no GitHub. As **imagens** também estão guardadas no GHCR.

**Restaurar os dados do Uptime Kuma a partir de um backup:**

```bash
cd /opt/projeto-devops
docker compose stop uptime-kuma
docker run --rm -v projeto-devops_kuma_data:/dados -v "$PWD/backups":/backup alpine \
  sh -c "rm -rf /dados/* && tar xzf /backup/kuma_data-AAAA-MM-DD_HHMM.tar.gz -C /dados"
docker compose start uptime-kuma
```
