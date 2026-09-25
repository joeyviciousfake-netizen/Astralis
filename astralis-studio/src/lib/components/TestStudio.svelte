<script lang="ts">
  // TestStudio — Campo de Testes como MESA DE DUELO (docs 04 §4.6 + 10 §10.2/10.3,
  // contrato test_state V1, D33/D34).
  // O usuário vê a mesa como no duelo: rival no topo, ele embaixo, mão em faixa.
  // CLIQUE num espaço vazio (ou ocupado) abre o picker de carta; X esvazia;
  // mini-botões viram p/ cima/baixo e ATK/DEF; clique numa carta da mão remove.
  // R1/R2/R4: nunca calcula jogo — só monta DADO (mesmo test_state + first_p1)
  // e lança o Astralis de verdade via jogar_duelo (--project + --setup).
  import { useCards } from "$lib/stores/cards.svelte";
  import { useDuelists } from "$lib/stores/duelists.svelte";
  import { useDecks } from "$lib/stores/decks.svelte";
  import { useSectionShell } from "$lib/section";
  import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";

  const cardsStore = useCards();
  const duelistsStore = useDuelists();
  const decksStore = useDecks();

  type Slot = { id: string; cima: boolean; atk: boolean };
  type ZonaKey = "p0m" | "p0s" | "p1m" | "p1s";
  const slotVazio = (): Slot => ({ id: "", cima: true, atk: true });
  const gradeVazia = (): Slot[] => [slotVazio(), slotVazio(), slotVazio(), slotVazio(), slotVazio()];

  // Duelo base (mesmo dado do Duelo rápido: os 2 duelistas + vida; a ordem é
  // FIXA em "você primeiro" porque o teste sempre começa na sua fase da mão).
  let d1 = $state("");
  let d2 = $state("");
  let vida = $state(4000);
  let vidaSugerida = $state(false);
  let seed = $state(42);
  let arena = $state("arena_starter");
  let arenas = $state<string[]>(["arena_starter"]);

  // Campo de Testes: minha mão (até 5) + 4 grades de 5 (null = vazio).
  let mao = $state<string[]>(["", "", "", "", ""]);
  let grades = $state<Record<ZonaKey, Slot[]>>({ p0m: gradeVazia(), p0s: gradeVazia(), p1m: gradeVazia(), p1s: gradeVazia() });

  type ItemValid = { campo: string; campoId?: string; mensagem: string; nivel?: string };
  let validLista = $state<ItemValid[]>([]);
  let validErro = $state("");
  let validando = $state(false);
  let valGen = $state(0);

  let msg = $state("");
  let ok = $state(false);
  let jogando = $state(false);

  // Picker de carta: qual espaço estamos preenchendo (null = fechado).
  type Alvo = { zona: ZonaKey | "mao"; index: number };
  let picker = $state<Alvo | null>(null);
  let busca = $state("");

  let mapa = $derived(cardsStore.idMap());

  useSectionShell({
    mount: () => {
      void cardsStore.loadAll();
      void duelistsStore.ensureNamesLoaded();
      void decksStore.ensureLoaded();
      void carregarArenas();
      void validarVivo();
    },
    cleanup: () => { if (timer !== null) clearTimeout(timer); },
  });

  async function carregarArenas() {
    try {
      const r = await invokeLoad<string[]>("listar_arenas");
      if (r.length) {
        arenas = r;
        if (!r.includes(arena)) arena = r[0];
      }
    } catch {
      /* fica no padrão */
    }
  }

  // Projeto vazio = sem duelista fixo: quando a lista carrega, escolhe os
  // dois primeiros; vida padrão = a do duelista 1 (igual ao Duelo rápido).
  $effect(() => {
    const lista = duelistsStore.duelists;
    if (lista.length) {
      if (!d1 || !lista.some((d) => d.id === d1)) trocarD1(lista[0].id);
      if (!d2 || !lista.some((d) => d.id === d2)) d2 = (lista[1] ?? lista[0]).id;
    }
    const d = duelistsStore.getById(d1);
    if (d && !vidaSugerida && d.starting_lp && d.starting_lp > 0) {
      vida = d.starting_lp;
      vidaSugerida = true;
    }
  });
  function trocarD1(v: string) {
    d1 = v;
    vidaSugerida = false;
  }

  function deckNome(duelId: string): string {
    const d = duelistsStore.getById(duelId);
    if (!d?.deck_id) return "sem deck";
    const dk = decksStore.getById(d.deck_id);
    return dk ? `${dk.name} (${dk.cards.length})` : d.deck_id;
  }

  function cartaDe(id: string) {
    return mapa.get(id.trim()) ?? null;
  }

  function linhaCarta(id: string): string {
    const t = id.trim();
    if (!t) return "vazio";
    const c = cartaDe(t);
    if (!c) return "não existe no projeto — escolha uma carta da lista";
    return c.card_type === "monster"
      ? `${c.name} • ATK ${c.attack ?? 0} / DEF ${c.defense ?? 0}`
      : `${c.name} • ${c.card_type}`;
  }

  function tipoCurto(id: string): string {
    const c = cartaDe(id);
    if (!c) return "";
    return c.card_type === "monster" ? "Monstro" : c.card_type === "spell" ? "Magia" : c.card_type;
  }

  function slotJson(s: Slot): Record<string, unknown> | null {
    const id = s.id.trim();
    if (!id) return null;
    // face_up/attack_position ausentes = true (contrato): só manda o que é falso.
    const o: Record<string, unknown> = { card_id: id };
    if (!s.cima) o.face_up = false;
    if (!s.atk) o.attack_position = false;
    return o;
  }

  function testeVazioLocal(): boolean {
    if (mao.some((m) => m.trim())) return false;
    return (Object.keys(grades) as ZonaKey[]).every((z) => grades[z].every((s) => !s.id.trim()));
  }

  function testStateJson(): Record<string, unknown> | null {
    if (testeVazioLocal()) return null;
    const zona = (z: ZonaKey) => grades[z].map(slotJson);
    return {
      my_hand: mao.map((m) => m.trim()).filter((m) => m),
      p0_monster: zona("p0m"),
      p0_spell: zona("p0s"),
      p1_monster: zona("p1m"),
      p1_spell: zona("p1s"),
    };
  }

  // Espelho EXATO do --setup que o Iniciar teste manda (mesmo duel_id e win do
  // Duelo rápido; duelistas/decks o Rust resolve do disco na hora de jogar).
  function montarSetup(): Record<string, unknown> {
    const ts = testStateJson();
    return {
      schema_version: 1,
      duel_id: "duel_studio_teste",
      duelist1: { duelist_id: d1 || "duelist_1", deck_id: "deck_1" },
      duelist2: { duelist_id: d2 || "duelist_2", deck_id: "deck_2" },
      starting_lp: Math.floor(Number(vida) || 0),
      turn_order: "first_p1",
      seed: Math.floor(Number(seed) || 0),
      arena_id: arena || "arena_starter",
      win: { on_lp_zero: true, on_deckout: true },
      ...(ts ? { test_state: ts } : {}),
    };
  }

  // Validação viva: pergunta ao backend (checar_test_state) a cada mudança,
  // com pausa de 350ms para não disparar um invoke por tecla.
  let timer: ReturnType<typeof setTimeout> | null = null;
  function agendarValidar() {
    if (timer !== null) clearTimeout(timer);
    timer = setTimeout(() => void validarVivo(), 350);
  }
  $effect(() => {
    void d1; void d2; void vida; void seed; void arena;
    void mao.join("|");
    void JSON.stringify(grades);
    void cardsStore.cards.length;
    agendarValidar();
  });

  async function validarVivo(): Promise<ItemValid[]> {
    const g = ++valGen;
    validErro = "";
    if (!cardsStore.cards.length) {
      if (g === valGen) validLista = [];
      return [];
    }
    validando = true;
    try {
      const r = await invokeLoad<ItemValid[]>("validar_test_state", { setup: montarSetup() });
      if (g !== valGen) return validLista;
      validLista = r ?? [];
      return validLista;
    } catch (e) {
      if (g === valGen) {
        validErro = errMsg(e);
        validLista = [];
      }
      return [];
    } finally {
      if (g === valGen) validando = false;
    }
  }

  let errosVivos = $derived(validLista.filter((v) => (v.nivel ?? "erro") !== "aviso"));
  let avisosVivos = $derived(validLista.filter((v) => (v.nivel ?? "erro") === "aviso"));

  // Contadores da mesa (só leitura, p/ o resumo da barra fixa).
  let maoCount = $derived(mao.filter((m) => m.trim()).length);
  let campoCount = $derived(
    (Object.keys(grades) as ZonaKey[]).reduce((n, z) => n + grades[z].filter((s) => s.id.trim()).length, 0),
  );

  // ---- Picker de carta (um modal só p/ a mesa inteira) ----
  function abrirPicker(zona: ZonaKey | "mao", index: number) {
    busca = "";
    picker = { zona, index };
  }
  function fecharPicker() {
    picker = null;
    busca = "";
  }
  function escolherCarta(id: string) {
    if (!picker) return;
    if (picker.zona === "mao") {
      mao[picker.index] = id;
    } else {
      const atual = grades[picker.zona][picker.index];
      grades[picker.zona][picker.index] = { id, cima: atual.cima, atk: atual.atk };
    }
    fecharPicker();
    void validarVivo();
  }
  function esvaziarAlvo() {
    if (!picker) return;
    if (picker.zona === "mao") mao[picker.index] = "";
    else grades[picker.zona][picker.index] = slotVazio();
    fecharPicker();
    void validarVivo();
  }
  function alvoTemCarta(): boolean {
    if (!picker) return false;
    return picker.zona === "mao" ? !!mao[picker.index].trim() : !!grades[picker.zona][picker.index].id.trim();
  }
  function alvoTitulo(): string {
    if (!picker) return "";
    if (picker.zona === "mao") return `Mão — espaço ${picker.index + 1}`;
    const nomes: Record<ZonaKey, string> = { p0m: "Seus monstros", p0s: "Suas magias", p1m: "Monstros do rival", p1s: "Magias do rival" };
    return `${nomes[picker.zona]} — espaço ${picker.index + 1}`;
  }

  let buscaLimpa = $derived(busca.trim().toLowerCase());
  let filtradas = $derived((() => {
    const arr = cardsStore.cards;
    if (!buscaLimpa) return arr;
    return arr.filter(
      (c) =>
        c.id.toLowerCase().includes(buscaLimpa) ||
        (c.name ?? "").toLowerCase().includes(buscaLimpa) ||
        String(c.attack ?? "").includes(buscaLimpa) ||
        String(c.defense ?? "").includes(buscaLimpa),
    );
  })());
  let resultados = $derived(filtradas.slice(0, 80));

  // ---- Toggles e limpeza por espaço ----
  function alternarCima(z: ZonaKey, i: number) {
    const s = grades[z][i];
    if (!s.id.trim()) return;
    grades[z][i] = { ...s, cima: !s.cima };
  }
  function alternarAtk(z: ZonaKey, i: number) {
    const s = grades[z][i];
    if (!s.id.trim()) return;
    grades[z][i] = { ...s, atk: !s.atk };
  }
  function esvaziarSlot(z: ZonaKey, i: number) {
    grades[z][i] = slotVazio();
    void validarVivo();
  }
  // Clique numa carta da mão REMOVE (pedido do usuário: mão é faixa rápida).
  function clicarMao(i: number) {
    if (mao[i].trim()) {
      mao[i] = "";
      void validarVivo();
    } else {
      abrirPicker("mao", i);
    }
  }

  function limparMesa() {
    mao = ["", "", "", "", ""];
    grades = { p0m: gradeVazia(), p0s: gradeVazia(), p1m: gradeVazia(), p1s: gradeVazia() };
    ok = true;
    msg = "Mesa limpa — mão vazia e os 20 espaços vazios (Iniciar teste assim abre um duelo normal).";
    void validarVivo();
  }

  async function iniciarTeste() {
    msg = "";
    ok = false;
    if (!cardsStore.cards.length) {
      msg = "Sem cartas no projeto — importe um pack antes de montar o teste.";
      return;
    }
    if (!d1 || !d2) {
      msg = "Escolha os dois duelistas antes de iniciar o teste.";
      return;
    }
    jogando = true;
    try {
      const atual = await validarVivo();
      const erros = atual.filter((v) => (v.nivel ?? "erro") !== "aviso");
      if (erros.length) {
        msg = `Arruma antes de testar:\n${erros.map((e) => `- ${e.mensagem}`).join("\n")}`;
        return;
      }
      const res: { mensagem?: unknown } = await invokeSave(
        "jogar_duelo",
        {
          pedido: {
            duelista1: d1,
            duelista2: d2,
            vida: Math.floor(Number(vida) || 0),
            seed: Math.floor(Number(seed) || 0),
            arena,
            ordem: "first_p1",
            test_state: testStateJson(),
          },
        },
        120000,
      );
      ok = true;
      msg = String(res?.mensagem ?? "Astralis aberto");
    } catch (e) {
      ok = false;
      msg = errMsg(e);
    } finally {
      jogando = false;
    }
  }
