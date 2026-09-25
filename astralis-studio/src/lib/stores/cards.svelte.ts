import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import snapshot from "../../generated/cards-snapshot.json";

// Carta Astralis (schemas/card.schema.json): o MESMO dado que o jogo lê.
// Só o que o Astralis sabe executar (R4) — extensão FM inclusa como dado
// (estrelas/senha/starchips: o jogo ignora na mesa V1, sem regra nova).
export type Card = {
  file?: string;
  schema_version?: number;
  id: string;
  name: string;
  description?: string;
  artwork?: string;
  card_type: string;
  monster_type?: string;
  attribute?: string;
  level?: number;
  attack?: number;
  defense?: number;
  guardian_star_1?: string;
  guardian_star_2?: string;
  password?: string;
  starchip_cost?: number;
  effects?: string[];
  tags?: string[];
};

export type CardTypeGroup = "monster" | "spell" | "trap" | "equip" | "ritual";

export function typeGroupOf(t: string): CardTypeGroup {
  if (t === "spell") return "spell";
  if (t === "trap") return "trap";
  if (t === "equip") return "equip";
  if (t === "ritual") return "ritual";
  return "monster";
}

export type CardFilters = {
  types: CardTypeGroup[];
  attrs: string[];
  atkMin: number | null; atkMax: number | null;
  defMin: number | null; defMax: number | null;
};

export const EMPTY_FILTERS: CardFilters = {
  types: [], attrs: [],
  atkMin: null, atkMax: null,
  defMin: null, defMax: null,
};

export type CartaArquivo = { file: string; data: Card };

// Busca cartas: app Tauri (comando listar_cartas) ou snapshot gerado
// (navegador / fallback). Mesma ordem dos dois lados.
export async function fetchCartas(): Promise<Card[]> {
  try {
    const res = await invokeLoad<CartaArquivo[]>("listar_cartas");
    return res.map((c) => ({ ...c.data, file: c.file }));
  } catch {
    const snap = snapshot as { cards?: CartaArquivo[] };
    return (snap.cards ?? []).map((c) => ({ ...c.data, file: c.file }));
  }
}

function emTauri(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

let cards = $state<Card[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);
// Fase do carregamento para a tela mostrar progresso real ("Lendo 762
// cartas…") em vez de "Carregando…" infinito. loadMs guarda quanto o último
// boot da lista levou (para provar a abertura em segundos).
let fase = $state<string | null>(null);
let loadMs = $state(0);
let filter = $state("");
let sortBy = $state<"id" | "atk" | "def">("id");
let selectedId = $state<string | null>(null);
let generation = $state(0);
let filters = $state<CardFilters>({ ...EMPTY_FILTERS, types: [], attrs: [] });
let indexCache: { arr: Card[]; map: Map<string, Card> } | null = null;

export function useCards() {
  return {
    get cards() { return cards; },
    get loading() { return loading; },
    get error() { return error; },
    get fase() { return fase; },
    get loadMs() { return loadMs; },
    get filter() { return filter; },
    set filter(v: string) { filter = v; },
    get sortBy() { return sortBy; },
    set sortBy(v: "id" | "atk" | "def") { sortBy = v; },
    get selectedId() { return selectedId; },
    set selectedId(v: string | null) { selectedId = v; },
    get generation() { return generation; },
    get filters() { return filters; },
    setFilters(patch: Partial<CardFilters>) { filters = { ...filters, ...patch }; },
    resetFilters() { filters = { ...EMPTY_FILTERS, types: [], attrs: [] }; filter = ""; },
    get activeFilterCount() {
      let n = 0;
      if (filters.types.length) n++;
      if (filters.attrs.length) n++;
      if (filters.atkMin !== null || filters.atkMax !== null) n++;
      if (filters.defMin !== null || filters.defMax !== null) n++;
      return n;
    },
    get filtered() {
      const hasFilter = filter !== "";
      const sorted = sortBy !== "id";
      const f = filters;
      const hasAdv = f.types.length > 0 || f.attrs.length > 0
        || f.atkMin !== null || f.atkMax !== null
        || f.defMin !== null || f.defMax !== null;
      let list: Card[];
      if (!hasFilter && !sorted && !hasAdv) {
        list = cards;
      } else {
        list = [...cards];
        if (hasFilter) {
          const q = filter.toLowerCase();
          list = list.filter(c => c.id.toLowerCase().includes(q) || (c.name ?? "").toLowerCase().includes(q)
            || String(c.attack ?? "").includes(q) || String(c.defense ?? "").includes(q));
        }
        if (hasAdv) {
          list = list.filter(c => {
            if (f.types.length && !f.types.includes(typeGroupOf(c.card_type))) return false;
            if (f.attrs.length && !f.attrs.includes(c.attribute ?? "")) return false;
            const atk = c.attack ?? 0;
            if (f.atkMin !== null && atk < f.atkMin) return false;
            if (f.atkMax !== null && atk > f.atkMax) return false;
            const def = c.defense ?? 0;
            if (f.defMin !== null && def < f.defMin) return false;
            if (f.defMax !== null && def > f.defMax) return false;
            return true;
          });
        }
        if (sortBy === "atk") list.sort((a, b) => (b.attack ?? 0) - (a.attack ?? 0));
        else if (sortBy === "def") list.sort((a, b) => (b.defense ?? 0) - (a.defense ?? 0));
        else list.sort((a, b) => a.id.localeCompare(b.id));
      }
      return list;
    },
    get selected() { return cards.find(c => c.id === selectedId) ?? null; },
    idMap() {
      if (!indexCache || indexCache.arr !== cards) {
        const map = new Map<string, Card>();
        for (const c of cards) map.set(c.id, c);
        indexCache = { arr: cards, map };
      }
      return indexCache.map;
    },
    async loadAll() {
      const gen = ++generation;
      loading = true; error = null;
      fase = "Lendo lista de cartas…";
      const t0 = (typeof performance !== "undefined") ? performance.now() : Date.now();
      try {
        const res = await fetchCartas();
        if (gen !== generation) return;
        // Entrega a lista em 1 lote (a lista da tela já é virtualizada: só
        // as linhas visíveis vão ao DOM). Cede 1 frame para a fase pintar.
        await new Promise((r) => setTimeout(r, 0));
        if (gen !== generation) return;
        cards = res;
        loadMs = Math.round(((typeof performance !== "undefined") ? performance.now() : Date.now()) - t0);
        if (!emTauri() && res.length) error = null;
      } catch (e) { if (gen === generation) error = errMsg(e); }
      finally { if (gen === generation) { loading = false; fase = null; } }
    },
    // Salva a carta no disco (projects/default/cards/<id>.json via Rust).
    async update(card: Card) {
      const { file: _drop, ...data } = card;
      try {
        await invokeSave("salvar_carta", { carta: data });
        const idx = cards.findIndex(c => c.id === card.id);
        if (idx >= 0) cards[idx] = { ...card };
        else cards = [...cards, { ...card }];
        return card;
      } catch (e) { error = errMsg(e); throw e; }
    },
    // Preview unificado (doc 10): valida + salva + abre o Astralis de verdade.
    async play(card: Card) {
      const { file: _drop, ...data } = card;
      const res: { mensagem?: unknown } = await invokeSave("jogar_carta", { carta: data }, 120000);
      return String(res?.mensagem ?? "Astralis aberto");
    },
  };
}
