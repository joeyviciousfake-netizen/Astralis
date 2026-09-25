<script lang="ts">
  // EffectsStudio — galeria + builder visual de efeitos (docs 07/14).
  // SIMPLES: galeria dos modelos de effects.json (clicar preenche o builder;
  // 4 atalhos prontos). AVANÇADO: blocos trigger→condições→alvo→ações.
  // SEM botão Testar/Play: o motor não existe no runtime (R4) — aviso fixo
  // "execução vem depois". Só Validar (dado) + Salvar (effects.json).
  import { useEffects, TEMPLATES, TRIGGER_OPS, TARGET_OPS, ACTION_OPS, COND_FIELDS, DURATIONS, textoDerivado } from "$lib/stores/effects.svelte";
  import type { Effect } from "$lib/stores/effects.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";

  const store = useEffects();

  useSectionShell({
    mount: () => { void store.ensureLoaded(); },
    onSave: () => { if (sel || isNew) save().catch(() => {}); },
  });

  let selId = $state<string | null>(null);
  let isNew = $state(false);
  let avancado = $state(false);

  let idEdit = $state("");
  let nomeEdit = $state("");
  let trigEdit = $state("card_summoned");
  let condsEdit = $state<Array<{ field: string; operator: string; value: string }>>([]);
  let alvoEdit = $state("opponent");
  let acoesEdit = $state<Array<{ action: string; amount: string; duration: string }>>([]);
  let fieldErrors = $state<Array<{ campo: string; mensagem: string }>>([]);
  const flash = $state({ msg: "", ok: false });

  let lista = $derived(store.dado.effects);
  let sel = $derived(lista.find((e) => e.id === selId) ?? null);

  function setFlash(msg: string, ok: boolean) {
    flash.msg = msg;
    flash.ok = ok;
  }

  let lastSync: string | null = null;
  $effect(() => {
    const s = sel;
    if (s && s.id !== lastSync) {
      lastSync = s.id;
      isNew = false;
      carregar(s);
    }
  });

  function carregar(s: Effect) {
    idEdit = s.id;
    nomeEdit = s.name ?? "";
    trigEdit = s.trigger;
    condsEdit = (s.conditions ?? []).map((c) => ({ field: c.field, operator: c.operator, value: String(c.value) }));
    alvoEdit = s.target;
    acoesEdit = (s.actions ?? []).map((a) => ({ action: a.action, amount: a.amount !== undefined ? String(a.amount) : "", duration: a.duration ?? "until_end_of_turn" }));
    fieldErrors = [];
    flash.msg = "";
  }

  function doModelo(tpl: (typeof TEMPLATES)[number]) {
    lastSync = null;
    isNew = true;
    const base = tpl.efeito.id || "effect_novo";
    carregar({ ...tpl.efeito, id: sugestaoId(base) });
    setFlash(`Modelo "${tpl.nome}" carregado — ajuste e clique em Salvar`, true);
  }

  function sugestaoId(base: string): string {
    let raiz = base.replace(/[^a-z0-9_]/g, "") || "effect_novo";
    if (!/^[a-z]/.test(raiz)) raiz = "effect_" + raiz;
    let n = 1;
    const tem = (id: string) => lista.some((e) => e.id === id);
    while (tem(`${raiz}${n > 1 ? n : ""}`)) n++;
    return `${raiz}${n > 1 ? n : ""}`;
  }

  function build(): Effect {
    const numOuTxt = (v: string): number | string => {
      const t = v.trim();
      if (t === "") return "";
      const n = Number(t);
      return Number.isFinite(n) ? Math.floor(n) : t;
    };
    return {
      id: (isNew ? idEdit.trim() : (sel?.id ?? idEdit.trim())) || "effect_novo",
      name: nomeEdit.trim() || "Sem nome",
      description: textoDerivado({
        id: "", name: "", trigger: trigEdit,
        conditions: condsEdit.map((c) => ({ field: c.field, operator: c.operator, value: numOuTxt(c.value) })),
        target: alvoEdit, actions: acoesEdit.map((a) => ({ action: a.action, amount: a.amount.trim() === "" ? undefined : Math.floor(Number(a.amount) || 0), duration: a.duration })),
        flow: { mode: "sequence" },
      }),
      trigger: trigEdit,
      conditions: condsEdit.map((c) => ({ field: c.field, operator: c.operator, value: numOuTxt(c.value) })),
      target: alvoEdit,
      actions: acoesEdit.map((a) => {
        const out: { action: string; amount?: number; duration?: string } = { action: a.action };
        if (a.amount.trim() !== "") out.amount = Math.floor(Number(a.amount) || 0);
        if (a.action === "modify_attack" || a.action === "modify_defense") out.duration = a.duration;
        return out;
      }),
      flow: { mode: "sequence" },
    };
  }

  async function save() {
    fieldErrors = [];
    try {
      const atual = build();
      const next = isNew ? [...lista, atual] : lista.map((e) => (e.id === atual.id ? atual : e));
      const msg = await store.save({ schema_version: 1, effects: next });
      if (isNew) {
        isNew = false;
        lastSync = atual.id;
        selId = atual.id;
      }
      setFlash(msg, true);
    } catch (e) {
      setFlash(`Falha ao salvar: ${errMsg(e)}`, false);
    }
  }

  async function validateNow() {
    fieldErrors = [];
    try {
      const erros = await store.validateOne(build());
      fieldErrors = erros;
      setFlash(erros.length ? `${erros.length} erro(s) — veja a lista` : "Efeito válido (dado ok — execução vem depois)", !erros.length);
    } catch (e) {
      setFlash(`Falha ao validar: ${errMsg(e)}`, false);
    }
  }

  function duplicate() {
    const s = sel;
    if (!s) return;
    lastSync = null;
    isNew = true;
    carregar({ ...s, id: sugestaoId(s.id.replace(/_copia\d*$/, "") + "_copia"), name: `${s.name} (cópia)` });
    setFlash("Cópia pronta — ajuste e clique em Salvar", true);
  }

  function createNew() {
    lastSync = null;
    isNew = true;
    idEdit = sugestaoId("effect_novo");
    nomeEdit = "";
    trigEdit = "card_summoned";
    condsEdit = [];
    alvoEdit = "opponent";
    acoesEdit = [{ action: "damage", amount: "500", duration: "until_end_of_turn" }];
    fieldErrors = [];
    setFlash("", true);
    selId = null;
  }

  function precisaValor(acao: string): boolean {
    return ["damage", "heal", "modify_attack", "modify_defense", "draw", "discard"].includes(acao);
  }
  function precisaDuracao(acao: string): boolean {
    return acao === "modify_attack" || acao === "modify_defense";
  }
  function rotuloValor(acao: string): string {
    if (acao === "draw" || acao === "discard") return "Quantas cartas";
    if (acao === "damage" || acao === "heal") return "Quanto de LP";
    return "Valor (negativo baixa)";
  }
