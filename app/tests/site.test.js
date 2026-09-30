// Testes automatizados do site (rodam com: npm test).
// Cada teste segue o padrão AAA: Arrange (preparar), Act (agir), Assert (verificar).
// Eles conferem o resultado do build, então rode "npm run build" antes.

const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const DIST = path.join(__dirname, "..", "dist");
const dados = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "src", "dados.json"), "utf8"));

function lerDist(arquivo) {
  const caminho = path.join(DIST, arquivo);
  assert.ok(fs.existsSync(caminho), `${arquivo} não existe em dist/. Rode "npm run build" antes dos testes.`);
  return fs.readFileSync(caminho, "utf8");
}

test("a página inicial mostra o nome da disciplina", () => {
  // Arrange
  const esperado = dados.disciplina;
  // Act
  const html = lerDist("index.html");
  // Assert
  assert.ok(html.includes(esperado), `A página não contém "${esperado}"`);
});

test("a página inicial mostra o nome completo de todos os integrantes", () => {
  const html = lerDist("index.html");
  for (const nome of dados.integrantes) {
    assert.ok(html.includes(nome), `Integrante ausente na página: ${nome}`);
  }
});

test("a lista de integrantes não tem nomes repetidos nem vazios", () => {
  const nomes = dados.integrantes.map((n) => n.trim());
  assert.ok(nomes.length > 0, "Nenhum integrante cadastrado");
  assert.ok(nomes.every((n) => n.length > 0), "Há um nome vazio na lista");
  assert.equal(new Set(nomes).size, nomes.length, "Há nomes repetidos na lista");
});

test("o build não deixou nenhum campo {{...}} sem preencher", () => {
  const html = lerDist("index.html");
  assert.doesNotMatch(html, /\{\{[A-Z_]+\}\}/);
});

test("a página tem a estrutura HTML básica", () => {
  const html = lerDist("index.html");
  assert.match(html, /^<!DOCTYPE html>/i);
  assert.match(html, /<html lang="pt-BR">/);
  assert.match(html, /<meta name="viewport"/);
  assert.match(html, /<title>[^<]+<\/title>/);
});

test("version.json informa o commit e a data do build", () => {
  const versao = JSON.parse(lerDist("version.json"));
  assert.ok(versao.commit, "version.json sem commit");
  assert.ok(versao.commitCurto, "version.json sem commitCurto");
  assert.ok(!Number.isNaN(Date.parse(versao.dataBuild)), "dataBuild não é uma data válida");
});

test("os arquivos de estilo e script foram gerados", () => {
  assert.ok(lerDist("style.css").length > 0);
  assert.ok(lerDist("app.js").length > 0);
});
