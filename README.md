# Projeto Integrador — Cloud & DevOps

Aplicação web da disciplina **DevOps e Computação em Nuvem** (Ciência da Computação · 2026.2 · Prof. Claudio Castelo), publicada em nuvem com Docker, HTTPS, CI/CD e monitoramento.

| | |
|---|---|
| **Aplicação** | https://SEU-DOMINIO ⚠️ *preencher* |
| **Monitoramento** | https://monitor.SEU-DOMINIO ⚠️ *preencher* |
| **Pipeline** | aba **Actions** deste repositório |
| **Documentação completa** | [docs/DOCUMENTACAO.md](docs/DOCUMENTACAO.md) |

## Integrantes

- Agnaldo Santos Silva Júnior
- Artur Oliveira Ximenes De Almeida
- Carlos Eduardo Passos Silva
- Eduardo Micael Saraiva Maia
- Guilherme Cavalcante Bandeira
- Lucas Gabriel Barreto Oliveira
- Ricardo Amorin Machado Junior

## Arquitetura

```
 Usuário
    │  https://SEU-DOMINIO
    ▼
 DNS (registro A) ──▶ IP público da VPS
                          │
          ┌───────────────┴────────────────────────────┐
          │ VPS Ubuntu · firewall: só 22, 80 e 443     │
          │                                            │
          │   Caddy (portas 80/443, HTTPS automático)  │
          │     ├──▶ app  (Nginx + site)               │
          │     └──▶ uptime-kuma (monitoramento)       │
          └────────────────────────────────────────────┘
```

**Código → Imagem → Contêiner → Aplicação**

1. **Código:** o site fica em `app/src/` e é versionado no Git.
2. **Imagem:** o `Dockerfile` gera o site, roda os testes e empacota tudo numa imagem Nginx, publicada no GitHub Container Registry (GHCR).
3. **Contêiner:** no servidor, o Docker Compose cria o contêiner `app` a partir dessa imagem.
4. **Aplicação:** o Caddy recebe o acesso em HTTPS e encaminha para o contêiner.

## Pipeline de CI/CD

A cada `git push` na `main`, o GitHub Actions executa:

```
git push → build → testes → build da imagem → teste da imagem → publica no GHCR → deploy → verifica a versão no ar
```

- Em **Pull Requests** roda só o build e os testes, para validar antes do merge.
- O **deploy** acessa o servidor por SSH com uma chave que **só consegue rodar o deploy**.
- Se a versão nova não ficar saudável, o servidor **volta sozinho para a versão anterior** (rollback).

## Tecnologias

Git e GitHub · GitHub Actions · Docker e Docker Compose · GitHub Container Registry · Nginx · Caddy (HTTPS com Let's Encrypt) · Uptime Kuma · Node.js (build e testes) · Ubuntu · UFW e Fail2ban

## Estrutura do projeto

```
.
├── app/                      Aplicação web
│   ├── src/                  Código-fonte do site (HTML, CSS, JS e dados do grupo)
│   ├── tests/                Testes automatizados
│   ├── build.js              Build: gera o site em app/dist/
│   ├── nginx.conf            Configuração do Nginx dentro do contêiner
│   └── package.json          Comandos npm run build e npm test
├── caddy/Caddyfile           Proxy reverso e HTTPS
├── scripts/
│   ├── setup-servidor.sh     Prepara uma VPS nova (Docker, firewall, usuário, chave SSH)
│   ├── deploy.sh             Deploy com rollback automático
│   ├── deploy-remoto.sh      Único comando permitido para a chave do pipeline
│   ├── smoke-test.sh         Teste da imagem Docker
│   ├── status.sh             Diagnóstico do ambiente
│   └── backup.sh             Backup dos dados
├── .github/workflows/
│   ├── ci-cd.yml             Pipeline de CI/CD
│   └── monitoramento.yml     Verificação externa de disponibilidade
├── docs/                     Documentação
├── Dockerfile                Receita da imagem da aplicação
├── docker-compose.yml        Ambiente de produção
├── docker-compose.local.yml  Ambiente local
└── .env.example              Modelo de configuração do servidor
```

## Como rodar no seu computador

Com o Docker instalado:

```bash
docker compose -f docker-compose.local.yml up --build
```

Depois abra http://localhost:8080.

Para rodar só o build e os testes (precisa do Node.js 22):

```bash
cd app
npm run build
npm test
```

## Segurança

- O firewall deixa abertas só as portas **22 (SSH)**, **80 (HTTP)** e **443 (HTTPS)**. A aplicação e o monitoramento não publicam portas.
- Senhas e chaves ficam nos **GitHub Secrets** e no `.env` do servidor, que **não vai para o Git**.
- Todo acesso HTTP é redirecionado para **HTTPS**, com certificado válido da Let's Encrypt.
- O painel de monitoramento exige login.
