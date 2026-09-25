<script lang="ts">
  // FusionsStudio — editor de fusões (doc 14 §14.2).
  // SIMPLES: lista de receitas A+B=C + botão Testar (= confere o dado contra
  // as cartas: receita exata vence, regra é fallback; NÃO executa jogo — o
  // motor de fusão não existe no runtime). AVANÇADO: aba Regras com selects
  // tipo+atributo→resultado + prioridade. Salva projects/default/fusions.json
  // via Tauri preservando o formato atual.
  import { useFusions } from "$lib/stores/fusions.svelte";
  import type { FusionRecipe, FusionRule } from "$lib/stores/fusions.svelte";
  import { useCards } from "$lib/stores/cards.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";
  import { MONSTER_TYPES, ATTRIBUTES } from "$lib/cardMeta";

  const store = useFusions();
  const cardsStore = useCards();

  useSectionShell({
    mount: () => { void store.ensureLoaded(); void cardsStore.loadAll(); },
    onSave: () => { save().catch(() => {}); },
  });

  let aba = $state<"receitas" | "regras" | "testar">("receitas");
  let avancado = $state(false);

  // Paginação das receitas: 25 mil linhas com 3 selects cada travavam o
  // navegador (pós-pack FM). Mostra 50 por página + busca por id/carta.
  let buscaReceita = $state("");
  let paginaRec = $state(0);
  const POR_PAGINA = 50;

  let testeA = $state("");
  let testeB = $state("");
  let testeMsg = $state("");
  let testeOk = $state(false);
  let testando = $state(false);

  const flash = $state({ msg: "", ok: false });
  function setFlash(msg: string, ok: boolean) {
    flash.msg = msg;
    flash.ok = ok;
  }

  let mapa = $derived(cardsStore.idMap());
  function nomeCarta(id: string): string {
    return mapa.get(id)?.name ?? id;
  }

  function receitas(): FusionRecipe[] {
    return store.dado.recipes;
  }
  let receitasFiltradas = $derived.by(() => {
    const todas = store.dado.recipes;
    const q = buscaReceita.trim().toLowerCase();
    if (!q) return todas;
    return todas.filter((r) =>
      r.id.toLowerCase().includes(q) ||
      r.input.card_a.toLowerCase().includes(q) ||
      r.input.card_b.toLowerCase().includes(q) ||
      r.result.toLowerCase().includes(q) ||
      nomeCarta(r.input.card_a).toLowerCase().includes(q) ||
      nomeCarta(r.input.card_b).toLowerCase().includes(q) ||
      nomeCarta(r.result).toLowerCase().includes(q),
    );
  });
  let totalPagRec = $derived(Math.max(1, Math.ceil(receitasFiltradas.length / POR_PAGINA)));
  let paginaSegura = $derived(Math.min(paginaRec, totalPagRec - 1));
  let receitasVisiveis = $derived(receitasFiltradas.slice(paginaSegura * POR_PAGINA, paginaSegura * POR_PAGINA + POR_PAGINA));
  function irPaginaRec(delta: number) {
    paginaRec = Math.min(totalPagRec - 1, Math.max(0, paginaSegura + delta));
  }
  function regras(): FusionRule[] {
    return [...store.dado.rules].sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0));
  }

  function trocarReceita(i: number, patch: Partial<FusionRecipe>) {
    const next = store.dado.recipes.map((r, x) => (x === i ? { ...r, ...patch, input: { ...r.input, ...(patch.input ?? {}) } } : r));
    store.setLocal({ ...store.dado, recipes: next });
  }
  function adicionarReceita() {
    const base = "fusion_receita_nova";
    let n = 1;
    const tem = (id: string) => store.dado.recipes.some((r) => r.id === id) || store.dado.rules.some((r) => r.id === id);
    while (tem(`${base}${n > 1 ? n : ""}`)) n++;
    const primeira = cardsStore.cards[0]?.id ?? "";
    store.setLocal({
      ...store.dado,
      recipes: [...store.dado.recipes, { id: `${base}${n > 1 ? n : ""}`, input: { card_a: primeira, card_b: primeira }, result: primeira }],
    });
  }
  function duplicarReceita(i: number) {
    const r = store.dado.recipes[i];
    if (!r) return;
    const base = r.id.replace(/_copia\d*$/, "");
    let n = 1;
    const tem = (id: string) => store.dado.recipes.some((x) => x.id === id) || store.dado.rules.some((x) => x.id === id);
    while (tem(`${base}_copia${n > 1 ? n : ""}`)) n++;
    const copia = { ...r, id: `${base}_copia${n > 1 ? n : ""}`, input: { ...r.input } };
    const next = [...store.dado.recipes];
    next.splice(i + 1, 0, copia);
    store.setLocal({ ...store.dado, recipes: next });
  }
  function removerReceita(i: number) {
    store.setLocal({ ...store.dado, recipes: store.dado.recipes.filter((_, x) => x !== i) });
  }

  function trocarRegra(id: string, patch: Partial<FusionRule>) {
    const next = store.dado.rules.map((r) => (r.id === id ? { ...r, ...patch, when: { ...r.when, ...(patch.when ?? {}) } } : r));
    store.setLocal({ ...store.dado, rules: next });
  }
  function adicionarRegra() {
    const base = "fusion_regra_nova";
    let n = 1;
    const tem = (id: string) => store.dado.recipes.some((r) => r.id === id) || store.dado.rules.some((r) => r.id === id);
    while (tem(`${base}${n > 1 ? n : ""}`)) n++;
    store.setLocal({
      ...store.dado,
      rules: [...store.dado.rules, { id: `${base}${n > 1 ? n : ""}`, when: { type_a: "dragon" }, result: cardsStore.cards[0]?.id ?? "", priority: 10 }],
    });
  }
  function removerRegra(id: string) {
    store.setLocal({ ...store.dado, rules: store.dado.rules.filter((r) => r.id !== id) });
  }

  async function save() {
    try {
      const msg = await store.save(store.dado);
      setFlash(msg, true);
    } catch (e) {
      setFlash(`Falha ao salvar: ${errMsg(e)}`, false);
    }
  }

  async function testar() {
    testeMsg = "";
    if (!testeA || !testeB) {
      testeOk = false;
      testeMsg = "Escolha as duas cartas (A e B) antes de testar.";
      return;
    }
    testando = true;
    try {
      const r = await store.testar(testeA, testeB);
      testeOk = r.achou;
      testeMsg = r.mensagem;
    } catch (e) {
      testeOk = false;
      testeMsg = errMsg(e);
    } finally {
      testando = false;
    }
  }

  function tipoNome(id: string): string {
    return MONSTER_TYPES.find((t) => t.id === id)?.name ?? id;
  }
  function attrNome(id: string): string {
    return ATTRIBUTES.find((t) => t.id === id)?.name ?? id;
  }
