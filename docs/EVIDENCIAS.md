# Evidências da entrega (N1)

O professor pode validar o ambiente funcionando. Por isso, além das evidências abaixo, **o site, o monitoramento e o pipeline precisam estar no ar** no dia da avaliação.

Salve os prints na pasta `docs/evidencias/` e marque cada item quando estiver pronto.

## Links da entrega

- [ ] Repositório (público): https://github.com/trabalhofaculadae/projeto-integrador-devops
- [ ] Aplicação: https://projetodevops.online
- [ ] Monitoramento: https://monitor.projetodevops.online

## 1. Ambiente Cloud

- [ ] Print do console da AWS: EC2 → Instâncias → `projeto-devops` (tipo, IP, estado "Executando")
- [ ] Print do Security Group `projeto-devops-sg` com as regras de entrada (22, 80, 443)
- [ ] Print do Elastic IP `3.146.126.88` associado à instância
- [ ] Saída destes comandos no servidor:

  ```bash
  cat /etc/os-release | head -2
  nproc && free -h && df -h /
  sudo ufw status verbose
  ```

## 2. Docker

- [ ] Saída de `docker compose ps` mostrando os 3 serviços com `Up` e o app `(healthy)`
- [ ] Saída de `docker images` mostrando a imagem `ghcr.io/trabalhofaculadae/projeto-integrador-devops`
- [ ] Print do pacote no GitHub (perfil → Packages → projeto-integrador-devops)

## 3. DNS e HTTPS

- [ ] Saída de `nslookup projetodevops.online` mostrando o IP da VPS
- [ ] Print dos registros A no painel de DNS da Hostinger
- [ ] Print do cadeado do navegador com o certificado válido (emitido pela Let's Encrypt)
- [ ] Saída de `curl -I http://projetodevops.online` mostrando o redirecionamento 308 para HTTPS

## 4. Pipeline CI/CD

- [ ] Print da aba Actions com uma execução verde (os 3 jobs)
- [ ] Print de uma execução vermelha causada de propósito (o CI barrando um erro)
- [ ] Print de um Pull Request com o check do CI
- [ ] Antes e depois: a página com o commit antigo e com o commit novo no rodapé, depois de um push
- [ ] Trecho do `deploy.log` do servidor (`tail deploy.log`)

## 5. Monitoramento

- [ ] Print do painel do Uptime Kuma com os monitores verdes
- [ ] Print de um alerta de indisponibilidade (parar o app com `docker compose stop app`, esperar o alerta e subir de novo)
- [ ] Print do workflow "Monitoramento externo" executado com sucesso
- [ ] Saída do `./scripts/status.sh`

## 6. Segurança

- [ ] Saída de `sudo ufw status` (só 22, 80 e 443)
- [ ] Print da tela de Secrets do GitHub (só os nomes aparecem, os valores ficam ocultos)
- [ ] Confirmar que o `.env` **não** está no repositório
- [ ] Print da tela de login do Uptime Kuma
