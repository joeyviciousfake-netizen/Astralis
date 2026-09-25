// saveBus — barramento tipado do pedido de salvar (Ctrl+S / botão Salvar).
// Transporte via inscritos (1 chamada por consumidor, sem falha silenciosa de
// string). Emissor: +page (Ctrl+S e o botão Salvar).
// Antes este arquivo tinha também o canal "ISO" (onIsoChanged/bumpIso e um
// contador de versão que ninguém lia): como o projeto abre sempre VAZIO
// (D29), ninguém emite "trocar de ISO" — o canal era código morto em 8 lugares
// e saiu daqui junto dos comentários sobre abrir ISO.
type Listener = () => void;
const saveListeners = new Set<Listener>();

/// Assina "salvar pedido" (Ctrl+S / botão Salvar). Devolve o unsubscribe.
export function onSaveRequested(fn: Listener): () => void {
  saveListeners.add(fn);
  return () => { saveListeners.delete(fn); };
}

/// Ctrl+S / botão salvar: avisa os inscritos.
export function requestSave() {
  // Paridade com o DOM: 1 ouvinte quebrado não cala os demais (erro no console).
  for (const fn of [...saveListeners]) {
    try {
      fn();
    } catch (e) {
      console.error("[astralis-studio] ouvinte de salvar falhou:", e);
    }
  }
}
