<script lang="ts">
  // ExportStudio — tela Exportar (doc 12 + bloco 7).
  // Plataforma (Windows/Linux/Android) + Aberto/Protegido + checklist
  // "testou?" + botão Exportar. POR ORA o botão só valida o projeto inteiro
  // e avisa "empacotamento vem depois" — não finje empacotar (R4/R6: .astralis
  // é binário trancado, nunca JSON em texto).
  import { useSectionShell } from "$lib/section";
  import { invokeSave, errMsg } from "$lib/stores/ipc";
  import { useCards } from "$lib/stores/cards.svelte";
  import { useDuelists } from "$lib/stores/duelists.svelte";
  import { useDecks } from "$lib/stores/decks.svelte";
  import { useFusions } from "$lib/stores/fusions.svelte";
  import { useValidate } from "$lib/stores/validate.svelte";

  function abrirImportacao() {
    arquivoPack?.click();
  }

  useSectionShell({ mount: () => {}, extra: [["astralis:importar-pack", abrirImportacao]] });

  let plataforma = $state("windows");
  let modo = $state("protegido");
  let checkDuelo = $state(false);
  let checkCartas = $state(false);
  let checkDecks = $state(false);

  type Item = { area: string; ok: boolean; detalhe: string };
  let itens = $state<Item[]>([]);
  let erros = $state(0);
  let avisos = $state(0);
  let msg = $state("");
  let ok = $state(false);
  let exportando = $state(false);
  let jaValidou = $state(false);

  // ---- IMPORTAR PACK (.json) ----
  // File picker → valida TUDO antes de mexer em nada (pack inválido = erro e
  // o projeto continua intacto) → backup automático do conteúdo atual para
  // projects/default/backups/pack_<data>_<hora>/ → SUBSTITUI o conteúdo do
  // projeto pelo conteúdo do pack (o que não está no pack é apagado;
  // fusions.json é trocado inteiro). Só dado, nada de jogo (R1/R4).
  // Precisa do app (escreve arquivos): no navegador é só leitura.
  type ResumoPack = {
    cartas: number; duelistas: number; decks: number;
    fusoes_novas: number; fusoes_puladas: number;
    regras_novas: number; regras_puladas: number;
    equips_ignorados: number; backups: string[];
    erros: string[]; avisos: string[]; mensagem: string;
  };
  let arquivoPack: HTMLInputElement | null = $state(null);
  let importando = $state(false);
  let impMsg = $state("");
  let impOk = $state(false);
  let resumo = $state<ResumoPack | null>(null);

  function emTauri(): boolean {
    return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
  }

  async function aoEscolherPack(e: Event) {
    const input = e.target as HTMLInputElement;
    const arq = input.files?.[0];
    input.value = "";
    if (!arq) return;
    impMsg = "";
    impOk = false;
    resumo = null;
    if (!emTauri()) {
      impMsg = "Para importar, abra o app via app.bat (no navegador é só leitura — importar escreve arquivos no projeto).";
      return;
    }
    importando = true;
    try {
      const conteudo = await arq.text();
      const r: ResumoPack = await invokeSave("importar_pack", { conteudo, nome: arq.name }, 180000);
      resumo = r;
      impOk = r.erros.length === 0;
      impMsg = r.mensagem;
      // Listas mudaram no disco: recarrega tudo para a tela mostrar o novo dado.
      try {
        await useCards().loadAll();
        await useDuelists().reload();
        await useDecks().reload();
        await useFusions().reload();
        await useValidate().refresh();
      } catch (e2) {
        impMsg += ` (Recarregue a aba para ver os novos dados: ${errMsg(e2)})`;
      }
    } catch (e) {
      impMsg = errMsg(e);
    } finally {
      importando = false;
    }
  }

  let checklistOk = $derived(checkDuelo && checkCartas && checkDecks);

  function zipNome(): string {
    const plat = plataforma === "windows" ? "windows" : plataforma === "linux" ? "linux" : "android";
    return `MeuJogo-${plat}.zip`;
  }

  async function exportar() {
    msg = "";
    exportando = true;
    try {
      const r: { erros: number; avisos: number; itens: Item[]; mensagem: string } =
        await invokeSave("validar_projeto", {}, 120000);
      erros = r.erros;
      avisos = r.avisos;
      itens = r.itens ?? [];
      jaValidou = true;
      if (r.erros > 0) {
        ok = false;
        msg = `${r.mensagem} Corrija e clique em Exportar de novo.`;
        return;
      }
      if (!checklistOk) {
        ok = false;
        msg = `Projeto válido, mas marque o checklist "testou?" antes de exportar (falta ${[!checkDuelo && "jogar um duelo", !checkCartas && "validar as cartas", !checkDecks && "conferir os decks"].filter(Boolean).join(", ")}.`;
        return;
      }
      ok = true;
      msg = `✓ Validação OK para ${zipNome()} (${modo === "protegido" ? "Protegido, com cadeado" : "Aberto, para mods"}). ${r.mensagem} Empacotamento (.astralis + zip) vem depois — por ora nada foi empacotado nem baixado.`;
    } catch (e) {
      ok = false;
      msg = errMsg(e);
    } finally {
      exportando = false;
    }
  }
