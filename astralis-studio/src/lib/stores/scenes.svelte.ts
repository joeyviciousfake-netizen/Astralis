import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";

// Cenas simples (bloco 6): JSON em campaign/scenes/<id>.json.
// Formato documentado no README do editor; schema formal fica p/ depois.
// Sem grafo/timeline agora: só lista de falas. Sem Play (o Astralis ainda não
// lê esse formato — R4, sem fingir).
export type CenaLinha = { character: string; text: string; background?: string };
export type Cena = {
  file?: string;
  schema_version?: number;
  id: string;
  name: string;
  background?: string;
  lines: CenaLinha[];
};

async function fetchCenas(): Promise<Cena[]> {
  const res = await invokeLoad<Array<{ file: string; data: Cena }>>("listar_cenas");
  return res.map((c) => ({ ...c.data, file: c.file }));
}

let cenas = $state<Cena[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);
let generation = $state(0);
let pending: Promise<void> | null = null;

export function useCenas() {
  return {
    get cenas() { return cenas; },
    get loading() { return loading; },
    get error() { return error; },
    async ensureLoaded() {
      if (pending) return pending;
      if (cenas.length) return;
      loading = true;
      error = null;
      const gen = ++generation;
      pending = (async () => {
        try {
          const res = await fetchCenas();
          if (gen !== generation) return;
          cenas = res;
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
      cenas = [];
      pending = null;
      await this.ensureLoaded();
    },
    getById(id: string): Cena | null {
      return cenas.find((c) => c.id === id) ?? null;
    },
    // Salva em campaign/scenes/<id>.json via Rust (valida antes).
    async save(c: Cena) {
      const { file: _drop, ...data } = c;
      const res: { mensagem?: unknown } = await invokeSave("salvar_cena", { cena: data });
      const idx = cenas.findIndex((x) => x.id === c.id);
      if (idx >= 0) cenas[idx] = { ...c };
      else cenas = [...cenas, { ...c }];
      return String(res?.mensagem ?? "Cena salva");
    },
    async validate(c: Cena): Promise<Array<{ campo: string; mensagem: string }>> {
      const { file: _drop, ...data } = c;
      return invokeLoad("validar_cena", { cena: data });
    },
  };
}
