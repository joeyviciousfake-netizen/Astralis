<script lang="ts">
  // DecksStudio — editor de decks (doc 14 §14.2).
  // SIMPLES: busca de cartas + duplo clique adiciona, lista do deck com ✕,
  // contador x/40 + aviso. AVANÇADO: filtros da busca, validar (alvo 40? IDs
  // existem?). Salva em projects/default/decks/ via Tauri (Rust valida
  // 20..60 + IDs reais). Duplicar antes de Criar (doc 14).
  import { useDecks } from "$lib/stores/decks.svelte";
  import type { Deck } from "$lib/stores/decks.svelte";
  import { useCards } from "$lib/stores/cards.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";
  import { typeName, cardTypeBg } from "$lib/cardMeta";

  const store = useDecks();
  const cardsStore = useCards();

  useSectionShell({
    mount: () => { void store.ensureLoaded(); void cardsStore.loadAll(); },
    onSave: () => { if (sel || isNew) save().catch(() => {}); },
  });

  let selId = $state<string | null>(null);
  let buscaCarta = $state("");
  let isNew = $state(false);
  let avancado = $state(false);

  let idEdit = $state("");
  let nomeEdit = $state("");
  let listaEdit = $state<string[]>([]);
  let fieldErrors = $state<Array<{ campo: string; mensagem: string }>>([]);
  const flash = $state({ msg: "", ok: false });

  let lista = $derived(store.decks ?? []);
  let sel = $derived(lista.find((d) => d.id === selId) ?? null);
  let mapa = $derived(cardsStore.idMap());

  let buscaRes = $derived.by(() => {
    const todas = cardsStore.cards;
    if (!buscaCarta) return todas.slice(0, 60);
    const q = buscaCarta.toLowerCase();
    return todas.filter((c) => c.id.toLowerCase().includes(q) || (c.name ?? "").toLowerCase().includes(q)).slice(0, 60);
  });

  let contagem = $derived(listaEdit.length);
  let avisoContagem = $derived.by(() => {
    if (!sel && !isNew) return "";
    if (contagem < 20) return `Faltam ${20 - contagem} cartas para o mínimo (20).`;
    if (contagem < 40) return `Faltam ${40 - contagem} para o alvo (40). Dá para jogar, mas o ideal é 40.`;
    if (contagem === 40) return "";
    if (contagem <= 60) return `Passou de 40 (${contagem}). Dá para jogar, mas o ideal é 40.`;
    return `Passou do máximo (60). Tire ${contagem - 60}.`;
  });
  let contagemOk = $derived(contagem === 40);

  let lastSync: string | null = null;
  $effect(() => {
    const s = sel;
    if (s && s.id !== lastSync) {
      lastSync = s.id;
      isNew = false;
      idEdit = s.id;
      nomeEdit = s.name ?? "";
      listaEdit = [...(s.cards ?? [])];
      fieldErrors = [];
      flash.msg = "";
    }
  });

  function setFlash(msg: string, ok: boolean) {
    flash.msg = msg;
    flash.ok = ok;
  }

  function adicionar(id: string) {
    if (listaEdit.length >= 60) {
      setFlash("Deck cheio (60 é o máximo). Tire alguma carta antes.", false);
      return;
    }
    listaEdit = [...listaEdit, id];
  }

  function removerIndice(i: number) {
    listaEdit = listaEdit.filter((_, x) => x !== i);
  }

  function contarNoDeck(id: string): number {
    return listaEdit.filter((c) => c === id).length;
  }

  function build(): Deck {
    return {
      schema_version: 1,
      id: (isNew ? idEdit.trim() : (sel?.id ?? idEdit.trim())) || "deck_novo",
      name: nomeEdit.trim() || "Sem nome",
      cards: [...listaEdit],
    };
  }

  async function save() {
    fieldErrors = [];
    try {
      const msg = await store.save(build());
      if (isNew) {
        isNew = false;
        const b = build();
        lastSync = b.id;
        selId = b.id;
      }
      setFlash(contagem === 40 ? msg : `${msg} (aviso: ${avisoContagem})`, contagem === 40);
    } catch (e) {
      setFlash(`Falha ao salvar: ${errMsg(e)}`, false);
    }
  }

  async function validateNow() {
    fieldErrors = [];
    try {
      const erros = await store.validate(build());
      fieldErrors = erros;
      const extra = contagem === 40 ? "" : ` (aviso: ${avisoContagem})`;
      setFlash(erros.length ? `${erros.length} erro(s) — veja a lista` : `Deck válido${extra}`, !erros.length && contagem === 40);
    } catch (e) {
      setFlash(`Falha ao validar: ${errMsg(e)}`, false);
    }
  }

  function duplicate() {
    const s = sel;
    if (!s) return;
    const base = s.id.replace(/_copia\d*$/, "");
    let n = 1;
    while (lista.some((d) => d.id === `${base}_copia${n > 1 ? n : ""}`)) n++;
    lastSync = null;
    isNew = true;
    idEdit = `${base}_copia${n > 1 ? n : ""}`;
    nomeEdit = `${s.name} (cópia)`;
    listaEdit = [...(s.cards ?? [])];
    fieldErrors = [];
    setFlash("Cópia pronta — ajuste e clique em Salvar", true);
  }

  function createNew() {
    lastSync = null;
    isNew = true;
    idEdit = "deck_novo";
    nomeEdit = "";
    listaEdit = [];
    fieldErrors = [];
    setFlash("", true);
    selId = null;
  }

  function cartaNome(id: string): string {
    return mapa.get(id)?.name ?? id;
  }
