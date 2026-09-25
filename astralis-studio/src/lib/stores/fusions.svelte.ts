import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import snapshot from "../../generated/cards-snapshot.json";

// Fusões Astralis (schemas/fusion.schema.json + examples/fusions.json):
// receitas explícitas A+B=C (prioridade máxima) + regras genéricas fallback.
// O Studio só edita e confere o dado; quem funde de verdade é o Astralis (R1).
export type FusionRecipe = {
  id: string;
  input: { card_a: string; card_b: string };
  result: string;
};
export type FusionRule = {
  id: string;
  when: { type_a?: string; attribute_a?: string; type_b?: string; attribute_b?: string; min_atk?: number };
  result: string;
  priority: number;
};
export type FusionsFile = { schema_version?: number; recipes: FusionRecipe[]; rules: FusionRule[] };
export type FusionTest = { achou: boolean; tipo: string; resultado: string; nome: string; mensagem: string };

type Snap = { fusions?: FusionsFile | { recipe_count: number; rule_count: number } };

function vazio(): FusionsFile {
  return { schema_version: 1, recipes: [], rules: [] };
}

async function fetchFusoes(): Promise<FusionsFile> {
  try {
    const raw = await invokeLoad<FusionsFile>("ler_fusoes");
    return { schema_version: 1, recipes: raw.recipes ?? [], rules: raw.rules ?? [] };
  } catch {
    // Snapshot enxuto (pós-pack FM): traz só a contagem, não as 25 mil
    // receitas — no navegador a aba Fusões pede o app.
    const snap = (snapshot as Snap).fusions;
    if (snap && Array.isArray((snap as FusionsFile).recipes)) {
      const f = snap as FusionsFile;
      return { schema_version: 1, recipes: f.recipes ?? [], rules: f.rules ?? [] };
    }
    if (snap && typeof (snap as { recipe_count?: number }).recipe_count === "number") {
      const c = snap as { recipe_count: number; rule_count: number };
      throw new Error(`Este projeto tem ${c.recipe_count} fusões e o navegador não carrega essa lista. Abra o app pelo app.bat para editar.`);
    }
    // Projeto vazio (o Studio abre vazio, D29) não é erro: é o estado normal.
    throw new Error("Este projeto está vazio — importe um pack (botão 📥 Importar) para ter fusões para editar.");
  }
}

let dado = $state<FusionsFile>(vazio());
let loading = $state(false);
let error = $state<string | null>(null);
let generation = $state(0);
let pending: Promise<void> | null = null;

export function useFusions() {
  return {
    get dado() { return dado; },
    get loading() { return loading; },
    get error() { return error; },
    async ensureLoaded() {
      if (pending) return pending;
      if (dado.recipes.length || dado.rules.length) return;
      loading = true;
      error = null;
      const gen = ++generation;
      pending = (async () => {
        try {
          const res = await fetchFusoes();
          if (gen !== generation) return;
          dado = res;
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
      dado = vazio();
      pending = null;
      await this.ensureLoaded();
    },
    setLocal(next: FusionsFile) {
      dado = next;
    },
    // Salva o arquivo inteiro (projects/default/fusions.json via Rust, que
    // valida receitas + regras antes). Formato preservado.
    async save(next: FusionsFile) {
      const res: { mensagem?: unknown } = await invokeSave("salvar_fusoes", { dado: { schema_version: 1, recipes: next.recipes, rules: next.rules } });
      dado = { schema_version: 1, recipes: next.recipes.map((r) => ({ ...r })), rules: next.rules.map((r) => ({ ...r, when: { ...r.when } })) };
      return String(res?.mensagem ?? "Fusões salvas");
    },
    // Testar = só confere o dado (receita exata vence, regra é fallback).
    // Não executa jogo (R1): o motor de fusão não existe no runtime.
    async testar(cardA: string, cardB: string): Promise<FusionTest> {
      return invokeLoad("testar_fusao", { cardA, cardB });
    },
  };
}
