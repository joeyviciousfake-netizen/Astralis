<script lang="ts">
  // ValidationPanel — relatório do lint do PROJETO: valida cada carta
  // contra o card.schema.json (Rust). Erros travam o Jogar. Modal sobre
  // o header, com revalidar manual.
  import { useValidate } from "$lib/stores/validate.svelte";

  let { open, onclose }: { open: boolean; onclose: () => void } = $props();
  const v = useValidate();

  let onlyErrors = $state(false);
  let shown = $derived.by(() => {
    const list = v.report?.issues ?? [];
    const f = onlyErrors ? list.filter(i => i.level === "erro") : list;
    return f.slice(0, 100);
  });
  let hidden = $derived((v.report?.issues.length ?? 0) - shown.length);
</script>

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="fixed inset-0 z-30 bg-zinc-950/70 backdrop-blur-sm flex items-center justify-center p-4" onclick={onclose} onkeydown={(e)=> { if (e.key === "Escape") onclose(); }}>
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="rounded-2xl bg-zinc-900 border border-zinc-700 w-full max-w-lg max-h-[80vh] flex flex-col overflow-hidden" role="dialog" aria-modal="true" aria-label="Validação do projeto" tabindex="-1" onclick={(e)=> e.stopPropagation()}>
      <div class="px-4 py-3 border-b border-zinc-800 flex items-center gap-2">
        <span class="text-sm font-bold">Validação do projeto</span>
        {#if v.report}
          <span class="text-[10px] px-2 py-0.5 rounded-full {v.report.error_count ? 'bg-rose-500/15 border border-rose-500/50 text-rose-300' : 'bg-emerald-500/15 border border-emerald-500/50 text-emerald-300'} font-bold">{v.report.error_count} erros • {v.report.warning_count} avisos</span>
        {/if}
        <div class="ml-auto flex items-center gap-2">
          <label class="flex items-center gap-1.5 text-[11px] text-zinc-400">
            <input type="checkbox" bind:checked={onlyErrors} class="accent-rose-600" /> só erros
          </label>
          <button class="px-3 py-1 rounded-full bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-[11px]" disabled={v.loading} onclick={()=> v.refresh()}>{v.loading ? "Validando…" : "↻ Revalidar"}</button>
          <button class="text-zinc-500 hover:text-zinc-200 px-1" title="Fechar" aria-label="Fechar validação" onclick={onclose}>✕</button>
        </div>
      </div>
      <div class="flex-1 overflow-auto divide-y divide-zinc-800/70">
        {#if v.loading && !v.report}
          <p class="p-6 text-xs text-zinc-500 text-center">Validando projeto…</p>
        {:else}
          {#if v.report && !v.report.completo}
            <p class="px-4 py-2 text-[11px] text-zinc-400 text-center border-b border-zinc-800/70">Mapeando erros por carta… {Math.round(v.report.progresso * 100)}% (totais acima já valem)</p>
          {/if}
          {#if v.loadError}
          <p class="p-6 text-xs text-amber-300 text-center">Falha ao validar: {v.loadError}</p>
          {:else if shown.length === 0 && v.report?.completo}
            <div class="p-6 flex flex-col items-center gap-2 text-center">
              <div class="w-10 h-10 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-lg">✓</div>
              <p class="text-xs text-zinc-300 font-semibold">{onlyErrors ? "Nenhum erro — projeto pronto para jogar" : "Projeto íntegro — nada a reportar"}</p>
            </div>
          {:else if shown.length === 0}
            <p class="p-6 text-xs text-zinc-500 text-center">Nenhum erro mapeado até aqui…</p>
          {:else}
          {#each shown as issue (`${issue.system}|${issue.card_id ?? "-"}|${issue.message}`)}
            <div class="px-4 py-2 flex items-start gap-2.5">
              <span class="mt-0.5 shrink-0 text-[10px] px-1.5 py-0.5 rounded font-bold {issue.level === 'erro' ? 'bg-rose-500/15 text-rose-300 border border-rose-500/40' : 'bg-amber-500/15 text-amber-300 border border-amber-500/40'}">{issue.level === 'erro' ? 'ERRO' : 'AVISO'}</span>
              <div class="min-w-0">
                <p class="text-xs text-zinc-200 leading-snug">{issue.message}</p>
                <p class="text-[10px] text-zinc-500 font-mono">{issue.system}{issue.card_id ? ` • #${issue.card_id}` : ''}</p>
              </div>
            </div>
          {/each}
          {#if hidden > 0}
            <p class="p-3 text-center text-[11px] text-zinc-500">+ {hidden} ocorrências (as 100 primeiras acima)</p>
          {/if}
          {/if}
        {/if}
      </div>
      {#if v.report && v.report.error_count > 0}
        <p class="px-4 py-2.5 border-t border-zinc-800 text-[11px] text-rose-300 bg-rose-950/20">Jogar travado até zerar os erros.</p>
      {/if}
    </div>
  </div>
{/if}
