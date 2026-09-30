# Imagem da aplicação, construída em duas etapas (multi-stage build).

# Etapa 1 — build e testes: gera o site em dist/ com o Node.
# Se algum teste falhar, a imagem não é criada.
FROM node:22-alpine AS build
WORKDIR /app
COPY app/package.json app/build.js ./
COPY app/src ./src
COPY app/tests ./tests
ARG GIT_SHA=local
ENV GIT_SHA=$GIT_SHA
RUN npm run build && npm test

# Etapa 2 — imagem final: só o Nginx com o site pronto (sem Node, bem menor).
FROM nginx:1.27-alpine
COPY app/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
# O Docker verifica sozinho, a cada 30 s, se a aplicação está respondendo
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/health || exit 1
