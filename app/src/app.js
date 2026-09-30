// Mostra na página se a aplicação está respondendo e qual versão está no ar.

const status = document.getElementById("status");
const statusTexto = document.getElementById("status-texto");

async function verificarSaude() {
  try {
    const resposta = await fetch("/health", { cache: "no-store" });
    if (!resposta.ok) throw new Error("HTTP " + resposta.status);
    status.dataset.estado = "online";
    statusTexto.textContent = "Aplicação online";
  } catch (erro) {
    status.dataset.estado = "erro";
    statusTexto.textContent = "Não foi possível verificar a aplicação";
  }
}

async function mostrarVersao() {
  try {
    const resposta = await fetch("/version.json", { cache: "no-store" });
    const versao = await resposta.json();
    document.getElementById("versao").textContent = versao.commitCurto;
    const data = new Date(versao.dataBuild);
    document.getElementById("data-build").textContent = data.toLocaleString("pt-BR");
  } catch (erro) {
    // Se falhar, a página continua mostrando a versão gravada no build.
  }
}

verificarSaude();
mostrarVersao();
