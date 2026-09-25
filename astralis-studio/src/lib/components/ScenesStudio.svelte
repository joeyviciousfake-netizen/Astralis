<script lang="ts">
  // ScenesStudio — editor simples de cenas (docs 08/09 + bloco 6).
  // Lista de cenas + editor de falas (personagem, texto, fundo), salvando JSON
  // simples em projects/default/scenes/. Sem grafo/timeline agora; sem Play de cena
  // (o Astralis ainda não lê esse formato — R4). Formato no README do editor.
  import { useCenas } from "$lib/stores/scenes.svelte";
  import type { Cena } from "$lib/stores/scenes.svelte";
  import { useSectionShell } from "$lib/section";
  import { errMsg } from "$lib/stores/ipc";
  import AssetDrop from "$lib/components/AssetDrop.svelte";

  const store = useCenas();

  useSectionShell({
    mount: () => { void store.ensureLoaded(); },
    onSave: () => { if (sel || isNew) save().catch(() => {}); },
  });

  let selId = $state<string | null>(null);
  let isNew = $state(false);
  let previewIdx = $state(0);

  let idEdit = $state("");
  let nomeEdit = $state("");
  let fundoEdit = $state("");
  let falasEdit = $state<Array<{ character: string; text: string; background: string }>>([]);
  let fieldErrors = $state<Array<{ campo: string; mensagem: string }>>([]);
  const flash = $state({ msg: "", ok: false });

  let lista = $derived(store.cenas ?? []);
  let sel = $derived(lista.find((c) => c.id === selId) ?? null);

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
      idEdit = s.id;
      nomeEdit = s.name ?? "";
      fundoEdit = s.background ?? "";
      falasEdit = (s.lines ?? []).map((l) => ({ character: l.character, text: l.text, background: l.background ?? "" }));
      previewIdx = 0;
      fieldErrors = [];
      flash.msg = "";
    }
  });

  function build(): Cena {
    return {
      schema_version: 1,
      id: (isNew ? idEdit.trim() : (sel?.id ?? idEdit.trim())) || "scene_nova",
      name: nomeEdit.trim() || "Sem nome",
      background: fundoEdit.trim() || undefined,
      lines: falasEdit.map((f) => ({
        character: f.character.trim(),
        text: f.text.trim(),
        ...(f.background.trim() ? { background: f.background.trim() } : {}),
      })),
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
      setFlash(erros.length ? `${erros.length} erro(s) — veja a lista` : "Cena válida", !erros.length);
    } catch (e) {
      setFlash(`Falha ao validar: ${errMsg(e)}`, false);
    }
  }

  function duplicate() {
    const s = sel;
    if (!s) return;
    const base = s.id.replace(/_copia\d*$/, "");
    let n = 1;
    while (lista.some((c) => c.id === `${base}_copia${n > 1 ? n : ""}`)) n++;
    lastSync = null;
    isNew = true;
    idEdit = `${base}_copia${n > 1 ? n : ""}`;
    nomeEdit = `${s.name} (cópia)`;
    fundoEdit = s.background ?? "";
    falasEdit = (s.lines ?? []).map((l) => ({ character: l.character, text: l.text, background: l.background ?? "" }));
    previewIdx = 0;
    fieldErrors = [];
    setFlash("Cópia pronta — ajuste e clique em Salvar", true);
  }

  function createNew() {
    lastSync = null;
    isNew = true;
    idEdit = "scene_nova";
    nomeEdit = "";
    fundoEdit = "";
    falasEdit = [{ character: "", text: "", background: "" }];
    previewIdx = 0;
    fieldErrors = [];
    setFlash("", true);
    selId = null;
  }

  function mover(i: number, dir: -1 | 1) {
    const j = i + dir;
    if (j < 0 || j >= falasEdit.length) return;
    const next = [...falasEdit];
    [next[i], next[j]] = [next[j], next[i]];
    falasEdit = next;
    previewIdx = Math.min(previewIdx, falasEdit.length - 1);
  }

  let falaAtual = $derived(falasEdit[Math.min(previewIdx, Math.max(0, falasEdit.length - 1))] ?? null);
  let fundoAtual = $derived(falaAtual?.background?.trim() || fundoEdit.trim());
</script>

