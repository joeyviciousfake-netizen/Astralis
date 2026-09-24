// purpose: esqueleto único de seção (mount + listeners ISO/save + flash).
// Antes cada seção copiava: createSaveFlash + onMount com ensure/load +
// addEventListener(fm-iso-loaded/fm-save-request) + cleanup com
// clearSaveTimer. Mesma ordem aqui: mount primeiro, listeners depois.
import { createSaveFlash } from "$lib/stores/saveFlash.svelte";
import { onIsoChanged, onSaveRequested } from "$lib/stores/isoVersion.svelte";
import { onMount } from "svelte";

export function useSectionShell(opts: {
  /** roda no mount, antes dos listeners (ensureLoaded/loadNames/...) */
  mount?: () => void;
  /** recarrega na troca de ISO */
  onIso?: () => void;
  /** salva no Ctrl+S global (o chamador checa saving/dirty) */
  onSave?: () => void;
  /** listeners extras de window ([evento, handler], removidos no cleanup) */
  extra?: Array<[string, (e: never) => void]>;
  /** limpeza extra (rAF, timers próprios) — roda depois das remoções */
  cleanup?: () => void;
  /** okMs do toast (padrão 3000) */
  flashMs?: number;
}) {
  const flash =
    opts.flashMs === undefined ? createSaveFlash() : createSaveFlash(opts.flashMs);
  onMount(() => {
    opts.mount?.();
    const offs: Array<() => void> = [];
    if (opts.onIso) {
      const h = () => opts.onIso?.();
      offs.push(onIsoChanged(h));
    }
    if (opts.onSave) {
      const s = () => opts.onSave?.();
      offs.push(onSaveRequested(s));
    }
    for (const [ev, fn] of opts.extra ?? []) {
      window.addEventListener(ev, fn as EventListener);
      offs.push(() => window.removeEventListener(ev, fn as EventListener));
    }
    return () => {
      for (const off of offs) off();
      flash.clearSaveTimer();
      opts.cleanup?.();
    };
  });
  return flash;
}
