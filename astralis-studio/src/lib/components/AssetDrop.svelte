<script lang="ts">
  // AssetDrop — arrastar PNG para carta/duelista/cena (doc 09/14).
  // Importa o arquivo para projects/default/assets/... via comando Rust importar_asset
  // e devolve o caminho para referenciar no dado. Sem arte, quem mostra é um
  // placeholder cinza automático (quem usa este componente desenha o cinza).
  // Erros sempre em PT-BR dizendo onde clicar.
  import { invokeSave, errMsg } from "$lib/stores/ipc";

  let {
    tipo,
    sugestao = "arte",
    value = "",
    rotulo = "Arraste um PNG aqui ou clique para escolher",
    onimport = null,
  }: {
    tipo: "carta" | "duelista" | "cena";
    sugestao?: string;
    value?: string;
    rotulo?: string;
    onimport?: ((caminho: string) => void) | null;
  } = $props();

  let arrastando = $state(false);
  let msg = $state("");
  let ok = $state(false);
  let enviando = $state(false);
  let inputEl: HTMLInputElement | null = $state(null);

  function emTauri(): boolean {
    return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
  }

  function nomeBase(sug: string): string {
    const base = sug.trim().toLowerCase().replace(/\s+/g, "_").replace(/[^a-z0-9_]/g, "");
    return base.replace(/^[^a-z]+/, "") || (tipo === "carta" ? "arte_carta" : tipo === "duelista" ? "arte_retrato" : "arte_fundo");
  }

  async function enviarArquivo(f: File) {
    msg = "";
    if (!emTauri()) {
      ok = false;
      msg = "Para importar, abra o app pelo app.bat (no navegador dá só para ver).";
      return;
    }
    if (f.type !== "image/png" && !f.name.toLowerCase().endsWith(".png")) {
      ok = false;
      msg = "Só vale PNG. Converta a imagem para .png e arraste de novo.";
      return;
    }
    if (f.size > 5 * 1024 * 1024) {
      ok = false;
      msg = "PNG muito grande (limite 5 MB). Comprima a imagem e tente de novo.";
      return;
    }
    enviando = true;
    try {
      const buf = new Uint8Array(await f.arrayBuffer());
      let bin = "";
      const passo = 8192;
      for (let i = 0; i < buf.length; i += passo) {
        bin += String.fromCharCode(...buf.subarray(i, i + passo));
      }
      const res: { file?: string; mensagem?: unknown } = await invokeSave("importar_asset", {
        pedido: { nome: nomeBase(sugestao), tipo, dados_base64: btoa(bin) },
      });
      ok = true;
      msg = String(res?.mensagem ?? "Imagem importada");
      if (res?.file) onimport?.(res.file);
    } catch (e) {
      ok = false;
      msg = errMsg(e);
    } finally {
      enviando = false;
    }
  }

  function aoSoltar(e: DragEvent) {
    e.preventDefault();
    arrastando = false;
    const f = e.dataTransfer?.files?.[0];
    if (f) void enviarArquivo(f);
  }
</script>

<div
  role="button"
  tabindex="0"
  aria-label={rotulo}
  class="rounded-xl border border-dashed px-3 py-2.5 text-center transition cursor-pointer {arrastando ? 'border-violet-500 bg-violet-600/10' : 'border-zinc-700 bg-zinc-950 hover:border-zinc-500'}"
  ondragover={(e) => { e.preventDefault(); arrastando = true; }}
  ondragleave={() => { arrastando = false; }}
  ondrop={aoSoltar}
  onclick={() => inputEl?.click()}
  onkeydown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); inputEl?.click(); } }}
>
  {#if value}
    <p class="text-[11px] font-mono text-zinc-400 truncate" title={value}>🖼 {value}</p>
    <p class="mt-0.5 text-[10px] text-zinc-600">{enviando ? "enviando…" : "arraste outro PNG para trocar, ou clique"}</p>
  {:else}
    <p class="text-xs text-zinc-400">{enviando ? "enviando…" : rotulo}</p>
    <p class="mt-0.5 text-[10px] text-zinc-600">PNG até 5 MB • vira cinza automático se faltar</p>
  {/if}
</div>
<!-- Seletor de arquivo: tem que estar RENDERIZADO, só invisível.
     O `class="hidden"` do Tailwind é display:none, e existem versões de
     WebView2 em que input.click() num input com display:none NÃO abre o
     diálogo (sintoma: cliquei e nada aconteceu). Este padrão (1px,
     opacity 0, pointer-events none) continua invisível para o usuário e
     funciona em todos os WebView2; tabindex/aria-hidden tiram o input
     invisível do tab order (a div visível é o controle).
     NÃO voltar para display:none.
     E fica FORA da div de propósito: input.click() dispara um evento de
     clique que sobe até os ancestrais, e a div é clicável (chama click()
     de novo) — dentro dela isso vira reentrada. Como a div chama
     `inputEl?.click()` e o input é irmão dela, o caminho é de mão única. -->
<input
  bind:this={inputEl}
  type="file"
  accept="image/png,.png"
  class="fixed left-0 top-0 h-px w-px opacity-0 pointer-events-none"
  tabindex="-1"
  aria-hidden="true"
  onchange={(e) => { const f = (e.target as HTMLInputElement).files?.[0]; if (f) void enviarArquivo(f); (e.target as HTMLInputElement).value = ""; }}
/>
{#if msg}<p class="mt-1 text-[11px] {ok ? 'text-emerald-300' : 'text-amber-300'}">{msg}</p>{/if}
