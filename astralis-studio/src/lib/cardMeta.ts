// Nomes PT-BR dos campos de carta + fundo por tipo.
// Só o que existe no schemas/card.schema.json (R4) — extensão FM inclusa
// (equip/ritual, 6 tipos novos, estrelas/senha/starchips: só dado, sem regra).
export const TYPE_NAMES: Record<string, string> = {
  monster: "Monstro",
  spell: "Magia",
  trap: "Armadilha",
  equip: "Equipamento",
  ritual: "Ritual",
};

export function typeName(t: string): string { return TYPE_NAMES[t] ?? t; }

export const MONSTER_TYPES: Array<{ id: string; name: string }> = [
  { id: "dragon", name: "Dragão" },
  { id: "spellcaster", name: "Mago" },
  { id: "warrior", name: "Guerreiro" },
  { id: "beast", name: "Fera" },
  { id: "aqua", name: "Aquático" },
  { id: "rock", name: "Pedra" },
  { id: "pyro", name: "Fogo" },
  { id: "thunder", name: "Trovão" },
  { id: "plant", name: "Planta" },
  { id: "zombie", name: "Zumbi" },
  { id: "fairy", name: "Fada" },
  { id: "insect", name: "Inseto" },
  { id: "machine", name: "Máquina" },
  { id: "fiend", name: "Demônio" },
  { id: "beast-warrior", name: "Fera Guerreira" },
  { id: "winged-beast", name: "Besta Alada" },
  { id: "dinosaur", name: "Dinossauro" },
  { id: "reptile", name: "Réptil" },
  { id: "sea-serpent", name: "Serpente Marinha" },
  { id: "fish", name: "Peixe" },
];

export function monsterTypeName(id: string): string {
  return MONSTER_TYPES.find((m) => m.id === id)?.name ?? id;
}

export const ATTRIBUTES: Array<{ id: string; name: string }> = [
  { id: "light", name: "Luz" },
  { id: "dark", name: "Trevas" },
  { id: "fire", name: "Fogo" },
  { id: "water", name: "Água" },
  { id: "earth", name: "Terra" },
  { id: "wind", name: "Vento" },
  { id: "divine", name: "Divino" },
];

export function attrName(id: string): string {
  return ATTRIBUTES.find((a) => a.id === id)?.name ?? id;
}

// Estrelas guardiãs FM (schemas/rule 11): só dado, o jogo ignora na mesa V1.
// Vazio = sem estrela (N/A na fonte).
export const GUARDIAN_STARS: Array<{ id: string; name: string }> = [
  { id: "sun", name: "Sol" },
  { id: "moon", name: "Lua" },
  { id: "mars", name: "Marte" },
  { id: "jupiter", name: "Júpiter" },
  { id: "mercury", name: "Mercúrio" },
  { id: "venus", name: "Vênus" },
  { id: "saturn", name: "Saturno" },
  { id: "uranus", name: "Urano" },
  { id: "neptune", name: "Netuno" },
  { id: "pluto", name: "Plutão" },
];

export function starName(id: string): string {
  return GUARDIAN_STARS.find((s) => s.id === id)?.name ?? id;
}

// Molduras padrão da carta (D23): as 6 JPGs 813x1185 viram o fundo do
// CardPreview, no lugar do desenho CSS antigo. Os arquivos versionados ficam
// em static/frames/ (o que o navegador/WebView mostra); a cópia de dados
// fica em projects/default/assets/frames/ (sobrevive ao boot D29, que só
// limpa assets/cards|portraits|backgrounds). Só visual (R1/R4): a escolha é
// pelo dado da carta, nada de regra.
// Mesma paleta do FM-Studio por tipo: monstro âmbar, magia esmeralda, trap rosa.
export function cardTypeBg(t: string): string {
  if (t === "spell") return "bg-gradient-to-br from-emerald-600 via-teal-600 to-emerald-700 border-emerald-600";
  if (t === "trap") return "bg-gradient-to-br from-rose-600 via-pink-600 to-rose-700 border-rose-600";
  if (t === "equip") return "bg-gradient-to-br from-sky-600 via-blue-600 to-sky-700 border-sky-600";
  if (t === "ritual") return "bg-gradient-to-br from-violet-600 via-purple-600 to-violet-700 border-violet-600";
  return "bg-gradient-to-br from-amber-600 via-yellow-600 to-amber-700 border-amber-600";
}

// ---- Molduras (fundo-imagem do CardPreview) ----
// Chave = moldura; valor = caminho servido pelo app (static/frames/).
export const FRAMES: Record<string, string> = {
  normal: "/frames/normal.jpg",
  effect: "/frames/effect.jpg",
  fusion: "/frames/fusion.jpg",
  ritual: "/frames/ritual.jpg",
  spell: "/frames/spell.jpg",
  trap: "/frames/trap.jpg",
};

export const FRAME_LABELS: Record<string, string> = {
  normal: "Monstro normal",
  effect: "Monstro com efeito",
  fusion: "Monstro de fusão",
  ritual: "Monstro de ritual",
  spell: "Magia",
  trap: "Armadilha",
};

