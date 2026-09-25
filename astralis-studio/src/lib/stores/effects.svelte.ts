import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import snapshot from "../../generated/cards-snapshot.json";

// Efeitos Astralis (schemas/effect.schema.json + examples/effects.json):
// blocos trigger→conditions→target→actions→flow. O Studio monta e valida o
// DADO; a execução vem depois (motor não existe no runtime — R4). Por isso
// NÃO há Testar/Play aqui, só Validar + Salvar.
export type EffectCondition = { field: string; operator: string; value: number | string };
export type EffectAction = { action: string; amount?: number; duration?: string };
export type Effect = {
  id: string;
  name: string;
  description?: string;
  trigger: string;
  conditions: EffectCondition[];
  target: string;
  actions: EffectAction[];
  flow: { mode: string };
};
export type EffectsFile = { schema_version?: number; effects: Effect[] };

type Snap = { effects?: Effect[] };

function vazio(): EffectsFile {
  return { schema_version: 1, effects: [] };
}

async function fetchEfeitos(): Promise<EffectsFile> {
  try {
    const raw = await invokeLoad<EffectsFile>("ler_efeitos");
    return { schema_version: 1, effects: raw.effects ?? [] };
  } catch {
    return { schema_version: 1, effects: (snapshot as Snap).effects ?? [] };
  }
}

let dado = $state<EffectsFile>(vazio());
let loading = $state(false);
let error = $state<string | null>(null);
let generation = $state(0);
let pending: Promise<void> | null = null;

