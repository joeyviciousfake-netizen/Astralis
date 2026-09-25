<script lang="ts">
  // LayoutStudio — editor visual do MOLDE da carta (aba Molde).
  // Só DADO (R1/R3/R4): move/redimensiona/reestiliza as 9 peças do molde V1
  // (schemas/card_layout.schema.json) e salva em
  // projects/default/layouts/ via ler_card_layout/salvar_card_layout.
  // Quem DESENHA de verdade é o Astralis (card_layout.gd + card_view.gd, via
  // --project) e o CardPreview aqui (lendo o mesmo molde — a carta atualiza
  // na hora). Sem peça nova (kinds fechados), sem campo novo na carta (V2).
  import { useLayout, moldePadrao, pecaOficial, kindDoErro, PECAS_ORDEM, KINDS_TEXTO, type Molde, type PecaRect, type ErroMolde } from "$lib/stores/layout.svelte";
  import { useCards } from "$lib/stores/cards.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";
  import CardPreview from "$lib/components/CardPreview.svelte";

  const layout = useLayout();
  const cardsStore = useCards();

  const flash = useSectionShell({
    mount: () => { void layout.ensureLoaded().then(initRascunho); },
    onSave: () => { if (rascunho && sujo) void salvar(); },
    extra: [["keydown", aoTeclado]],
  });
  const msg = $derived(flash.saveMsg);
  const msgOk = $derived(flash.saveOk);

  // Rascunho editável: SEMPRE com as 9 peças explícitas (o arquivo pode vir
  // parcial — peça ausente = default do scan, igual ao jogo; aqui vira
  // explícita para poder clicar e arrastar). Salvar grava as 9 (válido V1).
  let rascunho = $state<Molde | null>(null);
  let salvoJson = $state("");
  let hist = $state<string[]>([]);
  let sel = $state<string>("name");
  let erros = $state<ErroMolde[]>([]);
  let validando = $state(false);
  let salvando = $state(false);
  let arrastando = $state(false);
  let caixa: HTMLDivElement | null = $state(null);

  function initRascunho() {
    if (rascunho || !layout.molde) return;
    rascunho = normalizar(layout.molde);
    salvoJson = JSON.stringify(rascunho.pieces);
  }
  // Se o molde terminar de carregar depois (primeira visita), inicializa.
  $effect(() => { if (layout.molde) initRascunho(); });

  function normalizar(m: Molde): Molde {
    const base = moldePadrao();
    const porKind = new Map((m.pieces ?? []).map((p) => [p.kind, p]));
    const pieces = base.pieces.map((b) => {
      const o = porKind.get(b.kind);
      if (!o) return JSON.parse(JSON.stringify(b));
      return {
        id: typeof o.id === "string" && o.id ? o.id : b.id,
        kind: b.kind,
        rect: { ...b.rect, ...(o.rect ?? {}) },
        style: { ...b.style, ...(o.style ?? {}) },
        visible_when: (o.visible_when as string) ?? b.visible_when,
      };
    });
    return {
      schema_version: 1,
      id: typeof m.id === "string" && m.id ? m.id : base.id,
      name: typeof m.name === "string" && m.name ? m.name : base.name,
      description: typeof m.description === "string" ? m.description : base.description,
      layout_for: "monster",
      canvas: { w: 59, h: 86, unit: "per_mil" },
      pieces,
    };
  }

  let sujo = $derived(rascunho ? JSON.stringify(rascunho.pieces) !== salvoJson : false);
  let nErros = $derived(erros.filter((e) => (e.nivel ?? "erro") !== "aviso").length);

  function pecaIdx(kind: string): number {
    return rascunho?.pieces.findIndex((p) => p.kind === kind) ?? -1;
  }
  function rectDe(kind: string): PecaRect {
    const p = rascunho?.pieces.find((x) => x.kind === kind);
    const of = pecaOficial(kind);
    return { ...(of?.rect ?? { x: 0, y: 0, w: 0, h: 0 }), ...(p?.rect ?? {}) };
  }
  function estiloDe(kind: string): Record<string, number | boolean | string> {
    const p = rascunho?.pieces.find((x) => x.kind === kind);
    const of = pecaOficial(kind);
    return { ...(of?.style ?? {}), ...(p?.style ?? {}) } as Record<string, number | boolean | string>;
  }
  function alterada(kind: string): boolean {
    const p = rascunho?.pieces.find((x) => x.kind === kind);
    const of = pecaOficial(kind);
    return JSON.stringify(p) !== JSON.stringify(of);
  }

  function empilhar() {
    if (!rascunho) return;
    hist = [...hist.slice(-49), JSON.stringify(rascunho.pieces)];
  }
  function desfazer() {
    if (!hist.length || !rascunho) return;
    const ant = hist[hist.length - 1];
    hist = hist.slice(0, -1);
    rascunho.pieces = JSON.parse(ant);
  }
  function aoTeclado(e: KeyboardEvent) {
    // Ctrl+Z desfaz o molde — mas nunca dentro de campo de texto (lá o Z é do campo).
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z") {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      e.preventDefault();
      desfazer();
    }
  }

  // ---- Arrastar e redimensionar (por-mil da carta, igual ao contrato) ----
  type Gesto = { kind: string; canto: string | null; x0: number; y0: number; boxW: number; boxH: number; antes: PecaRect };
  let gesto: Gesto | null = null;
  const travar = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));

  function aoPointerPeca(e: PointerEvent, kind: string, canto: string | null) {
    e.stopPropagation();
    sel = kind;
    // Moldura: só seleciona na lista (ela cobre a carta toda — arrastar ela
    // seria mover o fundo sem querer).
    if (kind === "frame" || !rascunho || !caixa) return;
    const i = pecaIdx(kind);
    if (i < 0) return;
    const box = caixa.getBoundingClientRect();
    if (!box.width || !box.height) return;
    empilhar();
    arrastando = true;
    gesto = { kind, canto, x0: e.clientX, y0: e.clientY, boxW: box.width, boxH: box.height, antes: { ...rascunho.pieces[i].rect! } };
    e.preventDefault();
  }
  function aoMoverPonteiro(e: PointerEvent) {
    if (!gesto || !rascunho) return;
    const i = pecaIdx(gesto.kind);
    if (i < 0) return;
    const dx = ((e.clientX - gesto.x0) / gesto.boxW) * 1000;
    const dy = ((e.clientY - gesto.y0) / gesto.boxH) * 1000;
    const a = gesto.antes;
    const MIN = 20;
    if (gesto.canto === null) {
      rascunho.pieces[i].rect = {
        x: travar(Math.round(a.x + dx), 0, 1000 - a.w),
        y: travar(Math.round(a.y + dy), 0, 1000 - a.h),
        w: a.w, h: a.h,
      };
      return;
    }
    let { x, y, w, h } = a;
    if (gesto.canto.includes("d")) w = travar(Math.round(a.w + dx), MIN, 1000 - x);
    if (gesto.canto.includes("b")) h = travar(Math.round(a.h + dy), MIN, 1000 - y);
    if (gesto.canto.includes("e")) {
      const nx = travar(Math.round(a.x + dx), 0, a.x + a.w - MIN);
      w = travar(Math.round(a.w + (a.x - nx)), MIN, 1000 - nx);
      x = nx;
    }
    if (gesto.canto.includes("c")) {
      const ny = travar(Math.round(a.y + dy), 0, a.y + a.h - MIN);
      h = travar(Math.round(a.h + (a.y - ny)), MIN, 1000 - ny);
      y = ny;
    }
    rascunho.pieces[i].rect = { x, y, w, h };
  }
  function aoSoltarPonteiro() {
    gesto = null;
    arrastando = false;
  }

  // ---- Painel numérico (mesmos limites do contrato; nada sai da carta) ----
  function mudarRect(campo: "x" | "y" | "w" | "h", valor: number) {
    if (!rascunho) return;
    const i = pecaIdx(sel);
    if (i < 0 || !rascunho.pieces[i].rect) return;
    if (!Number.isFinite(valor)) return;
    empilhar();
    const r = { ...rascunho.pieces[i].rect! };
    const MIN = 20;
    if (campo === "x") { r.x = travar(Math.round(valor), 0, 1000 - MIN); if (r.x + r.w > 1000) r.w = 1000 - r.x; }
    if (campo === "y") { r.y = travar(Math.round(valor), 0, 1000 - MIN); if (r.y + r.h > 1000) r.h = 1000 - r.y; }
    if (campo === "w") r.w = travar(Math.round(valor), MIN, 1000 - r.x);
    if (campo === "h") r.h = travar(Math.round(valor), MIN, 1000 - r.y);
    rascunho.pieces[i].rect = r;
  }
  function mudarStyle(campo: string, valor: number | boolean | string) {
    if (!rascunho) return;
    const i = pecaIdx(sel);
    if (i < 0) return;
    empilhar();
    const s = { ...(rascunho.pieces[i].style ?? {}) } as Record<string, number | boolean | string>;
    if (campo === "font_size") {
      const n = Math.round(Number(valor));
      if (!Number.isFinite(n)) return;
      s.font_size = travar(n, 0, 1000);
    } else if (campo === "bold") {
      s.bold = valor === true;
    } else if (campo === "color") {
      if (!/^#[0-9a-fA-F]{6}$/.test(String(valor))) return;
      s.color = String(valor);
    } else if (campo === "align") {
      if (!["left", "center", "right"].includes(String(valor))) return;
      s.align = String(valor);
    } else if (campo === "z") {
      const n = Math.round(Number(valor));
      if (!Number.isFinite(n)) return;
      s.z = travar(n, 0, 10);
    }
    rascunho.pieces[i].style = s;
  }
  function mudarZ(delta: number) {
    const z = Number(estiloDe(sel).z ?? 5);
    mudarStyle("z", z + delta);
  }
  function mudarVis(v: string) {
    if (!rascunho) return;
    const i = pecaIdx(sel);
    if (i < 0) return;
    if (!["always", "monster_only"].includes(v)) return;
    empilhar();
    rascunho.pieces[i].visible_when = v;
  }

  // ---- Validar (ao vivo, com pausa) + Salvar (só grava se válido) ----
  let timerVal: ReturnType<typeof setTimeout> | null = null;
  $effect(() => {
    const snap = rascunho ? JSON.stringify(rascunho.pieces) : "";
    if (!rascunho || arrastando || !snap) return;
    if (timerVal) clearTimeout(timerVal);
    timerVal = setTimeout(() => { void validarAgora(snap); }, 500);
    return () => { if (timerVal) clearTimeout(timerVal); };
  });
  async function validarAgora(snap: string) {
    if (!rascunho || JSON.stringify(rascunho.pieces) !== snap) return;
    validando = true;
    try {
      erros = await layout.validate(rascunho);
    } catch (e) {
      erros = [{ campo: "Molde", mensagem: errMsg(e) }];
    } finally {
      validando = false;
    }
  }
  async function validarBotao() {
    if (!rascunho) return;
    flash.clear();
    await validarAgora(JSON.stringify(rascunho.pieces));
    const nAviso = erros.length - nErros;
    flash.flashSave(
      !erros.length ? "Molde válido — pode salvar." : `${nErros} erro(s)${nAviso ? ` e ${nAviso} aviso(s)` : ""} — veja a lista abaixo.`,
      !nErros,
    );
  }
  async function salvar() {
    if (!rascunho || salvando) return;
    salvando = true;
    flash.clear();
    try {
      const m = await layout.save(rascunho);
      salvoJson = JSON.stringify(rascunho.pieces);
      hist = [];
      erros = [];
      flash.flashSave(`${m} Para ver valendo no jogo, abra uma carta na aba Cartas e clique em Jogar (o Astralis lê este molde via --project).`, true);
    } catch (e) {
      flash.flashSave(errMsg(e), false);
      // Lista estruturada junto (onde clicar em cada erro).
      try { erros = await layout.validate(rascunho); } catch { /* a msg já mostra */ }
    } finally {
      salvando = false;
    }
  }
  function restaurar() {
    if (!rascunho) return;
    empilhar();
    const p = moldePadrao();
    rascunho.name = p.name;
    rascunho.description = p.description;
    rascunho.pieces = p.pieces;
    flash.flashSave("Molde padrão oficial de volta na tela — clique em Salvar para gravar.", true);
  }
  function irParaPeca(kind: string | null) {
    if (kind) sel = kind;
  }

  // ---- Carta-modelo: a selecionada (se monstro), senão o 1º monstro, senão
  // exemplo embutido (o molde V1 é de monstro; projeto vazio D29 edita com o
  // exemplo — o molde vale para todas do mesmo jeito).
  let modelo = $derived.by(() => {
    const selC = cardsStore.selected;
    const base = (selC && (selC.card_type ?? "monster") === "monster")
      ? selC
      : cardsStore.cards.find((c) => (c.card_type ?? "monster") === "monster");
    if (base) {
      return {
        nome: base.name ?? base.id, id: base.id, tipo: base.monster_type ?? "warrior",
        attr: base.attribute ?? "earth", nivel: base.level ?? 1, desc: base.description ?? "",
        atk: base.attack ?? 0, def: base.defense ?? 0, efeito: (base.effects ?? []).length > 0,
        arte: base.artwork ?? "", rotulo: base.name ?? base.id,
      };
    }
    return {
      nome: "Dragão Branco de Exemplo", id: "card_exemplo", tipo: "dragon",
      attr: "light", nivel: 8, desc: "Carta de exemplo — o molde vale para todas as cartas de monstro.",
      atk: 3000, def: 2500, efeito: false, arte: "", rotulo: "carta de exemplo",
    };
  });
  let usandoExemplo = $derived(!cardsStore.cards.some((c) => (c.card_type ?? "monster") === "monster"));
  let pecaSel = $derived(PECAS_ORDEM.find((p) => p.kind === sel) ?? PECAS_ORDEM[0]);
  let ehTexto = $derived(KINDS_TEXTO.includes(sel));
  let corSel = $derived(String(estiloDe(sel).color ?? "#000000"));
</script>

<div class="flex-1 min-h-0 flex flex-col gap-3 overflow-hidden">
  <!-- Barra do molde -->
  <div class="shrink-0 flex items-center gap-2 flex-wrap rounded-2xl border border-zinc-800 bg-zinc-950/60 px-4 py-2.5">
    <div class="min-w-0 mr-auto">
      <h2 class="text-sm font-black tracking-tight">Molde da carta {#if sujo}<span class="text-amber-300" title="Tem mudança ainda não salva">●</span>{/if}</h2>
      <p class="text-[11px] text-zinc-500 truncate">
        {#if layout.loading}Lendo molde…
        {:else if nErros}{nErros} erro(s) — arrume antes de salvar
        {:else if validando}Validando…
        {:else if sujo}com mudança não salva
        {:else}igual ao salvo ✓{/if}
      </p>
    </div>
    <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition disabled:opacity-40" disabled={!hist.length} onclick={desfazer} title="Desfaz a última mudança (Ctrl+Z)">↺ Desfazer</button>
    <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={restaurar} title="Volta ao padrão oficial do scan na tela (precisa Salvar para gravar)">Restaurar padrão</button>
    <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={validarBotao}>Validar</button>
    <button class="px-3 py-1.5 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition disabled:opacity-60" disabled={!rascunho || salvando} onclick={salvar}>{salvando ? "Salvando…" : "Salvar molde"}</button>
  </div>

  {#if msg}<p class="shrink-0 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {msgOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{msg}</p>{/if}
  {#if layout.error}<p class="shrink-0 text-xs rounded-lg px-3 py-2 border text-sky-300 bg-sky-950/30 border-sky-900/50">{layout.error}</p>{/if}
  {#if erros.length}
    <div class="shrink-0 rounded-xl border border-rose-900/60 bg-rose-950/20 divide-y divide-rose-900/40 max-h-28 overflow-y-auto">
      {#each erros as fe (fe.campo + fe.mensagem)}
        {@const kind = kindDoErro(fe.mensagem)}
        <p class="px-3 py-1.5 text-xs {fe.nivel === 'aviso' ? 'text-amber-200' : 'text-rose-200'}">
          <span class="font-bold">{fe.campo}:</span> {fe.mensagem}
          {#if kind}<button class="ml-2 underline hover:text-white" onclick={() => irParaPeca(kind)} title="Seleciona a peça na tela">mostrar peça →</button>{/if}
        </p>
      {/each}
    </div>
  {/if}

  {#if !rascunho}
    <p class="text-xs text-zinc-500">Lendo molde…</p>
  {:else}
  <div class="flex-1 min-h-0 grid lg:grid-cols-[minmax(0,380px)_minmax(0,1fr)] gap-3 overflow-hidden">
    <!-- Tela: a carta de verdade lendo o rascunho + camada de arrastar -->
    <section class="min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4">
      <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">TELA — CLIQUE E ARRASTE A PEÇA · CANTOS REDIMENSIONAM</p>
      {#if usandoExemplo}
        <p class="mb-2 text-[11px] text-sky-300/90">Projeto sem monstro — mostrando carta de exemplo (o molde vale para todas).</p>
      {:else}
        <p class="mb-2 text-[11px] text-zinc-500">Modelo: <span class="text-zinc-300 font-semibold">{modelo.rotulo}</span> (a carta selecionada na aba Cartas, se for monstro)</p>
      {/if}
      <div bind:this={caixa} class="relative w-full max-w-[320px] mx-auto" style="container-type: inline-size; touch-action: none;" role="application" aria-label="Editor visual do molde: arraste as peças para mover, puxe os cantos para redimensionar" onpointermove={aoMoverPonteiro} onpointerup={aoSoltarPonteiro} onpointercancel={aoSoltarPonteiro} onpointerleave={aoSoltarPonteiro}>
        <CardPreview
          nome={modelo.nome}
          idCarta={modelo.id}
          tipoMonstro={modelo.tipo}
          atributo={modelo.attr}
          nivel={modelo.nivel}
          descricao={modelo.desc}
          atk={modelo.atk}
          def={modelo.def}
          temEfeito={modelo.efeito}
          artwork={modelo.arte}
          molde={rascunho}
          esconderBorda
        />
        <!-- Camada de edição: uma área por peça (moldura só pela lista) -->
        {#each [...rascunho.pieces].sort((a, b) => Number(a.style?.z ?? 5) - Number(b.style?.z ?? 5)) as p (p.kind)}
          {#if p.kind !== "frame" && p.rect}
            {@const r = p.rect}
            {@const ativa = sel === p.kind}
            <div
              class="absolute rounded-sm {ativa ? '' : 'hover:bg-white/10'}"
              style="left: {r.x / 10}%; top: {r.y / 10}%; width: {r.w / 10}%; height: {r.h / 10}%; {ativa ? 'outline: 2px solid #a78bfa; outline-offset: 0; background: rgba(167,139,250,0.12); cursor: move;' : 'cursor: pointer;'}"
              onpointerdown={(e) => aoPointerPeca(e, p.kind, null)}
              title={PECAS_ORDEM.find((x) => x.kind === p.kind)?.nome ?? p.kind}
              role="button"
              tabindex="-1"
              aria-label="Editar peça {(PECAS_ORDEM.find((x) => x.kind === p.kind)?.nome ?? p.kind)}"
            >
              {#if ativa}
                {#each [["se", "-top-1.5 -left-1.5 cursor-nwse-resize"], ["sd", "-top-1.5 -right-1.5 cursor-nesw-resize"], ["ie", "-bottom-1.5 -left-1.5 cursor-nesw-resize"], ["id", "-bottom-1.5 -right-1.5 cursor-nwse-resize"]] as [canto, pos] (canto)}
                  <span
                    class="absolute {pos} w-3.5 h-3.5 rounded-sm bg-violet-400 border border-white shadow"
                    onpointerdown={(e) => aoPointerPeca(e, p.kind, canto)}
                    role="button"
                    tabindex="-1"
                    aria-label="Redimensionar pelo canto"
                  ></span>
                {/each}
              {/if}
            </div>
          {/if}
        {/each}
      </div>
      <p class="mt-2 text-[11px] text-zinc-500 text-center">Arraste para mover · puxe um canto roxo para redimensionar · tudo preso dentro da carta.</p>
    </section>

    <!-- Painel: lista das 9 + campos da selecionada -->
    <section class="min-h-0 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/60 p-4 space-y-3">
      <div>
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">PEÇAS (9 — SEM PEÇA NOVA NA V1)</p>
        <div class="flex gap-1 flex-wrap">
          {#each PECAS_ORDEM as p (p.kind)}
            {@const ativa = sel === p.kind}
            <button
              class="px-2.5 py-1 rounded-full text-[11px] font-medium border transition {ativa ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-900 text-zinc-400 border-zinc-800 hover:border-zinc-600'}"
              onclick={() => { sel = p.kind; }}
              title={p.dica}
            >{p.nome}{#if alterada(p.kind)}<span class="text-violet-500" title="Diferente do padrão"> ●</span>{/if}</button>
          {/each}
        </div>
      </div>

      <div class="rounded-xl border border-violet-600/30 bg-violet-950/20 p-3 space-y-2.5">
        <div class="flex items-center gap-2">
          <p class="text-xs font-bold">{pecaSel.nome}</p>
          <p class="text-[10px] font-mono text-zinc-500">{sel}</p>
          {#if alterada(sel)}<span class="text-[10px] text-violet-300">● diferente do padrão</span>{/if}
        </div>
        <p class="text-[11px] text-zinc-500">{pecaSel.dica}</p>

        {#if sel === "frame"}
          <p class="text-[11px] text-zinc-400">A moldura cobre a carta toda (fundo e borda) — sem ajuste na V1. Selecione outra peça para mover ou estilizar.</p>
        {:else}
          {@const r = rectDe(sel)}
          <div>
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">POSIÇÃO E TAMANHO (POR-MIL DA CARTA)</p>
            <div class="grid grid-cols-4 gap-1.5">
              {#each [["x", "X"], ["y", "Y"], ["w", "Larg"], ["h", "Alt"]] as [campo, rot] (campo)}
                <label class="block">
                  <span class="text-[10px] text-zinc-500">{rot}</span>
                  <input type="number" min="0" max="1000" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono focus:outline-none focus:border-violet-600" value={r[campo as "x"]} onchange={(e) => mudarRect(campo as "x", (e.target as HTMLInputElement).valueAsNumber)} />
                </label>
              {/each}
            </div>
          </div>

          {#if ehTexto}
            {@const s = estiloDe(sel)}
            <div>
              <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">LETRA (TAMANHO EM POR-MIL DA ALTURA)</p>
              <div class="grid grid-cols-2 gap-1.5">
                <label class="block">
                  <span class="text-[10px] text-zinc-500">Tamanho</span>
                  <input type="number" min="0" max="1000" class="w-full px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono focus:outline-none focus:border-violet-600" value={Number(s.font_size ?? 0)} onchange={(e) => mudarStyle("font_size", (e.target as HTMLInputElement).valueAsNumber)} />
                </label>
                <label class="flex items-end gap-1.5 pb-2 text-xs text-zinc-300">
                  <input type="checkbox" checked={s.bold === true} onchange={(e) => mudarStyle("bold", (e.target as HTMLInputElement).checked)} class="accent-violet-600 w-4 h-4" /> Negrito
                </label>
              </div>
              <div class="grid grid-cols-2 gap-1.5 mt-1.5">
                <label class="block">
                  <span class="text-[10px] text-zinc-500">Cor (hex)</span>
                  <span class="flex gap-1">
                    <input type="color" class="w-9 h-8 rounded-lg bg-zinc-950 border border-zinc-800 cursor-pointer" value={/^#[0-9a-fA-F]{6}$/.test(corSel) ? corSel : "#000000"} onchange={(e) => mudarStyle("color", (e.target as HTMLInputElement).value)} title="Escolher cor" />
                    <input class="flex-1 min-w-0 px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono focus:outline-none focus:border-violet-600" value={corSel} onchange={(e) => mudarStyle("color", (e.target as HTMLInputElement).value)} placeholder="#2a1c08" />
                  </span>
                </label>
                <div>
                  <span class="text-[10px] text-zinc-500">Alinhamento</span>
                  <div class="flex gap-1 mt-0.5">
                    {#each [["left", "◧"], ["center", "⬒"], ["right", "◨"]] as [a, icone] (a)}
                      <button class="flex-1 py-1.5 rounded-lg text-xs border transition {(s.align ?? "left") === a ? "bg-white text-zinc-900 border-white" : "bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600"}" onclick={() => mudarStyle("align", a)} title={a}>{icone}</button>
                    {/each}
                  </div>
                </div>
              </div>
            </div>
          {:else}
            <p class="text-[11px] text-zinc-400">Cor e letra vêm {sel === "attribute_orb" ? "do atributo da carta" : "da imagem da carta"} — aqui valem posição, tamanho e ordem.</p>
          {/if}

          <div>
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">ORDEM (QUEM FICA POR CIMA)</p>
            <div class="flex items-center gap-1.5">
              <button class="px-2.5 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={() => mudarZ(-1)} title="Manda para trás">▼ trás</button>
              <input type="number" min="0" max="10" class="w-16 px-2 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-xs font-mono text-center focus:outline-none focus:border-violet-600" value={Number(estiloDe(sel).z ?? 5)} onchange={(e) => mudarStyle("z", (e.target as HTMLInputElement).valueAsNumber)} title="0 = primeiro (fundo) até 10" />
              <button class="px-2.5 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={() => mudarZ(1)} title="Traz para frente">▲ frente</button>
            </div>
          </div>

          <div>
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">MOSTRAR</p>
            <div class="flex gap-1">
              {#each [["always", "Sempre"], ["monster_only", "Só em monstro"]] as [v, rot] (v)}
                {@const cur = rascunho.pieces[pecaIdx(sel)]?.visible_when ?? "always"}
                <button class="flex-1 py-1.5 rounded-lg text-xs font-medium border transition {cur === v ? "bg-white text-zinc-900 border-white" : "bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600"}" onclick={() => mudarVis(v)}>{rot}</button>
              {/each}
            </div>
          </div>
        {/if}
      </div>

      <p class="text-[11px] text-zinc-600">O molde vale para todas as cartas de monstro. Para ver valendo no jogo: Salvar aqui, depois Cartas → Jogar (o Astralis lê este arquivo via --project).</p>
    </section>
  </div>
  {/if}
</div>
