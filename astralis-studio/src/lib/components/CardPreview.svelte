<script lang="ts">
  // CardPreview — carta de MONSTRO estilo Yu-Gi-Oh (só visual, sem gameplay).
  // Proporção oficial 59mm x 86mm (~0.686): só a proporção, não o tamanho.
  // Medidas do scan real (Blue-Eyes 813x1200, W=100 H=100, topo=%H, lados=%W):
  // moldura borda escura ~1,2% / nome top 3,5% h6,5% laterais 3,5% / orbe
  // diam 9%W centro x91% top 3% / estrelas top 11,5% diam 6,5%W à direita
  // até x92% / arte quadrada top 16,5% lat 9→91% (82%W=56,3%H) / texto
  // top 74% bottom 95% lat 6→94% / rodapé 96→98,5%.
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

  const ORBE: Record<string, { kanji: string; en: string; fundo: string }> = {
    light: { kanji: "光", en: "LIGHT", fundo: "radial-gradient(circle at 35% 30%, #fff7cc, #f5b301 60%, #8a5a00)" },
    dark: { kanji: "闇", en: "DARK", fundo: "radial-gradient(circle at 35% 30%, #d8b4fe, #6d28d9 60%, #2e1065)" },
    fire: { kanji: "炎", en: "FIRE", fundo: "radial-gradient(circle at 35% 30%, #fecaca, #dc2626 60%, #450a0a)" },
    water: { kanji: "水", en: "WATER", fundo: "radial-gradient(circle at 35% 30%, #bae6fd, #0284c7 60%, #082f49)" },
    earth: { kanji: "地", en: "EARTH", fundo: "radial-gradient(circle at 35% 30%, #fde68a, #b45309 60%, #451a03)" },
    wind: { kanji: "風", en: "WIND", fundo: "radial-gradient(circle at 35% 30%, #bbf7d0, #16a34a 60%, #052e16)" },
    divine: { kanji: "神", en: "DIVINE", fundo: "radial-gradient(circle at 35% 30%, #ffffff, #eab308 60%, #713f12)" },
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
  <!-- Carta: proporção oficial 59/86. Palco absoluto em % da carta
       (topo=%H, lados=%W). Moldura item 1: borda escura fina ~1,2%W
       (border) + respiro interno ~3% (conteúdo começa em 3,5%+). -->
  <div
    class="w-full relative overflow-hidden"
    style="aspect-ratio: 59 / 86; border-radius: 4.5cqw; background: {MOLDURA[acab].fundo}; border: 1.2cqw solid #1c130a; box-shadow: 0 10px 30px rgba(0,0,0,0.55), inset 0 0 0 0.6cqw {MOLDURA[acab].brilho};"
  >
    <div class="absolute inset-0">
      <!-- 2. Barra de nome: top 3,5% H, altura 6,5% H, laterais 3,5% W.
           Serifada negrito marrom, ~3,8%H; bege claro com relevo.
           Padding direito reserva o orbe (centro x91%). -->
      <div class="absolute" style="left: 3.5%; top: 3.5%; width: 93%; height: 6.5%;">
        <div
          class="w-full h-full overflow-hidden flex items-center"
          style="background: linear-gradient(180deg, #f7ead0, #e9d3a3); border-radius: 1.6cqw; border: 0.5cqw solid #3d2a12; box-shadow: inset 0 0.4cqw 1cqw rgba(90, 60, 20, 0.45), inset 0 -0.4cqw 0.8cqw rgba(255,255,255,0.5); padding: 0.4cqw 10cqw 0.4cqw 2.4cqw;"
        >
          <p
            class="truncate"
            style="font-family: Georgia, 'Times New Roman', serif; font-weight: 700; font-size: 5.4cqw; color: #2a1c08; line-height: 1.15;"
            title={nome || "(sem nome)"}
          >{nome || "(sem nome)"}</p>
        </div>
      </div>

      <!-- 3. Orbe de atributo: diâmetro 9%W, centro x≈91% (left 86,5%),
           top ≈3%H sobrepondo a barra; kanji + rótulo pequeno em cima. -->
      <div
        class="absolute flex flex-col items-center justify-center"
        style="left: 86.5%; top: 3%; width: 9%; aspect-ratio: 1 / 1; border-radius: 9999px; background: {orbe.fundo}; border: 0.6cqw solid #2a1c08; box-shadow: 0 0.5cqw 1.5cqw rgba(0,0,0,0.5);"
        title="Atributo: {attrName(atributo)}"
      >
        <span style="font-size: 1.4cqw; line-height: 1; color: #fff; opacity: 0.9; font-weight: 700; letter-spacing: 0.02em;">{orbe.en}</span>
        <span style="font-size: 4.2cqw; line-height: 1.05; color: #fff; text-shadow: 0 0.2cqw 0.4cqw rgba(0,0,0,0.6);">{orbe.kanji}</span>
      </div>

      <!-- 4. Estrelas: fileira top ≈11,5%H, cada ★ ~6,5%W, grupo à
           DIREITA terminando em x≈92% (right 8%). N = level do dado. -->
      <div class="absolute flex items-center justify-end" style="left: 3.5%; right: 8%; top: 11.5%; gap: 0.6cqw;" title="Nível {estrelas}">
        {#each Array(estrelas) as _, i (i)}
          <span style="font-size: 6.5cqw; line-height: 1; color: #ff9d0a; text-shadow: 0 0 1cqw rgba(255,157,10,0.8), 0 0.3cqw 0.6cqw rgba(0,0,0,0.6);">★</span>
        {/each}
      </div>

      <!-- 5. Arte QUADRADA: top 16,5%H, laterais 9%→91% (largura 82%W),
           altura igual (82%W ≈56,3%H, termina ~72,8%). Moldura metálica
           ~1,2%W (border) + fio escuro interno (overlay). Cover. -->
      <button
        type="button"
        class="absolute overflow-hidden text-left transition"
        style="left: 9%; top: 16.5%; width: 82%; aspect-ratio: 1 / 1; border-radius: 1.2cqw; border: 1.2cqw solid #8a7d64; background: #101014; cursor: pointer; padding: 0;"
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
          class="absolute pointer-events-none"
          style="inset: 0; box-shadow: inset 0 0 0 0.4cqw #1a1208;"
        ></span>
        <span
          class="absolute"
          style="right: 1.6cqw; bottom: 1.4cqw; font-size: 3cqw; background: rgba(0,0,0,0.65); color: #fff; border-radius: 9999px; padding: 0.8cqw 2.2cqw; border: 0.3cqw solid rgba(255,255,255,0.35);"
        >✏️ trocar imagem</span>
      </button>

      <!-- 6. Caixa de texto: top ≈74%, bottom ≈95% (h 21%), lat 6%→94%.
           Pergaminho; quadradinhos vermelhos ~2%W nos 4 cantos; tipo
           negrito ~2,2%H; texto ~2%H; divisória; ATK/DEF ~2,6%H à direita. -->
      <div
        class="absolute overflow-hidden"
        style="left: 6%; top: 74%; width: 88%; height: 21%; background: linear-gradient(180deg, #f7ead0, #efdcb2); border-radius: 1.2cqw; border: 0.5cqw solid #3d2a12; box-shadow: inset 0 0 2cqw rgba(90, 60, 20, 0.35);"
      >
        <span class="absolute" style="left: 0.8cqw; top: 0.8cqw; width: 2cqw; height: 2cqw; background: #b91c1c; border: 0.3cqw solid #7f1d1d; border-radius: 0.3cqw;"></span>
        <span class="absolute" style="right: 0.8cqw; top: 0.8cqw; width: 2cqw; height: 2cqw; background: #b91c1c; border: 0.3cqw solid #7f1d1d; border-radius: 0.3cqw;"></span>
        <span class="absolute" style="left: 0.8cqw; bottom: 0.8cqw; width: 2cqw; height: 2cqw; background: #b91c1c; border: 0.3cqw solid #7f1d1d; border-radius: 0.3cqw;"></span>
        <span class="absolute" style="right: 0.8cqw; bottom: 0.8cqw; width: 2cqw; height: 2cqw; background: #b91c1c; border: 0.3cqw solid #7f1d1d; border-radius: 0.3cqw;"></span>
        <div class="w-full h-full flex flex-col" style="padding: 1.8cqw 3.4cqw 1.4cqw;">
          <p class="truncate" style="font-family: Georgia, 'Times New Roman', serif; font-weight: 700; font-size: 3.2cqw; color: #2a1c08; line-height: 1.3;">[{monsterTypeName(tipoMonstro)}/{temEfeito ? "Efeito" : "Normal"}]</p>
          <div class="w-full overflow-y-auto" style="flex: 1 1 auto; min-height: 0; margin-top: 0.8cqw;">
            {#if (descricao ?? "").trim()}
              <p style="font-family: Georgia, 'Times New Roman', serif; font-size: 2.9cqw; color: #2a1c08; line-height: 1.4; white-space: pre-line;">{(descricao ?? "").trim()}</p>
            {:else}
              <p style="font-family: Georgia, 'Times New Roman', serif; font-style: italic; font-size: 2.9cqw; color: #8a7a55; line-height: 1.4;">(sem texto — comum no pack FM)</p>
            {/if}
          </div>
          <div style="border-top: 0.3cqw solid #3d2a12; margin-top: 1cqw; padding-top: 0.8cqw;">
            <p class="text-right" style="font-family: Georgia, 'Times New Roman', serif; font-weight: 700; font-size: 3.8cqw; color: #2a1c08; line-height: 1.2;">ATK/{atk} DEF/{def}</p>
          </div>
        </div>
      </div>

      <!-- 7. Microtexto de rodapé: 96→98,5%H (top 96% h 2,5%),
           nº da carta à esquerda + copyright à direita, minúsculo. -->
      <div class="absolute flex items-center justify-between" style="left: 3.5%; right: 3.5%; top: 96%; height: 2.5%;">
        <p class="truncate" style="font-size: 1.9cqw; font-family: ui-monospace, monospace; color: rgba(255,255,255,0.8);" title={idCarta}>{idCarta || "···"}</p>
        <p style="font-size: 1.9cqw; color: rgba(255,255,255,0.6); white-space: nowrap;">© ASTRALIS</p>
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
