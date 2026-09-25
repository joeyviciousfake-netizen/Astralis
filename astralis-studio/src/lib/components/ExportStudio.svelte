<script lang="ts">
  // ExportStudio — tela Exportar (doc 12 + bloco 7).
  // Plataforma (Windows/Linux/Android) + Aberto/Protegido + checklist
  // "testou?" + botão Exportar. POR ORA o botão só valida o projeto inteiro
  // e avisa "empacotamento vem depois" — não finje empacotar (R4/R6: .astralis
  // é binário trancado, nunca JSON em texto).
  import { useSectionShell } from "$lib/section";
  import { invokeSave, errMsg } from "$lib/stores/ipc";
  import { useCards } from "$lib/stores/cards.svelte";
  import { useDuelists } from "$lib/stores/duelists.svelte";
  import { useDecks } from "$lib/stores/decks.svelte";
  import { useFusions } from "$lib/stores/fusions.svelte";
  import { useValidate } from "$lib/stores/validate.svelte";

  function abrirImportacao() {
    // DEF-2: sem o input montado o click() seria um não-faz-nada silencioso
    // (parece que "clicou e nada aconteceu"). Com mensagem, nunca há silêncio.
    if (!arquivoPack) {
      impOk = false;
      impMsg = "O seletor ainda não montou — aguarde 1 segundo e clique em Importar de novo.";
      return;
    }
    arquivoPack.click();
  }

  // Faixa verde sobrevive a reloads no MESMO processo/janela (HMR/F5 no dev):
  // sessionStorage morre ao FECHAR a janela (regra do usuário: fechar apaga)
  // mas atravessa reloads — e o disco também mantém (boot 1x por processo no
  // Rust), então a contagem restaurada nunca é fantasma. Sem isto o impMsg e
  // o resumo eram só memória do componente e sumiam a cada reload.
  const CHAVE_RESUMO_IMPORT = "astralis:resumo-import";
  function salvarResumoSessao() {
    try {
      sessionStorage.setItem(CHAVE_RESUMO_IMPORT, JSON.stringify({ impMsg, impOk, resumo }));
    } catch { /* sessão cheia/bloqueada: a faixa só não persiste */ }
  }
  function restaurarResumoSessao() {
    try {
      const cru = sessionStorage.getItem(CHAVE_RESUMO_IMPORT);
      if (!cru) return;
      const v = JSON.parse(cru) as { impMsg?: unknown; impOk?: unknown; resumo?: unknown };
      if (typeof v.impMsg === "string" && v.impMsg) impMsg = v.impMsg;
      impOk = v.impOk === true;
      if (v.resumo && typeof v.resumo === "object") resumo = v.resumo as ResumoPack;
      // Faixa verde restaurada após reload = projeto tem conteúdo: avisa a
      // +page para apagar o aviso de boot "Projeto zerado" (que é estado dela
      // e não some sozinho). Mesmo evento do import OK abaixo.
      if (impOk) window.dispatchEvent(new CustomEvent("astralis:projeto-carregado"));
    } catch { /* sessão corrompida: começa sem faixa */ }
  }

  useSectionShell({ mount: () => { restaurarResumoSessao(); }, extra: [["astralis:importar-pack", abrirImportacao]] });

  let plataforma = $state("windows");
  let modo = $state("protegido");
  let checkDuelo = $state(false);
  let checkCartas = $state(false);
  let checkDecks = $state(false);

  type Item = { area: string; ok: boolean; detalhe: string };
  let itens = $state<Item[]>([]);
  let erros = $state(0);
  let avisos = $state(0);
  let msg = $state("");
  let ok = $state(false);
  let exportando = $state(false);
  let jaValidou = $state(false);

  // ---- IMPORTAR PACK (.json) ----
  // File picker → valida TUDO antes de mexer em nada (pack inválido = erro e
  // o projeto continua intacto) → backup automático do conteúdo atual para
  // projects/default/backups/pack_<data>_<hora>/ → SUBSTITUI o conteúdo do
  // projeto pelo conteúdo do pack (o que não está no pack é apagado;
  // fusions.json é trocado inteiro). Só dado, nada de jogo (R1/R4).
  // Precisa do app (escreve arquivos): no navegador é só leitura.
  type ResumoPack = {
    cartas: number; duelistas: number; decks: number;
    fusoes_novas: number; fusoes_puladas: number; fusoes_mesma: number;
    regras_novas: number; regras_puladas: number;
    equips_ignorados: number; backups: string[];
    avisos: string[]; mensagem: string;
  };
  let arquivoPack: HTMLInputElement | null = $state(null);
  let importando = $state(false);
  let impMsg = $state("");
  let impOk = $state(false);
  let resumo = $state<ResumoPack | null>(null);

  // Aviso é uma linha inteira aqui, e existe um por carta/duelista/deck. O Rust
  // já corta em 30 (teto igual ao dos erros), mas a tela não depende disso:
  // mostra os 30 primeiros e o resto vira contagem.
  const AVISOS_MAX = 30;
  let avisosVisiveis = $derived(resumo ? resumo.avisos.slice(0, AVISOS_MAX) : []);
  let avisosRestantes = $derived(resumo ? resumo.avisos.length - avisosVisiveis.length : 0);
  // Repetida de verdade = pulada menos as A+A (mesma carta nos dois lados, que
  // nunca disparam no jogo). Os dois contadores NÃO podem virar um só: o texto
  // antigo ("N repetidos do próprio pack") mandava o usuário caçar uma
  // repetição que não existia — no pack FM eram 0 repetidas e 50 A+A.
  let fusoesRepetidas = $derived(resumo ? resumo.fusoes_puladas - resumo.fusoes_mesma : 0);

  function emTauri(): boolean {
    return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
  }

  // Lê qualquer arquivo (texto ou binário, ex. .apack) como base64 puro, sem o
  // prefixo `data:...;base64,`. O binário não viaja como texto: arq.text() num
  // .apack corromperia os bytes.
  function lerArquivoBase64(arq: File): Promise<string> {
    return new Promise((ok, no) => {
      const lr = new FileReader();
      lr.onload = () => {
        const s = String(lr.result ?? "");
        const i = s.indexOf(",");
        ok(i >= 0 ? s.slice(i + 1) : s);
      };
      lr.onerror = () => no(new Error("não consegui ler o arquivo aqui no app"));
      lr.readAsDataURL(arq);
    });
  }

  // Base64 do Rust de volta para bytes (download do .apack exportado).
  function base64ParaBytes(b64: string): Uint8Array {
    const s = atob(b64);
    const out = new Uint8Array(s.length);
    for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
    return out;
  }

  async function aoEscolherPack(e: Event) {
    const input = e.target as HTMLInputElement;
    const arq = input.files?.[0];
    input.value = "";
    // DEF-2: o seletor abriu mas voltou sem arquivo (cancelado ou o WebView2
    // não entregou o arquivo). Retornar em silêncio parecia "escolhi e nada
    // carregou" — agora sempre há mensagem visível na tela.
    if (!arq) {
      impOk = false;
      impMsg = "Nenhum arquivo chegou ao editor (o seletor abriu mas voltou vazio). Clique em “Escolher pack (.apack ou .json)” de novo e confirme o arquivo.";
      salvarResumoSessao();
      return;
    }
    impMsg = "";
    impOk = false;
    resumo = null;
    if (!emTauri()) {
      impMsg = "Para importar, abra o app via app.bat (no navegador é só leitura — importar escreve arquivos no projeto).";
      salvarResumoSessao();
      return;
    }
    importando = true;
    // Fase atual, só para a mensagem de erro dizer ONDE parou (ler o arquivo
    // aqui no app, validar no Rust, ou recarregar as abas depois).
    let faseImp = "lendo o arquivo";
    try {
      // Mesmo botão, dois formatos: .apack (binário, via base64) ou .json
      // antigo (texto, só-textos sem imagens). A resposta do Rust é a mesma
      // (ResumoPack) nos dois — o que muda é só como o arquivo viaja.
      const ehApack = arq.name.toLowerCase().endsWith(".apack");
      let r: ResumoPack;
      if (ehApack) {
        const dados = await lerArquivoBase64(arq);
        faseImp = "validando e importando";
        r = await invokeSave("importar_apack", { dados_base64: dados, nome: arq.name }, 180000);
      } else {
        const conteudo = await arq.text();
        faseImp = "validando e importando";
        r = await invokeSave("importar_pack", { conteudo, nome: arq.name }, 180000);
      }
      resumo = r;
      // Sem lista de erros no Ok: o Rust recusa o pack INTEIRO quando acha erro
      // (aí vem pelo Err e cai no catch, em âmbar). Chegou aqui = pack inteiro
      // passou. O campo `erros` que existia no Rust era Vec::new() fixo e o
      // `{#each}` que consumia era código morto.
      impOk = true;
      impMsg = r.mensagem;
      // .json antigo = .apack sem assets: entra como "só-textos, sem imagens".
      // O Rust não muda a mensagem dele (é a mesma do importar_pack); o aviso
      // de "sem imagens" vem daqui, da tela.
      if (!ehApack) {
        impMsg += "\n\nArquivo .json antigo: só-textos, sem imagens (onde houver arte, a tela mostra um cinza).";
      }
      // Listas mudaram no disco: recarrega tudo para a tela mostrar o novo dado.
      faseImp = "recarregando as abas";
      try {
        await useCards().loadAll();
        await useDuelists().reload();
        await useDecks().reload();
        await useFusions().reload();
        await useValidate().refresh();
      } catch (e2) {
        impMsg += ` (Recarregue a aba para ver os novos dados: ${errMsg(e2)})`;
      }
      salvarResumoSessao();
      // Projeto deixou de estar zerado: apaga o aviso de boot da +page (que
      // é estado dela e não some sozinho). Evento no padrão astralis:* já
      // usado por ir-importar/ir-duelo — sem store nova.
      window.dispatchEvent(new CustomEvent("astralis:projeto-carregado"));
    } catch (e) {
      impMsg = `Não deu para importar (${faseImp}): ${errMsg(e)}`;
      salvarResumoSessao();
    } finally {
      importando = false;
    }
  }

  let checklistOk = $derived(checkDuelo && checkCartas && checkDecks);

  function zipNome(): string {
    const plat = plataforma === "windows" ? "windows" : plataforma === "linux" ? "linux" : "android";
    return `Astralis-${plat}.zip`;
  }

  async function exportar() {
    msg = "";
    exportando = true;
    try {
      const r: { erros: number; avisos: number; itens: Item[]; mensagem: string } =
        await invokeSave("validar_projeto", {}, 120000);
      erros = r.erros;
      avisos = r.avisos;
      itens = r.itens ?? [];
      jaValidou = true;
      if (r.erros > 0) {
        ok = false;
        msg = `${r.mensagem} Corrija e clique em Exportar de novo.`;
        return;
      }
      if (!checklistOk) {
        ok = false;
        msg = `Projeto válido, mas marque o checklist "testou?" antes de exportar (falta ${[!checkDuelo && "jogar um duelo", !checkCartas && "validar as cartas", !checkDecks && "conferir os decks"].filter(Boolean).join(", ")}.`;
        return;
      }
      ok = true;
      msg = `✓ Validação OK para ${zipNome()} (${modo === "protegido" ? "Protegido, com cadeado" : "Aberto, para mods"}). ${r.mensagem} Empacotamento (.astralis + zip) vem depois — por ora nada foi empacotado nem baixado.`;
    } catch (e) {
      ok = false;
      msg = errMsg(e);
    } finally {
      exportando = false;
    }
  }

  // ---- EXPORTAR PACK (.apack V1) ----
  // Empacota o projeto atual num arquivo único .apack (textos + imagens, com
  // dedup) e baixa no navegador. Antes valida o projeto: com erro, não
  // empacota (mesma regra do botão Exportar). O checklist "testou?" é só da
  // fita final (.astralis) — pack de criação é arquivo aberto de trabalho.
  // DEF-2: todo caminho termina com mensagem visível, nunca silêncio.
  let expMsg = $state("");
  let expOk = $state(false);
  let exportandoPack = $state(false);

  async function exportarPack() {
    expMsg = "";
    expOk = false;
    exportandoPack = true;
    try {
      if (!emTauri()) {
        expMsg = "Para exportar, abra o app via app.bat (no navegador é só leitura — exportar lê os arquivos do projeto).";
        return;
      }
      const v: { erros: number; mensagem: string } = await invokeSave("validar_projeto", {}, 120000);
      if (v.erros > 0) {
        expMsg = `Não exportei: o projeto tem ${v.erros} erro(s). ${v.mensagem} Corrija nas abas e clique de novo.`;
        return;
      }
      const r: { nome: string; dados_base64: string; mensagem: string; avisos: string[] } =
        await invokeSave("exportar_apack", {}, 180000);
      if (!r.dados_base64) {
        expMsg = "O Rust devolveu o pack vazio (não era para acontecer). Clique em Exportar pack de novo.";
        return;
      }
      const bytes = base64ParaBytes(r.dados_base64);
      const url = URL.createObjectURL(new Blob([bytes.buffer as ArrayBuffer], { type: "application/zip" }));
      const a = document.createElement("a");
      a.href = url;
      a.download = r.nome || "studio_pack.apack";
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 5000);
      expOk = true;
      expMsg = `${r.mensagem}\nArquivo baixado: ${a.download} (${bytes.length} bytes). Para conferir, importe ele de volta no botão Importar acima.`;
      if (r.avisos.length) {
        expMsg += `\nAvisos:\n- ${r.avisos.join("\n- ")}`;
      }
    } catch (e) {
      expMsg = `Não deu para exportar: ${errMsg(e)}`;
    } finally {
      exportandoPack = false;
    }
  }
