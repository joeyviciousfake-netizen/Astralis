import { invokeLoad, invokeSave, errMsg } from "$lib/stores/ipc";
import { onSaveRequested } from "$lib/stores/saveBus.svelte";
import { fetchCartas } from "$lib/stores/cards.svelte";
import type { Card } from "$lib/stores/cards.svelte";

// Validação do PROJETO (Fase A — lint sem abrir o jogo).
//
// Pós-pack FM (762 cartas): SEM loop de 762 invokes no boot. O fluxo agora é:
// 1. `validar_projeto` (Rust, 1 invoke) → totais por área para o selo, rápido;
// 2. `validar_carta` em lotes paralelos (16 por vez) → quais cartas têm erro
//    (filtro "só com erro" da lista), com progresso real 0..1 em vez de
//    "validando…" infinito. Roda em background: a lista abre antes.
// Erros travam o Jogar; o detalhe valida só a carta aberta (Validar).
export type ValidationIssue = { system: string; level: string; card_id: string | null; message: string };
export type ValidationArea = { area: string; ok: boolean; detalhe: string };
export type ValidationReport = {
  issues: ValidationIssue[];
  error_count: number;
  warning_count: number;
  areas: ValidationArea[];
  mensagem: string;
  /** 0..1 — progresso do mapeamento por carta (1 = completo) */
  progresso: number;
  completo: boolean;
};

type ErroRust = { campo?: string; mensagem?: string; nivel?: string };
type ProjetoRust = { erros: number; avisos: number; itens: ValidationArea[]; mensagem: string };

// Lote paralelo: 16 invokes simultâneos (Tauri aguenta) em vez de 762
// sequenciais. Cada validar_carta no Rust é microssegundos + 1 leitura de
// effects.json — o gargalo era o round-trip serial, não o Rust.
const LOTE = 16;

async function validarUma(c: Card): Promise<ValidationIssue[]> {
  const { file: _drop, ...data } = c;
  const erros = await invokeLoad<ErroRust[]>("validar_carta", { carta: data });
  return erros.map((e) => ({
    system: e.campo ?? "Carta",
    // O Rust separa "erro" (trava salvar/jogar) de "aviso" (mostra, não
    // trava) — ex.: carta citando efeito que o projeto ainda não tem.
    level: e.nivel === "aviso" ? "aviso" : "erro",
    card_id: c.id,
    message: e.mensagem ?? "Carta inválida",
  }));
}

let report = $state<ValidationReport | null>(null);
let loading = $state(false);
let loadError = $state<string | null>(null);
let generation = $state(0);
let pending: Promise<void> | null = null;

export function useValidate() {
  return {
    get report() { return report; },
    get loading() { return loading; },
    get loadError() { return loadError; },
    /**
     * Revalida o projeto em background (não trava a lista).
     * @param conhecidas cartas já carregadas (evita buscar a lista 2x no boot)
     */
    async refresh(conhecidas?: Card[]) {
      if (pending) return pending;
      loading = true;
      loadError = null;
      const gen = ++generation;
      pending = (async () => {
        try {
          // Passo 1 (rápido, 1 invoke): totais por área para o selo.
          let proj: ProjetoRust;
          try {
            proj = await invokeSave<ProjetoRust>("validar_projeto", undefined, 60000);
          } catch (e) {
            if (gen !== generation) return;
            loadError = errMsg(e);
            return;
          }
          if (gen !== generation) return;
          report = {
            issues: report?.completo ? report.issues : [],
            error_count: proj.erros,
            warning_count: proj.avisos,
            areas: proj.itens ?? [],
            mensagem: proj.mensagem ?? "",
            progresso: 0.05,
            completo: false,
          };

          // Passo 2 (mapeamento por carta, em lotes paralelos, com progresso).
          const cartas = conhecidas && conhecidas.length ? conhecidas : await fetchCartas();
          if (gen !== generation) return;
          const issues: ValidationIssue[] = [];
          let falhas = 0;
          let feitos = 0;
          const total = Math.max(1, cartas.length);
          for (let i = 0; i < cartas.length; i += LOTE) {
            if (gen !== generation) return;
            const lote = cartas.slice(i, i + LOTE);
            const res = await Promise.all(
              lote.map((c) => validarUma(c).catch(() => { falhas++; return [] as ValidationIssue[]; })),
            );
            if (gen !== generation) return;
            for (const r of res) issues.push(...r);
            feitos += lote.length;
            report = {
              issues: [...issues],
              error_count: proj.erros,
              warning_count: proj.avisos,
              areas: proj.itens ?? [],
              mensagem: proj.mensagem ?? "",
              progresso: 0.05 + 0.95 * (feitos / total),
              completo: false,
            };
          }
          if (gen !== generation) return;
          if (falhas > LOTE) {
            loadError = `${falhas} cartas falharam ao validar — tente Revalidar.`;
          }
          report = {
            issues,
            error_count: proj.erros,
            warning_count: proj.avisos,
            areas: proj.itens ?? [],
            mensagem: proj.mensagem ?? "",
            progresso: 1,
            completo: true,
          };
        } catch (e) {
          if (gen === generation) { loadError = errMsg(e); }
        } finally {
          if (gen === generation) loading = false;
          pending = null;
        }
      })();
      return pending;
    },
    clear() {
      generation++;
      report = null;
      loadError = null;
      pending = null;
      loading = false;
    },
  };
}

// Revalida depois do save (best-effort com folga p/ o save terminar).
let saveTimer: ReturnType<typeof setTimeout> | null = null;
onSaveRequested(() => {
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => { void useValidate().refresh(); }, 2500);
});
