import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import snapshot from "../../generated/cards-snapshot.json";

// Deck Astralis (schemas/deck.schema.json): só id + nome + lista de Card IDs
// (R3). Alvo do jogo: 40 cartas (doc 14); schema aceita 20..60.
export type Deck = {
  file?: string;
  schema_version?: number;
  id: string;
  name: string;
  cards: string[];
};

type Snap = { decks?: Array<{ file: string; data: Deck }> };

async function fetchDecks(): Promise<Deck[]> {
  try {
    const res = await invokeLoad<Array<{ file: string; data: Deck }>>("listar_decks");
    return res.map((d) => ({ ...d.data, file: d.file }));
  } catch {
    return ((snapshot as Snap).decks ?? []).map((d) => ({ ...d.data, file: d.file }));
  }
}

let decks = $state<Deck[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);
let generation = $state(0);
let pending: Promise<void> | null = null;

export function useDecks() {
  return {
    get decks() { return decks; },
    get loading() { return loading; },
    get error() { return error; },
    async ensureLoaded() {
      if (pending) return pending;
      if (decks.length) return;
      loading = true;
      error = null;
      const gen = ++generation;
      pending = (async () => {
        try {
          const res = await fetchDecks();
          if (gen !== generation) return;
          decks = res;
        } catch (e) {
          if (gen === generation) error = errMsg(e);
        } finally {
          if (gen === generation) loading = false;
          pending = null;
        }
      })();
      return pending;
    },
    async reload() {
      generation++;
      decks = [];
      pending = null;
      await this.ensureLoaded();
    },
    getById(id: string): Deck | null {
      return decks.find((d) => d.id === id) ?? null;
    },
    // Salva o deck no disco (projects/default/decks/<id>.json via Rust, que
    // valida: 20..60 cartas + IDs precisam existir). Atualiza a lista local.
    async save(d: Deck) {
      const { file: _drop, ...data } = d;
      const res: { mensagem?: unknown } = await invokeSave("salvar_deck", { deck: data });
      const idx = decks.findIndex((x) => x.id === d.id);
      if (idx >= 0) decks[idx] = { ...d };
      else decks = [...decks, { ...d }];
      return String(res?.mensagem ?? "Deck salvo");
    },
    async validate(d: Deck): Promise<Array<{ campo: string; mensagem: string; nivel?: string }>> {
      const { file: _drop, ...data } = d;
      return invokeLoad("validar_deck", { deck: data });
    },
  };
}
