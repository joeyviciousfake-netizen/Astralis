<script lang="ts">
  // CardPreview — carta estilo Yu-Gi-Oh (só visual, sem gameplay).
  // FUNDO = uma das 6 molduras JPG (static/frames/), escolhida pelo dado da
  // carta (ver escolherMoldura em cardMeta): Normal/Effect/Fusion/Ritual/
  // Spell/Trap. Proporção 813/1185 = 0,6861 (original 59x86).
  // Os campos ficam SOBRE os espaços da imagem, nas posições do `molde`
  // (mesma fusão do jogo: peça ausente = default; sem molde = tudo default).
  // Default = scan das refs D23 (Normal-card Dark Magician + Spell-card
  // Messenger, 813x1185): nome 4,0/2,8/81x4,4 fs38; orbe x85/2,8 d9,2%L
  // (w90 h62 quadrado); estrelas y11,2 h4,2 d~4,7%L fs32; arte 9,5/16,8/
  // 81x55,6 quadrada; texto 5,5/73,5/89x21,5 fs19; tipo fs22; atk y91,5 h2,5
  // fs24 à direita abaixo do filete; rodapé 3,5/96/93x2,5 fs11. Magia/
  // armadilha sem selo impresso no frame → orbe SPELL/TRAP + faixa
  // "[SPELL CARD ∞]" / "[TRAP CARD ∞]" centralizada na fileira das estrelas.
  // Aba Molde continua valendo (D36): o dado manda — a correção abaixo é só
  // o default quando a peça falta; peça presente no molde vence.
  // Preview PURO: não valida, não salva, não mexe em regra.
  import AssetDrop from "$lib/components/AssetDrop.svelte";
  import { attrName, frameSrc, linhaTipo, escolherMoldura, FRAME_LABELS, attributeIcon, STAR_IMG } from "$lib/cardMeta";
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
  // Ritual também é monstro com nível (tem estrelas). Magia/equip/armadilha
  // não têm nível: no lugar das estrelas vai a faixa centralizada do tipo.
  let mostrarEstrelas = $derived(tipoCarta === "monster" || tipoCarta === "ritual");
  let mostrarFaixaMagia = $derived(tipoCarta === "spell" || tipoCarta === "equip" || tipoCarta === "trap");
  // Orbe: frames não trazem selo impresso, então o overlay mostra sempre —
  // monstro/ritual = atributo da carta; magia/equip = selo SPELL; armadilha
  // = selo TRAP (igual à ref Messenger of Peace, que tem o selo no canto).
  let iconeAtributo = $derived(
    tipoCarta === "spell" || tipoCarta === "equip"
      ? attributeIcon("spell")
      : tipoCarta === "trap"
        ? attributeIcon("trap")
        : attributeIcon(atributo),
  );
  let mostrarOrbe = $derived(!!iconeAtributo);
  // Faixa acima da arte nas magias/armadilhas: "[SPELL CARD ∞]" /
  // "[TRAP CARD ∞]" (ref Spell-card.jpg, centralizado, maiúsculas + infinito).
  let faixaMagia = $derived(tipoCarta === "trap" ? "[TRAP CARD ∞]" : "[SPELL CARD ∞]");
  // Nome branco nas molduras escuras (magia esmeralda / armadilha rosa),
  // preto nas claras (monstros âmbar / ritual azul) — igual às refs.
  let nomeClaro = $derived(tipoCarta === "spell" || tipoCarta === "trap" || tipoCarta === "equip");
  // Texto de monstro normal (sem efeito) é flavor em itálico (ref Dark
  // Magician: "The ultimate wizard..." entre aspas); com efeito/magia é reto.
  let textoItalico = $derived(tipoCarta === "monster" && !temEfeito && !ehFusao);

  let pedidoArte = $state(0);

  let estrelas = $derived(Math.min(12, Math.max(1, Math.floor(Number(nivel) || 1))));

  // ---- MOLDE (D23/D36): posição/tamanho/fonte/cor vêm do dado, não de
  // número fixo. Peça ausente no molde = default do scan das refs 813x1185
  // (CORRECAO abaixo, que ajusta o MOLDE_OFICIAL ainda com medidas do scan
  // antigo); peça presente no molde (aba Molde / projects) vence a correção.
  // Sem molde = tudo default corrigido = visual fiel às refs.
  // Conversões por-mil → tela: x/y/w/h em % do próprio eixo (÷10); font_size
  // em ‰ da ALTURA → cqw (1% da largura): cqw = fs × 1185 ÷ 8130 (nome 38→5,54).
  type RectMolde = { x: number; y: number; w: number; h: number };
  type EstiloMolde = { font_size?: number; bold?: boolean; color?: string; align?: string; z?: number };
  // Medidas % das refs (813x1185) → por-mil: barra título y2,8 h4,4 x4,0 w81
  // fs38; orbe x85 y2,8 w90 h62 (= quadrado 75px); estrelas y11,2 h4,2 d4,7%L
  // fs32; arte x9,5 y16,8 w81 h55,6 (quadrada 659px); texto x5,5 y73,5 w89
  // h21,5 fs19; tipo fs22; atk y91,5 h2,5 fs24; rodapé y96 h2,5 fs11.
  const CORRECAO: Record<string, { rect?: Partial<RectMolde>; style?: EstiloMolde }> = {
    name: { rect: { x: 40, y: 28, w: 810, h: 44 }, style: { font_size: 38, bold: true, align: "left", z: 5 } },
    attribute_orb: { rect: { x: 850, y: 28, w: 90, h: 62 }, style: { z: 6 } },
    level_stars: { rect: { x: 35, y: 112, w: 885, h: 42 }, style: { font_size: 32, bold: false, align: "right", z: 5 } },
    art_window: { rect: { x: 95, y: 168, w: 810, h: 556 }, style: { z: 4 } },
    type_line: { rect: { x: 95, y: 748, w: 810, h: 30 }, style: { font_size: 22, bold: true, align: "left", z: 5 } },
    text_box: { rect: { x: 55, y: 735, w: 890, h: 215 }, style: { font_size: 19, bold: false, align: "left", z: 3 } },
    atkdef_bar: { rect: { x: 95, y: 915, w: 810, h: 25 }, style: { font_size: 24, bold: true, align: "right", z: 5 } },
    footer: { rect: { x: 35, y: 960, w: 930, h: 25 }, style: { font_size: 11, bold: false, align: "left", z: 5 } },
  };
  function pecaMolde(kind: string): { rect: RectMolde; style: EstiloMolde } {
    const base = ((MOLDE_OFICIAL as unknown as Molde).pieces ?? []).find((p) => p.kind === kind) ?? {};
    const fix = CORRECAO[kind] ?? {};
    const over = ((molde as Molde | null)?.pieces ?? []).find((p) => p.kind === kind) ?? {};
    return {
      rect: {
        x: 0, y: 0, w: 0, h: 0,
        ...((base as { rect?: object }).rect ?? {}),
        ...(fix.rect ?? {}),
        ...((over as { rect?: object }).rect ?? {}),
      } as RectMolde,
      style: {
        ...((base as { style?: object }).style ?? {}),
        ...(fix.style ?? {}),
        ...((over as { style?: object }).style ?? {}),
      } as EstiloMolde,
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
    typeof s.font_size === "number" ? (s.font_size * 1185) / 8130 : padrao;
  const negrito = (s: EstiloMolde, padrao: boolean) =>
    typeof s.bold === "boolean" ? s.bold : padrao;
  // Cor do nome: molde manda, mas o default do scan antigo é escuro — nas
  // molduras escuras (magia/equip/armadilha) a ref é branca. Sem cor própria
  // no molde, usa branco nelas e marrom-escuro nos monstros.
  function corNome(s: EstiloMolde): string {
    const doMolde = ((molde as Molde | null)?.pieces ?? []).find((p) => p.kind === "name")?.style?.color;
    if (typeof doMolde === "string" && doMolde) return doMolde;
    if (typeof s.color === "string" && s.color.toLowerCase() !== "#2a1c08") return s.color;
    return nomeClaro ? "#ffffff" : "#2a1c08";
  }
  const corTxt = (s: EstiloMolde, padrao: string) =>
    typeof s.color === "string" ? s.color : padrao;
  const just = (s: EstiloMolde, padrao: string) => {
    const a = s.align ?? padrao;
    return a === "center" ? "center" : a === "right" ? "flex-end" : "flex-start";
  };
  const alinhTxt = (s: EstiloMolde, padrao: string) => (s.align ?? padrao) as string;

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
  <!-- Carta 813x1185 (0,6861 = 59/86). FUNDO = moldura JPG cobrindo tudo;
       campos por cima nas posições do molde. Fundo escuro só ao carregar. -->
  <div
    class="w-full relative overflow-hidden"
    style="aspect-ratio: 813 / 1185; border-radius: 2cqw; background: #1c130a; box-shadow: 0 10px 30px rgba(0,0,0,0.55);"
    title="Moldura: {FRAME_LABELS[moldura] ?? moldura}"
  >
    <img src={molduraSrc} alt="" aria-hidden="true" class="absolute inset-0 w-full h-full" style="object-fit: fill;" />
    <div class="absolute inset-0">
      <!-- Nome sobre a placa (só texto; a placa é da imagem). Ref: y2,8 h4,4
           x4,0 w81 — termina onde o orbe começa (x85), sem texto embaixo dele.
           Monstro = preto; magia/armadilha = branco (refs). -->
      <div class="absolute" style="left: {pc(pNome.rect.x)}; top: {pc(pNome.rect.y)}; width: {pc(pNome.rect.w)}; height: {pc(pNome.rect.h)};">
        <div
          class="w-full h-full overflow-hidden flex items-center"
          style="padding: 0.4cqw 1.5cqw 0.4cqw 2.4cqw; justify-content: {just(pNome.style, 'left')};"
        >
          <p
            class="truncate"
            style="font-family: Georgia, 'Times New Roman', serif; font-weight: {negrito(pNome.style, true) ? 700 : 400}; font-size: {fsCqw(pNome.style, 5.54)}cqw; color: {corNome(pNome.style)}; line-height: 1.15; letter-spacing: 0.02em;"
            title={nome || "(sem nome)"}
          >{(nome || "(sem nome)").toUpperCase()}</p>
        </div>
      </div>

      <!-- Orbe: PNG com kanji (static/attributes/). Ref: x85 y2,8 d9,2%L
           (quadrado). Monstro = atributo; magia = SPELL; armadilha = TRAP. -->
      {#if mostrarOrbe && iconeAtributo}
      <div
        class="absolute"
        style="left: {pc(pOrbe.rect.x)}; top: {pc(pOrbe.rect.y)}; width: {pc(pOrbe.rect.w)}; aspect-ratio: 1 / 1;"
        title="Atributo: {attrName(atributo)}"
      >
        <img src={iconeAtributo} alt="Atributo {attrName(atributo)}" class="w-full h-full" style="object-fit: contain; filter: drop-shadow(0 0.3cqw 0.3cqw rgba(0,0,0,0.45));" />
      </div>
      {/if}

      <!-- Estrelas = level (monstro/ritual, à direita — ref Dark Magician com
           7). Magia/armadilha: faixa "[SPELL CARD ∞]" / "[TRAP CARD ∞]"
           centralizada na mesma fileira (ref Messenger, y11,2 h4,2). -->
      {#if mostrarEstrelas}
      <div class="absolute flex items-center" style="left: {pc(pEstrelas.rect.x)}; right: {(1000 - pEstrelas.rect.x - pEstrelas.rect.w) / 10}%; top: {pc(pEstrelas.rect.y)}; height: {pc(pEstrelas.rect.h)}; gap: 0.8cqw; justify-content: {just(pEstrelas.style, 'right')};" title="Nível {estrelas}">
        {#each Array(estrelas) as _, i (i)}
          <img src={STAR_IMG} alt="★" style="height: {fsCqw(pEstrelas.style, 4.67)}cqw; aspect-ratio: 1 / 1; object-fit: contain;" />
        {/each}
      </div>
      {:else if mostrarFaixaMagia}
      <div class="absolute flex items-center justify-center" style="left: {pc(pEstrelas.rect.x)}; right: {(1000 - pEstrelas.rect.x - pEstrelas.rect.w) / 10}%; top: {pc(pEstrelas.rect.y)}; height: {pc(pEstrelas.rect.h)};" title={faixaMagia}>
        <p class="truncate" style="font-family: Georgia, 'Times New Roman', serif; font-weight: 700; font-size: {fsCqw(pEstrelas.style, 4.4)}cqw; color: #111111; line-height: 1.2; letter-spacing: 0.04em;">{faixaMagia}</p>
      </div>
      {/if}

      <!-- 5. Arte CRUA no quadrado: sem borda do editor (a moldura JPG já
           traz a borda cinza impressa). Só a imagem, cover. -->
      <button
        type="button"
        class="absolute overflow-hidden text-left transition"
        style="left: {pc(pArte.rect.x)}; top: {pc(pArte.rect.y)}; width: {pc(pArte.rect.w)}; height: {pc(pArte.rect.h)}; background: #101014; cursor: pointer; padding: 0; border: none;"
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
        {#if !esconderBorda}
        <span
          class="absolute"
          style="right: 1.6cqw; bottom: 1.4cqw; font-size: 3cqw; background: rgba(0,0,0,0.65); color: #fff; border-radius: 9999px; padding: 0.8cqw 2.2cqw; border: 0.3cqw solid rgba(255,255,255,0.35);"
        >✏️ trocar imagem</span>
        {/if}
      </button>

      <!-- Caixa de texto (pergaminho da imagem): monstro tem "[TIPO]" no topo
           (ref, maiúsculas) + descrição + ATK/DEF à direita abaixo do filete
           (só monstro — o filete é da moldura); magia tem só texto corrido
           (o tipo já está na faixa acima da arte — ref Messenger). -->
      <div
        class="absolute overflow-hidden"
        style="left: {pc(pTexto.rect.x)}; top: {pc(pTexto.rect.y)}; width: {pc(pTexto.rect.w)}; height: {pc(pTexto.rect.h)};"
      >
        <div class="w-full h-full flex flex-col" style="padding: 1.6cqw 3.2cqw 1.2cqw;">
          {#if !mostrarFaixaMagia}
          <p class="truncate" style="font-family: Georgia, 'Times New Roman', serif; font-weight: {negrito(pTipo.style, true) ? 700 : 400}; font-size: {fsCqw(pTipo.style, 3.21)}cqw; color: {corTxt(pTipo.style, '#2a1c08')}; line-height: 1.3; text-align: {alinhTxt(pTipo.style, 'left')};">{linhaTipo(tipoCarta, tipoMonstro, temEfeito).toUpperCase()}</p>
          {/if}
          <div class="w-full overflow-y-auto" style="flex: 1 1 auto; min-height: 0; margin-top: {mostrarFaixaMagia ? 0 : 0.8}cqw;">
            {#if (descricao ?? "").trim()}
              <p style="font-family: Georgia, 'Times New Roman', serif; {textoItalico ? 'font-style: italic;' : ''} font-size: {fsCqw(pTexto.style, 2.77)}cqw; color: {corTxt(pTexto.style, '#2a1c08')}; line-height: 1.4; white-space: pre-line; text-align: {alinhTxt(pTexto.style, 'left')};">{(descricao ?? "").trim()}</p>
            {:else}
              <p style="font-family: Georgia, 'Times New Roman', serif; font-style: italic; font-size: {fsCqw(pTexto.style, 2.77)}cqw; color: #8a7a55; line-height: 1.4;">(sem texto — comum no pack FM)</p>
            {/if}
          </div>
          {#if ehMonstro}
          <div style="margin-top: 0.6cqw;">
            <p style="font-family: Georgia, 'Times New Roman', serif; font-weight: {negrito(pAtk.style, true) ? 700 : 400}; font-size: {fsCqw(pAtk.style, 3.5)}cqw; color: {corTxt(pAtk.style, '#2a1c08')}; line-height: 1.2; text-align: {alinhTxt(pAtk.style, 'right')};">ATK/{atk} DEF/{def}</p>
          </div>
          {/if}
        </div>
      </div>

      <!-- Rodapé minúsculo (ref: y96 h2,5): id à esquerda + © à direita. -->
      <div class="absolute flex items-center justify-between" style="left: {pc(pRodape.rect.x)}; right: {(1000 - pRodape.rect.x - pRodape.rect.w) / 10}%; top: {pc(pRodape.rect.y)}; height: {pc(pRodape.rect.h)};">
        <p class="truncate" style="font-size: {fsCqw(pRodape.style, 1.6)}cqw; font-family: ui-monospace, monospace; color: {corTxt(pRodape.style, '#ffffff')}cc;" title={idCarta}>{idCarta || "···"}</p>
        <p style="font-size: {fsCqw(pRodape.style, 1.6)}cqw; color: {corTxt(pRodape.style, '#ffffff')}99; white-space: nowrap;">© ASTRALIS</p>
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