</script>

<div class="flex-1 min-h-0 flex gap-3 md:gap-4 overflow-hidden">
  <!-- Lista de decks -->
  <section class="w-[240px] lg:w-[280px] shrink-0 flex flex-col min-h-0 rounded-2xl border border-zinc-800 bg-zinc-950/60 overflow-hidden">
    <div class="p-3 pb-2">
      <p class="text-[10px] text-zinc-600">{lista.length} decks • Duplicar antes de criar</p>
    </div>
    <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-1">
      {#if store.loading}
        <p class="p-4 text-xs text-zinc-500 text-center">Carregando…</p>
      {:else if store.error}
        <p class="p-4 text-xs text-red-400 text-center">{store.error}</p>
      {:else if !lista.length}
        <p class="p-4 text-xs text-zinc-500 text-center">Nenhum deck.</p>
      {:else}
        {#each lista as d (d.id)}
          {@const ativo = !isNew && selId === d.id}
          {@const fora = d.cards.length !== 40}
          <button
            onclick={() => { selId = ativo ? null : d.id; isNew = false; }}
            class="w-full text-left rounded-xl border px-2 py-2 flex items-center gap-2 transition {ativo ? 'bg-white text-zinc-900 border-white shadow' : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-600 text-zinc-100'}"
          >
            <span class="w-9 h-9 rounded-xl bg-gradient-to-br from-teal-600 via-emerald-600 to-teal-700 flex items-center justify-center text-sm font-black text-white shrink-0">🂠</span>
            <span class="min-w-0 flex-1">
              <span class="block text-xs font-bold truncate">{d.name}{fora ? " ⚠" : ""}</span>
              <span class="block text-[10px] font-mono truncate {ativo ? 'text-zinc-600' : 'text-zinc-500'}">{d.cards.length}/40 • {d.id}</span>
            </span>
          </button>
        {/each}
      {/if}
    </div>
  </section>

  <!-- Editor -->
  <section class="flex-1 min-w-0 min-h-0 overflow-hidden rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4 flex flex-col">
    {#if sel || isNew}
      <div class="flex items-center gap-3 flex-wrap shrink-0">
        <div class="min-w-0">
          <h2 class="text-base font-black tracking-tight truncate">{nomeEdit || "(sem nome)"}</h2>
          <p class="text-[11px] font-mono text-zinc-500 truncate">{isNew ? idEdit : (sel?.id ?? "")}</p>
        </div>
        <span class="px-2.5 py-1 rounded-full text-xs font-bold border {contagemOk ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300' : 'bg-amber-500/10 border-amber-500/30 text-amber-300'}">{contagem}/40</span>
        <div class="ml-auto flex gap-1.5 flex-wrap items-center">
          <div class="flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
            <button class="px-2.5 py-1 rounded-full {!avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = false}>Simples</button>
            <button class="px-2.5 py-1 rounded-full {avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = true}>Avançado</button>
          </div>
          <button class="px-3 py-1.5 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={save}>Salvar</button>
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={validateNow}>Validar</button>
          {#if !isNew}<button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={duplicate}>Duplicar</button>{/if}
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={createNew}>Criar novo</button>
        </div>
      </div>
      {#if flash.msg}<p class="mt-2 shrink-0 text-xs rounded-lg px-3 py-2 border {flash.ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{flash.msg}</p>{/if}
      {#if avisoContagem}<p class="mt-2 shrink-0 text-xs rounded-lg px-3 py-2 border text-amber-300 bg-amber-950/30 border-amber-900/50">⚠ {avisoContagem}</p>{/if}
      {#if fieldErrors.length}
        <div class="mt-2 shrink-0 rounded-xl border border-rose-900/60 bg-rose-950/20 divide-y divide-rose-900/40 max-h-28 overflow-y-auto">
          {#each fieldErrors as fe (fe.campo + fe.mensagem)}
            <p class="px-3 py-1.5 text-xs text-rose-200"><span class="font-bold">{fe.campo}:</span> {fe.mensagem}</p>
          {/each}
        </div>
      {/if}

      {#if isNew || avancado}
        <div class="mt-2 shrink-0 grid sm:grid-cols-2 gap-2">
          <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
            <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">NOME</span>
            <input class="mt-1 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={nomeEdit} placeholder="Como aparece no jogo" />
          </label>
          {#if isNew}
            <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
              <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">ID (vira o nome do arquivo)</span>
              <input class="mt-1 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600" bind:value={idEdit} placeholder="deck_meu_baralho" />
            </label>
          {/if}
        </div>
      {/if}

      <div class="mt-2 flex-1 min-h-0 grid md:grid-cols-2 gap-3 overflow-hidden">
        <!-- Busca de cartas -->
        <div class="min-h-0 flex flex-col rounded-xl border border-zinc-800 bg-zinc-900/40 overflow-hidden">
          <div class="p-2.5 pb-2 shrink-0">
            <div class="relative">
              <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-600 text-xs">⌕</span>
              <input
                class="w-full pl-7 pr-2 py-1.5 rounded-full bg-zinc-950 border border-zinc-800 text-xs placeholder:text-zinc-600 focus:outline-none focus:border-violet-600"
                placeholder="Buscar carta… (duplo clique adiciona)"
                bind:value={buscaCarta}
              />
            </div>
          </div>
          <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-1">
            {#each buscaRes as c (c.id)}
              {@const qtd = contarNoDeck(c.id)}
              <button
                ondblclick={() => adicionar(c.id)}
                onclick={() => adicionar(c.id)}
                title="Clique ou duplo clique para adicionar"
                class="w-full text-left rounded-lg border border-zinc-800 bg-zinc-950 px-2 py-1.5 flex items-center gap-2 hover:border-violet-600 transition"
              >
                <span class="w-7 h-7 rounded-md bg-gradient-to-br border flex items-center justify-center text-[9px] font-black text-white shrink-0 {cardTypeBg(c.card_type)}">{typeName(c.card_type).slice(0, 1)}</span>
                <span class="min-w-0 flex-1">
                  <span class="block text-[11px] font-bold truncate">{c.name}</span>
                  <span class="block text-[9px] font-mono text-zinc-500 truncate">{c.id}{c.card_type === "monster" ? ` • ⚔${c.attack ?? 0}/🛡${c.defense ?? 0}` : ""}</span>
                </span>
                {#if qtd}<span class="px-1.5 py-0.5 rounded-full bg-violet-600/20 border border-violet-600/40 text-violet-300 text-[10px] font-bold">×{qtd}</span>{/if}
                <span class="text-emerald-400 text-sm font-bold" title="Adicionar">＋</span>
              </button>
            {/each}
          </div>
        </div>
        <!-- Cartas do deck -->
        <div class="min-h-0 flex flex-col rounded-xl border border-zinc-800 bg-zinc-900/40 overflow-hidden">
          <p class="p-2.5 pb-2 shrink-0 text-[10px] tracking-widest text-zinc-500 font-semibold">NO DECK ({contagem}) — clique no ✕ para tirar</p>
          <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-1">
            {#if !listaEdit.length}
              <p class="p-4 text-xs text-zinc-500 text-center">Deck vazio — busque ao lado e clique para adicionar.</p>
            {:else}
              {#each listaEdit as cid, i (i + "-" + cid)}
                {@const c = mapa.get(cid)}
                <div class="rounded-lg border border-zinc-800 bg-zinc-950 px-2 py-1.5 flex items-center gap-2">
                  {#if c}
                    <span class="w-7 h-7 rounded-md bg-gradient-to-br border flex items-center justify-center text-[9px] font-black text-white shrink-0 {cardTypeBg(c.card_type)}">{typeName(c.card_type).slice(0, 1)}</span>
                    <span class="min-w-0 flex-1">
                      <span class="block text-[11px] font-bold truncate">{i + 1}. {c.name}</span>
                      <span class="block text-[9px] font-mono text-zinc-500 truncate">{cid}</span>
                    </span>
                  {:else}
                    <span class="w-7 h-7 rounded-md bg-zinc-800 flex items-center justify-center text-[9px] text-amber-300 shrink-0">?</span>
                    <span class="min-w-0 flex-1">
                      <span class="block text-[11px] text-amber-300 truncate">{i + 1}. fora do projeto</span>
                      <span class="block text-[9px] font-mono text-zinc-500 truncate">{cid}</span>
                    </span>
                  {/if}
                  <button class="text-zinc-500 hover:text-rose-300 text-sm px-1" title="Remover do deck" onclick={() => removerIndice(i)}>✕</button>
                </div>
              {/each}
            {/if}
          </div>
        </div>
      </div>
    {:else}
      <div class="h-full min-h-[280px] flex flex-col items-center justify-center gap-3 text-center">
        <div class="w-16 h-16 rounded-3xl bg-gradient-to-br from-teal-600/20 to-emerald-600/20 border border-teal-500/20 flex items-center justify-center text-3xl">🂠</div>
        <p class="text-sm font-bold text-zinc-200">Escolha um deck na lista</p>
        <p class="text-xs text-zinc-500 max-w-sm">Ou clique em <span class="text-zinc-300 font-semibold">Criar novo</span> — mas prefira <span class="text-zinc-300 font-semibold">Duplicar</span> um parecido e editar.</p>
        <button class="mt-1 px-4 py-2 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={createNew}>Criar novo</button>
      </div>
    {/if}
  </section>
</div>