</script>

<div class="flex-1 min-h-0 overflow-y-auto flex flex-col items-center gap-3 p-2">
  <div class="w-full max-w-2xl rounded-2xl border border-zinc-800 bg-zinc-950/60 p-5">
    <div class="flex items-center gap-3">
      <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-sky-500 via-blue-600 to-indigo-600 flex items-center justify-center text-xl shrink-0">📥</span>
      <div>
        <h2 class="text-base font-black tracking-tight">IMPORTAR PACK</h2>
        <p class="text-[11px] text-zinc-500">Arquivo único .apack com imagens, ou o .json antigo só-textos: valida tudo antes, faz backup automático e SUBSTITUI o conteúdo do projeto (só dado, nada de jogo)</p>
      </div>
    </div>
    <!-- Seletor de arquivo: tem que estar RENDERIZADO, só invisível.
         O `class="hidden"` do Tailwind é display:none, e existem versões de
         WebView2 em que input.click() num input com display:none NÃO abre o
         diálogo (sintoma: cliquei e nada aconteceu). Este padrão (1px,
         opacity 0, pointer-events none) continua invisível para o usuário e
         funciona em todos os WebView2; tabindex/aria-hidden tiram o input
         invisível do tab order (o botão visível é o controle).
         NÃO voltar para display:none. -->
    <input
      bind:this={arquivoPack}
      type="file"
      accept=".apack,.json,application/json"
      class="fixed left-0 top-0 h-px w-px opacity-0 pointer-events-none"
      tabindex="-1"
      aria-hidden="true"
      onchange={aoEscolherPack}
    />
    <button
      class="mt-3 w-full py-3 rounded-2xl bg-sky-600 hover:bg-sky-500 text-white text-sm font-bold shadow-lg shadow-sky-600/20 transition disabled:opacity-50"
      disabled={importando}
      onclick={abrirImportacao}
    >{importando ? "Validando e importando…" : "📥 Escolher pack (.apack ou .json)…"}</button>
    {#if impMsg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {impOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{impMsg}</p>{/if}
    {#if resumo}
      <div class="mt-2 rounded-xl border border-zinc-800 divide-y divide-zinc-800/60 overflow-hidden">
        <div class="px-3 py-2 bg-zinc-900/40 text-xs">
          <span class="font-bold">{resumo.cartas} cartas, {resumo.duelistas} duelistas, {resumo.decks} decks, {resumo.fusoes_novas} fusões substituídos</span>{#if resumo.regras_novas}<span> (+ {resumo.regras_novas} regras)</span>{/if}
          {#if resumo.fusoes_mesma}<span class="text-zinc-400"> • {resumo.fusoes_mesma} fusões com a mesma carta nos dois lados foram ignoradas (nunca disparam no jogo)</span>{/if}
          {#if fusoesRepetidas}<span class="text-zinc-400"> • {fusoesRepetidas} fusões repetidas dentro do próprio pack foram puladas (mesmo par + resultado)</span>{/if}
          {#if resumo.equips_ignorados}<span class="text-zinc-400"> • {resumo.equips_ignorados} equips ignorados (sem schema V1)</span>{/if}
        </div>
        {#if resumo.backups.length}
          <p class="px-3 py-2 text-[11px] text-zinc-400 bg-zinc-900/40">💾 backup em {resumo.backups.join(" • ")}</p>
        {/if}
        <!-- Chave pelo ÍNDICE, não pelo texto: dois avisos idênticos (o mesmo
             "não existe neste projeto" em 40 cartas) quebravam o Svelte, que
             exige chave única. A lista é reescrita inteira a cada import e
             nunca é reordenada, então o índice é a chave estável. -->
        {#each avisosVisiveis as av, i (i)}
          <p class="px-3 py-2 text-[11px] text-sky-300 bg-zinc-900/40">ℹ {av}</p>
        {/each}
        {#if avisosRestantes > 0}
          <p class="px-3 py-2 text-[11px] text-zinc-400 bg-zinc-900/40">…e mais {avisosRestantes} aviso(s) não mostrados aqui (o resumo está na mensagem acima).</p>
        {/if}
      </div>
    {/if}
  </div>
  <div class="w-full max-w-2xl rounded-2xl border border-zinc-800 bg-zinc-950/60 p-5">
    <div class="flex items-center gap-3">
      <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-amber-500 via-orange-600 to-rose-600 flex items-center justify-center text-xl shrink-0">📦</span>
      <div>
        <h2 class="text-base font-black tracking-tight">EXPORTAR JOGO</h2>
        <p class="text-[11px] text-zinc-500">Valida tudo, exporta o pack (.apack, arquivo único com imagens) ou prepara a caixa (.astralis, vem depois)</p>
      </div>
    </div>

    <div class="mt-4 grid sm:grid-cols-2 gap-2">
      <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">PLATAFORMA</p>
        <div class="flex gap-1">
          {#each [["windows", "🪟 Windows"], ["linux", "🐧 Linux"], ["android", "🤖 Android"]] as [pid, plabel] (pid)}
            <button class="flex-1 py-2 rounded-lg text-xs font-medium border transition {plataforma === pid ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => plataforma = pid}>{plabel}</button>
          {/each}
        </div>
        <p class="mt-1.5 text-[11px] text-zinc-500 font-mono">{zipNome()}</p>
      </div>
      <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">MODO</p>
        <div class="flex gap-1">
          <button class="flex-1 py-2 rounded-lg text-xs font-medium border transition {modo === 'aberto' ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => modo = 'aberto'} title="Sem cadeado — bom para mods">🔓 Aberto</button>
          <button class="flex-1 py-2 rounded-lg text-xs font-medium border transition {modo === 'protegido' ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => modo = 'protegido'} title="Com cadeado — padrão para distribuir">🔒 Protegido</button>
        </div>
        <p class="mt-1.5 text-[11px] text-zinc-500">{modo === 'protegido' ? "Fita trancada com chave do jogo (trava cópia casual)." : "Só compactado + assinado (bom para mods)."}</p>
      </div>
    </div>

    <div class="mt-2 rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
      <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">CHECKLIST — "TESTOU A FITA?"</p>
      <div class="space-y-1.5">
        <label class="flex items-center gap-2 text-xs text-zinc-300 cursor-pointer">
          <input type="checkbox" bind:checked={checkDuelo} class="w-4 h-4 accent-emerald-600" /> Joguei um duelo de verdade na aba Duelo
        </label>
        <label class="flex items-center gap-2 text-xs text-zinc-300 cursor-pointer">
          <input type="checkbox" bind:checked={checkCartas} class="w-4 h-4 accent-emerald-600" /> Validei as cartas (selo "válido" no topo)
        </label>
        <label class="flex items-center gap-2 text-xs text-zinc-300 cursor-pointer">
          <input type="checkbox" bind:checked={checkDecks} class="w-4 h-4 accent-emerald-600" /> Conferi os decks (40 cartas cada)
        </label>
      </div>
    </div>

    <button
      class="mt-3 w-full py-3 rounded-2xl bg-amber-600 hover:bg-amber-500 text-white text-sm font-bold shadow-lg shadow-amber-600/20 transition disabled:opacity-50"
      disabled={exportando}
      onclick={exportar}
    >{exportando ? "Validando projeto…" : "⬆ Exportar"}</button>

    {#if msg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{msg}</p>{/if}

    <button
      class="mt-2 w-full py-3 rounded-2xl bg-sky-600 hover:bg-sky-500 text-white text-sm font-bold shadow-lg shadow-sky-600/20 transition disabled:opacity-50"
      disabled={exportandoPack}
      onclick={exportarPack}
      title="Empacota o projeto atual num arquivo único .apack (textos + imagens) e baixa"
    >{exportandoPack ? "Empacotando…" : "📦 Exportar pack (.apack)"}</button>

    {#if expMsg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {expOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{expMsg}</p>{/if}

    {#if jaValidou && itens.length}
      <div class="mt-2 rounded-xl border border-zinc-800 divide-y divide-zinc-800/60 overflow-hidden">
        {#each itens as it (it.area)}
          <div class="px-3 py-2 flex items-center gap-2 bg-zinc-900/40">
            <span class="w-2 h-2 rounded-full shrink-0 {it.ok ? 'bg-emerald-500' : 'bg-rose-500'}"></span>
            <span class="text-xs font-bold">{it.area}</span>
            <span class="ml-auto text-[11px] text-zinc-400 text-right">{it.detalhe}</span>
          </div>
        {/each}
        {#if erros === 0}
          <p class="px-3 py-2 text-[11px] text-zinc-500 bg-zinc-900/40">⚠ A fita final (.astralis binária + zip com o player) vem depois — o botão acima exporta o pack de criação (.apack, aberto, com imagens).</p>
        {/if}
      </div>
    {/if}
  </div>
</div>
