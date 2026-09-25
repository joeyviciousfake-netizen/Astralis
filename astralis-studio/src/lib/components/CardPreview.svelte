<script lang="ts">
  // CardPreview — carta de MONSTRO estilo Yu-Gi-Oh (só visual, sem gameplay).
  // Proporção oficial 59mm x 86mm (~0.686): só a proporção, não o tamanho.
  // Barra de nome + orbe de atributo, estrelas = level, janela da arte com
  // moldura (clicar abre o seletor de imagem existente), linha de tipo, caixa
  // de efeito (description), barra ATK/DEF e número embaixo.
  // Preview PURO: não valida, não salva, não mexe em regra. A arte que o
  // usuário escolhe entra no fluxo existente (importar_asset → campo artwork
  // → botão Salvar da tela). A borda/acabamento é SÓ visualização da sessão
  // (não salva na carta: não há campo de borda no contrato — ver retorno).
  import AssetDrop from "$lib/components/AssetDrop.svelte";
  import { monsterTypeName, attrName } from "$lib/cardMeta";

  type Acabamento = "classica" | "efeito" | "fusao";

  let {
    nome = "",
    idCarta = "",
    tipoMonstro = "warrior",
    atributo = "earth",
    nivel = 1,
    descricao = "",
    atk = 0,
    def = 0,
    temEfeito = false,
    artwork = "",
    arteUrl = null,
    sugestaoArte = "arte",
    aoImportarArte = null,
    aoArquivoArte = null,
  }: {
    nome?: string;
    idCarta?: string;
    tipoMonstro?: string;
    atributo?: string;
    nivel?: number;
    descricao?: string;
    atk?: number;
    def?: number;
    temEfeito?: boolean;
    artwork?: string;
    arteUrl?: string | null;
    sugestaoArte?: string;
    aoImportarArte?: ((caminho: string) => void) | null;
    aoArquivoArte?: ((f: File) => void) | null;
  } = $props();

  // Acabamento da borda: automático pelo dado (com efeito = laranja, sem
  // efeito = marrom clássica), a pessoa pode trocar só para visualizar.
  // Não salva: é estado local da sessão.
  let acabamento = $state<Acabamento | null>(null);
  $effect(() => {
    void idCarta;
    acabamento = null;
  });
  let auto: Acabamento = $derived(temEfeito ? "efeito" : "classica");
  let acab: Acabamento = $derived(acabamento ?? auto);

  let pedidoArte = $state(0);

  let estrelas = $derived(Math.min(12, Math.max(1, Math.floor(Number(nivel) || 1))));

  const ORBE: Record<string, { icone: string; fundo: string }> = {
    light: { icone: "☀", fundo: "radial-gradient(circle at 35% 30%, #fff7cc, #f5b301 60%, #8a5a00)" },
    dark: { icone: "🌙", fundo: "radial-gradient(circle at 35% 30%, #d8b4fe, #6d28d9 60%, #2e1065)" },
    fire: { icone: "🔥", fundo: "radial-gradient(circle at 35% 30%, #fecaca, #dc2626 60%, #450a0a)" },
    water: { icone: "💧", fundo: "radial-gradient(circle at 35% 30%, #bae6fd, #0284c7 60%, #082f49)" },
    earth: { icone: "⛰", fundo: "radial-gradient(circle at 35% 30%, #fde68a, #b45309 60%, #451a03)" },
    wind: { icone: "🌀", fundo: "radial-gradient(circle at 35% 30%, #bbf7d0, #16a34a 60%, #052e16)" },
    divine: { icone: "✨", fundo: "radial-gradient(circle at 35% 30%, #ffffff, #eab308 60%, #713f12)" },
  };
  let orbe = $derived(ORBE[atributo] ?? ORBE.earth);

  const MOLDURA: Record<Acabamento, { rotulo: string; fundo: string; brilho: string }> = {
    classica: {
      rotulo: "Clássica marrom",
      fundo: "linear-gradient(135deg, #5b3410 0%, #c98f4a 22%, #8a5a2b 45%, #e8c07a 68%, #5b3410 100%)",
      brilho: "rgba(232, 192, 122, 0.55)",
    },
    efeito: {
      rotulo: "Efeito laranja",
      fundo: "linear-gradient(135deg, #7c2d12 0%, #e08a3c 22%, #a35a1e 45%, #f5c06a 68%, #7c2d12 100%)",
      brilho: "rgba(245, 192, 106, 0.55)",
    },
    fusao: {
      rotulo: "Fusão roxa",
      fundo: "linear-gradient(135deg, #2a1042 0%, #7b3fc4 22%, #4b2180 45%, #b78df0 68%, #2a1042 100%)",
      brilho: "rgba(183, 141, 240, 0.55)",
    },
  };

  const ACABAMENTOS: Acabamento[] = ["classica", "efeito", "fusao"];

  // Arte de verdade só quando dá para mostrar sem inventar caminho: imagem
  // local recém-escolhida (arteUrl) ou URL pronta (http/data). Caminho
  // relativo do projeto (assets/...) não abre no navegador — aí é placeholder
  // cinza com o caminho escrito (igual ao resto do Studio).
  let arteMostravel = $derived.by(() => {
    if (arteUrl) return arteUrl;
    const a = (artwork ?? "").trim();
    if (a.startsWith("data:image/") || a.startsWith("http://") || a.startsWith("https://")) return a;
    return null;
  });
  let caminhoCurto = $derived((artwork ?? "").trim());
