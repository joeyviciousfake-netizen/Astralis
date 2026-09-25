<script lang="ts">
  // DuelistsStudio — editor de duelistas (doc 14 §14.2).
  // SIMPLES: nome, retrato (arrastar PNG), deck (select), vida + arquétipo num
  // clique (Bravo | Equilibrado | Defensor). AVANÇADO: 3 sliders + dropdown de
  // dificuldade + arena/música. Mesmo dado, mesma validação (Rust espelha o
  // duelist.schema.json). Salva em projects/default/duelists/ via Tauri.
  // Duplicar antes de Criar (doc 14). Vida é dado do duelista (doc 05 §5.3); a
  // batalha de verdade usa o duel_setup — o Duelo rápido sugere este valor.
  import { useDuelists } from "$lib/stores/duelists.svelte";
  import type { Duelist } from "$lib/stores/duelists.svelte";
  import { useDecks } from "$lib/stores/decks.svelte";
  import { useQuickDuel } from "$lib/stores/duelQuick.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";
  import AssetDrop from "$lib/components/AssetDrop.svelte";

  const store = useDuelists();
  const decksStore = useDecks();
  const quick = useQuickDuel();

  useSectionShell({
    mount: () => { void store.ensureNamesLoaded(); void decksStore.ensureLoaded(); },
    onIso: () => { selId = null; busca = ""; },
    onSave: () => { if (sel || isNew) save().catch(() => {}); },
  });

  const ARQUETIPOS = [
    { id: "bravo", nome: "Bravo", emoji: "🔥", desc: "Ataca muito, funde muito, segura pouco LP", preset: { dificuldade: "normal", agressividade: 80, uso_fusao: 70, protecao_lp: 30 } },
    { id: "equilibrado", nome: "Equilibrado", emoji: "⚖️", desc: "Meio a meio em tudo", preset: { dificuldade: "normal", agressividade: 50, uso_fusao: 50, protecao_lp: 50 } },
    { id: "defensor", nome: "Defensor", emoji: "🛡️", desc: "Segura LP, ataca com calma", preset: { dificuldade: "dificil", agressividade: 30, uso_fusao: 30, protecao_lp: 80 } },
  ] as const;

  let selId = $state<string | null>(null);
  let busca = $state("");
  let avancado = $state(false);
  let isNew = $state(false);

  // Edições
  let idEdit = $state("");
  let nomeEdit = $state("");
  let retratoEdit = $state("");
  let deckEdit = $state("");
  let vidaEdit = $state(4000);
  let difEdit = $state("normal");
  let agrEdit = $state(50);
  let fusEdit = $state(50);
  let proEdit = $state(50);
  let arenaEdit = $state("arena_starter");
  let musicaEdit = $state("");
  let fieldErrors = $state<Array<{ campo: string; mensagem: string }>>([]);
  const flash = $state({ msg: "", ok: false });

  let lista = $derived(store.duelists ?? []);
  let filtrada = $derived.by(() => {
    if (!busca) return lista;
    const q = busca.toLowerCase();
    return lista.filter((d) => d.name.toLowerCase().includes(q) || d.id.toLowerCase().includes(q));
  });
  let sel = $derived(lista.find((d) => d.id === selId) ?? null);
  let arquetipoAtual = $derived.by(() => {
    const cur = { dificuldade: difEdit, agressividade: agrEdit, uso_fusao: fusEdit, protecao_lp: proEdit };
    return ARQUETIPOS.find((a) => JSON.stringify(a.preset) === JSON.stringify(cur))?.id ?? null;
  });

  let lastSync: string | null = null;
  $effect(() => {
    const s = sel;
    if (s && s.id !== lastSync) {
      lastSync = s.id;
      isNew = false;
      idEdit = s.id;
      nomeEdit = s.name ?? "";
      retratoEdit = s.portrait ?? "";
      deckEdit = s.deck_id ?? "";
      vidaEdit = s.starting_lp ?? 4000;
      difEdit = s.ai_preset?.dificuldade ?? "normal";
      agrEdit = s.ai_preset?.agressividade ?? 50;
      fusEdit = s.ai_preset?.uso_fusao ?? 50;
      proEdit = s.ai_preset?.protecao_lp ?? 50;
      arenaEdit = s.arena ?? "arena_starter";
      musicaEdit = s.music ?? "";
      fieldErrors = [];
      flash.msg = "";
    }
  });

  function aplicarArquetipo(id: string) {
    const a = ARQUETIPOS.find((x) => x.id === id);
    if (!a) return;
    difEdit = a.preset.dificuldade;
    agrEdit = a.preset.agressividade;
    fusEdit = a.preset.uso_fusao;
    proEdit = a.preset.protecao_lp;
  }

  function build(): Duelist {
    return {
      schema_version: 1,
      id: (isNew ? idEdit.trim() : (sel?.id ?? idEdit.trim())) || "duelist_novo",
      name: nomeEdit.trim() || "Sem nome",
      portrait: retratoEdit.trim(),
      deck_id: deckEdit.trim(),
      starting_lp: Math.min(99999, Math.max(1, Math.floor(Number(vidaEdit) || 4000))),
      ai_preset: {
        dificuldade: difEdit,
        agressividade: Math.min(100, Math.max(0, Math.floor(Number(agrEdit) || 0))),
        uso_fusao: Math.min(100, Math.max(0, Math.floor(Number(fusEdit) || 0))),
        protecao_lp: Math.min(100, Math.max(0, Math.floor(Number(proEdit) || 0))),
      },
      arena: arenaEdit.trim() || "arena_starter",
      music: musicaEdit.trim() || undefined,
    };
  }

  function setFlash(msg: string, ok: boolean) {
    flash.msg = msg;
    flash.ok = ok;
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
      setFlash(msg, true);
    } catch (e) {
      setFlash(`Falha ao salvar: ${errMsg(e)}`, false);
    }
  }

  async function validateNow() {
    fieldErrors = [];
    try {
      const erros = await store.validate(build());
      fieldErrors = erros;
      setFlash(erros.length ? `${erros.length} erro(s) — veja a lista` : "Duelista válido", !erros.length);
    } catch (e) {
      setFlash(`Falha ao validar: ${errMsg(e)}`, false);
    }
  }

  function duplicate() {
    const s = sel;
    if (!s) return;
    const base = s.id.replace(/_copia\d*$/, "");
    let n = 1;
    const tem = (id: string) => lista.some((d) => d.id === id);
    while (tem(`${base}_copia${n > 1 ? n : ""}`)) n++;
    lastSync = null;
    isNew = true;
    idEdit = `${base}_copia${n > 1 ? n : ""}`;
    nomeEdit = `${s.name} (cópia)`;
    retratoEdit = s.portrait ?? "";
    deckEdit = s.deck_id ?? "";
    vidaEdit = s.starting_lp ?? 4000;
    difEdit = s.ai_preset?.dificuldade ?? "normal";
    agrEdit = s.ai_preset?.agressividade ?? 50;
    fusEdit = s.ai_preset?.uso_fusao ?? 50;
    proEdit = s.ai_preset?.protecao_lp ?? 50;
    arenaEdit = s.arena ?? "arena_starter";
    musicaEdit = s.music ?? "";
    fieldErrors = [];
    setFlash("Cópia pronta — ajuste e clique em Salvar", true);
  }

  function createNew() {
    lastSync = null;
    isNew = true;
    idEdit = "duelist_novo";
    nomeEdit = "";
    retratoEdit = "";
    deckEdit = decksStore.decks[0]?.id ?? "";
    vidaEdit = 4000;
    aplicarArquetipo("equilibrado");
    arenaEdit = "arena_starter";
    musicaEdit = "";
    fieldErrors = [];
    setFlash("", true);
    selId = null;
  }

  function difNome(v: string) {
    return v === "facil" ? "Fácil" : v === "dificil" ? "Difícil" : "Normal";
  }
