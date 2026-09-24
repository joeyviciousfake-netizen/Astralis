import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import { onIsoChanged } from "$lib/stores/isoVersion.svelte";
import snapshot from "../../generated/cards-snapshot.json";

// Duelista Astralis (schemas/duelist.schema.json). Editável no Studio (dado
// puro); quem joga e valida de verdade é o Astralis (R1/R4).
export type Duelist = {
  file?: string;
  schema_version?: number;
  id: string;
  name: string;
  portrait?: string;
  sprite?: string;
  deck_id?: string;
  starting_lp?: number;
  ai_preset?: { dificuldade?: string; agressividade?: number; uso_fusao?: number; protecao_lp?: number };
  arena?: string;
  music?: string;
};

export type DuelistDeck = {
  duelist_id: string;
  name: string;
  deck_id: string;
  deck_name: string;
  cards: string[];
};

type Snap = { duelists?: Array<{ file: string; data: Duelist }>; decks?: Array<{ file: string; data: { id?: string; name?: string; cards?: string[] } }> };

async function fetchDuelists(): Promise<Duelist[]> {
  try {
    const res = await invokeLoad<Array<{ file: string; data: Duelist }>>("listar_duelistas");
    return res.map((d) => ({ ...d.data, file: d.file }));
  } catch {
    return ((snapshot as Snap).duelists ?? []).map((d) => ({ ...d.data, file: d.file }));
  }
}

async function fetchDeck(deckId: string): Promise<{ name: string; cards: string[] }> {
  try {
    return await invokeLoad("ler_deck", { deckId });
  } catch {
    const decks = (snapshot as Snap).decks ?? [];
    const hit = decks.find((d) => d.data.id === deckId);
    if (!hit) throw new Error(`Deck "${deckId}" não encontrado`);
    return { name: hit.data.name ?? deckId, cards: hit.data.cards ?? [] };
  }
}

let duelistNames = $state<Array<{ id: string; name: string }> | null>(null);
let duelistsFull = $state<Duelist[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);
let generation = $state(0);
let namesPending: Promise<void> | null = null;
let dropsCache = new Map<string, DuelistDeck>();
let dropsInflight = new Map<string, Promise<DuelistDeck>>();

export function useDuelists() {
  return {
    get duelistNames() { return duelistNames; },
    get duelists() { return duelistsFull; },
    get loading() { return loading; },
    get error() { return error; },
    get generation() { return generation; },
    async ensureNamesLoaded() {
      if (duelistNames !== null) return;
      if (namesPending) return namesPending;
      loading = true; error = null;
      const gen = generation;
      namesPending = (async () => {
        try {
          const res = await fetchDuelists();
          if (gen !== generation) return;
          duelistsFull = res;
          duelistNames = res.map((d) => ({ id: d.id, name: d.name }));
        } catch (e) {
          if (gen === generation) {
            error = errMsg(e);
            duelistNames = null;
          }
        } finally {
          if (gen === generation) loading = false;
          namesPending = null;
        }
      })();
      return namesPending;
    },
    clear() {
      generation++;
      duelistNames = null;
      duelistsFull = [];
      error = null;
      namesPending = null;
      dropsCache.clear();
      dropsInflight.clear();
    },
    getById(id: string): Duelist | null {
      return duelistsFull.find((d) => d.id === id) ?? null;
    },
    // Salva o duelista no disco (schemas/examples/duelists/<id>.json via Rust,
    // que valida antes). Atualiza a lista local.
    async save(d: Duelist) {
      const { file: _drop, ...data } = d;
      const res: { mensagem?: unknown } = await invokeSave("salvar_duelista", { duelista: data });
      const idx = duelistsFull.findIndex((x) => x.id === d.id);
      if (idx >= 0) duelistsFull[idx] = { ...d };
      else duelistsFull = [...duelistsFull, { ...d }];
      duelistNames = duelistsFull.map((x) => ({ id: x.id, name: x.name }));
      dropsCache.delete(d.id);
      dropsInflight.delete(d.id);
      return String(res?.mensagem ?? "Duelista salvo");
    },
    async validate(d: Duelist): Promise<Array<{ campo: string; mensagem: string }>> {
      const { file: _drop, ...data } = d;
      return invokeLoad("validar_duelista", { duelista: data });
    },
    async reload() {
      generation++;
      duelistNames = null;
      namesPending = null;
      dropsCache.clear();
      dropsInflight.clear();
      await this.ensureNamesLoaded();
    },
    // Deck do duelista (leitura): lista de IDs de carta + nome do deck.
    async getDuelist(id: string): Promise<DuelistDeck> {
      const hit = dropsCache.get(id);
      if (hit) return hit;
      const inflight = dropsInflight.get(id);
      if (inflight) return inflight;
      const gen = generation;
      const p: Promise<DuelistDeck> = (async () => {
        try {
          const d = this.getById(id);
          if (!d) throw new Error(`Duelista "${id}" não encontrado`);
          if (!d.deck_id) throw new Error(`Duelista "${d.name}" não tem deck ligado`);
          const deck = await fetchDeck(d.deck_id);
          if (gen !== generation) throw new Error("dados recarregados");
          const out: DuelistDeck = { duelist_id: id, name: d.name, deck_id: d.deck_id, deck_name: deck.name, cards: deck.cards };
          dropsCache.set(id, out);
          return out;
        } finally {
          dropsInflight.delete(id);
        }
      })();
      dropsInflight.set(id, p);
      return p;
    },
  };
}

onIsoChanged(() => {
  useDuelists().clear();
});
