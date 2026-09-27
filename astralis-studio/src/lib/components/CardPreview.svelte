<script lang="ts">
  // CardPreview — carta estilo Yu-Gi-Oh (só visual, sem gameplay).
  // FUNDO = uma das 6 molduras JPG 813x1185 (static/frames/), escolhida pelo
  // dado da carta (ver escolherMoldura em cardMeta): Normal/Effect/Fusion/
  // Ritual/Spell/Trap. Proporção 813/1185 ≈ 59/86 (oficial).
  // Os campos (nome, estrelas=level, arte clicável, tipo, descrição, ATK/DEF,
  // atributo) ficam posicionados SOBRE os espaços da imagem, nas posições do
  // `molde` (mesma fusão do jogo: peça ausente = default do scan); sem molde
  // = tudo default. Aba Molde continua valendo (D36): só o fundo mudou, o
  // desenho CSS antigo (gradientes + botões de borda) foi removido.
  // Preview PURO: não valida, não salva, não mexe em regra. A arte que o
  // usuário escolhe entra no fluxo existente (importar_asset → campo artwork
  // → botão Salvar da tela).
  import AssetDrop from "$lib/components/AssetDrop.svelte";
  import { attrName, frameSrc, linhaTipo, escolherMoldura, FRAME_LABELS } from "$lib/cardMeta";
  import MOLDE_OFICIAL from "../../../../schemas/examples/layouts/card_layout_monster_default.json";
  import type { Molde } from "$lib/stores/layout.svelte";

  let {
    nome = "",
    idCarta = "",
    tipoCarta = "monster",
    tipoMonstro = "warrior",
    atributo = "earth",
    nivel = 1,
    descricao = "",
    atk = 0,
    def = 0,
    temEfeito = false,
    ehFusao = false,
    artwork = "",
    arteUrl = null,
    sugestaoArte = "arte",
    aoImportarArte = null,
    aoArquivoArte = null,
    molde = null,
    esconderBorda = false,
  }: {
    nome?: string;
    idCarta?: string;
    tipoCarta?: string;
    tipoMonstro?: string;
    atributo?: string;
    nivel?: number;
    descricao?: string;
    atk?: number;
    def?: number;
    temEfeito?: boolean;
    ehFusao?: boolean;
    artwork?: string;
    arteUrl?: string | null;
    sugestaoArte?: string;
    aoImportarArte?: ((caminho: string) => void) | null;
    aoArquivoArte?: ((f: File) => void) | null;
    molde?: Molde | null;
    esconderBorda?: boolean;
  } = $props();

  // Moldura-imagem de fundo, só pelo dado (sem botão de troca: o fundo padrão
  // é fixo por tipo). Magia/equip → magia; armadilha → armadilha; ritual →
  // ritual; monstro de fusão → fusão; com efeito → efeito; resto → normal.
  let moldura = $derived(escolherMoldura(tipoCarta, temEfeito, ehFusao));
  let molduraSrc = $derived(frameSrc(tipoCarta, temEfeito, ehFusao));
  let ehMonstro = $derived(tipoCarta === "monster" || tipoCarta === "ritual");
  // Orbe de atributo e estrelas só existem nas molduras de monstro (as de
  // magia/armadilha têm o próprio selo impresso na imagem).
  let mostrarOrbe = $derived(ehMonstro);
  let mostrarEstrelas = $derived(tipoCarta === "monster");

  let pedidoArte = $state(0);

  let estrelas = $derived(Math.min(12, Math.max(1, Math.floor(Number(nivel) || 1))));

  // ---- MOLDE (D23): posição/tamanho/fonte/cor vêm do dado, não de número
  // fixo. Peça ausente no molde = default do scan (mesma fusão do jogo em
  // card_layout.gd). Sem molde (uso antigo) = tudo default = visual idêntico.
  // Conversões por-mil → tela: x/y/w/h em % do próprio eixo (÷10); font_size
  // em ‰ da ALTURA → cqw (1% da largura): cqw = fs × 86 ÷ 590 (nome 37→5,39).
  type RectMolde = { x: number; y: number; w: number; h: number };
  type EstiloMolde = { font_size?: number; bold?: boolean; color?: string; align?: string; z?: number };
  function pecaMolde(kind: string): { rect: RectMolde; style: EstiloMolde } {
    const base = ((MOLDE_OFICIAL as unknown as Molde).pieces ?? []).find((p) => p.kind === kind) ?? {};
    const over = ((molde as Molde | null)?.pieces ?? []).find((p) => p.kind === kind) ?? {};
    return {
      rect: { x: 0, y: 0, w: 0, h: 0, ...((base as { rect?: object }).rect ?? {}), ...((over as { rect?: object }).rect ?? {}) } as RectMolde,
      style: { ...((base as { style?: object }).style ?? {}), ...((over as { style?: object }).style ?? {}) } as EstiloMolde,
    };
  }
  let pNome = $derived(pecaMolde("name"));
  let pOrbe = $derived(pecaMolde("attribute_orb"));
  let pEstrelas = $derived(pecaMolde("level_stars"));
  let pArte = $derived(pecaMolde("art_window"));
  let pTipo = $derived(pecaMolde("type_line"));
  let pTexto = $derived(pecaMolde("text_box"));
  let pAtk = $derived(pecaMolde("atkdef_bar"));
  let pRodape = $derived(pecaMolde("footer"));
  const pc = (v: number) => `${v / 10}%`;
  const fsCqw = (s: EstiloMolde, padrao: number) =>
    typeof s.font_size === "number" ? (s.font_size * 86) / 590 : padrao;
  const negrito = (s: EstiloMolde, padrao: boolean) =>
    typeof s.bold === "boolean" ? s.bold : padrao;
  const corTxt = (s: EstiloMolde, padrao: string) =>
    typeof s.color === "string" ? s.color : padrao;
  const just = (s: EstiloMolde, padrao: string) => {
    const a = s.align ?? padrao;
    return a === "center" ? "center" : a === "right" ? "flex-end" : "flex-start";
  };
  const alinhTxt = (s: EstiloMolde, padrao: string) => (s.align ?? padrao) as string;

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
  <!-- Carta: proporção 813/1185 das molduras (≈ 59/86 oficial). O FUNDO é a
       moldura JPG (img cobrindo a carta toda); os campos ficam por cima, nas
       posições do molde. Fundo escuro sólido só enquanto a imagem carrega. -->
  <div
    class="w-full relative overflow-hidden"
    style="aspect-ratio: 59 / 86; border-radius: 4.5cqw; background: #1c130a; box-shadow: 0 10px 30px rgba(0,0,0,0.55);"
    title="Moldura: {FRAME_LABELS[moldura] ?? moldura}"
  >
    <img src={molduraSrc} alt="" aria-hidden="true" class="absolute inset-0 w-full h-full" style="object-fit: fill;" />
    <div class="absolute inset-0">
      <!-- 2. Nome: texto sobre a placa da moldura (a placa desenhada é a
           da própria imagem; aqui só o texto, sem caixa). Posição do molde;
           padding direito reserva o orbe. -->
      <div class="absolute" style="left: {pc(pNome.rect.x)}; top: {pc(pNome.rect.y)}; width: {pc(pNome.rect.w)}; height: {pc(pNome.rect.h)};">
        <div
          class="w-full h-full overflow-hidden flex items-center"
          style="padding: 0.4cqw 10cqw 0.4cqw 2.4cqw; justify-content: {just(pNome.style, 'left')};"
        >
          <p
            class="truncate"
            style="font-family: Georgia, 'Times New Roman', serif; font-weight: {negrito(pNome.style, true) ? 700 : 400}; font-size: {fsCqw(pNome.style, 5.4)}cqw; color: {corTxt(pNome.style, '#2a1c08')}; line-height: 1.15;"
            title={nome || "(sem nome)"}
          >{nome || "(sem nome)"}</p>
        </div>
      </div>

      <!-- 3. Orbe de atributo: só nas molduras de monstro (magia/armadilha
           têm o próprio selo impresso na imagem). Posição vem do molde. -->
      {#if mostrarOrbe}
      <div
        class="absolute flex flex-col items-center justify-center"
        style="left: {pc(pOrbe.rect.x)}; top: {pc(pOrbe.rect.y)}; width: {pc(pOrbe.rect.w)}; aspect-ratio: 1 / 1; border-radius: 9999px; background: {orbe.fundo}; border: 0.6cqw solid #2a1c08; box-shadow: 0 0.5cqw 1.5cqw rgba(0,0,0,0.5);"
        title="Atributo: {attrName(atributo)}"
      >
        <span style="font-size: 1.4cqw; line-height: 1; color: #fff; opacity: 0.9; font-weight: 700; letter-spacing: 0.02em;">{orbe.en}</span>
        <span style="font-size: 4.2cqw; line-height: 1.05; color: #fff; text-shadow: 0 0.2cqw 0.4cqw rgba(0,0,0,0.6);">{orbe.kanji}</span>
      </div>
      {/if}

      <!-- 4. Estrelas = level do dado. Só em monstro normal/efeito/fusão
           (ritual/magia/armadilha não têm nível no dado V1). -->
      {#if mostrarEstrelas}
      <div class="absolute flex items-center" style="left: {pc(pEstrelas.rect.x)}; right: {(1000 - pEstrelas.rect.x - pEstrelas.rect.w) / 10}%; top: {pc(pEstrelas.rect.y)}; height: {pc(pEstrelas.rect.h)}; gap: 0.6cqw; justify-content: {just(pEstrelas.style, 'right')};" title="Nível {estrelas}">
        {#each Array(estrelas) as _, i (i)}
          <span style="font-size: {fsCqw(pEstrelas.style, 6.5)}cqw; line-height: 1; color: {corTxt(pEstrelas.style, '#ff9d0a')}; text-shadow: 0 0 1cqw rgba(255,157,10,0.8), 0 0.3cqw 0.6cqw rgba(0,0,0,0.6);">★</span>
        {/each}
      </div>
      {/if}

      <!-- 5. Arte QUADRADA: top 16,5%H, laterais 9%→91% (largura 82%W),
           altura igual (82%W ≈56,3%H, termina ~72,8%). Moldura metálica
           ~1,2%W (border) + fio escuro interno (overlay). Cover. -->
      <button
        type="button"
        class="absolute overflow-hidden text-left transition"
        style="left: {pc(pArte.rect.x)}; top: {pc(pArte.rect.y)}; width: {pc(pArte.rect.w)}; height: {pc(pArte.rect.h)}; border-radius: 1.2cqw; border: 1.2cqw solid #8a7d64; background: #101014; cursor: pointer; padding: 0;"
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
        {#if !esconderBorda}
        <span
          class="absolute"
          style="right: 1.6cqw; bottom: 1.4cqw; font-size: 3cqw; background: rgba(0,0,0,0.65); color: #fff; border-radius: 9999px; padding: 0.8cqw 2.2cqw; border: 0.3cqw solid rgba(255,255,255,0.35);"
        >✏️ trocar imagem</span>
        {/if}
      </button>

      <!-- 6. Caixa de texto sobre o espaço da imagem: linha de tipo (varia
           com o tipo da carta), descrição e ATK/DEF (só monstro). Posições
           do molde; a caixa desenhada em CSS saiu — o pergaminho agora é a
           própria moldura JPG. -->
      <div
        class="absolute overflow-hidden"
        style="left: {pc(pTexto.rect.x)}; top: {pc(pTexto.rect.y)}; width: {pc(pTexto.rect.w)}; height: {pc(pTexto.rect.h)};"
      >
        <div class="w-full h-full flex flex-col" style="padding: 1.8cqw 3.4cqw 1.4cqw;">
          <p class="truncate" style="font-family: Georgia, 'Times New Roman', serif; font-weight: {negrito(pTipo.style, true) ? 700 : 400}; font-size: {fsCqw(pTipo.style, 3.2)}cqw; color: {corTxt(pTipo.style, '#2a1c08')}; line-height: 1.3; text-align: {alinhTxt(pTipo.style, 'left')};">{linhaTipo(tipoCarta, tipoMonstro, temEfeito)}</p>
          <div class="w-full overflow-y-auto" style="flex: 1 1 auto; min-height: 0; margin-top: 0.8cqw;">
            {#if (descricao ?? "").trim()}
              <p style="font-family: Georgia, 'Times New Roman', serif; font-size: {fsCqw(pTexto.style, 2.9)}cqw; color: {corTxt(pTexto.style, '#2a1c08')}; line-height: 1.4; white-space: pre-line; text-align: {alinhTxt(pTexto.style, 'left')};">{(descricao ?? "").trim()}</p>
            {:else}
              <p style="font-family: Georgia, 'Times New Roman', serif; font-style: italic; font-size: {fsCqw(pTexto.style, 2.9)}cqw; color: #8a7a55; line-height: 1.4;">(sem texto — comum no pack FM)</p>
            {/if}
          </div>
          {#if ehMonstro}
          <div style="border-top: 0.3cqw solid #3d2a12; margin-top: 1cqw; padding-top: 0.8cqw;">
            <p style="font-family: Georgia, 'Times New Roman', serif; font-weight: {negrito(pAtk.style, true) ? 700 : 400}; font-size: {fsCqw(pAtk.style, 3.8)}cqw; color: {corTxt(pAtk.style, '#2a1c08')}; line-height: 1.2; text-align: {alinhTxt(pAtk.style, 'right')};">ATK/{atk} DEF/{def}</p>
          </div>
          {/if}
        </div>
      </div>

      <!-- 7. Microtexto de rodapé: 96→98,5%H (top 96% h 2,5%),
           nº da carta à esquerda + copyright à direita, minúsculo. -->
      <div class="absolute flex items-center justify-between" style="left: {pc(pRodape.rect.x)}; right: {(1000 - pRodape.rect.x - pRodape.rect.w) / 10}%; top: {pc(pRodape.rect.y)}; height: {pc(pRodape.rect.h)};">
        <p class="truncate" style="font-size: {fsCqw(pRodape.style, 1.9)}cqw; font-family: ui-monospace, monospace; color: {corTxt(pRodape.style, '#ffffff')}cc;" title={idCarta}>{idCarta || "···"}</p>
        <p style="font-size: {fsCqw(pRodape.style, 1.9)}cqw; color: {corTxt(pRodape.style, '#ffffff')}99; white-space: nowrap;">© ASTRALIS</p>
      </div>
    </div>
  </div>

  <!-- Seletor de imagem escondido: abre quando a pessoa clica na arte
       (mesmo fluxo importar_asset de antes). -->
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
