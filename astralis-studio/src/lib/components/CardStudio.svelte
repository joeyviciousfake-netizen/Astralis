<script lang="ts">
  // CardStudio — espelha o CardStudio do FM-Studio (mesma estrutura e visual:
  // lista virtualizada + busca + ordem + pills + chips, detalhe em caixas com
  // ↺ por campo, preview, Salvar/Validar/Duplicar/Criar/Jogar).
  // Dado 100% Astralis: schemas/card.schema.json via comandos Tauri
  // listar_cartas/salvar_carta/validar_carta/jogar_carta (R1/R4).
import { useCards } from "$lib/stores/cards.svelte";
import type { Card, CardTypeGroup } from "$lib/stores/cards.svelte";
import { useValidate } from "$lib/stores/validate.svelte";
import { useEffects } from "$lib/stores/effects.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";
  import { invoke } from "@tauri-apps/api/core";
  import { typeName, monsterTypeName, attrName, cardTypeBg, MONSTER_TYPES, ATTRIBUTES, GUARDIAN_STARS, starName } from "$lib/cardMeta";
  import AssetDrop from "$lib/components/AssetDrop.svelte";
  import snapshot from "../../generated/cards-snapshot.json";

  const KNOWN_EFFECTS: Array<{ id: string; name?: string }> = (snapshot as { effects?: Array<{ id: string; name?: string }> }).effects ?? [];

  let store = useCards();
  const v = useValidate();
  const effStore = useEffects();
  // Modelos de efeito: do PROJETO (app via ler_efeitos), snapshot só como
  // leitura de reserva no navegador. Projeto vazio = select vazio (R4: só o
  // que o Astralis sabe executar — e só o que importar).
  let modelosEfeitos = $derived(effStore.dado.effects.length ? effStore.dado.effects : KNOWN_EFFECTS);

  const detailFlash = useSectionShell({
    mount: () => { void effStore.ensureLoaded(); },
    onIso: () => { store.selectedId = null; lastSyncId = null; },
    onSave: () => {
      if (store.selected) save().catch((e) => detailFlash.flashSave(`Falha ao salvar carta: ${errMsg(e)}`, false));
    },
    extra: [["keydown", onEsc]],
    cleanup: () => {
      if (rafId !== null) cancelAnimationFrame(rafId);
    },
  });
  function onEsc(e: KeyboardEvent) {
    if (e.key === "Escape" && showFilters) showFilters = false;
  }
  const detailMsg = $derived(detailFlash.saveMsg);
  const detailOk = $derived(detailFlash.saveOk);

  // Edições do detalhe
  let nameEdit = $state("");
  let descEdit = $state("");
  let artEdit = $state("");
  let typeEdit = $state("monster");
  let mtypeEdit = $state("warrior");
  let attrEdit = $state("earth");
  let lvlEdit = $state(1);
  let atkEdit = $state(0);
  let defEdit = $state(0);
  // Dados FM (schemas/rule 11): só dado, o jogo ignora na mesa V1.
  // Vazio = ausente (N/A na fonte).
  let gstar1Edit = $state("");
  let gstar2Edit = $state("");
  let pwdEdit = $state("");
  let chipEdit = $state("");
  let effectsEdit = $state<string[]>([]);
  let tagsEdit = $state("");
  let idEdit = $state("");
  let isNew = $state(false);
  // Snapshot dos originais (ao selecionar) — campo alterado mostra ↺.
  type Orig = { name: string; desc: string; art: string; type: string; mtype: string; attr: string; lvl: number; atk: number; def: number; g1: string; g2: string; pwd: string; chip: string; effects: string[]; tags: string };
  let orig = $state<Orig | null>(null);
  let fieldErrors = $state<Array<{ campo: string; mensagem: string }>>([]);
  let playMsg = $state("");
  let playOk = $state(false);
  let effectPick = $state("");

  let isMonster = $derived(typeEdit === "monster");

  // sync edits quando a seleção muda (só no id novo)
  let lastSyncId: string | null = null;
  $effect(() => {
    const sel = store.selected;
    if (sel && sel.id !== lastSyncId) {
      lastSyncId = sel.id;
      isNew = false;
      nameEdit = sel.name ?? "";
      descEdit = sel.description ?? "";
      artEdit = sel.artwork ?? "";
      typeEdit = sel.card_type ?? "monster";
      mtypeEdit = sel.monster_type ?? "warrior";
      attrEdit = sel.attribute ?? "earth";
      lvlEdit = sel.level ?? 1;
      atkEdit = sel.attack ?? 0;
      defEdit = sel.defense ?? 0;
      gstar1Edit = sel.guardian_star_1 ?? "";
      gstar2Edit = sel.guardian_star_2 ?? "";
      pwdEdit = sel.password ?? "";
      chipEdit = sel.starchip_cost === undefined || sel.starchip_cost === null ? "" : String(sel.starchip_cost);
      effectsEdit = [...(sel.effects ?? [])];
      tagsEdit = (sel.tags ?? []).join(", ");
      idEdit = sel.id;
      fieldErrors = [];
      playMsg = "";
      orig = {
        name: nameEdit, desc: descEdit, art: artEdit, type: typeEdit,
        mtype: mtypeEdit, attr: attrEdit, lvl: lvlEdit, atk: atkEdit,
        def: defEdit, g1: gstar1Edit, g2: gstar2Edit, pwd: pwdEdit,
        chip: chipEdit, effects: [...effectsEdit], tags: tagsEdit,
      };
    }
  });

  function resetField<K extends keyof Orig>(k: K, set: (v: Orig[K]) => void) {
    if (!orig) return;
    set(orig[k]);
  }

  // Filtros: pills de tipo + painel (atributo, ATK/DEF, só com erro)
  const TYPE_PILLS: Array<{ id: CardTypeGroup | "all"; label: string }> = [
    { id: "all", label: "Todas" },
    { id: "monster", label: "Monstros" },
    { id: "spell", label: "Magias" },
    { id: "trap", label: "Armadilhas" },
    { id: "equip", label: "Equipamentos" },
    { id: "ritual", label: "Rituais" },
  ];
  let showFilters = $state(false);
  let onlyErrors = $state(false);
  let errorIds = $derived.by(() => new Set((v.report?.issues ?? []).map((i) => i.card_id)));
  let listed = $derived.by(() => {
    const base = store.filtered;
    if (!onlyErrors) return base;
    if (!v.report) return base;
    return base.filter((c) => errorIds.has(c.id));
  });
  function toggleType(g: CardTypeGroup | "all") {
    if (g === "all") { store.setFilters({ types: [] }); return; }
    const cur = store.filters.types;
    const next = cur.includes(g) ? cur.filter((x) => x !== g) : [...cur, g];
    if (!next.includes("monster")) {
      store.setFilters({ types: next, attrs: [], atkMin: null, atkMax: null, defMin: null, defMax: null });
    } else {
      store.setFilters({ types: next });
    }
  }
  function toggleAttr(a: string) {
    const cur = store.filters.attrs;
    store.setFilters({ attrs: cur.includes(a) ? cur.filter((x) => x !== a) : [...cur, a] });
  }
  function numOrNull(val: string): number | null {
    if (val.trim() === "") return null;
    const n = Number(val);
    return Number.isFinite(n) ? Math.max(0, Math.floor(n)) : null;
  }
  let showMonsterFields = $derived(store.filters.types.length === 0 || store.filters.types.includes("monster"));
  let activeChips = $derived.by(() => {
    const f = store.filters;
    const out: Array<{ label: string; clear: () => void }> = [];
    if (f.types.length) out.push({ label: `Tipo: ${f.types.map(typeName).join(", ")}`, clear: () => store.setFilters({ types: [] }) });
    if (f.attrs.length) out.push({ label: `Atrib.: ${f.attrs.map(attrName).join("/")}`, clear: () => store.setFilters({ attrs: [] }) });
    if (f.atkMin !== null || f.atkMax !== null) out.push({ label: `ATK ${f.atkMin ?? 0}–${f.atkMax ?? 9999}`, clear: () => store.setFilters({ atkMin: null, atkMax: null }) });
    if (f.defMin !== null || f.defMax !== null) out.push({ label: `DEF ${f.defMin ?? 0}–${f.defMax ?? 9999}`, clear: () => store.setFilters({ defMin: null, defMax: null }) });
    if (onlyErrors) out.push({ label: "Só com erro", clear: () => { onlyErrors = false; } });
    return out;
  });
  function onSearch(e: Event) {
    store.filter = (e.target as HTMLInputElement).value;
  }

  // Scroll virtual da lista (espelha o FM: só linhas visíveis no DOM)
  let scrollEl: HTMLDivElement | null = $state(null);
  let rowsEl: HTMLDivElement | null = $state(null);
  let scrollTop = $state(0);
  let containerHeight = $state(560);
  let rowH = $state(60);
  function measureRow() {
    const first = rowsEl?.firstElementChild as HTMLElement | null;
    if (!first) return;
    const h = Math.round(first.getBoundingClientRect().height) + 4;
    if (h >= 40 && h <= 160 && Math.abs(h - rowH) > 1) rowH = h;
  }
  let startIdx = $derived(Math.max(0, Math.floor(scrollTop / rowH) - 2));
  let visibleCount = $derived(Math.ceil(containerHeight / rowH) + 8);
  let endIdx = $derived(Math.min(listed.length, startIdx + visibleCount));
  let visibleWindowed = $derived(listed.slice(startIdx, endIdx));
  let totalHeight = $derived(listed.length * rowH);
  let topPad = $derived(startIdx * rowH);
  let rafId: number | null = null;
  function onScroll(e: Event) {
    const el = e.currentTarget as HTMLDivElement;
    if (rafId !== null) return;
    rafId = requestAnimationFrame(() => {
      scrollTop = el.scrollTop;
      rafId = null;
    });
  }
  $effect(() => {
    const el = scrollEl;
    const rows = rowsEl;
    if (!el) return;
    measureRow();
    containerHeight = el.clientHeight;
    el.addEventListener("scroll", onScroll, { passive: true });
    const ro = new ResizeObserver((entries) => {
      for (const ent of entries) {
        if (ent.target === el) containerHeight = ent.contentRect.height;
        else measureRow();
      }
    });
    ro.observe(el);
    if (rows) ro.observe(rows);
    return () => {
      el.removeEventListener("scroll", onScroll);
      ro.disconnect();
    };
  });
  let lastScrollToId: string | null = null;
  function selectInList(id: string) {
    lastScrollToId = id;
    store.selectedId = id;
  }
  $effect(() => {
    const sid = store.selectedId;
    if (sid === null || sid === lastScrollToId || !scrollEl) return;
    const idx = listed.findIndex((c) => c.id === sid);
    if (idx < 0) return;
    lastScrollToId = sid;
    const top = idx * rowH;
    if (top < scrollTop || top > scrollTop + containerHeight - rowH) {
      scrollTop = Math.max(0, top - Math.floor(containerHeight / 2));
      scrollEl.scrollTop = scrollTop;
    }
  });

  function buildCard(): Card {
    const tags = tagsEdit.split(",").map((t) => t.trim()).filter(Boolean);
    const card: Card = {
      schema_version: 1,
      id: (isNew ? idEdit.trim() : (store.selected?.id ?? idEdit.trim())) || "card_nova",
      name: nameEdit.trim() || "Sem nome",
      description: descEdit.trim(),
      artwork: artEdit.trim(),
      card_type: typeEdit,
      effects: [...effectsEdit],
      tags,
    };
    if (typeEdit === "monster") {
      card.monster_type = mtypeEdit;
      card.attribute = attrEdit;
      card.level = Math.min(12, Math.max(1, Math.floor(Number(lvlEdit) || 1)));
      card.attack = Math.min(9999, Math.max(0, Math.floor(Number(atkEdit) || 0)));
      card.defense = Math.min(9999, Math.max(0, Math.floor(Number(defEdit) || 0)));
    }
    // Dados FM: só entram quando preenchidos (vazio = ausente = N/A).
    if (gstar1Edit) card.guardian_star_1 = gstar1Edit;
    if (gstar2Edit) card.guardian_star_2 = gstar2Edit;
    if (pwdEdit.trim()) card.password = pwdEdit.trim();
    if (chipEdit.trim()) {
      const n = Math.floor(Number(chipEdit.trim()));
      card.starchip_cost = Number.isFinite(n) && n >= 0 ? n : (chipEdit.trim() as unknown as number);
    }
    return card;
  }

  async function save() {
    const card = buildCard();
    detailFlash.clear();
    fieldErrors = [];
    playMsg = "";
    try {
      const saved = await store.update(card);
      orig = {
        name: saved.name, desc: saved.description ?? "", art: saved.artwork ?? "",
        type: saved.card_type, mtype: saved.monster_type ?? "warrior",
        attr: saved.attribute ?? "earth", lvl: saved.level ?? 1,
        atk: saved.attack ?? 0, def: saved.defense ?? 0,
        g1: saved.guardian_star_1 ?? "", g2: saved.guardian_star_2 ?? "",
        pwd: saved.password ?? "",
        chip: saved.starchip_cost === undefined || saved.starchip_cost === null ? "" : String(saved.starchip_cost),
        effects: [...(saved.effects ?? [])], tags: (saved.tags ?? []).join(", "),
      };
      if (isNew) {
        isNew = false;
        lastSyncId = saved.id;
        store.selectedId = saved.id;
      }
      void v.refresh(store.cards);
      detailFlash.flashSave("Alterações salvas", true);
    } catch (e) {
      detailFlash.flashSave(`Falha ao salvar: ${errMsg(e)}`, false);
    }
  }

  async function validateNow() {
    fieldErrors = [];
    const card = buildCard();
    try {
      const { file: _drop, ...data } = card;
      const erros: Array<{ campo: string; mensagem: string }> = await invoke("validar_carta", { carta: data });
      fieldErrors = erros;
      detailFlash.flashSave(erros.length ? `${erros.length} erro(s) — veja a lista` : "Carta válida", !erros.length);
    } catch (e) {
      detailFlash.flashSave(`Falha ao validar: ${errMsg(e)}`, false);
    }
  }

  function duplicate() {
    const sel = store.selected;
    if (!sel) return;
    const base = sel.id.replace(/_copia\d*$/, "");
    let n = 1;
    while (store.idMap().has(`${base}_copia${n > 1 ? n : ""}`)) n++;
    const nid = `${base}_copia${n > 1 ? n : ""}`;
    lastSyncId = null;
    isNew = true;
    idEdit = nid;
    nameEdit = `${sel.name} (cópia)`;
    descEdit = sel.description ?? "";
    artEdit = sel.artwork ?? "";
    typeEdit = sel.card_type;
    mtypeEdit = sel.monster_type ?? "warrior";
    attrEdit = sel.attribute ?? "earth";
    lvlEdit = sel.level ?? 1;
    atkEdit = sel.attack ?? 0;
    defEdit = sel.defense ?? 0;
    gstar1Edit = sel.guardian_star_1 ?? "";
    gstar2Edit = sel.guardian_star_2 ?? "";
    pwdEdit = sel.password ?? "";
    chipEdit = sel.starchip_cost === undefined || sel.starchip_cost === null ? "" : String(sel.starchip_cost);
    effectsEdit = [...(sel.effects ?? [])];
    tagsEdit = (sel.tags ?? []).join(", ");
    orig = null;
    fieldErrors = [];
    detailFlash.flashSave("Cópia pronta — ajuste e clique em Salvar", true);
  }

  function createNew() {
    lastSyncId = null;
    isNew = true;
    idEdit = "card_nova";
    nameEdit = "";
    descEdit = "";
    artEdit = "";
    typeEdit = "monster";
    mtypeEdit = "warrior";
    attrEdit = "earth";
    lvlEdit = 1;
    atkEdit = 0;
    defEdit = 0;
    gstar1Edit = "";
    gstar2Edit = "";
    pwdEdit = "";
    chipEdit = "";
    effectsEdit = [];
    tagsEdit = "starter";
    orig = null;
    fieldErrors = [];
    playMsg = "";
    store.selectedId = null;
  }

  async function play() {
    playMsg = "";
    try {
      const msg = await store.play(buildCard());
      playOk = true;
      playMsg = msg;
    } catch (e) {
      playOk = false;
      playMsg = errMsg(e);
    }
  }

  function addEffect() {
    if (effectPick && !effectsEdit.includes(effectPick)) effectsEdit = [...effectsEdit, effectPick];
    effectPick = "";
  }
  function removeEffect(id: string) {
    effectsEdit = effectsEdit.filter((e) => e !== id);
  }
  function effectLabel(id: string) {
    const k = modelosEfeitos.find((e) => e.id === id);
    return k?.name ? `${k.name} (${id})` : id;
  }
