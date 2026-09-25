<script lang="ts">
  // TestStudio — Campo de Testes (docs 04 §4.6 + 10 §10.2/10.3, contrato test_state V1).
  // O usuário monta a MÃO dele + o CAMPO dos dois lados e clica Iniciar teste:
  // o Studio monta o duel_setup com test_state + first_p1 e lança o Astralis
  // de verdade via jogar_duelo (--project + --setup temporário, o MESMO caminho
  // do botão Jogar). R1/R2: nunca calcula jogo — só monta DADO e valida.
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
  let avancado = $state(false);
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

  function nomeCarta(id: string): string {
    const t = id.trim();
    if (!t) return "vazio";
    const c = mapa.get(t);
    if (!c) return "não existe no projeto — escolha uma carta da lista";
    const ad = c.card_type === "monster" ? ` • ATK ${c.attack ?? 0} / DEF ${c.defense ?? 0}` : ` • ${c.card_type}`;
    return `${c.name}${ad}`;
  }

  const ZONAS: Array<{ chave: ZonaKey; contrato: string; titulo: string; dica: string }> = [
    { chave: "p0m", contrato: "p0_monster", titulo: "Seus monstros", dica: "Seus 5 espaços de monstro (lado de cá)" },
    { chave: "p0s", contrato: "p0_spell", titulo: "Suas magias", dica: "Seus 5 espaços de magia (lado de cá)" },
    { chave: "p1m", contrato: "p1_monster", titulo: "Monstros do rival", dica: "Os 5 espaços de monstro do rival" },
    { chave: "p1s", contrato: "p1_spell", titulo: "Magias do rival", dica: "Os 5 espaços de magia do rival" },
  ];

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

