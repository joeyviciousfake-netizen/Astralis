// isoVersion — barramento tipado ISO/save (Fase 2, ADR-066).
// Substitui os eventos stringly-typed fm-iso-loaded/fm-save-request: typo
// aqui não compila, e os contadores permitem derivação/anti-stale. Transporte
// via inscritos (1 chamada por consumidor, sem falha silenciosa de string).
// Emissores: +page (abrir ISO, Ctrl+S, botão salvar). Singletons de app
// (stores) não precisam desinscrever — mesmo ciclo dos addEventListener antigos.
let isoVersion = $state(0);
let saveVersion = $state(0);

type Listener = () => void;
const isoListeners = new Set<Listener>();
const saveListeners = new Set<Listener>();

function notify(all: Set<Listener>, what: string) {
  // Paridade com o DOM: 1 ouvinte quebrado não cala os demais (erro no console).
  for (const fn of [...all]) {
    try {
      fn();
    } catch (e) {
      console.error(`[fm-studio] ouvinte ${what} falhou:`, e);
    }
  }
}

export function useIsoVersion() {
  return {
    get isoVersion() { return isoVersion; },
    get saveVersion() { return saveVersion; },
  };
}

/// Assina "ISO trocou" (devolve unsubscribe para cleanup em componentes).
export function onIsoChanged(fn: Listener): () => void {
  isoListeners.add(fn);
  return () => { isoListeners.delete(fn); };
}

/// Assina "salvar pedido" (Ctrl+S / botão). Mesmo ciclo que onIsoChanged.
export function onSaveRequested(fn: Listener): () => void {
  saveListeners.add(fn);
  return () => { saveListeners.delete(fn); };
}

/// Nova ISO carregada: incrementa a versão e avisa os inscritos.
export function bumpIso() {
  isoVersion++;
  notify(isoListeners, "iso");
}

/// Ctrl+S / botão salvar: incrementa a versão e avisa os inscritos.
export function requestSave() {
  saveVersion++;
  notify(saveListeners, "save");
}
