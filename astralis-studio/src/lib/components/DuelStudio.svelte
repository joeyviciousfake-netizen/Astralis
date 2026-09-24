<script lang="ts">
  // DuelStudio — duelo rápido (doc 14 §14.2).
  // SIMPLES: escolher os 2 duelistas + vida + Play (escreve o setup rápido
  // num temporário e lança o Godot com --setup <temp> — comando jogar_duelo). AVANÇADO:
  // seed, arena, ordem de turno. O editor nunca simula duelo (R1): só monta
  // o dado e abre o Astralis de verdade (preview unificado, doc 10).
  import { useDuelists } from "$lib/stores/duelists.svelte";
  import { useDecks } from "$lib/stores/decks.svelte";
  import { useQuickDuel } from "$lib/stores/duelQuick.svelte";
  import { useSectionShell } from "$lib/section";
  import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";

  const duelistsStore = useDuelists();
  const decksStore = useDecks();
  const quick = useQuickDuel();

  useSectionShell({
    mount: () => {
      void duelistsStore.ensureNamesLoaded();
      void decksStore.ensureLoaded();
      void carregarArenas();
    },
  });

  let d1 = $state("duelist_hero");
  let d2 = $state("duelist_rival");
  let vida = $state(4000);
  let vidaSugerida = $state(false);
  let avancado = $state(false);
  let seed = $state(42);
  let arena = $state("arena_starter");
  let ordem = $state("first_p1");
  let arenas = $state<string[]>(["arena_starter"]);

  let msg = $state("");
  let ok = $state(false);
  let jogando = $state(false);

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

  // Vida padrão = a do duelista 1 (dado dele, doc 05 §5.3).
  // Atalho "▶ Jogar" da aba Duelistas cai aqui (quickDuel).
  let ultimoQuick = $state(0);
  $effect(() => {
    if (quick.nonce !== ultimoQuick && quick.d1) {
      ultimoQuick = quick.nonce;
      trocarD1(quick.d1);
      if (quick.d2) d2 = quick.d2;
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

  async function jogar() {
    msg = "";
    if (!d1 || !d2) {
      ok = false;
      msg = "Escolha os dois duelistas antes de jogar.";
      return;
    }
    jogando = true;
    try {
      const res: { mensagem?: unknown } = await invokeSave(
        "jogar_duelo",
        { pedido: { duelista1: d1, duelista2: d2, vida: Math.floor(Number(vida) || 0), seed: Math.floor(Number(seed) || 0), arena, ordem } },
        120000
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

  function ordemNome(v: string): string {
    return v === "first_p1" ? "Jogador 1 começa" : v === "first_p2" ? "Jogador 2 começa" : "Sorteio";
  }
</script>

<div class="flex-1 min-h-0 overflow-y-auto flex flex-col items-center gap-4 p-2">
  <div class="w-full max-w-2xl rounded-2xl border border-zinc-800 bg-zinc-950/60 p-5">
    <div class="flex items-center gap-3">
      <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-emerald-600 via-teal-600 to-emerald-700 flex items-center justify-center text-xl shrink-0">⚔️</span>
      <div>
        <h2 class="text-base font-black tracking-tight">DUELO RÁPIDO</h2>
        <p class="text-[11px] text-zinc-500">Escolha os 2 duelistas + vida e aperte Play — abre o Astralis de verdade</p>
      </div>
      <div class="ml-auto flex p-0.5 rounded-full bg-zinc-900 border border-zinc-800 text-[11px]">
        <button class="px-2.5 py-1 rounded-full {!avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = false}>Simples</button>
        <button class="px-2.5 py-1 rounded-full {avancado ? 'bg-white text-zinc-900 font-semibold' : 'text-zinc-400'}" onclick={() => avancado = true}>Avançado</button>
      </div>
    </div>

    <div class="mt-4 grid sm:grid-cols-[1fr_auto_1fr] gap-2 items-center">
      <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">JOGADOR 1</span>
        <select class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" value={d1} onchange={(e) => trocarD1((e.target as HTMLSelectElement).value)}>
          {#each duelistsStore.duelists as d (d.id)}<option value={d.id}>{d.name}</option>{/each}
        </select>
        <span class="block mt-1 text-[11px] text-zinc-500">🂠 {deckNome(d1)}</span>
      </label>
      <span class="text-center text-zinc-600 font-black text-lg">×</span>
      <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">JOGADOR 2</span>
        <select class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={d2}>
          {#each duelistsStore.duelists as d (d.id)}<option value={d.id}>{d.name}</option>{/each}
        </select>
        <span class="block mt-1 text-[11px] text-zinc-500">🂠 {deckNome(d2)}</span>
      </label>
    </div>

    <div class="mt-2 grid sm:grid-cols-2 gap-2">
      <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">VIDA (LP inicial dos dois)</span>
        <input type="number" min="1" max="99999" step="500" class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={vida} />
      </label>
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
        <label class="block rounded-xl border border-violet-600/30 bg-violet-950/10 p-3">
          <span class="text-[10px] tracking-widest text-violet-300 font-semibold">QUEM COMEÇA</span>
          <select class="mt-1 w-full px-2.5 py-2 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={ordem}>
            <option value="first_p1">Jogador 1 começa</option>
            <option value="first_p2">Jogador 2 começa</option>
            <option value="random">Sorteio</option>
          </select>
        </label>
      {/if}
    </div>

    <button
      class="mt-4 w-full py-3 rounded-2xl bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-bold shadow-lg shadow-emerald-600/20 transition disabled:opacity-50"
      disabled={jogando}
      onclick={jogar}
    >{jogando ? "Abrindo o Astralis…" : "▶ Jogar agora"}</button>
    {#if msg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{msg}</p>{/if}
    <p class="mt-2 text-[11px] text-zinc-600">O Play escreve o setup rápido num arquivo temporário e abre o Astralis com ele (o starter do projeto continua intacto). {avancado ? `Seed ${seed} • ${arena} • ${ordemNome(ordem)}.` : ""}</p>
  </div>
</div>
