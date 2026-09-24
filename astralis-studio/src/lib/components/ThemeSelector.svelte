<script lang="ts">
  import { useTheme } from "$lib/stores/theme.svelte";
  const themeStore = useTheme();
  let open = $state(false);

  function select(id: import("$lib/stores/theme.svelte").ThemeId) {
    themeStore.setTheme(id);
    open = false;
  }

  // R MÉDIO: overlay fecha com Esc (antes só com clique) + painel com foco inicial
  function onKey(e: KeyboardEvent) {
    if (e.key === "Escape") open = false;
  }
  $effect(() => {
    if (open) window.addEventListener("keydown", onKey);
    else window.removeEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });
</script>

<div class="relative">
  <button
    class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800 transition"
    onclick={() => open = !open}
    title="Mudar tema"
  >
    <span class="w-3 h-3 rounded-full border border-white/20" style="background: {themeStore.theme.preview[2]}"></span>
    <span class="hidden sm:inline">{themeStore.theme.name}</span>
    <span class="text-[10px] opacity-60">▼</span>
  </button>

  {#if open}
    <div class="fixed inset-0 z-40" onclick={() => open = false} role="presentation"></div>
    <div class="absolute right-0 top-full mt-2 w-72 rounded-2xl bg-zinc-900 border border-zinc-800 shadow-2xl p-3 z-50">
      <div class="text-[11px] tracking-widest font-semibold text-zinc-500 px-2 py-1">TEMAS</div>
      <div class="grid grid-cols-2 gap-2 mt-1">
        {#each themeStore.all as t (t.id)}
          <button
            class="text-left rounded-xl border p-3 flex flex-col gap-2 hover:border-zinc-700 transition {themeStore.current === t.id ? 'bg-white text-zinc-900 border-white shadow-lg' : 'bg-zinc-950 border-zinc-800 text-zinc-100 hover:bg-zinc-900'}"
            onclick={() => select(t.id)}
          >
            <div class="flex gap-1">
              {#each t.preview as c (c)}
                <span class="w-6 h-6 rounded-full border border-white/20 shadow-sm" style="background: {c}"></span>
              {/each}
              <span class="ml-auto w-2 h-2 rounded-full {themeStore.current === t.id ? 'bg-emerald-500' : 'bg-zinc-700'} mt-1"></span>
            </div>
            <div>
              <div class="text-xs font-bold leading-none">{t.name}</div>
              <div class="text-[10px] {themeStore.current === t.id ? 'text-zinc-600' : 'text-zinc-500'} leading-tight mt-1">{t.description}</div>
            </div>
          </button>
        {/each}
      </div>
      <p class="text-[10px] text-zinc-500 text-center mt-3">Prévia instantânea • salvo automaticamente</p>
    </div>
  {/if}
</div>