// Escolha da moldura pelo dado da carta (automática, sem estado de sessão):
// magia/equipamento → magia (equipamento é magia de equipamento, sem moldura
// própria); armadilha → armadilha; ritual → ritual; monstro de fusão →
// fusão; monstro com efeito → efeito; resto → normal.
export function escolherMoldura(tipoCarta: string, temEfeito: boolean, ehFusao: boolean): string {
  if (tipoCarta === "spell" || tipoCarta === "equip") return "spell";
  if (tipoCarta === "trap") return "trap";
  if (tipoCarta === "ritual") return "ritual";
  if (ehFusao) return "fusion";
  if (temEfeito) return "effect";
  return "normal";
}

export function frameSrc(tipoCarta: string, temEfeito: boolean, ehFusao: boolean): string {
  return FRAMES[escolherMoldura(tipoCarta, temEfeito, ehFusao)] ?? FRAMES.normal;
}

// Linha de tipo que aparece na caixa de texto da carta.
export function linhaTipo(tipoCarta: string, tipoMonstro: string, temEfeito: boolean): string {
  if (tipoCarta === "spell") return "[Magia]";
  if (tipoCarta === "trap") return "[Armadilha]";
  if (tipoCarta === "equip") return "[Equipamento]";
  if (tipoCarta === "ritual") return `[${monsterTypeName(tipoMonstro)}/Ritual]`;
  return `[${monsterTypeName(tipoMonstro)}/${temEfeito ? "Efeito" : "Normal"}]`;
}

// ---- Atributo / estrela / verso padrão (D23) ----
// PNGs circulares com kanji em static/attributes|estrelas|backs (versionado,
// o que o navegador/WebView mostra); a cópia de dados fica em
// projects/default/assets/attributes|estrelas|backs (padrão frames/:
// sobrevive ao boot D29, que só limpa assets/cards|portraits|backgrounds).
// Só visual (R1/R4): a escolha é pelo dado da carta, nada de regra.
// Orbe = imagem do atributo da carta; atributo vazio/desconhecido = sem orbe
// (fallback: esconder, nunca inventar um).
export const ATTRIBUTE_ICONS: Record<string, string> = {
  light: "/attributes/light.png",
  dark: "/attributes/dark.png",
  fire: "/attributes/fire.png",
  water: "/attributes/water.png",
  earth: "/attributes/earth.png",
  wind: "/attributes/wind.png",
  divine: "/attributes/divine.png",
  spell: "/attributes/spell.png",
  trap: "/attributes/trap.png",
};

export function attributeIcon(id: string): string | null {
  const a = (id ?? "").trim().toLowerCase();
  return ATTRIBUTE_ICONS[a] ?? null;
}

// ---- Arte do projeto (só exibe dado, R1/R4) ----
// O CardPreview mostrava placeholder cinza para `artwork: assets/...` porque
// o navegador/WebView não abre caminho relativo do projeto. O resolvedor lê
// via comando Tauri `ler_asset` (só abaixo de projects/default/assets/) e
// guarda a data URL pronta num Map de sessão (cada arte é lida UMA vez).
// `data:`/`http` continuam diretos; caminho relativo volta null até carregar
// (o placeholder atual cobre esse meio-tempo). Nada de gameplay aqui.
import { invokeLoad } from "$lib/stores/ipc";

// Data URL pronta por caminho (sessão): assets/fm/card_0001.png -> data:...
const cacheArteProjeto = new Map<string, string>();
// Leitura em voo por caminho (duas cartas com a mesma arte dividem 1 invoke).
const arteEmVoo = new Map<string, Promise<string | null>>();

// Leitura do cache (síncrona): o que já foi lido volta na hora.
export function arteDoProjeto(caminho: string): string | null {
  return cacheArteProjeto.get((caminho ?? "").trim()) ?? null;
}

// Resolve `artwork` para URL mostrável: direto se já for URL, via `ler_asset`
// (1x por caminho, com cache) se for assets/..., null se não der para mostrar.
export function arteParaUrl(caminho: string): Promise<string | null> {
  const a = (caminho ?? "").trim();
  if (!a) return Promise.resolve(null);
  if (a.startsWith("data:image/") || a.startsWith("http://") || a.startsWith("https://")) {
    return Promise.resolve(a);
  }
  if (!a.startsWith("assets/")) return Promise.resolve(null);
  const pronta = cacheArteProjeto.get(a);
  if (pronta) return Promise.resolve(pronta);
  const voo = arteEmVoo.get(a);
  if (voo) return voo;
  const p = invokeLoad<{ dados_base64: string; mime: string }>("ler_asset", { caminho: a }).then(
    (r) => {
      const mime = (r?.mime || "image/png").trim() || "image/png";
      const url = `data:${mime};base64,${r.dados_base64}`;
      cacheArteProjeto.set(a, url);
      arteEmVoo.delete(a);
      return url as string | null;
    },
    () => {
      arteEmVoo.delete(a);
      return null;
    },
  );
  arteEmVoo.set(a, p);
  return p;
}

// Nível = esta bola laranja repetida N vezes (sem desenho CSS).
export const STAR_IMG = "/estrelas/estrela.png";

// Verso padrão da carta. Campo `card_back` OPCIONAL na carta:
// vazio/ausente = este padrão.
export const CARD_BACK_DEFAULT = "/backs/verso_padrao.png";
