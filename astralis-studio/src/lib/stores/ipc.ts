import { invoke } from "@tauri-apps/api/core";

// R ALTO: timeout padrão para todo IPC de load (antes só a FusionSection tinha
// 15s; os demais loads giravam para sempre se o backend pendurasse —
// precedente "mod CDZ", carta 001 no `Carregando…` infinito).
export const IPC_TIMEOUT_MS = 15000;

export function withTimeout<T>(p: Promise<T>, ms = IPC_TIMEOUT_MS): Promise<T> {
  let t: ReturnType<typeof setTimeout> | null = null;
  const timeout = new Promise<never>((_, rej) => {
    t = setTimeout(() => rej(new Error(`Tempo esgotado após ${ms / 1000}s — tente de novo`)), ms);
  });
  return Promise.race([p, timeout]).finally(() => {
    if (t) clearTimeout(t);
  });
}

/// Invoke com timeout padrão (loads). Para saves usar `invokeSave`
/// (escrita pode legitimamente demorar em ISO 517MB — 60s em vez de
/// infinito; antes um save pendurado travava `saving=true` para sempre).
export const SAVE_TIMEOUT_MS = 60000;

export function invokeLoad<T>(cmd: string, args?: Record<string, unknown>, ms = IPC_TIMEOUT_MS): Promise<T> {
  return invokeWithTimeout(cmd, () => invoke<T>(cmd, args), ms);
}

export function invokeSave<T>(cmd: string, args?: Record<string, unknown>, ms = SAVE_TIMEOUT_MS): Promise<T> {
  return invokeWithTimeout(cmd, () => invoke<T>(cmd, args), ms);
}

/// Invoke com timeout que não finge abortar: o Tauri não cancela o backend,
/// então o resultado tardio é registrado como ignorado em vez de sumir em
/// silêncio (antes o WAV temporário órfão + conclusão tardia eram invisíveis).
function invokeWithTimeout<T>(cmd: string, work: () => Promise<T>, ms: number): Promise<T> {
  // work() primeiro: se lançar síncrono (mock/SSR), propaga como antes e
  // nenhum timer é criado — timer órfão rejeitaria sem inscrito (regressão
  // pega pelo teste "invoke travado": 2 unhandled "Tempo esgotado").
  const p = work();
  let timer: ReturnType<typeof setTimeout> | null = null;
  let expired = false;
  const t0 = Date.now();
  const timeout = new Promise<never>((_, rej) => {
    timer = setTimeout(() => {
      expired = true;
      rej(new Error(`Tempo esgotado após ${ms / 1000}s — tente de novo`));
    }, ms);
  });
  void p.then(
    () => { if (expired) logIpc(cmd, Date.now() - t0, null, true); },
    (e) => { if (expired) logIpc(cmd, Date.now() - t0, e instanceof Error ? e.message : String(e), true); },
  );
  return timed(cmd, Promise.race([p, timeout]).finally(() => {
    if (timer) clearTimeout(timer);
  }));
}

/// Log de diagnóstico em lote: eventos acumulam em memória e descarregam de
/// 2s em 2s numa chamada só (1 IPC em vez de N — a mesa dispara dezenas por
/// seleção). Erro descarrega na hora. Fire-and-forget: nunca quebra o chamador.
type LogItem = { origin: string; level: string; area: string; msg: string };
let logQueue: LogItem[] = [];
let logTimer: ReturnType<typeof setTimeout> | null = null;
const LOG_FLUSH_MS = 2000;

function scheduleFlush() {
  if (logTimer !== null) return;
  logTimer = setTimeout(() => {
    logTimer = null;
    void flushDebugLog();
  }, LOG_FLUSH_MS);
}

/// Descarrega a fila agora (o visor chama antes de ler — zero defasagem lá).
export function flushDebugLog(): Promise<void> {
  if (logTimer !== null) {
    clearTimeout(logTimer);
    logTimer = null;
  }
  if (!logQueue.length) return Promise.resolve();
  const batch = logQueue;
  logQueue = [];
  return invoke("debug_push_batch", { events: batch }).then(
    () => {},
    () => {},
  );
}

function logIpc(cmd: string, ms: number, err: string | null, late = false) {
  if (cmd.startsWith("debug_")) return;
  // Nunca engolir o resultado real: invoke pode até lançar síncrono
  // (mock/SSR) — o erro do log morre aqui, o do chamador passa intacto.
  try {
    logQueue.push({
      origin: "ui",
      level: err ? "error" : "info",
      area: "ipc",
      msg: `${cmd} ${err ? `ERRO: ${err}` : `ok ${ms}ms`}${late ? " (tardio, ignorado)" : ""}`,
    });
    if (err) {
      void flushDebugLog();
    } else {
      scheduleFlush();
    }
  } catch {
    /* diagnóstico nunca quebra o app */
  }
}

/// Log de ação da UI em lote (mesma fila do hook IPC: 1 IPC a cada 2s, não 1
/// por ação — antes cada play/select emitia 2 invokes `debug_push` avulsos).
export function queueUiLog(area: string, msg: string, level = "info"): void {
  try {
    logQueue.push({ origin: "ui", level, area, msg });
    scheduleFlush();
  } catch {
    /* diagnóstico nunca quebra o app */
  }
}

function timed<T>(cmd: string, p: Promise<T>): Promise<T> {
  const t0 = Date.now();
  return p.then(
    (v) => {
      logIpc(cmd, Date.now() - t0, null);
      return v;
    },
    (e) => {
      logIpc(cmd, Date.now() - t0, e instanceof Error ? e.message : String(e));
      throw e;
    },
  );
}

/// Mensagem de erro sem `any`: Error → message, resto → String().
/// (Antes cada `catch(e: any)` repetia `String(e?.message ?? e)`.)
export function errMsg(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}
