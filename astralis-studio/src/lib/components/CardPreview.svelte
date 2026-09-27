<script lang="ts">
  // CardPreview — carta estilo Yu-Gi-Oh (só visual, sem gameplay).
  // FUNDO = uma das 6 molduras JPG (static/frames/), escolhida pelo dado da
  // carta (ver escolherMoldura em cardMeta): Normal/Effect/Fusion/Ritual/
  // Spell/Trap. Proporção 813/1185 = 0,6861 (original 59x86).
  // Os campos ficam SOBRE os espaços da imagem, nas posições de MEDIDAS
  // (única fonte de medida: scan a pixel das molduras limpas 813x1185 +
  // refs Normal-card Dark Magician e Spell-card Messenger — ver tabela).
  // O molde (aba Molde / D36) continua vencendo quando a peça existir:
  // peça presente no molde sobrepõe o default; peça ausente = MEDIDAS puras.
  // Não há mais camada de correção por cima do default.
  // Preview PURO: não valida, não salva, não mexe em regra.
  import AssetDrop from "$lib/components/AssetDrop.svelte";
  import { attrName, frameSrc, linhaTipo, escolherMoldura, FRAME_LABELS, attributeIcon, STAR_IMG, arteDoProjeto, arteParaUrl } from "$lib/cardMeta";
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

  // ---- MEDIDAS (única fonte do default): scan a pixel das molduras limpas
  // 813x1185 (normal/spell/trap conferidos — geometria igual, desvio <2px)
  // + refs Normal-card (orbe/estrelas/ATK) e Spell-card (faixa). x/w em ‰ da
  // LARGURA (÷10 = %), y/h em ‰ da ALTURA, font_size em ‰ da ALTURA.
  // Placa título x26-794 y25-136 (texto dentro, até x664 p/ não invadir o
  // orbe); orbe ref x677-754 y52-128 (d~77px, só existe na ref — o frame
  // limpo não traz círculo); fileira y140-204 (7 estrelas ref x368-727 à
  // direita, d~40px; faixa magia centralizada na mesma fileira); arte cinza
  // útil x100-720 y220-836 (620x617, área DENTRO da borda azul); creme útil
  // x60-759 y899-1115 (dentro da borda laranja); tipo no topo do creme
  // y907; filete ATK ref y1078, texto y1080-1102 à direita até x753; rodapé
  // y1140-1170 (fundo bege entre creme e borda do cartão).
  // Conversão font_size ‰ → cqw (1% da largura): cqw = fs × 1185 ÷ 8130
  // (nome 38→5,54 = 45px; estrela 32→4,67 = 38px; texto 19→2,77 = 22px).
  type RectMolde = { x: number; y: number; w: number; h: number };
  type EstiloMolde = { font_size?: number; bold?: boolean; color?: string; align?: string; z?: number };
  const MEDIDAS: Record<string, { rect: RectMolde; style: EstiloMolde }> = {
    name: { rect: { x: 54, y: 27, w: 763, h: 78 }, style: { font_size: 38, bold: true, align: "left", z: 5 } },
    attribute_orb: { rect: { x: 833, y: 44, w: 95, h: 65 }, style: { z: 6 } },
    level_stars: { rect: { x: 34, y: 118, w: 886, h: 54 }, style: { font_size: 32, bold: false, align: "right", z: 5 } },
    art_window: { rect: { x: 123, y: 186, w: 764, h: 521 }, style: { z: 4 } },
    type_line: { rect: { x: 91, y: 765, w: 827, h: 27 }, style: { font_size: 22, bold: true, align: "left", z: 5 } },
    text_box: { rect: { x: 74, y: 759, w: 861, h: 183 }, style: { font_size: 19, bold: false, align: "left", z: 3 } },
    atkdef_bar: { rect: { x: 91, y: 911, w: 836, h: 20 }, style: { font_size: 24, bold: true, align: "right", z: 5 } },
    footer: { rect: { x: 34, y: 962, w: 931, h: 25 }, style: { font_size: 11, bold: false, align: "left", z: 5 } },
  };
  // Fusão em 2 camadas: default = MEDIDAS; peça presente no molde (aba Molde
  // / projects, D36) vence por campo. Sem molde = tudo MEDIDAS = fiel às refs.
  function pecaMolde(kind: string): { rect: RectMolde; style: EstiloMolde } {
    const def = MEDIDAS[kind] ?? { rect: { x: 0, y: 0, w: 0, h: 0 }, style: {} };
    const over = ((molde as Molde | null)?.pieces ?? []).find((p) => p.kind === kind) ?? {};
    return {
      rect: {
        ...def.rect,
        ...((over as { rect?: object }).rect ?? {}),
      } as RectMolde,
      style: {
        ...def.style,
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
  // Cor do nome: molde manda; sem cor no molde nem no default, usa branco
  // nas molduras escuras (magia/equip/armadilha, ref Messenger) e
  // marrom-escuro nos monstros (ref Dark Magician).
  function corNome(s: EstiloMolde): string {
    const doMolde = ((molde as Molde | null)?.pieces ?? []).find((p) => p.kind === "name")?.style?.color;
    if (typeof doMolde === "string" && doMolde) return doMolde;
    if (typeof s.color === "string" && s.color) return s.color;
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
  // relativo do projeto (assets/...) é lido via `ler_asset` (cache de sessão
  // no cardMeta.ts) — null enquanto carrega, com o placeholder cinza atual.
  let arteProjeto = $state<string | null>(null);
  $effect(() => {
    const a = (artwork ?? "").trim();
    if (!a.startsWith("assets/")) {
      arteProjeto = null;
      return;
    }
    arteProjeto = arteDoProjeto(a);
    if (!arteProjeto) {
      void arteParaUrl(a).then((url) => {
        if (url) arteProjeto = url;
      });
    }
  });
  let arteMostravel = $derived.by(() => {
    if (arteUrl) return arteUrl;
    const a = (artwork ?? "").trim();
    if (a.startsWith("data:image/") || a.startsWith("http://") || a.startsWith("https://")) return a;
    if (a.startsWith("assets/")) return arteProjeto;
    return null;
  });
  let caminhoCurto = $derived((artwork ?? "").trim());
</script>

<div class="w-full max-w-[320px] mx-auto" style="container-type: inline-size;">
  <!-- Carta segue a moldura original 832x1248 (D38 corrigida: molduras do
       usuário, sem edição). FUNDO = moldura JPG cobrindo tudo;
       campos por cima nas posições do molde. Fundo escuro só ao carregar. -->
  <div
    class="w-full relative overflow-hidden"
    style="aspect-ratio: 832 / 1248; border-radius: 2cqw; background: #1c130a; box-shadow: 0 10px 30px rgba(0,0,0,0.55);"
    title="Moldura: {FRAME_LABELS[moldura] ?? moldura}"
  >
    <img src={molduraSrc} alt="" aria-hidden="true" class="absolute inset-0 w-full h-full" style="object-fit: fill;" />
    <div class="absolute inset-0">
      <!-- Nome sobre a placa (só texto; a placa é da imagem). MEDIDAS: placa
           x26-794 y25-136, texto até x664 (não invade o orbe, que começa
           em x677). Monstro = preto; magia/armadilha = branco (refs). -->
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

      <!-- Orbe: PNG com kanji (static/attributes/). MEDIDAS da ref: x677-754
           y52-128 (d~77px, quadrado). Monstro = atributo; magia = SPELL;
           armadilha = TRAP. O frame limpo não traz círculo — o overlay é o
           selo, igual à ref Messenger of Peace. -->
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
           7, x368-727, d~40px). Magia/armadilha: faixa "[SPELL CARD ∞]" /
           "[TRAP CARD ∞]" centralizada na mesma fileira y140-204
           (ref Messenger). O frame limpo traz o vão vazio. -->
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

      <!-- Rodapé minúsculo (MEDIDAS y1140 h30): id à esquerda + © à direita. -->
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
