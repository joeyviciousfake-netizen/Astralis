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

// Mesma paleta do FM-Studio por tipo: monstro âmbar, magia esmeralda, trap rosa.
export function cardTypeBg(t: string): string {
  if (t === "spell") return "bg-gradient-to-br from-emerald-600 via-teal-600 to-emerald-700 border-emerald-600";
  if (t === "trap") return "bg-gradient-to-br from-rose-600 via-pink-600 to-rose-700 border-rose-600";
  if (t === "equip") return "bg-gradient-to-br from-sky-600 via-blue-600 to-sky-700 border-sky-600";
  if (t === "ritual") return "bg-gradient-to-br from-violet-600 via-purple-600 to-violet-700 border-violet-600";
  return "bg-gradient-to-br from-amber-600 via-yellow-600 to-amber-700 border-amber-600";
}