<div class="flex-1 min-h-0 overflow-y-auto flex flex-col items-center gap-4 p-2">
  <!-- Uma lista só p/ os 722 nomes (datalist): os 25 campos digitam e filtram
    sem montar 25 selects de 722 opções (era isso que travava a aba Fusões). -->
  <datalist id="teste-cartas-lista">
    {#each cardsStore.cards as c (c.id)}<option value={c.id}>{c.name}</option>{/each}
  </datalist>

  <div class="w-full max-w-3xl rounded-2xl border border-zinc-800 bg-zinc-950/60 p-5">
    <div class="flex items-center gap-3">
      <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-violet-600 via-indigo-600 to-violet-700 flex items-center justify-center text-xl shrink-0">🎯</span>
      <div>
        <h2 class="text-base font-black tracking-tight">CAMPO DE TESTES</h2>
        <p class="text-[11px] text-zinc-500">Monte sua mão + o campo dos dois lados e abra o Astralis de verdade — sempre na sua fase da mão</p>
      </div>
      <div class="ml-auto flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
        <button class="px-2.5 py-1 rounded-full {!avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = false}>Simples</button>
        <button class="px-2.5 py-1 rounded-full {avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = true}>Avançado</button>
      </div>
    </div>

    {#if !cardsStore.cards.length && !cardsStore.loading}
      <div class="mt-4 rounded-xl border border-dashed border-zinc-700 bg-zinc-900/40 px-4 py-5 text-center">
        <p class="text-xs text-zinc-300">Sem cartas — importe um pack para montar o teste.</p>
        <button class="mt-2 px-3 py-1.5 rounded-full bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition" onclick={() => window.dispatchEvent(new CustomEvent("astralis:ir-importar"))}>📥 Importar pack…</button>
      </div>
    {:else}
      <!-- Quem duela (mesmo dado do Duelo rápido; ordem fixa: você primeiro) -->
      <div class="mt-4 grid sm:grid-cols-[1fr_auto_1fr] gap-2 items-center">
        <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">VOCÊ (JOGADOR 1)</span>
          <select class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" value={d1} onchange={(e) => trocarD1((e.target as HTMLSelectElement).value)}>
            {#if !duelistsStore.duelists.length}<option value="">— importe um pack —</option>{/if}
            {#each duelistsStore.duelists as d (d.id)}<option value={d.id}>{d.name}</option>{/each}
          </select>
          <span class="block mt-1 text-[11px] text-zinc-500">🂠 {deckNome(d1)}</span>
        </label>
        <span class="text-center text-zinc-600 font-black text-lg">×</span>
        <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">RIVAL (JOGADOR 2)</span>
          <select class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={d2}>
            {#if !duelistsStore.duelists.length}<option value="">— importe um pack —</option>{/if}
            {#each duelistsStore.duelists as d (d.id)}<option value={d.id}>{d.name}</option>{/each}
          </select>
          <span class="block mt-1 text-[11px] text-zinc-500">🂠 {deckNome(d2)}</span>
        </label>
      </div>

      {#if !duelistsStore.duelists.length && !duelistsStore.loading}
        <div class="mt-2 rounded-xl border border-dashed border-zinc-700 bg-zinc-900/40 px-4 py-3 text-center">
          <p class="text-xs text-zinc-300">Sem duelistas — importe um pack para escolher quem duela.</p>
          <button class="mt-2 px-3 py-1.5 rounded-full bg-sky-600 hover:bg-sky-500 text-white text-xs font-semibold transition" onclick={() => window.dispatchEvent(new CustomEvent("astralis:ir-importar"))}>📥 Importar pack…</button>
        </div>
      {/if}

      <div class="mt-2 grid sm:grid-cols-2 gap-2">
        <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">VIDA (LP inicial dos dois)</span>
          <input type="number" min="1" max="99999" step="500" class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={vida} />
        </label>
        <div class="rounded-xl border border-emerald-900/50 bg-emerald-950/20 p-3">
          <span class="text-[10px] tracking-widest text-emerald-300 font-semibold">QUEM COMEÇA (FIXO NO TESTE)</span>
          <p class="mt-1 text-sm text-emerald-200">Você primeiro — o teste sempre abre na sua fase da mão.</p>
        </div>
        {#if avancado}
          <label class="block rounded-xl border border-violet-600/30 bg-violet-950/10 p-3">
            <span class="text-[10px] tracking-widest text-violet-300 font-semibold">SEED (mesmo número = mesmo embaralho)</span>
            <input type="number" class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={seed} />
          </label>
          <label class="block rounded-xl border border-violet-600/30 bg-violet-950/10 p-3">
            <span class="text-[10px] tracking-widest text-violet-300 font-semibold">ARENA</span>
            <select class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={arena}>
              {#each arenas as a (a)}<option value={a}>{a}</option>{/each}
            </select>
          </label>
        {/if}
      </div>

      <!-- Minha mão (até 5; o resto o jogo completa até 5 na hora) -->
      <div class="mt-4 rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">MINHA MÃO (até 5 — digite e escolha da lista)</p>
        <div class="mt-2 grid sm:grid-cols-2 gap-1.5">
          {#each mao as carta, i (i)}
            <div class="rounded-lg border border-zinc-800 bg-zinc-950 p-2">
              <div class="flex items-center gap-1.5">
                <span class="text-[11px] text-zinc-500 font-bold w-4 text-center">{i + 1}</span>
                <input
                  list="teste-cartas-lista"
                  class="flex-1 min-w-0 px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs"
                  placeholder="vazio"
                  bind:value={mao[i]}
                />
                <button class="shrink-0 px-2 py-1 rounded-lg text-[11px] text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800 transition" title="Esvaziar este espaço" onclick={() => mao[i] = ""}>✕</button>
              </div>
              <p class="mt-1 text-[11px] {mapa.has(mao[i].trim()) || !mao[i].trim() ? 'text-zinc-600' : 'text-amber-300'}">{nomeCarta(mao[i])}</p>
            </div>
          {/each}
        </div>
      </div>

      <!-- Campo dos dois lados: 4 grades de 5 -->
      {#each ZONAS as z (z.chave)}
        <div class="mt-2 rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">{z.titulo.toUpperCase()}</p>
          <p class="text-[11px] text-zinc-600">{z.dica} — cada espaço: carta ou vazio + virada e posição</p>
          <div class="mt-2 grid gap-1.5">
            {#each grades[z.chave] as slot, i (i)}
              <div class="rounded-lg border border-zinc-800 bg-zinc-950 p-2">
                <div class="flex items-center gap-1.5 flex-wrap">
                  <span class="text-[11px] text-zinc-500 font-bold w-4 text-center">{i + 1}</span>
                  <input
                    list="teste-cartas-lista"
                    class="flex-1 min-w-[140px] px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs"
                    placeholder="vazio"
                    bind:value={grades[z.chave][i].id}
                  />
                  <label class="inline-flex items-center gap-1 text-[11px] text-zinc-400 {slot.id.trim() ? '' : 'opacity-40'}">
                    <input type="checkbox" bind:checked={grades[z.chave][i].cima} disabled={!slot.id.trim()} /> P/ cima
                  </label>
                  <label class="inline-flex items-center gap-1 text-[11px] text-zinc-400 {slot.id.trim() ? '' : 'opacity-40'}">
                    <input type="checkbox" bind:checked={grades[z.chave][i].atk} disabled={!slot.id.trim()} /> ATK
                  </label>
                  <button class="shrink-0 px-2 py-1 rounded-lg text-[11px] text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800 transition" title="Esvaziar este espaço" onclick={() => grades[z.chave][i] = slotVazio()}>✕</button>
                </div>
                <p class="mt-1 text-[11px] {mapa.has(slot.id.trim()) || !slot.id.trim() ? 'text-zinc-600' : 'text-amber-300'}">
                  {nomeCarta(slot.id)}{slot.id.trim() ? (slot.cima ? " • virada p/ cima" : " • virada p/ baixo") + (slot.atk ? " • em Ataque" : " • em Defesa") : ""}
                </p>
              </div>
            {/each}
          </div>
        </div>
      {/each}

      <!-- Validação viva (backend): nunca em silêncio -->
      <div class="mt-2 rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">CONFERÊNCIA (validação do próprio jogo, ao digitar)</p>
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
      </div>

      <div class="mt-4 flex gap-2">
        <button
          class="flex-1 py-3 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-bold shadow-lg shadow-emerald-600/20 transition disabled:opacity-50"
          disabled={jogando}
          onclick={iniciarTeste}
        >{jogando ? "Abrindo o Astralis…" : "▶ Iniciar teste"}</button>
        <button
          class="px-4 py-3 rounded-2xl bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-200 text-sm font-semibold transition disabled:opacity-50"
          disabled={jogando}
          title="Esvazia a mão e os 20 espaços"
          onclick={limparMesa}
        >Limpar mesa</button>
      </div>
      {#if msg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{msg}</p>{/if}
      <p class="mt-2 text-[11px] text-zinc-600">O Iniciar teste escreve o setup (com a mesa que você montou) num arquivo temporário e abre o Astralis com ele por cima do projeto (projects/default via --project). Quem joga é o Astralis — o editor só monta o dado.</p>
    {/if}
  </div>
</div>