</script>

<div class="flex-1 min-h-0 flex flex-col gap-3 overflow-hidden">
  <div class="shrink-0 flex items-center gap-2 flex-wrap">
    <div class="flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
      <button class="px-3 py-1 rounded-full {!avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => { avancado = false; aba = "receitas"; }}>Simples</button>
      <button class="px-3 py-1 rounded-full {avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = true}>Avançado</button>
    </div>
    {#if avancado}
      <div class="flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
        <button class="px-3 py-1 rounded-full {aba === 'receitas' ? 'bg-zinc-700 text-white font-semibold' : 'text-zinc-400'}" onclick={() => aba = "receitas"}>Receitas</button>
        <button class="px-3 py-1 rounded-full {aba === 'regras' ? 'bg-zinc-700 text-white font-semibold' : 'text-zinc-400'}" onclick={() => aba = "regras"}>Regras</button>
        <button class="px-3 py-1 rounded-full {aba === 'testar' ? 'bg-zinc-700 text-white font-semibold' : 'text-zinc-400'}" onclick={() => aba = "testar"}>Testar</button>
      </div>
    {:else}
      <div class="flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
        <button class="px-3 py-1 rounded-full {aba === 'receitas' ? 'bg-zinc-700 text-white font-semibold' : 'text-zinc-400'}" onclick={() => aba = "receitas"}>Receitas</button>
        <button class="px-3 py-1 rounded-full {aba === 'testar' ? 'bg-zinc-700 text-white font-semibold' : 'text-zinc-400'}" onclick={() => aba = "testar"}>Testar</button>
      </div>
    {/if}
    <button class="ml-auto px-3 py-1.5 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={save}>Salvar</button>
  </div>
  {#if flash.msg}<p class="shrink-0 text-xs rounded-lg px-3 py-2 border {flash.ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{flash.msg}</p>{/if}

  {#if store.loading}
    <p class="text-xs text-zinc-500">Carregando…</p>
  {:else if store.error}
    <p class="text-xs text-red-400">{store.error}</p>
  {:else if aba === "receitas"}
    <div class="flex-1 min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-3 space-y-2">
      <div class="flex items-center gap-2 flex-wrap">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">{receitas().length} RECEITAS (A+B=C — receita exata sempre vence)</p>
        <div class="relative">
          <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-600 text-xs">⌕</span>
          <input
            class="pl-7 pr-2 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs placeholder:text-zinc-600 focus:outline-none focus:border-violet-600 w-52"
            placeholder="Buscar receita ou carta…"
            value={buscaReceita}
            oninput={(e) => { buscaReceita = (e.target as HTMLInputElement).value; paginaRec = 0; }}
          />
        </div>
        <button class="ml-auto px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={adicionarReceita}>＋ Nova receita</button>
      </div>
      {#if receitasFiltradas.length > POR_PAGINA}
        <div class="flex items-center gap-2 text-[11px] text-zinc-400">
          <button class="px-2.5 py-1 rounded-full bg-zinc-900 border border-zinc-800 hover:border-zinc-600 disabled:opacity-40" disabled={paginaSegura === 0} onclick={() => irPaginaRec(-1)}>←</button>
          <span>Página {paginaSegura + 1} de {totalPagRec} — mostrando {paginaSegura * POR_PAGINA + 1}–{Math.min(receitasFiltradas.length, paginaSegura * POR_PAGINA + POR_PAGINA)} de {receitasFiltradas.length}</span>
          <button class="px-2.5 py-1 rounded-full bg-zinc-900 border border-zinc-800 hover:border-zinc-600 disabled:opacity-40" disabled={paginaSegura >= totalPagRec - 1} onclick={() => irPaginaRec(1)}>→</button>
        </div>
      {:else}
        <p class="text-[10px] text-zinc-600">{receitasFiltradas.length} receita(s) — busque para filtrar as {receitas().length}</p>
      {/if}
      {#if !receitasVisiveis.length}
        <p class="p-4 text-xs text-zinc-500 text-center">Nenhuma receita — clique em Nova receita ou ajuste a busca.</p>
      {/if}
      {#each receitasVisiveis as r, i (r.id + "|" + (paginaSegura * POR_PAGINA + i))}
        {@const ri = paginaSegura * POR_PAGINA + i}
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
          <div class="flex items-center gap-2 mb-2">
            <input class="px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono w-44" value={r.id} oninput={(e) => trocarReceita(ri, { id: (e.target as HTMLInputElement).value })} title="ID da receita" />
            <div class="ml-auto flex gap-1">
              <button class="px-2 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" title="Duplicar receita" onclick={() => duplicarReceita(ri)}>Duplicar</button>
              <button class="px-2 py-1 rounded-lg bg-zinc-800 hover:bg-rose-900 border border-zinc-700 text-[11px]" title="Remover receita" onclick={() => removerReceita(ri)}>✕</button>
            </div>
          </div>
          <div class="grid grid-cols-[1fr_auto_1fr_auto_1fr] gap-1.5 items-center">
            <select class="px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.input.card_a} onchange={(e) => trocarReceita(ri, { input: { ...r.input, card_a: (e.target as HTMLSelectElement).value } })}>
              {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
            </select>
            <span class="text-zinc-500 font-black">＋</span>
            <select class="px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.input.card_b} onchange={(e) => trocarReceita(ri, { input: { ...r.input, card_b: (e.target as HTMLSelectElement).value } })}>
              {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
            </select>
            <span class="text-emerald-400 font-black">=</span>
            <select class="px-2 py-1.5 rounded-lg bg-zinc-950 border border-emerald-900 text-xs" value={r.result} onchange={(e) => trocarReceita(ri, { result: (e.target as HTMLSelectElement).value })}>
              {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
            </select>
          </div>
          <p class="mt-1 text-[11px] text-zinc-500">{nomeCarta(r.input.card_a)} + {nomeCarta(r.input.card_b)} = <span class="text-emerald-300 font-semibold">{nomeCarta(r.result)}</span></p>
        </div>
      {/each}
      {#if receitasFiltradas.length > POR_PAGINA}
        <div class="flex items-center gap-2 text-[11px] text-zinc-400">
          <button class="px-2.5 py-1 rounded-full bg-zinc-900 border border-zinc-800 hover:border-zinc-600 disabled:opacity-40" disabled={paginaSegura === 0} onclick={() => irPaginaRec(-1)}>←</button>
          <span>Página {paginaSegura + 1} de {totalPagRec}</span>
          <button class="px-2.5 py-1 rounded-full bg-zinc-900 border border-zinc-800 hover:border-zinc-600 disabled:opacity-40" disabled={paginaSegura >= totalPagRec - 1} onclick={() => irPaginaRec(1)}>→</button>
        </div>
      {/if}
    </div>
  {:else if aba === "regras"}
    <div class="flex-1 min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-3 space-y-2">
      <div class="flex items-center gap-2">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">{regras().length} REGRAS (fallback — vale se não houver receita exata; maior prioridade vence; campo vazio = coringa)</p>
        <button class="ml-auto px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={adicionarRegra}>＋ Nova regra</button>
      </div>
      {#if !regras().length}
        <p class="p-4 text-xs text-zinc-500 text-center">Nenhuma regra — clique em Nova regra.</p>
      {/if}
      {#each regras() as r (r.id)}
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
          <div class="flex items-center gap-2 mb-2 flex-wrap">
            <input class="px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono w-44" value={r.id} oninput={(e) => trocarRegra(r.id, { id: (e.target as HTMLInputElement).value })} title="ID da regra" />
            <label class="flex items-center gap-1 text-[11px] text-zinc-400">prioridade
              <input type="number" min="0" class="w-16 px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.priority} oninput={(e) => trocarRegra(r.id, { priority: Math.max(0, Math.floor(Number((e.target as HTMLInputElement).value) || 0)) })} />
            </label>
            <button class="ml-auto px-2 py-1 rounded-lg bg-zinc-800 hover:bg-rose-900 border border-zinc-700 text-[11px]" title="Remover regra" onclick={() => removerRegra(r.id)}>✕</button>
          </div>
          <div class="grid sm:grid-cols-2 lg:grid-cols-5 gap-1.5">
            <label class="block"><span class="text-[10px] text-zinc-500">tipo A</span>
              <select class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.when.type_a ?? ""} onchange={(e) => trocarRegra(r.id, { when: { ...r.when, type_a: (e.target as HTMLSelectElement).value || undefined } })}>
                <option value="">qualquer</option>
                {#each MONSTER_TYPES as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
              </select>
            </label>
            <label class="block"><span class="text-[10px] text-zinc-500">atributo A</span>
              <select class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.when.attribute_a ?? ""} onchange={(e) => trocarRegra(r.id, { when: { ...r.when, attribute_a: (e.target as HTMLSelectElement).value || undefined } })}>
                <option value="">qualquer</option>
                {#each ATTRIBUTES as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
              </select>
            </label>
            <label class="block"><span class="text-[10px] text-zinc-500">tipo B</span>
              <select class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.when.type_b ?? ""} onchange={(e) => trocarRegra(r.id, { when: { ...r.when, type_b: (e.target as HTMLSelectElement).value || undefined } })}>
                <option value="">qualquer</option>
                {#each MONSTER_TYPES as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
              </select>
            </label>
            <label class="block"><span class="text-[10px] text-zinc-500">atributo B</span>
              <select class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.when.attribute_b ?? ""} onchange={(e) => trocarRegra(r.id, { when: { ...r.when, attribute_b: (e.target as HTMLSelectElement).value || undefined } })}>
                <option value="">qualquer</option>
                {#each ATTRIBUTES as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
              </select>
            </label>
            <label class="block"><span class="text-[10px] text-zinc-500">ATK mín (olha a maior das duas)</span>
              <input type="number" min="0" step="100" class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" value={r.when.min_atk ?? ""} placeholder="qualquer" oninput={(e) => { const v = (e.target as HTMLInputElement).value.trim(); trocarRegra(r.id, { when: { ...r.when, min_atk: v === "" ? undefined : Math.max(0, Math.floor(Number(v) || 0)) } }); }} />
            </label>
          </div>
          <label class="block mt-1.5"><span class="text-[10px] text-zinc-500">→ nasce</span>
            <select class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-emerald-900 text-xs" value={r.result} onchange={(e) => trocarRegra(r.id, { result: (e.target as HTMLSelectElement).value })}>
              {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
            </select>
          </label>
          <p class="mt-1 text-[11px] text-zinc-500">{r.when.type_a ? tipoNome(r.when.type_a) : "qualquer tipo"} {r.when.attribute_a ? `(${attrNome(r.when.attribute_a)})` : ""} + {r.when.type_b ? tipoNome(r.when.type_b) : "qualquer tipo"} {r.when.attribute_b ? `(${attrNome(r.when.attribute_b)})` : ""} → <span class="text-emerald-300 font-semibold">{nomeCarta(r.result)}</span> (prioridade {r.priority})</p>
        </div>
      {/each}
    </div>
  {:else}
    <div class="flex-1 min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4">
      <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">TESTAR FUSÃO — só confere o dado (receita exata vence, regra é fallback). Não executa jogo.</p>
      <div class="mt-2 grid sm:grid-cols-[1fr_auto_1fr] gap-2 items-center max-w-2xl">
        <select class="px-2.5 py-2 rounded-lg bg-zinc-900 border border-zinc-800 text-sm" bind:value={testeA}>
          <option value="">Carta A…</option>
          {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
        </select>
        <span class="text-center text-zinc-500 font-black">＋</span>
        <select class="px-2.5 py-2 rounded-lg bg-zinc-900 border border-zinc-800 text-sm" bind:value={testeB}>
          <option value="">Carta B…</option>
          {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
        </select>
      </div>
      <button class="mt-2 px-4 py-2 rounded-full bg-violet-600 hover:bg-violet-500 text-white text-xs font-semibold transition disabled:opacity-50" disabled={testando} onclick={testar}>{testando ? "Testando…" : "Testar fusão"}</button>
      {#if testeMsg}<p class="mt-2 max-w-2xl text-xs rounded-lg px-3 py-2 border {testeOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{testeMsg}</p>{/if}
    </div>
  {/if}
</div>