</script>

<div class="flex-1 min-h-0 flex gap-3 md:gap-4 overflow-hidden">
  <!-- Lista -->
  <section class="w-[300px] lg:w-[340px] shrink-0 flex flex-col min-h-0 rounded-2xl border border-zinc-800 bg-zinc-950/60 overflow-hidden">
    <div class="p-3 pb-2 space-y-2">
      <div class="flex items-center gap-2">
        <div class="relative flex-1">
          <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-600 text-xs">⌕</span>
          <input
            class="w-full pl-7 pr-2 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs placeholder:text-zinc-600 focus:outline-none focus:border-violet-600"
            placeholder="Buscar nome, id, ATK…"
            value={store.filter}
            oninput={onSearch}
          />
        </div>
        <select
          class="px-2 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs text-zinc-300 focus:outline-none"
          value={store.sortBy}
          onchange={(e) => { store.sortBy = (e.target as HTMLSelectElement).value as "id" | "atk" | "def"; }}
          title="Ordem"
        >
          <option value="id">ID</option>
          <option value="atk">ATK</option>
          <option value="def">DEF</option>
        </select>
      </div>
      <div class="flex items-center gap-1 flex-wrap">
        {#each TYPE_PILLS as p (p.id)}
          {@const active = p.id === "all" ? store.filters.types.length === 0 : store.filters.types.includes(p.id)}
          <button
            class="px-2.5 py-1 rounded-full text-[11px] font-medium border transition {active ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-900 text-zinc-400 border-zinc-800 hover:border-zinc-600'}"
            onclick={() => toggleType(p.id)}>{p.label}</button>
        {/each}
        <button
          class="ml-auto px-2.5 py-1 rounded-full text-[11px] font-medium border transition {showFilters || store.activeFilterCount ? 'bg-violet-600/20 text-violet-300 border-violet-600/50' : 'bg-zinc-900 text-zinc-400 border-zinc-800 hover:border-zinc-600'}"
          onclick={() => { showFilters = !showFilters; }}
          title="Filtros avançados"
        >Filtros{#if store.activeFilterCount}<span class="ml-1 px-1 rounded-full bg-violet-600 text-white text-[10px]">{store.activeFilterCount}</span>{/if}</button>
      </div>
      {#if showFilters}
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5 space-y-2">
          {#if showMonsterFields}
            <div>
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">ATRIBUTO</p>
              <div class="flex gap-1 flex-wrap">
                {#each ATTRIBUTES as a (a.id)}
                  <button
                    class="px-2 py-0.5 rounded-full text-[11px] border transition {store.filters.attrs.includes(a.id) ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}"
                    onclick={() => toggleAttr(a.id)}>{a.name}</button>
                {/each}
              </div>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div>
                <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">ATK MÍN/MÁX</p>
                <div class="flex gap-1">
                  <input class="w-full px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" placeholder="0" value={store.filters.atkMin ?? ""} oninput={(e) => store.setFilters({ atkMin: numOrNull((e.target as HTMLInputElement).value) })} />
                  <input class="w-full px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" placeholder="9999" value={store.filters.atkMax ?? ""} oninput={(e) => store.setFilters({ atkMax: numOrNull((e.target as HTMLInputElement).value) })} />
                </div>
              </div>
              <div>
                <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">DEF MÍN/MÁX</p>
                <div class="flex gap-1">
                  <input class="w-full px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" placeholder="0" value={store.filters.defMin ?? ""} oninput={(e) => store.setFilters({ defMin: numOrNull((e.target as HTMLInputElement).value) })} />
                  <input class="w-full px-2 py-1 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" placeholder="9999" value={store.filters.defMax ?? ""} oninput={(e) => store.setFilters({ defMax: numOrNull((e.target as HTMLInputElement).value) })} />
                </div>
              </div>
            </div>
          {/if}
          <label class="flex items-center gap-1.5 text-[11px] text-zinc-400">
            <input type="checkbox" bind:checked={onlyErrors} class="accent-rose-600" /> só com erro
          </label>
          <button class="text-[11px] text-zinc-500 hover:text-zinc-200" onclick={() => { store.resetFilters(); onlyErrors = false; }}>limpar tudo</button>
        </div>
      {/if}
      {#if activeChips.length}
        <div class="flex gap-1 flex-wrap">
          {#each activeChips as chip (chip.label)}
            <button class="px-2 py-0.5 rounded-full bg-violet-600/15 border border-violet-600/40 text-violet-300 text-[10px] hover:bg-violet-600/25" onclick={chip.clear} title="Remover filtro">{chip.label} ✕</button>
          {/each}
        </div>
      {/if}
      <p class="text-[10px] text-zinc-600">{listed.length} de {store.cards.length} cartas</p>
    </div>
    <div bind:this={scrollEl} class="flex-1 overflow-y-auto px-2 pb-2 min-h-0">
      {#if listed.length}
        <div style="height: {totalHeight}px; position: relative;">
          <div bind:this={rowsEl} class="space-y-1" style="padding-top: {topPad}px;">
            {#each visibleWindowed as c (c.id)}
              {@const sel = !isNew && store.selectedId === c.id}
              {@const hasErr = errorIds.has(c.id)}
              <button
                onclick={() => selectInList(c.id)}
                class="w-full text-left rounded-xl border px-2 py-1.5 flex items-center gap-2 transition {sel ? 'bg-white text-zinc-900 border-white shadow' : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-600 text-zinc-100'}"
              >
                <span class="w-9 h-9 rounded-lg bg-gradient-to-br border flex items-center justify-center text-[10px] font-black shrink-0 {cardTypeBg(c.card_type)} text-white">{typeName(c.card_type).slice(0, 1)}</span>
                <span class="min-w-0 flex-1">
                  <span class="block text-xs font-bold truncate">{c.name}{hasErr ? " ⚠" : ""}</span>
                  <span class="block text-[10px] font-mono truncate {sel ? 'text-zinc-600' : 'text-zinc-500'}">{c.id}</span>
                </span>
                {#if typeName(c.card_type) === "Monstro" || c.card_type === "monster"}
                  <span class="text-right shrink-0">
                    <span class="block text-[11px] font-bold">⚔ {c.attack ?? 0}</span>
                    <span class="block text-[10px] {sel ? 'text-zinc-600' : 'text-zinc-500'}">🛡 {c.defense ?? 0}</span>
                  </span>
                {/if}
              </button>
            {/each}
          </div>
        </div>
      {:else if !store.cards.length && !store.loading}
        <div class="p-4 text-center">
          <p class="text-xs text-zinc-400">Projeto vazio — nada carregado.</p>
          <p class="mt-1 text-xs text-zinc-500">Importe um pack para começar.</p>
          <button class="mt-2 px-3 py-1.5 rounded-full bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition" onclick={() => window.dispatchEvent(new CustomEvent("astralis:importar-pack"))}>📥 Importar pack…</button>
        </div>
      {:else}
        <p class="p-4 text-xs text-zinc-500 text-center">Nenhuma carta — ajuste a busca ou crie uma nova.</p>
      {/if}
    </div>
  </section>

  <!-- Detalhe -->
  <section class="flex-1 min-w-0 min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4">
    {#if store.selected || isNew}
      {@const selId = isNew ? idEdit : (store.selected?.id ?? "")}
      <div class="flex items-center gap-3 flex-wrap">
        <span class="w-11 h-11 rounded-xl bg-gradient-to-br border flex items-center justify-center text-sm font-black text-white {cardTypeBg(typeEdit)}">{typeName(typeEdit).slice(0, 1)}</span>
        <div class="min-w-0">
          <h2 class="text-base font-black tracking-tight truncate">{nameEdit || "(sem nome)"}</h2>
          <p class="text-[11px] font-mono text-zinc-500 truncate">{selId} • {typeName(typeEdit)}</p>
        </div>
        <div class="ml-auto flex gap-1.5 flex-wrap">
          <button class="px-3 py-1.5 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={save}>Salvar</button>
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={validateNow}>Validar</button>
          {#if !isNew}
            <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={duplicate}>Duplicar</button>
          {/if}
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={createNew}>Criar nova</button>
          <button class="px-3 py-1.5 rounded-full bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-lg shadow-emerald-600/20 transition" onclick={play}>▶ Jogar</button>
        </div>
      </div>
      {#if detailMsg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border {detailOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{detailMsg}</p>{/if}
      {#if playMsg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {playOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-rose-300 bg-rose-950/30 border-rose-900/50'}">{playMsg}</p>{/if}
      {#if fieldErrors.length}
        <div class="mt-2 rounded-xl border border-rose-900/60 bg-rose-950/20 divide-y divide-rose-900/40">
          {#each fieldErrors as fe (fe.campo + fe.mensagem)}
            <p class="px-3 py-1.5 text-xs text-rose-200"><span class="font-bold">{fe.campo}:</span> {fe.mensagem}</p>
          {/each}
        </div>
      {/if}

      <div class="mt-3 grid md:grid-cols-2 gap-2.5">
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <div class="flex items-center gap-1.5 mb-1.5">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">NOME</p>
            {#if orig && nameEdit !== orig.name}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("name", (x) => { nameEdit = x; })}>↺</button>{/if}
          </div>
          <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={nameEdit} placeholder="Como a carta aparece no jogo" />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <div class="flex items-center gap-1.5 mb-1.5">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">ID {isNew ? "(editável — vira o nome do arquivo)" : "(fixo — não muda)"}</p>
          </div>
          <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600 disabled:opacity-60" bind:value={idEdit} disabled={!isNew} placeholder="card_meu_dragao" />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <div class="flex items-center gap-1.5 mb-1.5">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">TIPO</p>
            {#if orig && typeEdit !== orig.type}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("type", (x) => { typeEdit = x; })}>↺</button>{/if}
          </div>
          <div class="flex gap-1 flex-wrap">
            {#each [["monster", "Monstro"], ["spell", "Magia"], ["trap", "Armadilha"], ["equip", "Equipamento"], ["ritual", "Ritual"]] as [tid, tlabel] (tid)}
              <button class="flex-1 min-w-[80px] py-1.5 rounded-lg text-xs font-medium border transition {typeEdit === tid ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => { typeEdit = tid; }}>{tlabel}</button>
            {/each}
          </div>
        </div>
        {#if isMonster}
          <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
            <div class="flex items-center gap-1.5 mb-1.5">
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">TIPO DE MONSTRO</p>
              {#if orig && mtypeEdit !== orig.mtype}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("mtype", (x) => { mtypeEdit = x; })}>↺</button>{/if}
            </div>
            <select class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none" bind:value={mtypeEdit}>
              {#each MONSTER_TYPES as m (m.id)}<option value={m.id}>{m.name}</option>{/each}
            </select>
          </div>
          <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
            <div class="flex items-center gap-1.5 mb-1.5">
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">ATRIBUTO</p>
              {#if orig && attrEdit !== orig.attr}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("attr", (x) => { attrEdit = x; })}>↺</button>{/if}
            </div>
            <select class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none" bind:value={attrEdit}>
              {#each ATTRIBUTES as a (a.id)}<option value={a.id}>{a.name}</option>{/each}
            </select>
          </div>
          <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">NÍVEL • ATK • DEF</p>
            <div class="grid grid-cols-3 gap-2">
              <label class="block">
                <span class="text-[10px] text-zinc-500">Nv (1–12){#if orig && lvlEdit !== orig.lvl}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("lvl", (x) => { lvlEdit = x; })}>↺</button>{/if}</span>
                <input type="number" min="1" max="12" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={lvlEdit} />
              </label>
              <label class="block">
                <span class="text-[10px] text-zinc-500">ATK{#if orig && atkEdit !== orig.atk}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("atk", (x) => { atkEdit = x; })}>↺</button>{/if}</span>
                <input type="number" min="0" max="9999" step="10" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={atkEdit} />
              </label>
              <label class="block">
                <span class="text-[10px] text-zinc-500">DEF{#if orig && defEdit !== orig.def}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("def", (x) => { defEdit = x; })}>↺</button>{/if}</span>
                <input type="number" min="0" max="9999" step="10" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={defEdit} />
              </label>
            </div>
          </div>
        {/if}
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3 md:col-span-2">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">DADOS FM (só dado — o jogo ignora na mesa)</p>
          <div class="grid sm:grid-cols-2 gap-2">
            <label class="block">
              <span class="text-[10px] text-zinc-500">Estrela guardiã 1{#if orig && gstar1Edit !== orig.g1}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("g1", (x) => { gstar1Edit = x; })}>↺</button>{/if}</span>
              <select class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none" bind:value={gstar1Edit}>
                <option value="">— sem estrela —</option>
                {#each GUARDIAN_STARS as s (s.id)}<option value={s.id}>{s.name}</option>{/each}
              </select>
            </label>
            <label class="block">
              <span class="text-[10px] text-zinc-500">Estrela guardiã 2{#if orig && gstar2Edit !== orig.g2}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("g2", (x) => { gstar2Edit = x; })}>↺</button>{/if}</span>
              <select class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none" bind:value={gstar2Edit}>
                <option value="">— sem estrela —</option>
                {#each GUARDIAN_STARS as s (s.id)}<option value={s.id}>{s.name}</option>{/each}
              </select>
            </label>
            <label class="block">
              <span class="text-[10px] text-zinc-500">Senha (8 números, vazio = sem senha){#if orig && pwdEdit !== orig.pwd}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("pwd", (x) => { pwdEdit = x; })}>↺</button>{/if}</span>
              <input inputmode="numeric" maxlength="8" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600" bind:value={pwdEdit} placeholder="ex.: 89631139" />
            </label>
            <label class="block">
              <span class="text-[10px] text-zinc-500">Starchips (999999 = não comprável, vazio = N/A){#if orig && chipEdit !== orig.chip}<button class="ml-1 text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("chip", (x) => { chipEdit = x; })}>↺</button>{/if}</span>
              <input inputmode="numeric" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600" bind:value={chipEdit} placeholder="ex.: 160" />
            </label>
          </div>
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3 md:col-span-2">
          <div class="flex items-center gap-1.5 mb-1.5">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">DESCRIÇÃO</p>
            {#if orig && descEdit !== orig.desc}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("desc", (x) => { descEdit = x; })}>↺</button>{/if}
          </div>
          <textarea rows="2" class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={descEdit} placeholder="Texto que aparece na carta"></textarea>
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <div class="flex items-center gap-1.5 mb-1.5">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">ARTE (arraste um PNG ou edite o caminho)</p>
            {#if orig && artEdit !== orig.art}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("art", (x) => { artEdit = x; })}>↺</button>{/if}
          </div>
          <AssetDrop tipo="carta" sugestao={isNew ? idEdit : (store.selected?.id ?? "arte")} value={artEdit} onimport={(c) => artEdit = c} />
          <input class="mt-1.5 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono focus:outline-none focus:border-violet-600" bind:value={artEdit} placeholder="assets/cards/minha_arte.png" />
          {#if !artEdit.trim()}
            <p class="mt-1 text-[11px] text-amber-300/90">⚠ sem arte — a prévia mostra um placeholder cinza (igual ao pack FM, que não traz imagem)</p>
          {/if}
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <div class="flex items-center gap-1.5 mb-1.5">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">TAGS (separadas por vírgula)</p>
            {#if orig && tagsEdit !== orig.tags}<button class="text-[11px] text-zinc-500 hover:text-zinc-200" title="Restaurar" onclick={() => resetField("tags", (x) => { tagsEdit = x; })}>↺</button>{/if}
          </div>
          <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={tagsEdit} placeholder="starter, dragao" />
        </div>
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3 md:col-span-2">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">EFEITOS (só vale o que o Astralis sabe executar)</p>
          {#if effectsEdit.length}
            <div class="flex gap-1.5 flex-wrap mb-2">
              {#each effectsEdit as ef (ef)}
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-violet-600/15 border border-violet-600/40 text-violet-200 text-xs">
                  {effectLabel(ef)}
                  <button class="text-violet-400 hover:text-white" title="Remover" onclick={() => removeEffect(ef)}>✕</button>
                </span>
              {/each}
            </div>
          {:else}
            <p class="text-xs text-zinc-500 mb-2">Sem efeitos — carta normal.</p>
          {/if}
          <div class="flex gap-1.5">
            <select class="flex-1 px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none" bind:value={effectPick}>
              <option value="">Escolher modelo…</option>
              {#each modelosEfeitos as k (k.id)}
                <option value={k.id}>{k.name ?? k.id} ({k.id})</option>
              {/each}
            </select>
            <button class="px-3 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={addEffect}>Adicionar</button>
          </div>
        </div>
        <div class="rounded-2xl border border-zinc-700 bg-zinc-900 p-4 md:col-span-2">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-2">PRÉVIA</p>
          <div class="mx-auto w-56 rounded-2xl border-2 {cardTypeBg(typeEdit)} bg-zinc-950 p-3 shadow-xl">
            <p class="text-center text-sm font-black truncate">{nameEdit || "(sem nome)"}</p>
            <p class="text-center text-[10px] text-zinc-400">{typeName(typeEdit)}{isMonster ? ` • ${monsterTypeName(mtypeEdit)} • ${attrName(attrEdit)} • Nv ${lvlEdit}` : ""}</p>
            {#if gstar1Edit || gstar2Edit}
              <p class="text-center text-[10px] text-amber-300/90">☆ {[gstar1Edit, gstar2Edit].filter(Boolean).map(starName).join(" + ")}</p>
            {/if}
            {#if artEdit.trim()}
              <div class="mt-2 h-24 rounded-lg bg-zinc-900 border border-zinc-800 flex flex-col items-center justify-center gap-0.5 px-2">
                <span class="text-2xl">{typeEdit === "spell" ? "✨" : typeEdit === "trap" ? "🪤" : "🐲"}</span>
                <span class="text-[9px] font-mono text-zinc-500 truncate max-w-full">{artEdit.trim()}</span>
              </div>
            {:else}
              <div class="mt-2 h-24 rounded-lg bg-zinc-800 border border-zinc-700 flex flex-col items-center justify-center gap-0.5">
                <span class="text-2xl grayscale opacity-50">🖼</span>
                <span class="text-[9px] text-zinc-500">sem arte (cinza automático)</span>
              </div>
            {/if}
            {#if isMonster}
              <p class="mt-2 text-center text-sm font-black">⚔ {atkEdit} <span class="text-zinc-500">/</span> 🛡 {defEdit}</p>
            {/if}
            <p class="mt-1.5 text-[11px] text-zinc-400 leading-snug line-clamp-3">{descEdit || "(sem descrição)"}</p>
            {#if !artEdit.trim()}
              <p class="mt-1.5 text-[10px] text-amber-300/90 text-center">⚠ sem arte — o jogo mostra um cinza no lugar</p>
            {/if}
            {#if !descEdit.trim()}
              <p class="mt-1 text-[10px] text-amber-300/90 text-center">⚠ sem texto (comum no pack FM)</p>
            {/if}
          </div>
        </div>
      </div>
    {:else}
      <div class="h-full min-h-[280px] flex flex-col items-center justify-center gap-3 text-center">
        <div class="w-16 h-16 rounded-3xl bg-gradient-to-br from-violet-600/20 to-indigo-600/20 border border-violet-500/20 flex items-center justify-center text-3xl">🃏</div>
        <p class="text-sm font-bold text-zinc-200">Escolha uma carta na lista</p>
        <p class="text-xs text-zinc-500 max-w-sm">Ou clique em <span class="text-zinc-300 font-semibold">Criar nova</span> — mas prefira <span class="text-zinc-300 font-semibold">Duplicar</span> uma parecida e editar.</p>
        <button class="mt-1 px-4 py-2 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={createNew}>Criar nova</button>
      </div>
    {/if}
  </section>
</div>
