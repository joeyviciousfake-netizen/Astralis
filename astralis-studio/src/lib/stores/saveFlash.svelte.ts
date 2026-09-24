// saveFlash — toast de save em UM lugar. Antes o trio
// (saveMsg/saveOk/saveTimer + flashSave) vivia copiado em 7 componentes
// com dois dialetos de duração e fragile `msg.includes('Salvo')`.
export function createSaveFlash(okMs = 3000, errMs = 4000) {
  let saveMsg = $state("");
  let saveOk = $state(false);
  let saveTimer: ReturnType<typeof setTimeout> | null = null;
  function flashSave(msg: string, ok: boolean) {
    saveMsg = msg;
    saveOk = ok;
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(() => { saveMsg = ""; }, ok ? okMs : errMs);
  }
  function clearSaveTimer() {
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = null;
  }
  function clear() {
    clearSaveTimer();
    saveMsg = "";
  }
  return {
    get saveMsg() { return saveMsg; },
    get saveOk() { return saveOk; },
    flashSave,
    clearSaveTimer,
    clear,
  };
}
