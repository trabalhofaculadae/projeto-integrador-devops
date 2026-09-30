// Build do site: gera a pasta dist/ a partir de src/.
// - Preenche o index.html com os dados de src/dados.json
// - Grava version.json com o commit e a data do build
// Não usa nenhuma dependência externa: só o Node.

const fs = require("node:fs");
const path = require("node:path");

const SRC = path.join(__dirname, "src");
const DIST = path.join(__dirname, "dist");

function escaparHtml(texto) {
  return String(texto)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function build() {
  const dados = JSON.parse(fs.readFileSync(path.join(SRC, "dados.json"), "utf8"));
  const commit = process.env.GIT_SHA || "local";
  const commitCurto = commit === "local" ? "local" : commit.slice(0, 7);
  const dataBuild = new Date().toISOString();

  const integrantes = dados.integrantes
    .map((nome) => `        <li>${escaparHtml(nome)}</li>`)
    .join("\n");

  const valores = {
    DISCIPLINA: escaparHtml(dados.disciplina),
    PROJETO: escaparHtml(dados.projeto),
    CURSO: escaparHtml(dados.curso),
    INSTITUICAO: escaparHtml(dados.instituicao),
    PROFESSOR: escaparHtml(dados.professor),
    SEMESTRE: escaparHtml(dados.semestre),
    INTEGRANTES: integrantes,
    COMMIT_CURTO: commitCurto,
    DATA_BUILD: dataBuild,
  };

  let html = fs.readFileSync(path.join(SRC, "index.html"), "utf8");
  for (const [chave, valor] of Object.entries(valores)) {
    html = html.replaceAll(`{{${chave}}}`, valor);
  }

  fs.rmSync(DIST, { recursive: true, force: true });
  fs.mkdirSync(DIST, { recursive: true });
  fs.writeFileSync(path.join(DIST, "index.html"), html);
  fs.copyFileSync(path.join(SRC, "style.css"), path.join(DIST, "style.css"));
  fs.copyFileSync(path.join(SRC, "app.js"), path.join(DIST, "app.js"));
  fs.writeFileSync(
    path.join(DIST, "version.json"),
    JSON.stringify({ commit, commitCurto, dataBuild }, null, 2) + "\n"
  );

  console.log(`Build concluído em dist/ (commit ${commitCurto}, ${dados.integrantes.length} integrantes)`);
}

build();