export function useEffects() {
  return {
    get dado() { return dado; },
    get loading() { return loading; },
    get error() { return error; },
    async ensureLoaded() {
      if (pending) return pending;
      if (dado.effects.length) return;
      loading = true;
      error = null;
      const gen = ++generation;
      pending = (async () => {
        try {
          const res = await fetchEfeitos();
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
    setLocal(next: EffectsFile) {
      dado = next;
    },
    // Salva o arquivo inteiro (projects/default/effects.json via Rust, que
    // valida cada bloco antes). Formato preservado.
    async save(next: EffectsFile) {
      const res: { mensagem?: unknown } = await invokeSave("salvar_efeitos", { dado: { schema_version: 1, effects: next.effects } });
      dado = { schema_version: 1, effects: next.effects.map((e) => ({ ...e, conditions: e.conditions.map((c) => ({ ...c })), actions: e.actions.map((a) => ({ ...a })), flow: { ...e.flow } })) };
      return String(res?.mensagem ?? "Efeitos salvos");
    },
    async validateOne(ef: Effect): Promise<Array<{ campo: string; mensagem: string }>> {
      return invokeLoad("validar_efeito", { efeito: ef });
    },
  };
}

// Modelos prontos do Modo Simples (doc 07 §7.4): só preenchem o builder com o
// mesmo formato. Nada aqui executa — é atalho de autoria.
export const TEMPLATES: Array<{ id: string; nome: string; desc: string; efeito: Effect }> = [
  {
    id: "tpl_dano", nome: "Dano ao invocar", desc: "Quando entra, tira LP do oponente",
    efeito: { id: "", name: "Dano ao invocar", description: "", trigger: "card_summoned", conditions: [], target: "opponent", actions: [{ action: "damage", amount: 500 }], flow: { mode: "sequence" } },
  },
  {
    id: "tpl_enfraquecer", nome: "Enfraquecer inimigo", desc: "Quando entra, baixa o ATK de 1 inimigo",
    efeito: { id: "", name: "Enfraquecer inimigo", description: "", trigger: "card_summoned", conditions: [{ field: "opponent_monster_attack", operator: ">=", value: 1000 }], target: "enemy_monster", actions: [{ action: "modify_attack", amount: -500, duration: "until_end_of_turn" }], flow: { mode: "sequence" } },
  },
  {
    id: "tpl_comprar", nome: "Comprar carta", desc: "Quando entra, você compra cartas",
    efeito: { id: "", name: "Comprar carta", description: "", trigger: "card_summoned", conditions: [], target: "self_player", actions: [{ action: "draw", amount: 1 }], flow: { mode: "sequence" } },
  },
  {
    id: "tpl_destruir", nome: "Destruir ao morrer", desc: "Quando morre, leva 1 inimigo junto",
    efeito: { id: "", name: "Destruir ao morrer", description: "", trigger: "card_destroyed", conditions: [], target: "enemy_monster", actions: [{ action: "destroy" }], flow: { mode: "sequence" } },
  },
];

export const TRIGGER_OPS: Array<{ id: string; nome: string }> = [
  { id: "card_summoned", nome: "Quando esta carta entra em campo" },
  { id: "card_destroyed", nome: "Quando esta carta é destruída" },
  { id: "turn_started", nome: "No começo do turno" },
  { id: "turn_finished", nome: "No fim do turno" },
  { id: "attack_started", nome: "Quando um ataque começa" },
  { id: "damage_dealt", nome: "Quando dano é causado" },
];

export const TARGET_OPS: Array<{ id: string; nome: string }> = [
  { id: "self", nome: "Esta carta" },
  { id: "self_player", nome: "Eu (jogador)" },
  { id: "opponent", nome: "Oponente (LP)" },
  { id: "ally_monster", nome: "1 monstro meu" },
  { id: "enemy_monster", nome: "1 monstro inimigo" },
  { id: "all_ally_monsters", nome: "Todos os meus monstros" },
  { id: "all_enemy_monsters", nome: "Todos os inimigos" },
  { id: "selected_card", nome: "1 carta escolhida" },
  { id: "random_card", nome: "1 carta aleatória" },
  { id: "card_in_graveyard", nome: "1 carta do cemitério" },
  { id: "card_in_hand", nome: "1 carta da mão" },
];

export const ACTION_OPS: Array<{ id: string; nome: string }> = [
  { id: "damage", nome: "Causar dano (LP)" },
  { id: "heal", nome: "Recuperar LP" },
  { id: "modify_attack", nome: "Mudar ATK" },
  { id: "modify_defense", nome: "Mudar DEF" },
  { id: "destroy", nome: "Destruir" },
  { id: "draw", nome: "Comprar carta" },
  { id: "discard", nome: "Descartar carta" },
];

export const COND_FIELDS: Array<{ id: string; nome: string }> = [
  { id: "opponent_monster_attack", nome: "ATK do monstro inimigo" },
  { id: "player_lp", nome: "Meu LP" },
  { id: "opponent_lp", nome: "LP do oponente" },
  { id: "attribute", nome: "Atributo" },
  { id: "monster_type", nome: "Tipo de monstro" },
];

export const DURATIONS: Array<{ id: string; nome: string }> = [
  { id: "until_end_of_turn", nome: "Até o fim do turno" },
  { id: "this_turn", nome: "Só neste turno" },
  { id: "permanent", nome: "Para sempre" },
];

// Texto humano DERIVADO do dado (doc 07: texto é exibição, nunca lógica).
export function textoDerivado(ef: Effect): string {
  const trig = TRIGGER_OPS.find((t) => t.id === ef.trigger)?.nome ?? ef.trigger;
  const alvo = TARGET_OPS.find((t) => t.id === ef.target)?.nome ?? ef.target;
  const acoes = ef.actions.map((a) => {
    switch (a.action) {
      case "damage": return `causa ${a.amount ?? "?"} de dano`;
      case "heal": return `recupera ${a.amount ?? "?"} de LP`;
      case "modify_attack": return `muda o ATK em ${a.amount ?? "?"}`;
      case "modify_defense": return `muda a DEF em ${a.amount ?? "?"}`;
      case "destroy": return "destrói";
      case "draw": return `compra ${a.amount ?? "?"} carta(s)`;
      case "discard": return `descarta ${a.amount ?? "?"} carta(s)`;
      default: return a.action;
    }
  });
  const conds = ef.conditions.length
    ? `, se ${ef.conditions.map((c) => `${COND_FIELDS.find((f) => f.id === c.field)?.nome ?? c.field} ${c.operator} ${c.value}`).join(" e ")}`
    : "";
  return `${trig}${conds}: ${acoes.join(", depois ") || "(sem ação)"} em ${alvo}.`;
}