</script>

<div class="flex-1 min-h-0 flex gap-3 md:gap-4 overflow-hidden">
  <!-- Lista -->
  <section class="w-[260px] lg:w-[300px] shrink-0 flex flex-col min-h-0 rounded-2xl border border-zinc-800 bg-zinc-950/60 overflow-hidden">
    <div class="p-3 pb-2 space-y-2">
      <div class="relative">
        <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-600 text-xs">⌕</span>
        <input
          class="w-full pl-7 pr-2 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs placeholder:text-zinc-600 focus:outline-none focus:border-violet-600"
          placeholder="Buscar duelista…"
          bind:value={busca}
        />
      </div>
      <p class="text-[10px] text-zinc-600">{filtrada.length} duelistas • Duplicar antes de criar</p>
    </div>
    <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-1">
      {#if store.loading}
        <p class="p-4 text-xs text-zinc-500 text-center">Carregando…</p>
      {:else if store.error}
        <p class="p-4 text-xs text-red-400 text-center">{store.error}</p>
      {:else if !filtrada.length}
        <p class="p-4 text-xs text-zinc-500 text-center">Nenhum duelista.</p>
      {:else}
        {#each filtrada as d (d.id)}
          {@const ativo = !isNew && selId === d.id}
          <button
            onclick={() => { selId = ativo ? null : d.id; isNew = false; }}
            class="w-full text-left rounded-xl border px-2 py-2 flex items-center gap-2 transition {ativo ? 'bg-white text-zinc-900 border-white shadow' : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-600 text-zinc-100'}"
          >
            <span class="w-9 h-9 rounded-full bg-gradient-to-br from-indigo-600 via-violet-600 to-violet-700 flex items-center justify-center text-sm font-black text-white shrink-0 ring-1 ring-white/10">{(d.name || "?").slice(0, 1)}</span>
            <span class="min-w-0">
              <span class="block text-xs font-bold truncate">{d.name}</span>
              <span class="block text-[10px] font-mono truncate {ativo ? 'text-zinc-600' : 'text-zinc-500'}">{d.id}</span>
            </span>
          </button>
        {/each}
      {/if}
    </div>
  </section>

  <!-- Detalhe -->
  <section class="flex-1 min-w-0 min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4">
    {#if sel || isNew}
      <div class="flex items-center gap-3 flex-wrap">
        <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-indigo-600 via-violet-600 to-violet-700 flex items-center justify-center text-lg font-black text-white shrink-0 ring-1 ring-white/10">{(nomeEdit || "?").slice(0, 1)}</span>
        <div class="min-w-0">
          <h2 class="text-base font-black tracking-tight truncate">{nomeEdit || "(sem nome)"}</h2>
          <p class="text-[11px] font-mono text-zinc-500 truncate">{isNew ? idEdit : (sel?.id ?? "")}</p>
        </div>
        <div class="ml-auto flex gap-1.5 flex-wrap items-center">
          <div class="flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
            <button class="px-2.5 py-1 rounded-full {!avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = false}>Simples</button>
            <button class="px-2.5 py-1 rounded-full {avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = true}>Avançado</button>
          </div>
          <button class="px-3 py-1.5 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={save}>Salvar</button>
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={validateNow}>Validar</button>
          {#if !isNew}<button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={duplicate}>Duplicar</button>{/if}
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={createNew}>Criar novo</button>
          {#if !isNew && sel}<button class="px-3 py-1.5 rounded-full bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-lg shadow-emerald-600/20 transition" title="Vai para a aba Duelo com este duelista já escolhido" onclick={() => { const outro = lista.find((d) => d.id !== sel.id)?.id ?? sel.id; quick.pedir(sel.id, outro); }}>▶ Jogar</button>{/if}
        </div>
      </div>
      {#if flash.msg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border {flash.ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{flash.msg}</p>{/if}
      {#if fieldErrors.length}
        <div class="mt-2 rounded-xl border border-rose-900/60 bg-rose-950/20 divide-y divide-rose-900/40">
          {#each fieldErrors as fe (fe.campo + fe.mensagem)}
            <p class="px-3 py-1.5 text-xs text-rose-200"><span class="font-bold">{fe.campo}:</span> {fe.mensagem}</p>
          {/each}
        </div>
      {/if}

      <div class="mt-3 grid md:grid-cols-2 gap-2.5">
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">NOME</p>
          <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={nomeEdit} placeholder="Como aparece no jogo" />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">ID {isNew ? "(editável — vira o nome do arquivo)" : "(fixo — não muda)"}</p>
          <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600 disabled:opacity-60" bind:value={idEdit} disabled={!isNew} placeholder="duelist_meu_rival" />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">RETRATO (arraste um PNG)</p>
          {#if retratoEdit.trim()}
            <div class="mb-1.5 h-16 rounded-lg bg-zinc-800 border border-zinc-700 flex items-center justify-center text-2xl">🙂</div>
          {:else}
            <div class="mb-1.5 h-16 rounded-lg bg-zinc-800 border border-zinc-700 flex flex-col items-center justify-center gap-0.5">
              <span class="text-xl grayscale opacity-50">🖼</span>
              <span class="text-[9px] text-zinc-500">sem arte (cinza automático)</span>
            </div>
          {/if}
          <AssetDrop tipo="duelista" sugestao={idEdit || "retrato"} value={retratoEdit} onimport={(c) => retratoEdit = c} />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">DECK</p>
          <select id="field-deck" class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none" bind:value={deckEdit}>
            <option value="">Escolher deck…</option>
            {#each decksStore.decks as dk (dk.id)}
              <option value={dk.id}>{dk.name} ({dk.cards.length})</option>
            {/each}
          </select>
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mt-2 mb-1.5" id="field-lp">VIDA (LP inicial sugerido)</p>
          <input type="number" min="1" max="99999" step="100" class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={vidaEdit} />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3 md:col-span-2" id="field-arquetipo">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">ESTILO DE JOGO — um clique {arquetipoAtual ? "" : "(personalizado ✏️)"}</p>
          <div class="grid sm:grid-cols-3 gap-1.5">
            {#each ARQUETIPOS as a (a.id)}
              <button
                class="text-left rounded-xl border p-2.5 transition {arquetipoAtual === a.id ? 'bg-white text-zinc-900 border-white shadow' : 'bg-zinc-950 text-zinc-200 border-zinc-800 hover:border-zinc-600'}"
                onclick={() => aplicarArquetipo(a.id)}
              >
                <span class="text-base">{a.emoji}</span>
                <span class="block text-xs font-bold mt-0.5">{a.nome}</span>
                <span class="block text-[10px] mt-0.5 {arquetipoAtual === a.id ? 'text-zinc-600' : 'text-zinc-500'}">{a.desc}</span>
              </button>
            {/each}
          </div>
        </div>
        {#if avancado}
          <div class="rounded-xl border border-violet-600/30 bg-violet-950/10 p-3 md:col-span-2">
            <p class="text-[10px] tracking-widest text-violet-300 font-semibold mb-2">AVANÇADO — estilo de jogo nº a nº (mesma IA do jogo, só parâmetros)</p>
            <label class="block mb-2" id="field-dificuldade">
              <span class="text-[11px] text-zinc-400">Dificuldade</span>
              <div class="flex gap-1 mt-1">
                {#each [["facil", "Fácil"], ["normal", "Normal"], ["dificil", "Difícil"]] as [vid, vlabel] (vid)}
                  <button class="flex-1 py-1.5 rounded-lg text-xs font-medium border transition {difEdit === vid ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => difEdit = vid}>{vlabel}</button>
                {/each}
              </div>
            </label>
            {#each [["Agressividade — quanto ele ataca", "agr", agrEdit, (v: number) => agrEdit = v, "field-agressividade"], ["Uso de fusão — quanto ele funde cartas", "fus", fusEdit, (v: number) => fusEdit = v, "field-uso_fusao"], ["Proteção de LP — quanto ele se defende", "pro", proEdit, (v: number) => proEdit = v, "field-protecao_lp"]] as [slabel, _sid, sval, sset, fid] (fid)}
              <label class="block mb-2" id={String(fid)}>
                <span class="text-[11px] text-zinc-400">{slabel}: <span class="font-bold text-zinc-100">{sval}</span></span>
                <input type="range" min="0" max="100" value={Number(sval)} oninput={(e) => (sset as (v: number) => void)(Number((e.target as HTMLInputElement).value))} class="w-full accent-violet-600" />
              </label>
            {/each}
            <div class="grid sm:grid-cols-2 gap-2 mt-2">
              <label class="block">
                <span class="text-[11px] text-zinc-400">Arena</span>
                <input class="mt-1 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono" bind:value={arenaEdit} />
              </label>
              <label class="block">
                <span class="text-[11px] text-zinc-400">Música (caminho, opcional)</span>
                <input class="mt-1 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono" bind:value={musicaEdit} placeholder="assets/music/..." />
              </label>
            </div>
          </div>
        {:else}
          <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3 md:col-span-2">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">RESUMO DO ESTILO</p>
            <p class="text-xs text-zinc-300 mt-1">Dificuldade: <span class="font-bold">{difNome(difEdit)}</span> • Agressividade {agrEdit} • Fusão {fusEdit} • Proteção LP {proEdit} • Vida {vidaEdit}</p>
          </div>
        {/if}
      </div>
    {:else}
      <div class="h-full min-h-[280px] flex flex-col items-center justify-center gap-3 text-center">
        <div class="w-16 h-16 rounded-3xl bg-gradient-to-br from-indigo-600/20 to-violet-600/20 border border-violet-500/20 flex items-center justify-center text-3xl">⬢</div>
        <p class="text-sm font-bold text-zinc-200">Escolha um duelista na lista</p>
        <p class="text-xs text-zinc-500 max-w-sm">Ou clique em <span class="text-zinc-300 font-semibold">Criar novo</span> — mas prefira <span class="text-zinc-300 font-semibold">Duplicar</span> um parecido e editar.</p>
        <button class="mt-1 px-4 py-2 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={createNew}>Criar novo</button>
      </div>
    {/if}
  </section>
</div>