<div class="flex-1 min-h-0 flex gap-3 md:gap-4 overflow-hidden">
  <!-- Lista -->
  <section class="w-[240px] lg:w-[280px] shrink-0 flex flex-col min-h-0 rounded-2xl border border-zinc-800 bg-zinc-950/60 overflow-hidden">
    <div class="p-3 pb-2 flex items-center gap-2">
      <p class="text-[10px] text-zinc-600">{lista.length} cenas • sem grafo por ora</p>
      <button class="ml-auto px-2.5 py-1 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" onclick={createNew}>＋ Nova</button>
    </div>
    <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-1">
      {#if store.loading}
        <p class="p-4 text-xs text-zinc-500 text-center">Carregando…</p>
      {:else if store.error}
        <p class="p-4 text-xs text-red-400 text-center">{store.error}</p>
      {:else if !lista.length}
        <p class="p-4 text-xs text-zinc-500 text-center">Nenhuma cena — clique em Nova.</p>
      {:else}
        {#each lista as c (c.id)}
          {@const ativo = !isNew && selId === c.id}
          <button
            onclick={() => { selId = ativo ? null : c.id; isNew = false; }}
            class="w-full text-left rounded-xl border px-2 py-2 flex items-center gap-2 transition {ativo ? 'bg-white text-zinc-900 border-white shadow' : 'bg-zinc-900/60 border-zinc-800 hover:border-zinc-600 text-zinc-100'}"
          >
            <span class="w-9 h-9 rounded-xl bg-gradient-to-br from-amber-500 via-orange-600 to-rose-600 flex items-center justify-center text-sm shrink-0">🎬</span>
            <span class="min-w-0 flex-1">
              <span class="block text-xs font-bold truncate">{c.name}</span>
              <span class="block text-[10px] font-mono truncate {ativo ? 'text-zinc-600' : 'text-zinc-500'}">{c.lines?.length ?? 0} falas • {c.id}</span>
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
        <div class="ml-auto flex gap-1.5 flex-wrap">
          <button class="px-3 py-1.5 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={save}>Salvar</button>
          <button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={validateNow}>Validar</button>
          {#if !isNew}<button class="px-3 py-1.5 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-xs transition" onclick={duplicate}>Duplicar</button>{/if}
        </div>
      </div>
      {#if flash.msg}<p class="mt-2 shrink-0 text-xs rounded-lg px-3 py-2 border {flash.ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{flash.msg}</p>{/if}
      {#if fieldErrors.length}
        <div class="mt-2 shrink-0 rounded-xl border border-rose-900/60 bg-rose-950/20 divide-y divide-rose-900/40 max-h-24 overflow-y-auto">
          {#each fieldErrors as fe (fe.campo + fe.mensagem)}
            <p class="px-3 py-1.5 text-xs text-rose-200"><span class="font-bold">{fe.campo}:</span> {fe.mensagem}</p>
          {/each}
        </div>
      {/if}

      <div class="mt-2 shrink-0 grid sm:grid-cols-3 gap-2">
        <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
          <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">NOME</span>
          <input class="mt-1 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm focus:outline-none focus:border-violet-600" bind:value={nomeEdit} placeholder="Como aparece na lista" />
        </label>
        {#if isNew}
          <label class="block rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
            <span class="text-[10px] tracking-widest text-zinc-500 font-semibold">ID (vira o nome do arquivo)</span>
            <input class="mt-1 w-full px-2.5 py-1.5 rounded-lg bg-zinc-950 border border-zinc-800 text-sm font-mono focus:outline-none focus:border-violet-600" bind:value={idEdit} placeholder="scene_encontro_rival" />
          </label>
        {/if}
        <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
          <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1">FUNDO (arraste um PNG)</p>
          <AssetDrop tipo="cena" sugestao={isNew ? idEdit : (sel?.id ?? "fundo")} value={fundoEdit} onimport={(c) => fundoEdit = c} />
        </div>
      </div>

      <div class="mt-2 flex-1 min-h-0 grid lg:grid-cols-2 gap-3 overflow-hidden">
        <!-- Falas -->
        <div class="min-h-0 flex flex-col rounded-xl border border-zinc-800 bg-zinc-900/40 overflow-hidden" id="field-lines">
          <div class="p-2.5 pb-2 shrink-0 flex items-center gap-2">
            <p class="text-[10px] tracking-widest text-zinc-500 font-semibold">FALAS ({falasEdit.length})</p>
            <button class="ml-auto px-2.5 py-1 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" onclick={() => { falasEdit = [...falasEdit, { character: "", text: "", background: "" }]; previewIdx = falasEdit.length - 1; }}>＋ fala</button>
          </div>
          <div class="flex-1 overflow-y-auto px-2 pb-2 min-h-0 space-y-2">
            {#each falasEdit as f, i (i)}
              <div class="rounded-lg border border-zinc-800 bg-zinc-950 p-2">
                <div class="flex items-center gap-1.5 mb-1.5">
                  <span class="px-1.5 py-0.5 rounded bg-zinc-800 text-[10px] font-bold text-zinc-400">{i + 1}</span>
                  <input class="flex-1 min-w-0 px-2 py-1 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={f.character} placeholder="Personagem (quem fala)" />
                  <button class="text-zinc-600 hover:text-zinc-200 text-xs px-1" title="Sobe" onclick={() => mover(i, -1)}>▲</button>
                  <button class="text-zinc-600 hover:text-zinc-200 text-xs px-1" title="Desce" onclick={() => mover(i, 1)}>▼</button>
                  <button class="text-zinc-500 hover:text-rose-300 text-xs px-1" title="Remover fala" onclick={() => { falasEdit = falasEdit.filter((_, x) => x !== i); previewIdx = 0; }}>✕</button>
                </div>
                <textarea rows="2" class="w-full px-2 py-1 rounded-lg bg-zinc-900 border border-zinc-800 text-xs" bind:value={f.text} placeholder="O que ele(a) diz…"></textarea>
                <input class="mt-1 w-full px-2 py-1 rounded-lg bg-zinc-900 border border-zinc-800 text-[11px] font-mono" bind:value={f.background} placeholder="Fundo só desta fala (opcional)" />
              </div>
            {/each}
          </div>
        </div>
        <!-- Prévia leitura -->
        <div class="min-h-0 flex flex-col rounded-xl border border-zinc-800 bg-zinc-900/40 overflow-hidden">
          <p class="p-2.5 pb-2 shrink-0 text-[10px] tracking-widest text-zinc-500 font-semibold">PRÉVIA DE LEITURA (como o jogador vê)</p>
          <div class="flex-1 min-h-0 mx-2 mb-2 rounded-xl bg-zinc-800 border border-zinc-700 flex flex-col overflow-hidden">
            {#if fundoAtual}
              <p class="px-3 py-1 text-[10px] font-mono text-zinc-400 truncate">🖼 {fundoAtual}</p>
            {:else}
              <div class="h-16 bg-zinc-700/60 flex items-center justify-center text-[10px] text-zinc-500">(fundo cinza — sem arte)</div>
            {/if}
            <div class="flex-1 min-h-0 overflow-y-auto p-3 space-y-2">
              {#if !falasEdit.length}
                <p class="text-xs text-zinc-500 text-center">Sem falas ainda.</p>
              {:else}
                {#each falasEdit as f, i (i)}
                  <button class="w-full text-left rounded-lg border px-2.5 py-2 transition {i === previewIdx ? 'border-violet-500 bg-violet-600/10' : 'border-zinc-700 bg-zinc-950/60'}" onclick={() => previewIdx = i}>
                    <p class="text-[11px] font-bold text-violet-300">{f.character || "(sem personagem)"}</p>
                    <p class="text-xs text-zinc-200 mt-0.5">{f.text || "(sem texto)"}</p>
                  </button>
                {/each}
              {/if}
            </div>
            {#if falasEdit.length > 1}
              <div class="shrink-0 flex items-center gap-2 p-2 border-t border-zinc-700">
                <button class="px-3 py-1 rounded-full bg-zinc-700 hover:bg-zinc-600 text-[11px]" onclick={() => previewIdx = Math.max(0, previewIdx - 1)}>◀</button>
                <span class="text-[11px] text-zinc-400">{previewIdx + 1} / {falasEdit.length}</span>
                <button class="px-3 py-1 rounded-full bg-zinc-700 hover:bg-zinc-600 text-[11px]" onclick={() => previewIdx = Math.min(falasEdit.length - 1, previewIdx + 1)}>▶</button>
              </div>
            {/if}
          </div>
        </div>
      </div>
    {:else}
      <div class="h-full min-h-[280px] flex flex-col items-center justify-center gap-3 text-center">
        <div class="w-16 h-16 rounded-3xl bg-gradient-to-br from-amber-500/20 to-rose-600/20 border border-orange-500/20 flex items-center justify-center text-3xl">🎬</div>
        <p class="text-sm font-bold text-zinc-200">Escolha uma cena na lista</p>
        <p class="text-xs text-zinc-500 max-w-sm">Ou clique em <span class="text-zinc-300 font-semibold">Nova</span> — mas prefira <span class="text-zinc-300 font-semibold">Duplicar</span> uma parecida e editar.</p>
        <button class="mt-1 px-4 py-2 rounded-full bg-white text-zinc-900 text-xs font-semibold hover:bg-zinc-200 transition" onclick={createNew}>Criar nova</button>
      </div>
    {/if}
  </section>
</div>
