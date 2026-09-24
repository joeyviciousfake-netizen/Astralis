// quickDuel — atalho "Jogar com ele" da aba Duelistas para a aba Duelo.
// Só carrega os selects (d1/d2); quem abre o Astralis de verdade é o Play da
// aba Duelo (jogar_duelo). Sem simulação (R1).
let d1 = $state<string | null>(null);
let d2 = $state<string | null>(null);
let nonce = $state(0);

export function useQuickDuel() {
  return {
    get d1() { return d1; },
    get d2() { return d2; },
    get nonce() { return nonce; },
    pedir(duelista1: string, duelista2: string) {
      d1 = duelista1;
      d2 = duelista2;
      nonce++;
      if (typeof window !== "undefined") {
        window.dispatchEvent(new CustomEvent("astralis:ir-duelo"));
      }
    },
  };
}