</script>

<div class="flex-1 min-h-0 flex flex-col gap-2 overflow-hidden">
  <div class="shrink-0 rounded-xl border border-amber-500/30 bg-amber-500/10 px-3 py-2">
    <p class="text-[11px] text-amber-200">⚠ <span class="font-bold">Execução vem depois.</span> Aqui você monta o dado do efeito; o jogo ainda não executa efeitos (sem botão Testar/Play de propósito).</p>
  </div>

  <div class="flex-1 min-h-0 flex gap-3 overflow-hidden">
    <!-- Galeria -->
    <section class="w-[260px] lg:w-[300px] shrink-0 flex flex-col min-h-0 rounded-2xl border border-zinc-800 bg-zinc-950/60 overflow-hidden">
      <div class="p-3 pb-2 flex items-center gap-2">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">GALERIA ({lista.length})</p>
        <button class="ml-auto px-2.5 py-1 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" onclick={createNew}>＋ Novo</button>
      </div>
      <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-1">
        {#if store.loading}
          <p class="p-4 text-xs text-zinc-500 text-center">Carregando…</p>
        {:else if store.error}
          <p class="p-4 text-xs text-red-400 text-center">{store.error}</p>
        {:else}
          {#each lista as e (e.id)}
            {@const ativo = !isNew && selId === e.id}
            <button
              onclick={() => { selId = ativo ? null : e.id; isNew = false; }}
              class="w-full text-left rounded-xl border px-2 py-2 transition {ativo ? 'bg-white text-zinc-900 border-white shadow' : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-600 text-zinc-100'}"
            >
              <span class="block text-xs font-bold truncate">✨ {e.name}</span>
              <span class="block text-[10px] font-mono truncate {ativo ? 'text-zinc-600' : 'text-zinc-500'}">{e.id}</span>
            </button>
          {/each}
          <p class="pt-1 text-[10px] tracking-widest text-zinc-600 font-semibold px-1">ATALHOS (preenchem o builder)</p>
          {#each TEMPLATES as t (t.id)}
            <button
              onclick={() => doModelo(t)}
              class="w-full text-left rounded-xl border border-dashed border-zinc-700 px-2 py-1.5 hover:border-violet-500 transition"
            >
              <span class="block text-[11px] font-bold text-violet-300">＋ {t.nome}</span>
              <span class="block text-[10px] text-zinc-500">{t.desc}</span>
            </button>
          {/each}
        {/if}
      </div>
    </section>

    <!-- Builder -->
    <section class="flex-1 min-w-0 min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4">
      {#if sel || isNew}
        <div class="flex items-center gap-3 flex-wrap">
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

        <div class="mt-3 space-y-2.5">
          <div class="grid md:grid-cols-2 gap-2.5">
            <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">NOME</p>
              <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={nomeEdit} placeholder="Ex.: Dano ao invocar" />
            </div>
            <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">ID {isNew ? "(editável)" : "(fixo)"}</p>
              <input class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600 disabled:opacity-60" bind:value={idEdit} disabled={!isNew} placeholder="effect_meu_efeito" />
            </div>
          </div>

          <div class="rounded-xl border border-violet-600/30 bg-violet-950/10 p-3" id="field-trigger">
            <p class="text-[10px] tracking-widest text-violet-300 font-semibold mb-1.5">1 • QUANDO (gatilho — só o que o jogo sabe executar)</p>
            <select class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={trigEdit}>
              {#each TRIGGER_OPS as t (t.id)}<option value={t.id}>{t.nome}</option>{/each}
            </select>
          </div>

          {#if avancado || condsEdit.length}
            <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3" id="field-conditions">
              <div class="flex items-center gap-2 mb-1.5">
                <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">2 • SOMENTE SE (condições — vazio = sempre vale)</p>
                <button class="ml-auto px-2 py-0.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" onclick={() => condsEdit = [...condsEdit, { field: "opponent_monster_attack", operator: ">=", value: "1000" }]}>＋ condição</button>
              </div>
              {#if !condsEdit.length}
                <p class="text-xs text-zinc-500">Sem condições — vale sempre.</p>
              {/if}
              {#each condsEdit as c, i (i)}
                <div class="grid grid-cols-[1fr_auto_1fr_auto] gap-1.5 items-center mb-1.5">
                  <select class="px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" bind:value={c.field}>
                    {#each COND_FIELDS as f (f.id)}<option value={f.id}>{f.nome}</option>{/each}
                  </select>
                  <select class="px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" bind:value={c.operator}>
                    {#each [">", "<", ">=", "<=", "==", "!="] as op (op)}<option value={op}>{op}</option>{/each}
                  </select>
                  <input class="px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs" bind:value={c.value} placeholder="1000 ou texto" />
                  <button class="text-zinc-500 hover:text-rose-300 px-1" title="Remover condição" onclick={() => condsEdit = condsEdit.filter((_, x) => x !== i)}>✕</button>
                </div>
              {/each}
            </div>
          {/if}

          <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3" id="field-target">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">{avancado ? "3" : "2"} • EM QUEM (alvo)</p>
            <select class="w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm" bind:value={alvoEdit}>
              {#each TARGET_OPS as t (t.id)}<option value={t.id}>{t.nome}</option>{/each}
            </select>
          </div>

          <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3" id="field-actions">
            <div class="flex items-center gap-2 mb-1.5">
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">{avancado ? "4" : "3"} • O QUE ACONTECE (ações em sequência)</p>
              <button class="ml-auto px-2 py-0.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" onclick={() => acoesEdit = [...acoesEdit, { action: "damage", amount: "500", duration: "until_end_of_turn" }]}>＋ ação</button>
            </div>
            {#if !acoesEdit.length}
              <p class="text-xs text-rose-300">Sem ação — todo efeito precisa de pelo menos 1 (clique em ＋ ação).</p>
            {/if}
            {#each acoesEdit as a, i (i)}
              <div class="rounded-lg border border-zinc-800 bg-zinc-950 p-2 mb-1.5">
                <div class="grid sm:grid-cols-[1fr_auto] gap-1.5 items-center">
                  <select class="px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={a.action}>
                    {#each ACTION_OPS as o (o.id)}<option value={o.id}>{o.nome}</option>{/each}
                  </select>
                  <button class="text-zinc-500 hover:text-rose-300 px-1 text-sm" title="Remover ação" onclick={() => acoesEdit = acoesEdit.filter((_, x) => x !== i)}>✕</button>
                </div>
                {#if precisaValor(a.action) || precisaDuracao(a.action)}
                  <div class="grid sm:grid-cols-2 gap-1.5 mt-1.5">
                    {#if precisaValor(a.action)}
                      <label class="block"><span class="text-[10px] text-zinc-500">{rotuloValor(a.action)}</span>
                        <input type="number" class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={a.amount} placeholder="500" />
                      </label>
                    {/if}
                    {#if precisaDuracao(a.action)}
                      <label class="block"><span class="text-[10px] text-zinc-500">Por quanto tempo</span>
                        <select class="mt-0.5 w-full px-2 py-1.5 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={a.duration}>
                          {#each DURATIONS as d (d.id)}<option value={d.id}>{d.nome}</option>{/each}
                        </select>
                      </label>
                    {/if}
                  </div>
                {/if}
              </div>
            {/each}
            <p class="text-[10px] text-zinc-600">Fluxo: sequência (uma ação depois da outra). Condições avançadas (se/senão/repetir) vêm depois.</p>
          </div>

          <div class="rounded-xl border border-emerald-900/50 bg-emerald-950/20 p-3">
            <p class="text-[10px] tracking-widest text-emerald-300 font-semibold mb-1">COMO FICA O TEXTO DA CARTA (gerado sozinho)</p>
            <p class="text-xs text-zinc-200 italic">"{textoDerivado(build())}"</p>
          </div>
        </div>
      {:else}
        <div class="h-full min-h-[280px] flex flex-col items-center justify-center gap-3 text-center">
          <div class="w-16 h-16 rounded-3xl bg-gradient-to-br from-violet-600/20 to-indigo-600/20 border border-violet-500/20 flex items-center justify-center text-3xl">✨</div>
          <p class="text-sm font-bold text-zinc-200">Escolha um modelo na galeria</p>
          <p class="text-xs text-zinc-500 max-w-sm">Ou use um <span class="text-zinc-300 font-semibold">atalho</span> — ele preenche o builder e você ajusta 2–3 campos.</p>
        </div>
      {/if}
    </section>
  </div>
</div>