</script>

<!-- Snippet de UM espaço da mesa: vazio = tracejado convidativo; cheio = mini
  carta clicável (abre o picker), com X p/ anular e 2 mini-botões (virada e
  posição). Botão direito também vira p/ cima/baixo. `compact` = lado do rival
  (menor, de costas quando virada p/ baixo). -->
{#snippet espaco(z: ZonaKey, i: number, compact: boolean)}
  {@const s = grades[z][i]}
  {@const c = cartaDe(s.id)}
  {@const ladoRival = z === "p1m" || z === "p1s"}
  {#if !s.id.trim()}
    <button
      class="group rounded-xl border-2 border-dashed flex flex-col items-center justify-center gap-0.5 transition cursor-pointer
        {compact ? 'min-h-[64px] py-2' : 'min-h-[92px] py-3'}
        {ladoRival ? 'border-rose-900/50 bg-rose-950/10 hover:border-rose-700 hover:bg-rose-950/25' : 'border-emerald-900/50 bg-emerald-950/10 hover:border-emerald-600 hover:bg-emerald-950/25'}"
      title="Espaço {i + 1} vazio — clique para colocar uma carta"
      onclick={() => abrirPicker(z, i)}
    >
      <span class="{compact ? 'text-base' : 'text-xl'} text-zinc-600 group-hover:text-zinc-300 transition leading-none">＋</span>
      <span class="text-[10px] text-zinc-600 group-hover:text-zinc-400 transition">vazio</span>
    </button>
  {:else if !s.cima}
    <!-- Virada p/ baixo: mostra o verso (igual p/ os dois lados) -->
    <div
      class="rounded-xl border-2 overflow-hidden transition
        {compact ? 'min-h-[64px]' : 'min-h-[92px]'}
        {ladoRival ? 'border-rose-800/70 bg-gradient-to-br from-rose-950 via-zinc-900 to-zinc-950' : 'border-sky-800/70 bg-gradient-to-br from-sky-950 via-zinc-900 to-zinc-950'}"
      title="{linhaCarta(s.id)} • virada p/ baixo • {s.atk ? 'em Ataque' : 'em Defesa'} — clique para trocar, botão direito desvira"
      role="button"
      tabindex="0"
      onclick={() => abrirPicker(z, i)}
      oncontextmenu={(e) => { e.preventDefault(); alternarCima(z, i); }}
      onkeydown={(e) => { if (e.target !== e.currentTarget) return; if (e.key === "Enter" || e.key === " ") { e.preventDefault(); abrirPicker(z, i); } }}
    >
      <div class="flex items-center justify-between px-1 pt-0.5">
        <span class="text-[9px] text-zinc-500 font-bold">{i + 1}</span>
        <button class="px-1 rounded text-[10px] text-zinc-500 hover:text-rose-300 hover:bg-white/10 transition" title="Anular (esvaziar este espaço)" onclick={(e) => { e.stopPropagation(); esvaziarSlot(z, i); }}>✕</button>
      </div>
      <div class="flex flex-col items-center pb-1 px-1">
        <span class="{compact ? 'text-lg' : 'text-2xl'} leading-none">🂠</span>
        {#if !compact}<span class="text-[9px] text-zinc-500">virada p/ baixo</span>{/if}
        <span class="flex gap-0.5 mt-0.5">
          <button class="px-1 py-px rounded text-[9px] bg-white/10 hover:bg-white/20 text-zinc-200 transition" title="Desvirar (p/ cima)" onclick={() => alternarCima(z, i)}>▲</button>
          <button class="px-1 py-px rounded text-[9px] bg-white/10 hover:bg-white/20 text-zinc-200 transition" title={s.atk ? "Está em Ataque — clique p/ Defesa" : "Está em Defesa — clique p/ Ataque"} onclick={() => alternarAtk(z, i)}>{s.atk ? "🗡" : "🛡"}</button>
        </span>
      </div>
    </div>
  {:else}
    <!-- Virada p/ cima: mini carta com nome + ATK/DEF -->
    <div
      class="rounded-xl border-2 overflow-hidden transition cursor-pointer hover:-translate-y-0.5
        {compact ? 'min-h-[64px]' : 'min-h-[92px]'}
        {ladoRival ? 'border-rose-800/60 bg-zinc-900 hover:border-rose-500 hover:shadow-lg hover:shadow-rose-950/40' : 'border-emerald-800/60 bg-zinc-900 hover:border-emerald-500 hover:shadow-lg hover:shadow-emerald-950/40'}"
      title="{linhaCarta(s.id)} • {s.atk ? 'em Ataque' : 'em Defesa'} — clique para trocar, botão direito vira p/ baixo"
      role="button"
      tabindex="0"
      onclick={() => abrirPicker(z, i)}
      oncontextmenu={(e) => { e.preventDefault(); alternarCima(z, i); }}
      onkeydown={(e) => { if (e.target !== e.currentTarget) return; if (e.key === "Enter" || e.key === " ") { e.preventDefault(); abrirPicker(z, i); } }}
    >
      <div class="flex items-center gap-1 px-1 pt-0.5">
        <span class="text-[9px] font-black {ladoRival ? 'text-rose-400' : 'text-emerald-400'}">{s.atk ? "🗡" : "🛡"}</span>
        {#if !compact}<span class="text-[9px] text-zinc-500 uppercase tracking-wide">{tipoCurto(s.id)}</span>{/if}
        <button class="ml-auto px-1 rounded text-[10px] text-zinc-500 hover:text-rose-300 hover:bg-white/10 transition" title="Anular (esvaziar este espaço)" onclick={(e) => { e.stopPropagation(); esvaziarSlot(z, i); }}>✕</button>
      </div>
      <p class="px-1.5 text-left font-semibold text-zinc-100 leading-tight {compact ? 'text-[10px] line-clamp-1' : 'text-[11px] line-clamp-2'}">{c?.name ?? s.id}</p>
      {#if !compact}
        <p class="px-1.5 text-left text-[10px] text-zinc-400">
          {c?.card_type === "monster" ? `ATK ${c.attack ?? 0} / DEF ${c.defense ?? 0}` : tipoCurto(s.id)}
        </p>
      {/if}
      <div class="flex gap-0.5 px-1 pb-1 pt-0.5">
        <button class="px-1 py-px rounded text-[9px] bg-white/5 hover:bg-white/15 text-zinc-300 transition" title="Virar p/ baixo (verso)" onclick={() => alternarCima(z, i)}>▼ verso</button>
        <button class="px-1 py-px rounded text-[9px] bg-white/5 hover:bg-white/15 text-zinc-300 transition" title={s.atk ? "Está em Ataque — clique p/ Defesa" : "Está em Defesa — clique p/ Ataque"} onclick={() => alternarAtk(z, i)}>{s.atk ? "ATK" : "DEF"}</button>
      </div>
    </div>
  {/if}
{/snippet}

<div class="flex-1 min-h-0 flex flex-col overflow-hidden">
  {#if !cardsStore.cards.length && !cardsStore.loading}
    <div class="flex-1 min-h-0 overflow-y-auto flex flex-col items-center p-2">
      <div class="w-full max-w-3xl rounded-2xl border border-dashed border-zinc-700 bg-zinc-900/40 px-4 py-8 text-center">
        <p class="text-3xl">🎯</p>
        <p class="mt-2 text-sm font-bold text-zinc-200">Campo de Testes vazio — sem cartas no projeto</p>
        <p class="mt-1 text-xs text-zinc-400">Importe um pack para montar a mesa e abrir o duelo de verdade.</p>
        <button class="mt-3 px-4 py-2 rounded-full bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition" onclick={() => window.dispatchEvent(new CustomEvent("astralis:ir-importar"))}>📥 Importar pack…</button>
      </div>
    </div>
  {:else}
    <!-- Topo: quem duela (compacto, sempre visível) -->
    <div class="shrink-0 px-2 pt-2">
      <div class="w-full max-w-5xl mx-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 px-3 py-2.5">
        <div class="flex items-center gap-2 flex-wrap">
          <span class="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-600 via-indigo-600 to-violet-700 flex items-center justify-center text-sm shrink-0">🎯</span>
          <label class="flex items-center gap-1.5 min-w-0">
            <span class="text-[10px] tracking-widest text-emerald-400 font-bold">VOCÊ</span>
            <select class="max-w-[140px] px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" value={d1} onchange={(e) => trocarD1((e.target as HTMLSelectElement).value)}>
              {#if !duelistsStore.duelists.length}<option value="">— importe um pack —</option>{/if}
              {#each duelistsStore.duelists as d (d.id)}<option value={d.id}>{d.name}</option>{/each}
            </select>
          </label>
          <span class="text-zinc-600 font-black text-sm">×</span>
          <label class="flex items-center gap-1.5 min-w-0">
            <span class="text-[10px] tracking-widest text-rose-400 font-bold">RIVAL</span>
            <select class="max-w-[140px] px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={d2}>
              {#if !duelistsStore.duelists.length}<option value="">— importe um pack —</option>{/if}
              {#each duelistsStore.duelists as d (d.id)}<option value={d.id}>{d.name}</option>{/each}
            </select>
          </label>
          <label class="flex items-center gap-1.5">
            <span class="text-[10px] tracking-widest text-zinc-500 font-bold">VIDA</span>
            <input type="number" min="1" max="99999" step="500" class="w-20 px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={vida} />
          </label>
          <span class="hidden sm:inline text-[10px] text-emerald-300/80 bg-emerald-950/30 border border-emerald-900/40 rounded-full px-2 py-1">Você começa — sempre na sua fase da mão</span>
          <details class="ml-auto text-xs text-zinc-400">
            <summary class="cursor-pointer hover:text-zinc-200 transition text-[11px]">⚙ Ajustes (seed, arena)</summary>
            <div class="flex items-center gap-2 mt-1.5 flex-wrap">
              <label class="flex items-center gap-1.5">
                <span class="text-[10px] text-zinc-500">Seed</span>
                <input type="number" class="w-20 px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={seed} title="Mesmo número = mesmo embaralho" />
              </label>
              <label class="flex items-center gap-1.5">
                <span class="text-[10px] text-zinc-500">Arena</span>
                <select class="max-w-[160px] px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={arena}>
                  {#each arenas as a (a)}<option value={a}>{a}</option>{/each}
                </select>
              </label>
            </div>
          </details>
        </div>
        {#if !duelistsStore.duelists.length && !duelistsStore.loading}
          <div class="mt-2 rounded-xl border border-dashed border-zinc-700 bg-zinc-900/40 px-3 py-2 text-center">
            <p class="text-xs text-zinc-300">Sem duelistas — importe um pack para escolher quem duela.
              <button class="ml-1 px-2.5 py-1 rounded-full bg-sky-600 hover:bg-sky-500 text-white text-[11px] font-semibold transition" onclick={() => window.dispatchEvent(new CustomEvent("astralis:ir-importar"))}>📥 Importar pack…</button>
            </p>
          </div>
        {/if}
      </div>
    </div>

    <!-- A MESA (rolável): rival em cima, você embaixo, mão em faixa -->
    <div class="flex-1 min-h-0 overflow-y-auto px-2 py-2">
      <div class="w-full max-w-5xl mx-auto flex flex-col gap-2">
        <!-- RIVAL (topo, compacto, tom vermelho) -->
        <section class="rounded-2xl border border-rose-900/40 bg-gradient-to-b from-rose-950/30 to-zinc-950/60 p-2.5">
          <div class="flex items-center gap-2 px-1 pb-1.5">
            <span class="w-2 h-2 rounded-full bg-rose-500"></span>
            <h3 class="text-[11px] font-black tracking-widest text-rose-300">RIVAL</h3>
            <span class="text-[10px] text-zinc-500">clique num espaço para colocar • ✕ anula • ▼/▲ vira • ATK/DEF troca</span>
          </div>
          <p class="px-1 pb-1 text-[10px] tracking-widest text-rose-400/70 font-semibold">MAGIAS DO RIVAL</p>
          <div class="grid grid-cols-5 gap-1.5">
            {#each grades.p1s as _, i (i)}{@render espaco("p1s", i, true)}{/each}
          </div>
          <p class="px-1 pt-2 pb-1 text-[10px] tracking-widest text-rose-400/70 font-semibold">MONSTROS DO RIVAL</p>
          <div class="grid grid-cols-5 gap-1.5">
            {#each grades.p1m as _, i (i)}{@render espaco("p1m", i, true)}{/each}
          </div>
        </section>

        <!-- Divisor: placar da mesa -->
        <div class="flex items-center gap-2 px-1 text-[11px] text-zinc-500">
          <span class="flex-1 h-px bg-zinc-800"></span>
          <span>🂠 Mão {maoCount}/5 • Campo {campoCount}/20 {testeVazioLocal() ? "• mesa vazia = duelo normal" : ""}</span>
          <span class="flex-1 h-px bg-zinc-800"></span>
        </div>

        <!-- VOCÊ (embaixo, maior, tom verde) -->
        <section class="rounded-2xl border border-emerald-900/40 bg-gradient-to-b from-emerald-950/25 to-zinc-950/60 p-2.5">
          <div class="flex items-center gap-2 px-1 pb-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
            <h3 class="text-[11px] font-black tracking-widest text-emerald-300">VOCÊ</h3>
            <span class="text-[10px] text-zinc-500">botão direito também vira p/ cima/baixo</span>
            <button class="ml-auto text-[11px] text-zinc-500 hover:text-zinc-200 transition" title="Esvazia a mão e os 20 espaços" onclick={limparMesa}>🧹 Limpar mesa</button>
          </div>
          <p class="px-1 pb-1 text-[10px] tracking-widest text-emerald-400/70 font-semibold">SEUS MONSTROS</p>
          <div class="grid grid-cols-5 gap-1.5">
            {#each grades.p0m as _, i (i)}{@render espaco("p0m", i, false)}{/each}
          </div>
          <p class="px-1 pt-2 pb-1 text-[10px] tracking-widest text-emerald-400/70 font-semibold">SUAS MAGIAS</p>
          <div class="grid grid-cols-5 gap-1.5">
            {#each grades.p0s as _, i (i)}{@render espaco("p0s", i, false)}{/each}
          </div>
        </section>

        <!-- MÃO (faixa: clique numa carta REMOVE, clique no vazio ABRE o picker) -->
        <section class="rounded-2xl border border-sky-900/40 bg-sky-950/10 p-2.5">
          <div class="flex items-center gap-2 px-1 pb-1.5">
            <span class="text-sm">🂠</span>
            <h3 class="text-[11px] font-black tracking-widest text-sky-300">SUA MÃO (até 5)</h3>
            <span class="text-[10px] text-zinc-500">clique na carta para tirar • clique no vazio para colocar • o jogo completa até 5 na hora</span>
          </div>
          <div class="grid grid-cols-5 gap-1.5">
            {#each mao as idCarta, i (i)}
              {#if !idCarta.trim()}
                <button
                  class="rounded-xl border-2 border-dashed border-sky-900/50 bg-sky-950/10 hover:border-sky-500 hover:bg-sky-950/25 min-h-[64px] flex flex-col items-center justify-center gap-0.5 transition cursor-pointer group"
                  title="Mão {i + 1} vazia — clique para colocar uma carta"
                  onclick={() => abrirPicker("mao", i)}
                >
                  <span class="text-base text-zinc-600 group-hover:text-zinc-300 transition leading-none">＋</span>
                  <span class="text-[10px] text-zinc-600 group-hover:text-zinc-400 transition">{i + 1} • vazio</span>
                </button>
              {:else}
                {@const cc = cartaDe(idCarta)}
                <button
                  class="rounded-xl border-2 border-sky-800/60 bg-zinc-900 hover:border-sky-400 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-sky-950/40 min-h-[64px] px-1.5 py-1 flex flex-col items-start justify-center gap-px transition cursor-pointer text-left"
                  title="{linhaCarta(idCarta)} — clique para TIRAR da mão"
                  onclick={() => clicarMao(i)}
                >
                  <span class="w-full flex items-center gap-1">
                    <span class="text-[9px] text-zinc-500 font-bold">{i + 1}</span>
                    <span class="text-[9px] text-zinc-500 uppercase">{tipoCurto(idCarta)}</span>
                    <span class="ml-auto text-[10px] text-zinc-500">✕</span>
                  </span>
                  <span class="text-[11px] font-semibold text-zinc-100 leading-tight line-clamp-1">{cc?.name ?? idCarta}</span>
                  {#if cc?.card_type === "monster"}
                    <span class="text-[10px] text-zinc-400">ATK {cc.attack ?? 0} / DEF {cc.defense ?? 0}</span>
                  {/if}
                </button>
              {/if}
            {/each}
          </div>
        </section>

        <!-- Conferência detalhada (a validação viva, nunca em silêncio) -->
        <section class="rounded-2xl border border-zinc-800 bg-zinc-900/60 px-3 py-2">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">CONFERÊNCIA (validação do próprio jogo, ao montar)</p>
          {#if validando}
            <p class="mt-1 text-[11px] text-zinc-500">Validando…</p>
          {:else if validErro}
            <p class="mt-1 text-[11px] text-amber-300">Não consegui validar agora: {validErro} — o Iniciar teste valida de novo.</p>
          {:else if errosVivos.length}
            <ul class="mt-1 space-y-1">
              {#each errosVivos as e, i (i)}<li class="text-[11px] text-amber-300">• {e.mensagem}</li>{/each}
            </ul>
          {:else if avisosVivos.length}
            <ul class="mt-1 space-y-1">
              {#each avisosVivos as e, i (i)}<li class="text-[11px] text-zinc-400">• {e.mensagem}</li>{/each}
            </ul>
            <p class="mt-1 text-[11px] text-emerald-300">✓ Pronto para testar (só avisos).</p>
          {:else if testeVazioLocal()}
            <p class="mt-1 text-[11px] text-zinc-500">Mesa vazia — preencha a mão ou o campo, ou inicie assim mesmo (abre um duelo normal, sempre na sua fase da mão).</p>
          {:else}
            <p class="mt-1 text-[11px] text-emerald-300">✓ Tudo certo — pode clicar em Iniciar teste.</p>
          {/if}
          {#if msg}<p class="mt-1.5 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{msg}</p>{/if}
          <p class="mt-1.5 text-[11px] text-zinc-600">O Iniciar teste escreve o setup (com a mesa que você montou) num arquivo temporário e abre o Astralis com ele por cima do projeto (projects/default via --project). Quem joga é o Astralis — o editor só monta o dado.</p>
        </section>
      </div>
    </div>

    <!-- Barra fixa: resumo + Iniciar teste -->
    <div class="shrink-0 px-2 pb-2">
      <div class="w-full max-w-5xl mx-auto rounded-2xl border border-zinc-700 bg-zinc-950/90 backdrop-blur px-3 py-2.5 flex items-center gap-2.5 flex-wrap shadow-2xl shadow-black/50">
        {#if validando}
          <span class="flex items-center gap-1.5 text-[11px] text-zinc-400"><span class="w-2 h-2 rounded-full bg-zinc-500 animate-pulse"></span>Validando…</span>
        {:else if validErro}
          <span class="flex items-center gap-1.5 text-[11px] text-amber-300"><span class="w-2 h-2 rounded-full bg-amber-500"></span>Sem validar agora — o botão valida de novo</span>
        {:else if errosVivos.length}
          <span class="flex items-center gap-1.5 text-[11px] text-amber-300"><span class="w-2 h-2 rounded-full bg-amber-500"></span>{errosVivos.length} erro(s) — arrume acima</span>
        {:else if testeVazioLocal()}
          <span class="flex items-center gap-1.5 text-[11px] text-zinc-400"><span class="w-2 h-2 rounded-full bg-zinc-500"></span>Mesa vazia = duelo normal</span>
        {:else}
          <span class="flex items-center gap-1.5 text-[11px] text-emerald-300"><span class="w-2 h-2 rounded-full bg-emerald-500"></span>Mão {maoCount}/5 • Campo {campoCount}/20 • pronto</span>
        {/if}
        <span class="ml-auto flex gap-2">
          <button
            class="px-4 py-2.5 rounded-2xl bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-200 text-xs font-semibold transition disabled:opacity-50"
            disabled={jogando}
            title="Esvazia a mão e os 20 espaços"
            onclick={limparMesa}
          >Limpar</button>
          <button
            class="px-6 py-2.5 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-bold shadow-lg shadow-emerald-600/20 transition disabled:opacity-50"
            disabled={jogando}
            onclick={iniciarTeste}
          >{jogando ? "Abrindo o Astralis…" : "▶ Iniciar teste"}</button>
        </span>
      </div>
    </div>

    <!-- Picker modal: busca por nome/id, mostra ATK/DEF, anula com o botão -->
    {#if picker}
      <div
        class="fixed inset-0 z-50 flex items-center justify-center p-3 bg-black/70 backdrop-blur-sm"
        role="dialog"
        tabindex="-1"
        aria-modal="true"
        aria-label={alvoTitulo()}
        onclick={(e) => { if (e.target === e.currentTarget) fecharPicker(); }}
        onkeydown={(e) => { if (e.key === "Escape") fecharPicker(); }}
      >
        <div class="w-full max-w-lg rounded-2xl border border-zinc-700 bg-zinc-950 shadow-2xl overflow-hidden flex flex-col max-h-[85vh]">
          <div class="px-4 pt-3 pb-2 border-b border-zinc-800">
            <div class="flex items-center gap-2">
              <p class="text-sm font-bold">🂠 {alvoTitulo()}</p>
              <button class="ml-auto px-2 py-1 rounded-lg text-xs text-zinc-400 hover:text-white hover:bg-zinc-800 transition" title="Fechar (Esc)" onclick={fecharPicker}>✕</button>
            </div>
            <input
              class="mt-2 w-full px-3 py-2 rounded-xl bg-zinc-900 border border-zinc-700 text-sm placeholder:text-zinc-600 focus:outline-none focus:border-violet-500"
              placeholder="Busque por nome ou id… (ex.: dark, fm_0001, 2500)"
              bind:value={busca}
            />
            <p class="mt-1 text-[11px] text-zinc-500">
              {filtradas.length === cardsStore.cards.length ? `${cardsStore.cards.length} cartas — digite para filtrar` : `${filtradas.length} achada(s)`}{filtradas.length > 80 ? " (mostrando 80)" : ""}
            </p>
          </div>
          <div class="flex-1 min-h-0 overflow-y-auto p-2 space-y-1">
            {#if !resultados.length}
              <p class="px-3 py-6 text-center text-xs text-zinc-500">Nenhuma carta com “{busca.trim()}”. Tente outro nome ou id.</p>
            {:else}
              {#each resultados as c (c.id)}
                <button
                  class="w-full text-left px-3 py-2 rounded-xl border border-transparent hover:border-violet-600/50 hover:bg-violet-950/20 transition flex items-center gap-2"
                  title={c.id}
                  onclick={() => escolherCarta(c.id)}
                >
                  <span class="min-w-0 flex-1">
                    <span class="block text-xs font-semibold text-zinc-100 truncate">{c.name}</span>
                    <span class="block text-[10px] text-zinc-500 truncate">{c.id}{c.card_type === "monster" ? ` • ATK ${c.attack ?? 0} / DEF ${c.defense ?? 0}` : ` • ${c.card_type}`}</span>
                  </span>
                  <span class="shrink-0 text-[10px] px-1.5 py-0.5 rounded-full {c.card_type === 'monster' ? 'bg-amber-950/50 text-amber-300 border border-amber-900/50' : 'bg-sky-950/50 text-sky-300 border border-sky-900/50'}">
                    {c.card_type === "monster" ? "Monstro" : c.card_type === "spell" ? "Magia" : c.card_type}
                  </span>
                </button>
              {/each}
            {/if}
          </div>
          <div class="px-3 py-2.5 border-t border-zinc-800 flex gap-2">
            {#if alvoTemCarta()}
              <button class="flex-1 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-200 text-xs font-semibold transition" title="Deixa este espaço vazio" onclick={esvaziarAlvo}>✕ Deixar vazio</button>
            {/if}
            <button class="flex-1 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-200 text-xs font-semibold transition" onclick={fecharPicker}>Fechar</button>
          </div>
        </div>
      </div>
    {/if}
  {/if}
</div>