</script>

<div class="flex-1 min-h-0 overflow-y-auto flex flex-col items-center gap-3 p-2">
  <div class="w-full max-w-2xl rounded-2xl border border-zinc-800 bg-zinc-950/60 p-5">
    <div class="flex items-center gap-3">
      <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-sky-500 via-blue-600 to-indigo-600 flex items-center justify-center text-xl shrink-0">📥</span>
      <div>
        <h2 class="text-base font-black tracking-tight">IMPORTAR PACK</h2>
        <p class="text-[11px] text-zinc-500">Escolhe um .json pack: valida tudo antes, faz backup automático e SUBSTITUI o conteúdo do projeto (só dado, nada de jogo)</p>
      </div>
    </div>
    <input bind:this={arquivoPack} type="file" accept=".json,application/json" class="hidden" onchange={aoEscolherPack} />
    <button
      class="mt-3 w-full py-3 rounded-2xl bg-sky-600 hover:bg-sky-500 text-white text-sm font-bold shadow-lg shadow-sky-600/20 transition disabled:opacity-50"
      disabled={importando}
      onclick={abrirImportacao}
    >{importando ? "Validando e importando…" : "📥 Escolher pack (.json)…"}</button>
    {#if impMsg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {impOk ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{impMsg}</p>{/if}
    {#if resumo}
      <div class="mt-2 rounded-xl border border-zinc-800 divide-y divide-zinc-800/60 overflow-hidden">
        <div class="px-3 py-2 bg-zinc-900/40 text-xs">
          <span class="font-bold">{resumo.cartas} cartas, {resumo.duelistas} duelistas, {resumo.decks} decks, {resumo.fusoes_novas} fusões substituídos</span>{#if resumo.regras_novas}<span> (+ {resumo.regras_novas} regras)</span>{/if}
          {#if resumo.fusoes_puladas + resumo.regras_puladas}<span class="text-zinc-400"> • {resumo.fusoes_puladas + resumo.regras_puladas} repetidos do próprio pack (pulados)</span>{/if}
          {#if resumo.equips_ignorados}<span class="text-zinc-400"> • {resumo.equips_ignorados} equips ignorados (sem schema V1)</span>{/if}
        </div>
        {#if resumo.backups.length}
          <p class="px-3 py-2 text-[11px] text-zinc-400 bg-zinc-900/40">💾 backup em {resumo.backups.join(" • ")}</p>
        {/if}
        {#each resumo.avisos as av (av)}
          <p class="px-3 py-2 text-[11px] text-sky-300 bg-zinc-900/40">ℹ {av}</p>
        {/each}
        {#each resumo.erros as er (er)}
          <p class="px-3 py-2 text-[11px] text-rose-300 bg-zinc-900/40">✕ {er}</p>
        {/each}
      </div>
    {/if}
  </div>
  <div class="w-full max-w-2xl rounded-2xl border border-zinc-800 bg-zinc-950/60 p-5">
    <div class="flex items-center gap-3">
      <span class="w-11 h-11 rounded-2xl bg-gradient-to-br from-amber-500 via-orange-600 to-rose-600 flex items-center justify-center text-xl shrink-0">📦</span>
      <div>
        <h2 class="text-base font-black tracking-tight">EXPORTAR JOGO</h2>
        <p class="text-[11px] text-zinc-500">Valida tudo e prepara a caixa (videogame + fita) — empacotamento vem depois</p>
      </div>
    </div>

    <div class="mt-4 grid sm:grid-cols-2 gap-2">
      <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">PLATAFORMA</p>
        <div class="flex gap-1">
          {#each [["windows", "🪟 Windows"], ["linux", "🐧 Linux"], ["android", "🤖 Android"]] as [pid, plabel] (pid)}
            <button class="flex-1 py-2 rounded-lg text-xs font-medium border transition {plataforma === pid ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => plataforma = pid}>{plabel}</button>
          {/each}
        </div>
        <p class="mt-1.5 text-[11px] text-zinc-500 font-mono">{zipNome()}</p>
      </div>
      <div class="rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
        <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">MODO</p>
        <div class="flex gap-1">
          <button class="flex-1 py-2 rounded-lg text-xs font-medium border transition {modo === 'aberto' ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => modo = 'aberto'} title="Sem cadeado — bom para mods">🔓 Aberto</button>
          <button class="flex-1 py-2 rounded-lg text-xs font-medium border transition {modo === 'protegido' ? 'bg-white text-zinc-900 border-white' : 'bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-600'}" onclick={() => modo = 'protegido'} title="Com cadeado — padrão para distribuir">🔒 Protegido</button>
        </div>
        <p class="mt-1.5 text-[11px] text-zinc-500">{modo === 'protegido' ? "Fita trancada com chave do jogo (trava cópia casual)." : "Só compactado + assinado (bom para mods)."}</p>
      </div>
    </div>

    <div class="mt-2 rounded-xl border border-zinc-800 bg-zinc-900/60 p-3">
      <p class="text-[10px] tracking-widest text-zinc-500 font-semibold mb-1.5">CHECKLIST — "TESTOU A FITA?"</p>
      <div class="space-y-1.5">
        <label class="flex items-center gap-2 text-xs text-zinc-300 cursor-pointer">
          <input type="checkbox" bind:checked={checkDuelo} class="w-4 h-4 accent-emerald-600" /> Joguei um duelo de verdade na aba Duelo
        </label>
        <label class="flex items-center gap-2 text-xs text-zinc-300 cursor-pointer">
          <input type="checkbox" bind:checked={checkCartas} class="w-4 h-4 accent-emerald-600" /> Validei as cartas (selo "válido" no topo)
        </label>
        <label class="flex items-center gap-2 text-xs text-zinc-300 cursor-pointer">
          <input type="checkbox" bind:checked={checkDecks} class="w-4 h-4 accent-emerald-600" /> Conferi os decks (40 cartas cada)
        </label>
      </div>
    </div>

    <button
      class="mt-3 w-full py-3 rounded-2xl bg-amber-600 hover:bg-amber-500 text-white text-sm font-bold shadow-lg shadow-amber-600/20 transition disabled:opacity-50"
      disabled={exportando}
      onclick={exportar}
    >{exportando ? "Validando projeto…" : "⬆ Exportar"}</button>

    {#if msg}<p class="mt-2 text-xs rounded-lg px-3 py-2 border whitespace-pre-line {ok ? 'text-emerald-300 bg-emerald-950/30 border-emerald-900/50' : 'text-amber-300 bg-amber-950/30 border-amber-900/50'}">{msg}</p>{/if}

    {#if jaValidou && itens.length}
      <div class="mt-2 rounded-xl border border-zinc-800 divide-y divide-zinc-800/60 overflow-hidden">
        {#each itens as it (it.area)}
          <div class="px-3 py-2 flex items-center gap-2 bg-zinc-900/40">
            <span class="w-2 h-2 rounded-full shrink-0 {it.ok ? 'bg-emerald-500' : 'bg-rose-500'}"></span>
            <span class="text-xs font-bold">{it.area}</span>
            <span class="ml-auto text-[11px] text-zinc-400 text-right">{it.detalhe}</span>
          </div>
        {/each}
        {#if erros === 0}
          <p class="px-3 py-2 text-[11px] text-zinc-500 bg-zinc-900/40">⚠ Empacotamento (.astralis binário + zip com o player) vem depois — esta tela só valida, não empacota.</p>
        {/if}
      </div>
    {/if}
  </div>
</div>