</script>

<div class="w-full max-w-[320px] mx-auto" style="container-type: inline-size;">
  <!-- Carta: proporção oficial 59/86 -->
  <div
    class="w-full overflow-hidden"
    style="aspect-ratio: 59 / 86; border-radius: 4.5cqw; background: {MOLDURA[acab].fundo}; padding: 3.2cqw; box-shadow: 0 10px 30px rgba(0,0,0,0.55), inset 0 0 0 0.6cqw {MOLDURA[acab].brilho};"
  >
    <div class="w-full h-full flex flex-col" style="gap: 1.8cqw;">
      <!-- Barra de nome + orbe de atributo -->
      <div class="relative shrink-0 flex items-center" style="padding-right: 9cqw;">
        <div
          class="w-full overflow-hidden"
          style="background: linear-gradient(180deg, #f7ead0, #e9d3a3); border-radius: 1.6cqw; border: 0.5cqw solid #3d2a12; box-shadow: inset 0 0 2cqw rgba(90, 60, 20, 0.45); padding: 1.2cqw 2.4cqw;"
        >
          <p
            class="truncate"
            style="font-family: Georgia, 'Times New Roman', serif; font-weight: 700; font-size: 4.4cqw; color: #2a1c08; line-height: 1.25;"
            title={nome || "(sem nome)"}
          >{nome || "(sem nome)"}</p>
        </div>
        <div
          class="absolute flex items-center justify-center"
          style="right: 0; top: 50%; translate: 0 -50%; width: 9.5cqw; height: 9.5cqw; border-radius: 9999px; background: {orbe.fundo}; border: 0.6cqw solid #2a1c08; box-shadow: 0 0.5cqw 1.5cqw rgba(0,0,0,0.5); font-size: 4.6cqw;"
          title="Atributo: {attrName(atributo)}"
        >{orbe.icone}</div>
      </div>

      <!-- Estrelas de nível -->
      <div class="shrink-0 flex items-center justify-end" style="gap: 0.8cqw; min-height: 4.6cqw;" title="Nível {estrelas}">
        {#each Array(estrelas) as _, i (i)}
          <span style="font-size: 4.2cqw; line-height: 1; color: #ff9d0a; text-shadow: 0 0 1cqw rgba(255,157,10,0.8), 0 0.3cqw 0.6cqw rgba(0,0,0,0.6);">★</span>
        {/each}
      </div>

      <!-- Janela da arte (clica e troca) -->
      <button
        type="button"
        class="relative w-full overflow-hidden text-left transition"
        style="flex: 1 1 34%; min-height: 0; border-radius: 1.2cqw; border: 1.2cqw solid #3d2a12; outline: 0.5cqw solid {MOLDURA[acab].brilho}; background: #101014; cursor: pointer;"
        onclick={() => { pedidoArte += 1; }}
        title="Clique para trocar a imagem (abre o seletor de PNG)"
        aria-label="Trocar imagem da carta"
      >
        {#if arteMostravel}
          <img src={arteMostravel} alt="Arte da carta {nome}" class="absolute inset-0 w-full h-full" style="object-fit: cover;" />
        {:else}
          <span class="absolute inset-0 flex flex-col items-center justify-center" style="gap: 1cqw; background: radial-gradient(circle at 50% 40%, #3f3f46, #18181b 75%); padding: 2cqw;">
            <span style="font-size: 9cqw; line-height: 1; filter: grayscale(1); opacity: 0.6;">🖼</span>
            {#if caminhoCurto}
              <span class="truncate" style="max-width: 100%; font-size: 2.8cqw; font-family: ui-monospace, monospace; color: #a1a1aa;" title={caminhoCurto}>{caminhoCurto}</span>
            {:else}
              <span style="font-size: 3cqw; color: #a1a1aa;">sem arte (cinza automático)</span>
            {/if}
          </span>
        {/if}
        <span
          class="absolute"
          style="right: 1.6cqw; bottom: 1.4cqw; font-size: 3cqw; background: rgba(0,0,0,0.65); color: #fff; border-radius: 9999px; padding: 0.8cqw 2.2cqw; border: 0.3cqw solid rgba(255,255,255,0.35);"
        >✏️ trocar imagem</span>
      </button>

      <!-- Linha de tipo -->
      <div class="shrink-0" style="background: linear-gradient(180deg, #f7ead0, #e9d3a3); border-radius: 1.2cqw; border: 0.5cqw solid #3d2a12; padding: 1cqw 2.4cqw;">
        <p class="truncate" style="font-family: Georgia, 'Times New Roman', serif; font-size: 3.4cqw; color: #2a1c08; line-height: 1.3;">[{monsterTypeName(tipoMonstro)}/{temEfeito ? "Efeito" : "Normal"}]</p>
      </div>

      <!-- Caixa de texto de efeito -->
      <div class="w-full overflow-y-auto" style="flex: 1 1 26%; min-height: 0; background: linear-gradient(180deg, #f7ead0, #efdcb2); border-radius: 1.2cqw; border: 0.5cqw solid #3d2a12; box-shadow: inset 0 0 2cqw rgba(90, 60, 20, 0.35); padding: 1.6cqw 2.4cqw;">
        {#if (descricao ?? "").trim()}
          <p style="font-family: Georgia, 'Times New Roman', serif; font-size: 3.2cqw; color: #2a1c08; line-height: 1.45; white-space: pre-line;">{(descricao ?? "").trim()}</p>
        {:else}
          <p style="font-family: Georgia, 'Times New Roman', serif; font-style: italic; font-size: 3.2cqw; color: #8a7a55; line-height: 1.45;">(sem texto — comum no pack FM)</p>
        {/if}
      </div>

      <!-- Barra ATK/DEF -->
      <div class="shrink-0 flex items-center justify-end" style="background: linear-gradient(180deg, #f7ead0, #e9d3a3); border-radius: 1.2cqw; border: 0.5cqw solid #3d2a12; padding: 1cqw 2.4cqw; gap: 3cqw;">
        <p style="font-family: Georgia, 'Times New Roman', serif; font-weight: 700; font-size: 4cqw; color: #2a1c08; line-height: 1.2;">ATK/{atk} DEF/{def}</p>
      </div>

      <!-- Número embaixo -->
      <div class="shrink-0 flex items-center justify-between" style="padding: 0 1cqw;">
        <p class="truncate" style="font-size: 2.6cqw; font-family: ui-monospace, monospace; color: rgba(255,255,255,0.75);" title={idCarta}>{idCarta || "···"}</p>
        <p style="font-size: 2.6cqw; color: rgba(255,255,255,0.55);">Nv {estrelas} • {attrName(atributo)}</p>
      </div>
    </div>
  </div>

  <!-- Acabamento da borda (só visualização, não salva) -->
  <div class="mt-2 rounded-xl border border-zinc-800 bg-zinc-900/60" style="padding: 2.5cqw 3cqw;">
    <p style="font-size: 3.4cqw; letter-spacing: 0.12em;" class="tracking-widest text-zinc-500 font-semibold">BORDA — SÓ VISUALIZAÇÃO (NÃO SALVA)</p>
    <div class="flex" style="gap: 1.5cqw; margin-top: 1.5cqw;">
      {#each ACABAMENTOS as a (a)}
        <button
          type="button"
          class="flex-1 rounded-lg border transition"
          style="padding: 1.6cqw 1cqw; font-size: 3.2cqw; font-weight: 600; {(acabamento ?? auto) === a ? 'background: #fff; color: #18181b; border-color: #fff;' : 'background: #09090b; color: #a1a1aa; border-color: #3f3f46;'}"
          onclick={() => { acabamento = a; }}
          title={a === auto ? `${MOLDURA[a].rotulo} (automática pelo dado)` : MOLDURA[a].rotulo}
        >{MOLDURA[a].rotulo}{a === auto ? " • auto" : ""}</button>
      {/each}
    </div>
    <!-- Seletor de imagem escondido: abre quando a pessoa clica na arte -->
    <AssetDrop
      tipo="carta"
      sugestao={sugestaoArte}
      value={artwork}
      escondido
      acionar={pedidoArte}
      onimport={aoImportarArte}
      onarquivo={aoArquivoArte}
    />
  </div>
</div>
