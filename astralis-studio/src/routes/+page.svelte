<script lang="ts">
  // Página principal — espelha o +page do FM-Studio (mesmo header 64px blur,
  // nav em pílula, pills de estado, selo de validação clicável, Ctrl+S).
  // Projeto do editor abre VAZIO (D29) e só enche por Importar pack. Cartas
  // (JSON real), Duelistas/Decks (leitura), Efeitos, Fusões, Duelo, Testes,
  // Cenas, Exportar.
  // Jogar lança o Astralis de verdade (preview unificado, doc 10).
  import { onMount, tick } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import { useCards } from "$lib/stores/cards.svelte";
  import CardStudio from "$lib/components/CardStudio.svelte";
  import DuelistsStudio from "$lib/components/DuelistsStudio.svelte";
  import DecksStudio from "$lib/components/DecksStudio.svelte";
  import FusionsStudio from "$lib/components/FusionsStudio.svelte";
  import EffectsStudio from "$lib/components/EffectsStudio.svelte";
  import DuelStudio from "$lib/components/DuelStudio.svelte";
  import TestStudio from "$lib/components/TestStudio.svelte";
  import ScenesStudio from "$lib/components/ScenesStudio.svelte";
  import ExportStudio from "$lib/components/ExportStudio.svelte";
  import { createSaveFlash } from "$lib/stores/saveFlash.svelte";
  import { requestSave } from "$lib/stores/saveBus.svelte";
  import ThemeSelector from "$lib/components/ThemeSelector.svelte";
  import ValidationPanel from "$lib/components/ValidationPanel.svelte";
  import { useValidate } from "$lib/stores/validate.svelte";
  import { useDuelists } from "$lib/stores/duelists.svelte";
  import { errMsg } from "$lib/stores/ipc";
  let store = useCards();
  let duelists = useDuelists();
  type Tab = "cards" | "duelists" | "decks" | "fusions" | "effects" | "duel" | "testes" | "cenas" | "export";
  let tab = $state<Tab>("cards");
  // Abas pesadas (Fusões com 25 mil receitas, etc.) só MONTAM quando abertas
  // a primeira vez — antes as 8 montavam juntas no boot (mesmo ocultas) e a
  // aba Fusões travava o navegador renderizando tudo de uma vez.
  let visitadas = $state<Set<Tab>>(new Set(["cards"]));
  function setTab(t: Tab) {
    tab = t;
    if (!visitadas.has(t)) visitadas = new Set(visitadas).add(t);
  }
  let cardsLen = $derived(store.cards.length);
  let isLoading = $derived(store.loading);
  let faseCarga = $derived(store.fase);
  let hasError = $derived(store.error);
  // Aviso de boot (D29): o editor abre APAGANDO o conteúdo do projeto, sem
  // backup. A mensagem do comando preparar_boot ("Projeto zerado (N arquivos
  // apagados), sem backup") aparecia só no Rust — o frontend jogava fora. Agora
  // vira uma faixa junto do convite "projeto vazio": informa, não bloqueia.
  let avisoBoot = $state("");
  const playFlash = createSaveFlash(8000);
  const playMsg = $derived(playFlash.saveMsg);
  const playOk = $derived(playFlash.saveOk);
  let showValidation = $state(false);
  const v = useValidate();
  let seal = $derived.by(() => {
    const r = v.report;
    if (!cardsLen) {
      if (isLoading) return { dot: "bg-zinc-500 animate-pulse", text: faseCarga ?? "carregando…", title: "Carregando cartas…" };
      return { dot: "bg-zinc-600", text: "sem cartas", title: "Nenhuma carta no projeto" };
    }
    if (v.loadError && !r) return { dot: "bg-amber-500", text: "validação falhou", title: v.loadError };
    if (!r) return { dot: "bg-zinc-500 animate-pulse", text: "validando…", title: "Validando projeto em background…" };
    if (!r.completo) return { dot: "bg-zinc-500 animate-pulse", text: `validando ${Math.round(r.progresso * 100)}%`, title: "Mapeando erros por carta (a lista já funciona)…" };
    if (r.error_count > 0) return { dot: "bg-rose-500 shadow shadow-rose-500/30", text: `${r.error_count} erros`, title: `${r.error_count} erros — clique para ver` };
    return { dot: "bg-emerald-500 shadow shadow-emerald-500/30", text: "válido", title: "Projeto íntegro — clique para ver o relatório" };
  });
  let validPct = $derived(v.report && !v.report.completo ? Math.round(v.report.progresso * 100) : null);

  async function ensureValidForPlay(): Promise<boolean> {
    await v.refresh(store.cards);
    const r = v.report;
    if (r && r.error_count > 0) {
      const first = r.issues.find((i) => i.level === "erro");
      playFlash.flashSave(`Jogar travado: ${r.error_count} erro(s) — ${first?.message ?? "ver relatório"}`, false);
      showValidation = true;
      return false;
    }
    return true;
  }

  async function playSelected() {    playFlash.clear();
    try {
      const sel = store.selected;
      if (!sel) { playFlash.flashSave("Escolha uma carta na aba Cartas antes de jogar.", false); return; }
      if (!(await ensureValidForPlay())) return;
      const msg = await store.play(sel);
      playFlash.flashSave(msg, true);
    } catch (e) { playFlash.flashSave(errMsg(e), false); }
  }

  // Botão "Importar" (cabeçalho e faixa de projeto vazio): vai para a aba
  // Exportar e manda o ExportStudio abrir o seletor de arquivo.
  //
  // DEF-1 (bug "cliquei em Importar e não aconteceu nada"): o painel Exportar
  // só MONTA na primeira visita à aba (lazy-mount, por performance: as 8 abas
  // juntas travavam o navegador com 25 mil receitas) e o listener do
  // "astralis:importar-pack" é registrado no onMount dele. Disparar o evento
  // no mesmo tick do setTab jogava o evento no vazio: a aba trocava (o usuário
  // via a tela Exportar) e abrirImportacao nunca rodava. O await tick() espera
  // o Svelte aplicar a troca de aba e rodar o onMount do painel antes do
  // disparo — um evento só, então o seletor abre uma vez.
  // NÃO remova o await e NÃO troque por montagem-eager: são essas duas coisas
  // que desfazem o import ou a performance.
  //
  // DEF-2 (mesmo bug em outras abas): os botões "Importar pack…" dos estados
  // vazios de Cartas/Duelo NÃO podem disparar "astralis:importar-pack" direto —
  // sem trocar de aba o painel pode nem estar montado (evento no vazio, nada
  // acontece) ou o resultado aparece na Exportar escondida (parece que "não
  // carregou"). Eles disparam "astralis:ir-importar", que cai aqui no
  // irImportar (troca de aba + tick + evento, com a Exportar visível).
  async function irImportar() {
    setTab("export");
    await tick();
    window.dispatchEvent(new CustomEvent("astralis:importar-pack"));
  }

  onMount(() => {
    setTab("cards");
    // Boot VAZIO (ordem do usuário, D29): APAGA tudo de projects/default/
    // (comando preparar_boot, sem backup) ANTES da primeira listagem;
    // depois lista normal (vazio + convite "Importe um pack para começar").
    // No navegador o invoke falha e cai no snapshot (o build sai vazio).
    // Boot em 2 tempos: primeiro a lista (1 invoke) + nomes de duelistas em
    // paralelo; a validação roda em background DEPOIS (não trava a abertura).
    void (async () => {
      try {
        const r = await invoke<{ limpou?: boolean; mensagem?: string }>("preparar_boot");
        // Só o zerado de verdade (limpou=true, processo novo) vira aviso.
        // O "Sessão já aberta — N arquivo(s) mantido(s)" do reload (D32,
        // limpou=false) é info silenciosa de propósito: com conteúdo em disco
        // ele nunca pode aparecer como atenção junto da faixa verde.
        if (r?.limpou && r.mensagem) avisoBoot = r.mensagem;
      } catch { /* navegador: snapshot vazio */ }
      await Promise.all([store.loadAll(), duelists.ensureNamesLoaded()]);
      // Se há cartas em disco (import feito antes de um F5, aba Exportar ainda
      // nem montou), o aviso de boot é obsoleto: projeto já não está zerado.
      if (store.cards.length > 0) avisoBoot = "";
      void v.refresh(store.cards);
    })();
    const onKey = (e: KeyboardEvent) => { if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") { e.preventDefault(); requestSave(); } };
    const irDuelo = () => setTab("duel");
    // DEF-2: botões "Importar pack…" de outras abas pedem por aqui (troca de
    // aba + tick + evento), nunca pelo "astralis:importar-pack" direto.
    const irImportarEv = () => void irImportar();
    // Boot zerou mas o Importar encheu depois: o ExportStudio dispara
    // "astralis:projeto-carregado" no import OK e ao restaurar a faixa verde
    // do sessionStorage — aqui o aviso de boot some (projeto não está zerado).
    const projetoCarregadoEv = () => { avisoBoot = ""; };
    window.addEventListener("keydown", onKey);
    window.addEventListener("astralis:ir-duelo", irDuelo);
    window.addEventListener("astralis:ir-importar", irImportarEv);
    window.addEventListener("astralis:projeto-carregado", projetoCarregadoEv);
    return () => { window.removeEventListener("keydown", onKey); window.removeEventListener("astralis:ir-duelo", irDuelo); window.removeEventListener("astralis:ir-importar", irImportarEv); window.removeEventListener("astralis:projeto-carregado", projetoCarregadoEv); playFlash.clearSaveTimer(); };
  });
</script>

<main class="h-screen h-[100dvh] w-screen overflow-hidden bg-[#09090b] text-zinc-100 flex flex-col selection:bg-violet-600/30">
  <!-- Subtle mesh gradient -->
  <div class="pointer-events-none fixed inset-0 -z-10">
    <div class="absolute inset-0 bg-gradient-to-b from-violet-950/20 via-transparent to-transparent"></div>
    <div class="absolute -top-32 -right-32 h-[480px] w-[480px] rounded-full bg-violet-600/10 blur-3xl"></div>
    <div class="absolute top-40 -left-32 h-[360px] w-[360px] rounded-full bg-indigo-600/10 blur-3xl"></div>
  </div>

  <!-- Header -->
  <header class="shrink-0 z-20 border-b border-zinc-800/80 bg-zinc-950/70 backdrop-blur-xl">
    <div class="w-full max-w-[1920px] 2xl:max-w-none mx-auto px-4 md:px-6 xl:px-8 h-[64px] flex items-center justify-between gap-4">
      <div class="flex items-center gap-3 min-w-0">
        <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-violet-600 via-indigo-600 to-violet-700 flex items-center justify-center shadow-lg shadow-violet-600/20 ring-1 ring-white/10 shrink-0">
          <span class="text-white font-black text-[13px] tracking-tight">AS</span>
        </div>
        <div class="min-w-0">
          <h1 class="text-[15px] font-black tracking-tight leading-none">ASTRALIS STUDIO</h1>
          <p class="text-[10px] tracking-[0.18em] text-zinc-500 font-semibold">EDITOR DE CARTAS E DUELOS</p>
        </div>
        <span class="hidden lg:inline-flex ml-2 px-2 py-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[10px] tracking-widest font-medium text-zinc-400">EDITOR</span>
        <span class="hidden xl:inline-flex px-2 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-[10px] font-semibold text-emerald-400">v0.1.0 • TAURI 2</span>
      </div>

      <nav class="hidden md:flex items-center gap-1 p-1 rounded-full bg-zinc-900 border border-zinc-800 shadow-inner max-w-[46vw] overflow-x-auto">
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'cards' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('cards')}>
          <span class="text-[11px] opacity-60">▤</span>Cartas{#if store.cards.length}<span class="text-[10px] opacity-60">{store.cards.length}</span>{/if}
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'duelists' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('duelists')}>
          <span class="text-[11px] opacity-60">⬢</span>Duelistas
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'decks' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('decks')}>
          <span class="text-[11px] opacity-60">🂠</span>Decks
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'fusions' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('fusions')}>
          <span class="text-[11px] opacity-60">🧪</span>Fusões
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'effects' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('effects')}>
          <span class="text-[11px] opacity-60">✨</span>Efeitos
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'duel' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('duel')}>
          <span class="text-[11px] opacity-60">⚔️</span>Duelo
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'testes' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('testes')}>
          <span class="text-[11px] opacity-60">🎯</span>Testes
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'cenas' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('cenas')}>
          <span class="text-[11px] opacity-60">🎬</span>Cenas
        </button>
        <button class="px-3.5 py-1.5 rounded-full text-xs font-medium transition flex items-center gap-1.5 {tab === 'export' ? 'bg-white text-zinc-900 shadow' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800'}" onclick={() => setTab('export')}>
          <span class="text-[11px] opacity-60">📦</span>Exportar
        </button>
      </nav>

      <div class="flex items-center gap-2 shrink-0">
        <div class="hidden lg:flex items-center gap-2 pl-3 pr-1 py-1 rounded-full bg-zinc-900 border border-zinc-800">
          <span class="w-2 h-2 rounded-full {cardsLen ? 'bg-emerald-500 shadow shadow-emerald-500/30' : 'bg-zinc-600'}"></span>
          <span class="text-xs text-zinc-400">{cardsLen ? `${cardsLen} cartas` : 'sem cartas'}</span>
        </div>
        <button class="hidden lg:flex items-center gap-2 pl-3 pr-3 py-1 rounded-full bg-zinc-900 border border-zinc-800 hover:border-zinc-600 transition" onclick={() => showValidation = true} title={seal.title}>
          <span class="w-2 h-2 rounded-full {seal.dot}"></span>
          <span class="text-xs text-zinc-400">{seal.text}</span>
        </button>
        <ThemeSelector />
        <button class="inline-flex items-center gap-2 px-3 py-2 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-white text-xs font-medium transition" onclick={() => requestSave()} title="Salvar carta aberta (Ctrl+S)">
          <span class="hidden sm:inline">Salvar</span><span class="sm:hidden">Salvar</span>
        </button>
        <button class="inline-flex items-center gap-2 px-3 py-2 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-white text-xs font-medium transition" onclick={irImportar} title="Importar um .json pack para o projeto (valida e incorpora)">
          <span class="hidden sm:inline">📥 Importar…</span><span class="sm:hidden">📥</span>
        </button>
        <button class="inline-flex items-center gap-2 px-3 py-2 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-white text-xs font-medium transition" onclick={() => setTab('export')} title="Validar o projeto e preparar a exportação">
          <span class="hidden sm:inline">Exportar…</span><span class="sm:hidden">📦</span>
        </button>
        <button class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-lg shadow-emerald-600/20 transition" onclick={playSelected} title="Salvar + abrir o Astralis de verdade">
          <span class="hidden sm:inline">▶ Jogar</span><span class="sm:hidden">▶</span>
        </button>
      </div>
    </div>
    <!-- mobile nav -->
    <div class="md:hidden border-t border-zinc-800/50 bg-zinc-950/50">
      <nav class="flex gap-1 p-2 overflow-auto">
        {#each [['cards', 'Cartas'], ['duelists', 'Duelistas'], ['decks', 'Decks'], ['fusions', 'Fusões'], ['effects', 'Efeitos'], ['duel', 'Duelo'], ['testes', 'Testes'], ['cenas', 'Cenas'], ['export', 'Exportar']] as [id, label] (id)}
          <button class="flex-1 py-2 rounded-full text-[11px] font-medium whitespace-nowrap {tab === id ? 'bg-white text-zinc-900' : 'bg-zinc-900 text-zinc-400 border border-zinc-800'}" onclick={() => setTab(id as Tab)}>{label}</button>
        {/each}
      </nav>
    </div>
  </header>

  <div class="flex-1 min-h-0 flex flex-col w-full max-w-[1920px] 2xl:max-w-none mx-auto px-3 md:px-4 xl:px-6 2xl:px-8 py-3 md:py-4 gap-3 md:gap-4 overflow-hidden">
    {#if isLoading}<p class="shrink-0 text-xs text-zinc-500 flex items-center gap-2"><span class="w-3 h-3 border-2 border-zinc-700 border-t-violet-600 rounded-full animate-spin"></span>{faseCarga ?? "Carregando…"} {#if cardsLen}({cardsLen}…){/if}</p>{/if}
    {#if !isLoading && validPct !== null}<p class="shrink-0 text-xs text-zinc-500 flex items-center gap-2"><span class="w-3 h-3 border-2 border-zinc-700 border-t-violet-600 rounded-full animate-spin"></span>Validando projeto… {validPct}% (a lista já funciona)</p>{/if}
    {#if hasError}<p class="shrink-0 text-xs text-red-400 bg-red-950/30 border border-red-900/50 rounded-lg px-3 py-2">{hasError}</p>{/if}
    {#if !isLoading && !hasError && cardsLen === 0}
      <div class="shrink-0 flex items-center gap-3 rounded-xl border border-dashed border-zinc-700 bg-zinc-900/40 px-4 py-3">
        <span class="text-lg">📥</span>
        <p class="text-xs text-zinc-300">Projeto vazio — nada carregado. Importe um pack para começar.</p>
        <button class="ml-auto shrink-0 px-3 py-1.5 rounded-full bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition" onclick={irImportar}>Importar pack…</button>
      </div>
    {/if}
    {#if avisoBoot && cardsLen === 0}
      <div class="shrink-0 rounded-xl border border-amber-900/60 bg-amber-950/30 px-4 py-3">
        <p class="text-xs font-semibold text-amber-200">Atenção: abrir o Studio limpa o projeto</p>
        <p class="text-xs text-amber-300/90 whitespace-pre-line">{avisoBoot}</p>
      </div>
    {/if}
    {#if playMsg}<p class="shrink-0 text-xs whitespace-pre-line {playOk ? 'text-emerald-400 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'} border rounded-lg px-3 py-2">{playMsg}</p>{/if}

    <div class="flex-1 min-h-0 flex flex-col overflow-hidden">
      {#if visitadas.has("cards")}<div class:hidden={tab !== "cards"} class="flex-1 min-h-0 flex flex-col overflow-hidden"><CardStudio /></div>{/if}
      {#if visitadas.has("duelists")}<div class:hidden={tab !== "duelists"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><DuelistsStudio /></div>{/if}
      {#if visitadas.has("decks")}<div class:hidden={tab !== "decks"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><DecksStudio /></div>{/if}
      {#if visitadas.has("fusions")}<div class:hidden={tab !== "fusions"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><FusionsStudio /></div>{/if}
      {#if visitadas.has("effects")}<div class:hidden={tab !== "effects"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><EffectsStudio /></div>{/if}
      {#if visitadas.has("duel")}<div class:hidden={tab !== "duel"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><DuelStudio /></div>{/if}
      {#if visitadas.has("testes")}<div class:hidden={tab !== "testes"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><TestStudio /></div>{/if}
      {#if visitadas.has("cenas")}<div class:hidden={tab !== "cenas"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><ScenesStudio /></div>{/if}
      {#if visitadas.has("export")}<div class:hidden={tab !== "export"} class="flex-1 min-h-0 overflow-hidden flex flex-col"><ExportStudio /></div>{/if}
    </div>

    <p class="shrink-0 text-center text-[10px] tracking-widest text-zinc-600">ASTRALIS STUDIO • TAURI 2 • SVELTE 5 • TAILWIND 4</p>
  </div>
  <ValidationPanel open={showValidation} onclose={() => showValidation = false} />
</main>
