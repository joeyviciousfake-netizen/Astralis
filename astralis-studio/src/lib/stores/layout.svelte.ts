import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import oficialJson from "../../../../schemas/examples/layouts/card_layout_monster_default.json";

// Molde da carta (schemas/card_layout.schema.json V1): o MESMO dado que o
// jogo lê em projects/default/layouts/ via --project (comandos Tauri
// ler_card_layout/salvar_card_layout/validar_molde, R1/R4). O Studio EDITA o
// dado; quem desenha é o Astralis (card_layout.gd + card_view.gd) e o
// CardPreview (que lê este mesmo molde). V1 = só o molde de monstro, 9 kinds
// fechados, sem campo novo na carta.

export type PecaRect = { x: number; y: number; w: number; h: number };
export type PecaStyle = {
  font_size?: number;
  bold?: boolean;
  color?: string;
  align?: string;
  z?: number;
};
export type Peca = {
  id: string;
  kind: string;
  rect?: PecaRect;
  style?: PecaStyle;
  visible_when?: string;
};
export type Molde = {
  schema_version: number;
  id: string;
  name: string;
  description?: string;
  layout_for?: string;
  canvas?: { w: number; h: number; unit: string };
  pieces: Peca[];
};
export type ErroMolde = { campo: string; campo_id?: string; mensagem: string; nivel?: string };

// Ordem visual na carta (de cima para baixo; moldura por último por ser fundo).
export const PECAS_ORDEM: Array<{ kind: string; nome: string; dica: string }> = [
  { kind: "name", nome: "Nome", dica: "vem do nome da carta" },
  { kind: "attribute_orb", nome: "Orbe de atributo", dica: "posição daqui; cor vem do atributo" },
  { kind: "level_stars", nome: "Estrelas", dica: "quantidade = nível da carta" },
  { kind: "art_window", nome: "Janela da arte", dica: "vem da imagem da carta" },
  { kind: "type_line", nome: "Linha de tipo", dica: "tipo do monstro" },
  { kind: "text_box", nome: "Caixa de texto", dica: "vem da descrição" },
  { kind: "atkdef_bar", nome: "Barra ATK/DEF", dica: "só aparece em monstro" },
  { kind: "footer", nome: "Rodapé", dica: "id da carta + ©" },
  { kind: "frame", nome: "Moldura", dica: "fundo e borda — cobre a carta toda" },
];
export const KINDS = PECAS_ORDEM.map((p) => p.kind);
// Peças com texto (só nelas fonte/cor/alinhamento fazem efeito; nas outras a
// cor vem do atributo/imagem/fundo — igual ao jogo).
export const KINDS_TEXTO = ["name", "level_stars", "type_line", "text_box", "atkdef_bar", "footer"];

const oficial = oficialJson as unknown as Molde;

function clonar<T>(v: T): T {
  return JSON.parse(JSON.stringify(v));
}

// Cópia nova do oficial a cada chamada (sem estado compartilhado).
export function moldePadrao(): Molde {
  return clonar(oficial);
}

export function pecaOficial(kind: string): Peca | null {
  return clonar(oficial.pieces.find((p) => p.kind === kind) ?? null);
}

export function nomePeca(kind: string): string {
  return PECAS_ORDEM.find((p) => p.kind === kind)?.nome ?? kind;
}

// Extrai o kind citado entre aspas na mensagem de erro do Rust
// (ex.: Peça "name" repetida) para o "onde clicar" levar até a peça.
export function kindDoErro(mensagem: string): string | null {
  const m = /"([a-z_]+)"/.exec(mensagem ?? "");
  if (m && (KINDS as string[]).includes(m[1])) return m[1];
  return null;
}

let molde = $state<Molde | null>(null);
let loading = $state(false);
let error = $state<string | null>(null);
let generation = $state(0);
let pending: Promise<void> | null = null;

export function useLayout() {
  return {
    get molde() { return molde; },
    get loading() { return loading; },
    get error() { return error; },
    async ensureLoaded() {
      if (pending) return pending;
      if (molde) return;
      loading = true;
      error = null;
      const gen = ++generation;
      pending = (async () => {
        try {
          const res = await invokeLoad<Molde>("ler_card_layout");
          if (gen !== generation) return;
          molde = { ...res, pieces: [...(res.pieces ?? [])] };
        } catch (e) {
          // Navegador (sem Tauri): mostra o oficial para editar à vontade; o
          // Salvar avisa para abrir pelo app. Nada em silêncio.
          if (gen !== generation) return;
          molde = moldePadrao();
          error = `Sem o app, mostrando o molde padrão oficial. Para salvar, abra pelo app.bat. (${errMsg(e)})`;
        } finally {
          if (gen === generation) loading = false;
          pending = null;
        }
      })();
      return pending;
    },
    async reload() {
      generation++;
      molde = null;
      pending = null;
      await this.ensureLoaded();
    },
    // Valida sem gravar (mesma lista PT-BR de onde clicar do salvar).
    async validate(m: Molde): Promise<ErroMolde[]> {
      return invokeLoad<ErroMolde[]>("validar_molde", { molde: m });
    },
    // Salva o molde inteiro (o Rust valida antes; inválido não grava).
    async save(m: Molde): Promise<string> {
      const res: { mensagem?: unknown } = await invokeSave("salvar_card_layout", { molde: m });
      molde = clonar(m);
      return String(res?.mensagem ?? "Molde salvo");
    },
  };
}
